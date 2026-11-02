//! Settings commands (P3 batch, 12 commands).
//!
//! ## Wire differences from upstream, and why
//!
//! Upstream ships the SillyTavern settings aggregate as a **binary** response and uploads
//! settings frames with `append_settings_commit_chunk(request: tauri::ipc::Request)` (raw
//! body). OHOS keeps a single JSON command channel instead of adding Buffer entry points:
//!
//! - `get_sillytavern_settings` returns the DTO as JSON. Same payload, ~26 KB; the binary
//!   path only existed to avoid WebView IPC framing, which NAPI does not have.
//! - `append_settings_commit_chunk` takes `{"sessionId","offset","chunkBase64"}`. ArkTS
//!   encodes chunk bytes with `util.Base64Helper.encodeToStringSync(...)` (`@kit.ArkTS`),
//!   Rust decodes here. Offsets stay byte-exact, so multi-byte UTF-8 chunk boundaries are safe.
//!
//! ## Deliberately dropped side effects
//!
//! `update_tauritavern_settings` upstream also poked `DevObservabilityHub` (dev log stream),
//! `HostResourceService` (tray/tray-menu resources) and the Windows tray. None of those exist
//! on OHOS; the service call itself (proxy apply + chat-backup settings) is unchanged.

use base64::Engine;
use base64::engine::general_purpose::STANDARD as BASE64;

use tt_application::dto::settings_dto::{
    SettingsSnapshotDto, TauriTavernSettingsDto, UpdateTauriTavernSettingsDto, UserSettingsDto,
    UserSettingsRevisionDto, UserSettingsSaveResultDto,
};
use tt_contracts::byte_commit::CommitBegin;
use tt_contracts::chat::ChatBackupStorageStats;

use crate::host::Ctx;
use crate::presentation::dispatch::Args;
use crate::presentation::errors::CommandError;
use crate::presentation::helpers::{log_command, map_command_error};

pub async fn get_tauritavern_settings(
    ctx: &Ctx<'_>,
) -> Result<TauriTavernSettingsDto, CommandError> {
    log_command("get_tauritavern_settings");

    ctx.services
        .settings_service
        .get_tauritavern_settings()
        .await
        .map_err(map_command_error("Failed to get TauriTavern settings"))
}

pub async fn get_chat_backup_storage_stats(
    ctx: &Ctx<'_>,
) -> Result<Option<ChatBackupStorageStats>, CommandError> {
    log_command("get_chat_backup_storage_stats");

    ctx.services
        .settings_service
        .get_chat_backup_storage_stats()
        .await
        .map_err(map_command_error(
            "Failed to get chat backup storage statistics",
        ))
}

pub async fn update_tauritavern_settings(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<TauriTavernSettingsDto, CommandError> {
    let dto: UpdateTauriTavernSettingsDto = args.typed("dto")?;
    log_command("update_tauritavern_settings");

    ctx.services
        .settings_service
        .update_tauritavern_settings(dto)
        .await
        .map_err(map_command_error("Failed to update TauriTavern settings"))
}

pub async fn begin_settings_commit(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<CommitBegin, CommandError> {
    let expected: Option<UserSettingsRevisionDto> = args.optional_typed("expectedRevision")?;
    log_command("begin_settings_commit");

    ctx.services
        .settings_service
        .begin_commit(expected)
        .await
        .map_err(map_command_error("Failed to begin settings commit"))
}

/// `{ sessionId, offset, chunkBase64 }` → next byte offset.
pub async fn append_settings_commit_chunk(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<u64, CommandError> {
    let session_id: String = args.require("sessionId")?;
    let offset: u64 = args.require_u64("offset")?;
    let chunk_base64: String = args.require("chunkBase64")?;
    let bytes = BASE64.decode(chunk_base64.as_bytes()).map_err(|error| {
        CommandError::BadRequest(format!("chunkBase64 is not valid base64: {error}"))
    })?;
    log_command(format!(
        "append_settings_commit_chunk session={} offset={} len={}",
        session_id,
        offset,
        bytes.len()
    ));

    ctx.services
        .settings_service
        .append_commit(&session_id, offset, &bytes)
        .await
        .map_err(map_command_error("Failed to append settings commit chunk"))
}

pub async fn finish_settings_commit(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<UserSettingsSaveResultDto, CommandError> {
    let session_id: String = args.require("sessionId")?;
    let expected_size: u64 = args.require_u64("expectedSize")?;
    log_command(format!(
        "finish_settings_commit session={} size={}",
        session_id, expected_size
    ));

    ctx.services
        .settings_service
        .finish_commit(&session_id, expected_size)
        .await
        .map_err(map_command_error("Failed to finish settings commit"))
}

pub async fn abort_settings_commit(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let session_id: String = args.require("sessionId")?;
    log_command(format!("abort_settings_commit session={}", session_id));

    ctx.services
        .settings_service
        .abort_commit(&session_id)
        .await
        .map_err(map_command_error("Failed to abort settings commit"))
}

/// Returns the settings aggregate as JSON (upstream returns it as a binary response).
///
/// The service hands back **already encoded** bytes (`SettingsJsonDto { bytes: Arc<Vec<u8>> }`,
/// shared with its cache). We only re-parse them so the value can be embedded in the command
/// envelope; no re-serialisation of the DTO is involved.
pub async fn get_sillytavern_settings(ctx: &Ctx<'_>) -> Result<serde_json::Value, CommandError> {
    log_command("get_sillytavern_settings");

    let settings = ctx
        .services
        .settings_service
        .get_sillytavern_settings()
        .await
        .map_err(map_command_error("Failed to get SillyTavern settings"))?;

    serde_json::from_slice(&settings.bytes).map_err(|error| {
        CommandError::InternalServerError(format!(
            "Backend produced invalid SillyTavern settings JSON: {error}"
        ))
    })
}

pub async fn create_settings_snapshot(ctx: &Ctx<'_>) -> Result<(), CommandError> {
    log_command("create_settings_snapshot");

    ctx.services
        .settings_service
        .create_snapshot()
        .await
        .map_err(map_command_error("Failed to create settings snapshot"))
}

pub async fn get_settings_snapshots(
    ctx: &Ctx<'_>,
) -> Result<Vec<SettingsSnapshotDto>, CommandError> {
    log_command("get_settings_snapshots");

    ctx.services
        .settings_service
        .get_snapshots()
        .await
        .map_err(map_command_error("Failed to get settings snapshots"))
}

pub async fn load_settings_snapshot(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<UserSettingsDto, CommandError> {
    let name: String = args.require("name")?;
    log_command(format!("load_settings_snapshot {}", name));

    ctx.services
        .settings_service
        .load_snapshot(&name)
        .await
        .map_err(map_command_error(format!(
            "Failed to load settings snapshot {}",
            name
        )))
}

pub async fn restore_settings_snapshot(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<(), CommandError> {
    let name: String = args.require("name")?;
    log_command(format!("restore_settings_snapshot {}", name));

    ctx.services
        .settings_service
        .restore_snapshot(&name)
        .await
        .map_err(map_command_error(format!(
            "Failed to restore settings snapshot {}",
            name
        )))
}
