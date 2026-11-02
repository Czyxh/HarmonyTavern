//! OHOS adapters for the sync service graph (replaces upstream
//! `composition/adapters/tauri_sync.rs`).
//!
//! Upstream wires LAN/TT sync through six `adapters::*` helpers. Every one of them depends
//! on Tauri only through `AppHandle::emit`; the OHOS port swaps that for
//! `super::events::emit` (same event names, same payloads) so the ArkTS side sees an
//! identical contract. The two service wrappers (`ServiceSyncAutomation*`) carry no Tauri
//! dependency and are copied verbatim.

use std::collections::HashMap;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use async_trait::async_trait;
use tokio::sync::{Mutex, oneshot};
use ttsync_contract::sync::SyncMode;

use tt_application::services::lan_sync_service::LanSyncService;
use tt_application::services::tt_sync_service::TtSyncService;
use tt_contracts::lan_discovery::LanDiscoveredDevice;
use tt_contracts::sync::SyncJobEvent;
use tt_contracts::sync_automation::{SyncAutomationStatus, SyncAutomationToastEvent};
use tt_domain::errors::DomainError;
use tt_domain::models::lan_sync::LanSyncPairRequestEvent;
use tt_ports::lan_discovery::LanDiscoveryHost;
use tt_ports::lan_sync::{LanPairingApprovalRequest, LanServerEvents, PairingApproval};
use tt_ports::sync::SyncJobEventPublisher;
use tt_ports::sync_automation::{
    SyncAutomationEndpointCatalog, SyncAutomationEventPublisher, SyncAutomationLanServerControl,
};

pub fn sync_automation_events() -> Arc<dyn SyncAutomationEventPublisher> {
    Arc::new(OhosSyncAutomationEventPublisher)
}

pub fn sync_job_events() -> Arc<dyn SyncJobEventPublisher> {
    Arc::new(OhosSyncJobEventPublisher)
}

pub fn pairing_approval() -> Arc<dyn PairingApproval> {
    Arc::new(OhosPairingApproval::new())
}

pub fn lan_server_events() -> Arc<dyn LanServerEvents> {
    Arc::new(OhosLanServerEvents)
}

pub fn lan_discovery_host() -> Arc<dyn LanDiscoveryHost> {
    Arc::new(OhosLanDiscoveryHost::default())
}

pub fn sync_automation_lan_server(
    lan_sync_service: Arc<LanSyncService>,
    lan_sync_allowed: bool,
) -> Arc<dyn SyncAutomationLanServerControl> {
    Arc::new(ServiceSyncAutomationLanServerControl {
        lan_sync_service,
        lan_sync_allowed,
    })
}

pub fn sync_automation_endpoint_catalog(
    lan_sync_service: Arc<LanSyncService>,
    tt_sync_service: Arc<TtSyncService>,
    lan_sync_allowed: bool,
) -> Arc<dyn SyncAutomationEndpointCatalog> {
    Arc::new(ServiceSyncAutomationEndpointCatalog {
        lan_sync_service,
        tt_sync_service,
        lan_sync_allowed,
    })
}

struct OhosSyncAutomationEventPublisher;

impl SyncAutomationEventPublisher for OhosSyncAutomationEventPublisher {
    fn publish_status(&self, status: SyncAutomationStatus) {
        let payload = serde_json::to_value(status).expect("sync automation status is JSON");
        super::events::emit("sync_auto:status", payload);
    }

    fn publish_toast(&self, event: SyncAutomationToastEvent) {
        let payload = serde_json::to_value(event).expect("sync automation toast is JSON");
        super::events::emit("sync_auto:toast", payload);
    }
}

struct OhosSyncJobEventPublisher;

impl SyncJobEventPublisher for OhosSyncJobEventPublisher {
    fn publish_sync_job(&self, event: SyncJobEvent) {
        let payload = serde_json::to_value(event).expect("sync job event is JSON");
        super::events::emit("sync:job", payload);
    }
}

struct OhosLanServerEvents;

impl LanServerEvents for OhosLanServerEvents {
    fn report_lan_server_error(&self, message: String) {
        tracing::error!(target: "ttavern.user_visible", "{message}");
    }

    fn pairing_completed(&self) {
        super::events::emit("lan_sync:pairing_completed", serde_json::json!({}));
    }
}

/// `LanDiscoveryHost` for OHOS. Upstream toggles the OS multicast socket via a Tauri
/// platform adapter; on OHOS the mdns socket lives inside `LanPeerDiscovery` (adapter) and
/// this host side only confirms the enable/disable switch, which gates the adapter's
/// discovery loop (`peer_discovery.rs` calls `set_enabled` before scanning). Multicast
/// reception itself is a real-device verification point (P6.2 验收).
#[derive(Default)]
struct OhosLanDiscoveryHost {
    enabled: AtomicBool,
}

#[async_trait]
impl LanDiscoveryHost for OhosLanDiscoveryHost {
    async fn set_enabled(&self, enabled: bool) -> Result<(), DomainError> {
        self.enabled.store(enabled, Ordering::Relaxed);
        tracing::info!(enabled, "LAN discovery switch toggled");
        Ok(())
    }

    fn publish_changed(&self, devices: Vec<LanDiscoveredDevice>) {
        let payload = serde_json::to_value(devices).expect("discovered devices are JSON");
        super::events::emit("lan_sync:devices_changed", payload);
    }
}

/// Pairing approval bridged through the event channel: emits `lan_sync:pair_request` and
/// waits for the ArkTS side to answer via `pairing_approval_respond` (confirm). Mirrors the
/// upstream oneshot map exactly — including the expiry timeout and the cancel-all path.
struct OhosPairingApproval {
    pending: Mutex<HashMap<String, oneshot::Sender<bool>>>,
}

impl OhosPairingApproval {
    fn new() -> Self {
        Self {
            pending: Mutex::new(HashMap::new()),
        }
    }
}

#[async_trait]
impl PairingApproval for OhosPairingApproval {
    async fn request(&self, request: LanPairingApprovalRequest) -> Result<bool, DomainError> {
        let (tx, rx) = oneshot::channel();
        {
            let mut pending = self.pending.lock().await;
            pending.insert(request.request_id.clone(), tx);
        }

        let payload = serde_json::to_value(LanSyncPairRequestEvent {
            request_id: request.request_id.clone(),
            peer_device_id: request.peer_device_id,
            peer_device_name: request.peer_device_name,
            peer_ip: request.peer_ip,
        })
        .expect("pair request is JSON");
        super::events::emit("lan_sync:pair_request", payload);

        let timeout = Duration::from_millis(request.expires_at_ms.saturating_sub(now_ms()));
        match tokio::time::timeout(timeout, rx).await {
            Ok(Ok(accepted)) => Ok(accepted),
            Ok(Err(_)) => Err(DomainError::cancelled("Pairing request cancelled")),
            Err(_) => {
                self.pending.lock().await.remove(&request.request_id);
                Err(DomainError::AuthenticationError("Pairing expired".to_string()))
            }
        }
    }

    async fn confirm(&self, request_id: &str, accept: bool) -> Result<(), DomainError> {
        let tx = self
            .pending
            .lock()
            .await
            .remove(request_id)
            .ok_or_else(|| DomainError::NotFound(format!("Pair request not found: {request_id}")))?;

        tx.send(accept).map_err(|_| {
            DomainError::InternalError("Pairing decision receiver dropped".to_string())
        })
    }

    async fn cancel_all(&self) {
        self.pending.lock().await.clear();
    }
}

struct ServiceSyncAutomationLanServerControl {
    lan_sync_service: Arc<LanSyncService>,
    lan_sync_allowed: bool,
}

#[async_trait]
impl SyncAutomationLanServerControl for ServiceSyncAutomationLanServerControl {
    fn validate_allowed(&self) -> Result<(), DomainError> {
        if !self.lan_sync_allowed {
            return Err(DomainError::InvalidData(
                "LAN Sync is not allowed by the current platform policy".to_string(),
            ));
        }
        Ok(())
    }

    async fn start(&self) -> Result<(), DomainError> {
        self.validate_allowed()?;
        self.lan_sync_service.start_server().await.map(|_| ())
    }

    async fn ensure_running(&self) -> Result<(), DomainError> {
        self.validate_allowed()?;
        if !self.lan_sync_service.get_status().await?.running {
            return Err(DomainError::InvalidData(
                "LAN Sync server is not running. Start the sync port before using LAN auto upload."
                    .to_string(),
            ));
        }
        Ok(())
    }
}

struct ServiceSyncAutomationEndpointCatalog {
    lan_sync_service: Arc<LanSyncService>,
    tt_sync_service: Arc<TtSyncService>,
    lan_sync_allowed: bool,
}

#[async_trait]
impl SyncAutomationEndpointCatalog for ServiceSyncAutomationEndpointCatalog {
    async fn validate_target(
        &self,
        target: &tt_contracts::sync_automation::SyncAutomationTarget,
        mode: SyncMode,
    ) -> Result<(), DomainError> {
        match target {
            tt_contracts::sync_automation::SyncAutomationTarget::Lan { device_id } => {
                if !self.lan_sync_allowed {
                    return Err(DomainError::InvalidData(
                        "LAN Sync is not allowed by the current platform policy".to_string(),
                    ));
                }

                let devices = self.lan_sync_service.list_paired_devices().await?;
                devices
                    .iter()
                    .find(|device| device.device_id == *device_id)
                    .ok_or_else(|| {
                        DomainError::NotFound(format!("LAN Sync device not found: {device_id}"))
                    })?;
            }
            tt_contracts::sync_automation::SyncAutomationTarget::Tt { server_device_id } => {
                let servers = self.tt_sync_service.list_servers().await?;
                let server = servers
                    .iter()
                    .find(|server| server.server_device_id.as_str() == server_device_id.as_str())
                    .ok_or_else(|| {
                        DomainError::NotFound(format!(
                            "TT-Sync server not found: {server_device_id}"
                        ))
                    })?;
                if !server.permissions.write {
                    return Err(DomainError::AuthenticationError(
                        "TT-Sync server does not grant write permission".to_string(),
                    ));
                }
                if mode == SyncMode::Mirror && !server.permissions.mirror_delete {
                    return Err(DomainError::AuthenticationError(
                        "TT-Sync server does not grant mirror_delete permission".to_string(),
                    ));
                }
            }
        }
        Ok(())
    }
}

fn now_ms() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_millis() as u64
}
