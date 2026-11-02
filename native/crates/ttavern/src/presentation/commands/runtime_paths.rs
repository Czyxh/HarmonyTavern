//! Runtime path commands (P3 row 4).
//!
//! `set_data_root` is deliberately NOT supported: upstream's portable mode relocates the
//! data root at the user's request, which needs a restartable process and a writable sibling
//! directory. On OHOS the data root is the app sandbox (`filesDir`), fixed by the system.
//! The command still exists so the ArkTS settings screen reads a clear, stable error
//! instead of "unknown command".

use serde::Serialize;

use tt_application::services::runtime_paths_service::{RuntimeModeInfo, RuntimePathsInfo};

use crate::host::Ctx;
use crate::presentation::errors::CommandError;
use crate::presentation::helpers::{log_command, map_command_error};

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct RuntimePathsDto {
    pub mode: String,
    pub data_root: String,
    pub configured_data_root: Option<String>,
    pub migration_pending: bool,
    pub migration_error: Option<String>,
}

fn runtime_mode_to_string(mode: RuntimeModeInfo) -> String {
    match mode {
        RuntimeModeInfo::Standard => "standard".to_string(),
        RuntimeModeInfo::Portable => "portable".to_string(),
    }
}

fn runtime_paths_dto(info: RuntimePathsInfo) -> RuntimePathsDto {
    RuntimePathsDto {
        mode: runtime_mode_to_string(info.mode),
        data_root: info.data_root.to_string_lossy().to_string(),
        configured_data_root: info
            .configured_data_root
            .map(|path| path.to_string_lossy().to_string()),
        migration_pending: info.migration_pending,
        migration_error: info.migration_error,
    }
}

pub fn get_runtime_paths(ctx: &Ctx<'_>) -> Result<RuntimePathsDto, CommandError> {
    log_command("get_runtime_paths");

    ctx.services
        .runtime_paths_service
        .get_runtime_paths()
        .map(runtime_paths_dto)
        .map_err(CommandError::from)
}

pub async fn set_data_root(ctx: &Ctx<'_>, raw: &str) -> Result<(), CommandError> {
    let raw = raw.trim();
    log_command(format!("set_data_root {}", raw));

    ctx.services
        .runtime_paths_service
        .request_data_root_change(raw)
        .await
        .map_err(map_command_error("Failed to set data root"))
}
