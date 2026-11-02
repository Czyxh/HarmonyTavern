//! Sync automation 命令（上游 `sync_automation_commands.rs`，P6.2 可移植 3 条）。
//!
//! 顶层键为 snake 字面量（`config`）；`update_config` 的 config 走 `typed`。
//!
//! 对应 DevEco 工程路径：native/crates/ttavern/src/presentation/commands/sync_automation.rs

use tt_contracts::sync_automation::{SyncAutomationConfig, SyncAutomationStatus};

use crate::host::Ctx;
use crate::presentation::dispatch::Args;
use crate::presentation::errors::CommandError;
use crate::presentation::helpers::{log_command, map_command_error};

pub async fn sync_automation_get_config(
    ctx: &Ctx<'_>,
) -> Result<SyncAutomationConfig, CommandError> {
    log_command("sync_automation_get_config");
    ctx.services
        .sync_automation_service
        .get_config()
        .await
        .map_err(map_command_error("Failed to get sync automation config"))
}

pub async fn sync_automation_update_config(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<SyncAutomationConfig, CommandError> {
    let config: SyncAutomationConfig = args.typed("config")?;
    log_command("sync_automation_update_config");
    ctx.services
        .sync_automation_service
        .update_config(config)
        .await
        .map_err(map_command_error("Failed to update sync automation config"))
}

pub async fn sync_automation_get_status(
    ctx: &Ctx<'_>,
) -> Result<SyncAutomationStatus, CommandError> {
    log_command("sync_automation_get_status");
    Ok(ctx.services.sync_automation_service.get_status().await)
}
