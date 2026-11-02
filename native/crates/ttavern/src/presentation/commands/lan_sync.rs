//! LAN sync 命令（上游 `lan_sync_commands.rs`，P6.2 可移植 17 条）。
//!
//! iOS 策略检查跳过（宿主作用域 Ignored）。顶层键为 snake 字面量（`pair_uri` /
//! `address` / `name` / `device_id` / `request_id` / `accept` / `options` / `mode` /
//! `persist` / `overwrite_policy`）；bool 用 `require_typed::<bool>`，枚举走 `typed`。
//!
//! 宿主重建 DTO：`LanSyncPairingInfoDto` / `LanSyncPairedDeviceDto`（p62-contract.md）。
//!
//! 对应 DevEco 工程路径：native/crates/ttavern/src/presentation/commands/lan_sync.rs

use serde::Serialize;
use ttsync_contract::sync::{OverwritePolicy, SyncMode};

use tt_contracts::lan_discovery::LanDiscoveredDevice;
use tt_contracts::sync::{SyncJobReport, SyncOperationOptions};
use tt_domain::models::lan_sync::{LanSyncPairedDeviceSummary, LanSyncStatus};

use crate::host::Ctx;
use crate::presentation::dispatch::Args;
use crate::presentation::errors::CommandError;
use crate::presentation::helpers::{log_command, map_command_error};

#[derive(Debug, Clone, Serialize)]
pub struct LanSyncPairingInfoDto {
    pub address: String,
    pub pair_uri: String,
    pub qr_svg: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct LanSyncPairedDeviceDto {
    pub device_id: String,
    pub device_name: String,
    pub last_known_address: Option<String>,
    pub paired_at_ms: u64,
    pub last_sync_ms: Option<u64>,
}

impl From<LanSyncPairedDeviceSummary> for LanSyncPairedDeviceDto {
    fn from(device: LanSyncPairedDeviceSummary) -> Self {
        Self {
            device_id: device.device_id,
            device_name: device.device_name,
            last_known_address: device.last_known_address,
            paired_at_ms: device.paired_at_ms,
            last_sync_ms: device.last_sync_ms,
        }
    }
}

pub async fn lan_sync_get_status(ctx: &Ctx<'_>) -> Result<LanSyncStatus, CommandError> {
    log_command("lan_sync_get_status");
    ctx.services
        .lan_sync_service
        .get_status()
        .await
        .map_err(map_command_error("Failed to get LAN sync status"))
}

pub async fn lan_sync_start_server(ctx: &Ctx<'_>) -> Result<LanSyncStatus, CommandError> {
    log_command("lan_sync_start_server");
    ctx.services
        .lan_sync_service
        .start_server()
        .await
        .map_err(map_command_error("Failed to start LAN sync server"))
}

pub async fn lan_sync_stop_server(ctx: &Ctx<'_>) -> Result<(), CommandError> {
    log_command("lan_sync_stop_server");
    ctx.services
        .lan_sync_service
        .stop_server()
        .await
        .map_err(map_command_error("Failed to stop LAN sync server"))
}

pub async fn lan_sync_get_pairing_info(
    ctx: &Ctx<'_>,
) -> Result<LanSyncPairingInfoDto, CommandError> {
    log_command("lan_sync_get_pairing_info");
    ctx.services
        .lan_sync_service
        .get_pairing_info()
        .await
        .and_then(|info| {
            let qr_svg = generate_qr_svg(&info.pair_uri)?;
            Ok(LanSyncPairingInfoDto {
                address: info.address,
                pair_uri: info.pair_uri,
                qr_svg,
            })
        })
        .map_err(map_command_error("Failed to get LAN sync pairing info"))
}

pub async fn lan_sync_request_pairing(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<LanSyncPairedDeviceDto, CommandError> {
    let pair_uri: String = args.require("pair_uri")?;
    log_command("lan_sync_request_pairing");
    ctx.services
        .lan_sync_service
        .request_pairing(&pair_uri)
        .await
        .map(LanSyncPairedDeviceDto::from)
        .map_err(map_command_error("Failed to request LAN sync pairing"))
}

pub async fn lan_sync_discover_devices(
    ctx: &Ctx<'_>,
) -> Result<Vec<LanDiscoveredDevice>, CommandError> {
    log_command("lan_sync_discover_devices");
    ctx.services
        .lan_sync_service
        .discover_devices()
        .await
        .map_err(map_command_error("Failed to discover LAN sync devices"))
}

pub async fn lan_sync_connect_address(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let address: String = args.require("address")?;
    log_command("lan_sync_connect_address");
    ctx.services
        .lan_sync_service
        .connect_address(&address)
        .await
        .map_err(map_command_error("Failed to connect to LAN device"))
}

pub async fn lan_sync_set_device_name(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let name: String = args.require("name")?;
    log_command("lan_sync_set_device_name");
    ctx.services
        .lan_sync_service
        .set_device_name(&name)
        .await
        .map_err(map_command_error("Failed to rename this device"))
}

pub async fn lan_sync_pair_device(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<LanSyncPairedDeviceDto, CommandError> {
    let device_id: String = args.require("device_id")?;
    log_command("lan_sync_pair_device");
    ctx.services
        .lan_sync_service
        .pair_device(&device_id)
        .await
        .map(LanSyncPairedDeviceDto::from)
        .map_err(map_command_error("Failed to pair LAN sync device"))
}

pub async fn lan_sync_confirm_pairing(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let request_id: String = args.require("request_id")?;
    let accept: bool = args.require_typed("accept")?;
    log_command("lan_sync_confirm_pairing");
    ctx.services
        .lan_sync_service
        .confirm_pairing(&request_id, accept)
        .await
        .map_err(map_command_error("Failed to confirm LAN sync pairing"))
}

pub async fn lan_sync_list_devices(
    ctx: &Ctx<'_>,
) -> Result<Vec<LanSyncPairedDeviceDto>, CommandError> {
    log_command("lan_sync_list_devices");
    ctx.services
        .lan_sync_service
        .list_paired_devices()
        .await
        .map(|devices| {
            devices
                .into_iter()
                .map(LanSyncPairedDeviceDto::from)
                .collect()
        })
        .map_err(map_command_error("Failed to list LAN sync devices"))
}

pub async fn lan_sync_remove_device(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let device_id: String = args.require("device_id")?;
    log_command("lan_sync_remove_device");
    ctx.services
        .lan_sync_service
        .remove_paired_device(&device_id)
        .await
        .map_err(map_command_error("Failed to remove LAN sync device"))
}

pub async fn lan_sync_sync_from_device(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<SyncJobReport, CommandError> {
    let device_id: String = args.require("device_id")?;
    let options: SyncOperationOptions = args.typed("options")?;
    log_command("lan_sync_sync_from_device");
    ctx.services
        .lan_sync_service
        .sync_from_device(&device_id, options)
        .await
        .map_err(map_command_error("Failed to run LAN sync pull"))
}

pub async fn lan_sync_push_to_device(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<SyncJobReport, CommandError> {
    let device_id: String = args.require("device_id")?;
    let options: SyncOperationOptions = args.typed("options")?;
    log_command("lan_sync_push_to_device");
    ctx.services
        .lan_sync_service
        .push_to_device(&device_id, options)
        .await
        .map_err(map_command_error("Failed to request LAN sync push"))
}

pub async fn lan_sync_set_sync_mode(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let mode: SyncMode = args.typed("mode")?;
    let persist: bool = args.require_typed("persist")?;
    log_command("lan_sync_set_sync_mode");
    ctx.services
        .lan_sync_service
        .set_sync_mode(mode, persist)
        .await
        .map_err(map_command_error("Failed to set LAN sync mode"))
}

pub async fn lan_sync_clear_sync_mode_override(ctx: &Ctx<'_>) -> Result<(), CommandError> {
    log_command("lan_sync_clear_sync_mode_override");
    ctx.services
        .lan_sync_service
        .clear_sync_mode_override()
        .await;
    Ok(())
}

pub async fn lan_sync_set_overwrite_policy(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<(), CommandError> {
    let overwrite_policy: OverwritePolicy = args.typed("overwrite_policy")?;
    log_command("lan_sync_set_overwrite_policy");
    ctx.services
        .lan_sync_service
        .set_overwrite_policy(overwrite_policy)
        .await
        .map_err(map_command_error("Failed to set sync overwrite policy"))
}

fn generate_qr_svg(text: &str) -> Result<String, tt_domain::errors::DomainError> {
    let code = qrcode::QrCode::new(text.as_bytes())
        .map_err(|error| tt_domain::errors::DomainError::InternalError(error.to_string()))?;
    Ok(code
        .render::<qrcode::render::svg::Color>()
        .min_dimensions(200, 200)
        .build())
}
