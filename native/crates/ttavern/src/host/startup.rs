//! One-shot startup snapshot (replaces upstream `app/startup_profile.rs`).
//!
//! Loaded once during `initialize`, before services are assembled, because
//! `SettingsService` and `AppState` both need the same snapshot: runtime setting changes
//! go through `SettingsService` afterwards, only startup-only effects read this.
//!
//! Differences from upstream, both forced by the platform:
//! - iOS policy is always `Ignored` (we are not on iOS, so no factory profile exists).
//! - the factory profile env var (`TAURITAVERN_IOS_POLICY_PROFILE`) is not used.

use std::path::Path;

use tt_adapter_storage_core::load_tauritavern_settings_blocking;
use tt_domain::errors::DomainError;
use tt_domain::ios_policy::{
    IosPolicyActivationReport, IosPolicyScope, resolve_ios_policy_activation_report,
};
use tt_domain::models::settings::TauriTavernSettings;

#[derive(Debug, Clone)]
pub struct StartupProfile {
    pub tauritavern_settings: TauriTavernSettings,
    pub ios_policy: IosPolicyActivationReport,
}

impl StartupProfile {
    pub fn load(data_root: &Path) -> Result<Self, DomainError> {
        let tauritavern_settings = load_tauritavern_settings_blocking(
            &data_root.join("default-user"),
            &initial_tauritavern_settings(),
        )?;
        tauritavern_settings
            .chat_backups
            .validate()
            .map_err(|error| DomainError::InvalidData(error.message()))?;

        let ios_policy =
            resolve_ios_policy_activation_report(IosPolicyScope::Ignored, None, None)?;

        Ok(Self {
            tauritavern_settings,
            ios_policy,
        })
    }
}

/// Native defaults shared by startup loading and repository composition.
pub fn initial_tauritavern_settings() -> TauriTavernSettings {
    TauriTavernSettings::default()
}
