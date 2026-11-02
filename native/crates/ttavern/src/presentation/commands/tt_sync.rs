//! TT-Sync 命令（上游 `tt_sync_commands.rs`，P6.2 可移植 5 条）。
//!
//! 顶层键为 snake 字面量（`pair_uri` / `server_device_id` / `mode` / `options`）。
//! 宿主重建 DTO：`TtSyncPermissionsDto` / `TtSyncPairedServerDto`（p62-contract.md）。
//!
//! 对应 DevEco 工程路径：native/crates/ttavern/src/presentation/commands/tt_sync.rs

use serde::Serialize;
use ttsync_contract::sync::SyncMode;

use tt_contracts::sync::{SyncJobReport, SyncOperationOptions};
use tt_domain::models::tt_sync::TtSyncPairedServer;

use crate::host::Ctx;
use crate::presentation::dispatch::Args;
use crate::presentation::errors::CommandError;
use crate::presentation::helpers::{log_command, map_command_error};

#[derive(Debug, Clone, Serialize)]
pub struct TtSyncPermissionsDto {
    pub read: bool,
    pub write: bool,
    pub mirror_delete: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct TtSyncPairedServerDto {
    pub server_device_id: String,
    pub server_device_name: String,
    pub base_url: String,
    pub spki_sha256: String,
    pub permissions: TtSyncPermissionsDto,
    pub paired_at_ms: u64,
    pub last_sync_ms: Option<u64>,
}

impl From<TtSyncPairedServer> for TtSyncPairedServerDto {
    fn from(server: TtSyncPairedServer) -> Self {
        Self {
            server_device_id: server.server_device_id.to_string(),
            server_device_name: server.server_device_name,
            base_url: server.base_url,
            spki_sha256: server.spki_sha256,
            permissions: TtSyncPermissionsDto {
                read: server.permissions.read,
                write: server.permissions.write,
                mirror_delete: server.permissions.mirror_delete,
            },
            paired_at_ms: server.paired_at_ms,
            last_sync_ms: server.last_sync_ms,
        }
    }
}

pub async fn tt_sync_pair(ctx: &Ctx<'_>, args: &Args) -> Result<TtSyncPairedServerDto, CommandError> {
    let pair_uri: String = args.require("pair_uri")?;
    log_command("tt_sync_pair");
    ctx.services
        .tt_sync_service
        .pair(&pair_uri)
        .await
        .map(TtSyncPairedServerDto::from)
        .map_err(map_command_error("Failed to pair TT-Sync server"))
}

pub async fn tt_sync_list_servers(
    ctx: &Ctx<'_>,
) -> Result<Vec<TtSyncPairedServerDto>, CommandError> {
    log_command("tt_sync_list_servers");
    ctx.services
        .tt_sync_service
        .list_servers()
        .await
        .map(|servers| {
            servers
                .into_iter()
                .map(TtSyncPairedServerDto::from)
                .collect()
        })
        .map_err(map_command_error("Failed to list TT-Sync servers"))
}

pub async fn tt_sync_remove_server(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let server_device_id: String = args.require("server_device_id")?;
    log_command("tt_sync_remove_server");
    ctx.services
        .tt_sync_service
        .remove_server(&server_device_id)
        .await
        .map_err(map_command_error("Failed to remove TT-Sync server"))
}

pub async fn tt_sync_pull(ctx: &Ctx<'_>, args: &Args) -> Result<SyncJobReport, CommandError> {
    let server_device_id: String = args.require("server_device_id")?;
    let mode: SyncMode = args.typed("mode")?;
    let options: SyncOperationOptions = args.typed("options")?;
    log_command("tt_sync_pull");
    ctx.services
        .tt_sync_service
        .pull(&server_device_id, mode, options)
        .await
        .map_err(map_command_error("Failed to run TT-Sync pull"))
}

pub async fn tt_sync_push(ctx: &Ctx<'_>, args: &Args) -> Result<SyncJobReport, CommandError> {
    let server_device_id: String = args.require("server_device_id")?;
    let mode: SyncMode = args.typed("mode")?;
    let options: SyncOperationOptions = args.typed("options")?;
    log_command("tt_sync_push");
    ctx.services
        .tt_sync_service
        .push(&server_device_id, mode, options)
        .await
        .map_err(map_command_error("Failed to run TT-Sync push"))
}
