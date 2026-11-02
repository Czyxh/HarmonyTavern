//! Default content commands (P3 row 9).
//!
//! Upstream hardcodes the `default-user` handle here; kept as-is so the ArkTS startup
//! sequence matches (multi-user support arrives with the login flow, which OHOS does not
//! port in P3).

use base64::Engine as _;

use crate::host::Ctx;
use crate::presentation::dispatch::Args;
use crate::presentation::errors::CommandError;
use crate::presentation::helpers::{ensure_ios_policy_allows, log_command, map_command_error};

/// Handle the backend seeds content into (SillyTavern's single-user default).
const DEFAULT_USER_HANDLE: &str = "default-user";

pub async fn initialize_default_content(ctx: &Ctx<'_>) -> Result<(), CommandError> {
    log_command("initialize_default_content");

    ctx.services
        .content_service
        .initialize_default_content(DEFAULT_USER_HANDLE)
        .await
        .map_err(map_command_error("Failed to initialize default content"))
}

pub async fn is_default_content_initialized(ctx: &Ctx<'_>) -> Result<bool, CommandError> {
    log_command("is_default_content_initialized");

    ctx.services
        .content_service
        .is_default_content_initialized(DEFAULT_USER_HANDLE)
        .await
        .map_err(map_command_error(
            "Failed to check default content initialization state",
        ))
}

/// Fetch a remote character card / asset for import.
///
/// Upstream returns `ExternalImportDownloadResult { data: Vec<u8>, file_name, mime_type }`,
/// which serde would encode as a byte array; the JSON channel returns base64 instead and keeps
/// the two metadata fields. The backend enforces the same `http`/`https` scheme allow-list.
pub async fn download_external_import_url(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<serde_json::Value, CommandError> {
    let url: String = args.require("url")?;
    log_command("download_external_import_url");

    ensure_ios_policy_allows(
        &ctx.startup.ios_policy,
        ctx.startup.ios_policy.capabilities.content.external_import,
        "content.external_import",
    )?;

    let downloaded = ctx
        .services
        .content_service
        .download_external_import_url(&url)
        .await
        .map_err(map_command_error("Failed to download external import URL"))?;

    Ok(serde_json::json!({
        "fileName": downloaded.file_name,
        "mimeType": downloaded.mime_type,
        "dataBase64": base64::engine::general_purpose::STANDARD.encode(&downloaded.data),
        "byteLength": downloaded.data.len(),
    }))
}
