//! Product / version commands (P4) — port of the `get_client_version` half of upstream
//! `presentation/commands/bridge.rs`.
//!
//! The other `bridge.rs` commands are deliberately absent:
//! - `emit_event`               → replaced by the `setEventListener` event channel
//! - `read_dev_web_resource`    → dev-only WebView source reader, meaningless on OHOS
//! - notification commands      → P7 (need `@kit.NotificationKit` + authorisation)
//!
//! The payload keeps upstream's field names (`agent`, `pkgVersion`, `tauriVersion`, …) because
//! SillyTavern extensions parse them for compatibility checks.

use serde_json::json;

use crate::presentation::errors::CommandError;
use crate::presentation::helpers::log_command;

/// SillyTavern frontend baseline the backend aggregates were written against.
/// Same value as upstream `bridge.rs`; changing it changes what extensions think they run on.
const SILLYTAVERN_COMPAT_VERSION: &str = "1.19.0";

pub async fn get_client_version() -> Result<serde_json::Value, CommandError> {
    log_command("get_client_version");

    Ok(json!({
        // Upstream shape: `SillyTavern:<compat>:<client>`; the client segment names the shell.
        "agent": format!("SillyTavern:{}:HarmonyTavern", SILLYTAVERN_COMPAT_VERSION),
        "pkgVersion": SILLYTAVERN_COMPAT_VERSION,
        // Upstream reports the Tauri shell version here; ours is the native host version.
        "tauriVersion": env!("CARGO_PKG_VERSION"),
        "gitRevision": option_env!("HARMONYTAVERN_GIT_REVISION"),
        "gitBranch": option_env!("HARMONYTAVERN_GIT_BRANCH"),
        // No git branch in the OHOS build → upstream's `None` branch maps to Stable.
        "defaultUpdateChannel": tt_domain::models::update::UpdateChannel::Stable,
    }))
}
