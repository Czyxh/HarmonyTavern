//! World-info (世界书 / lorebook) commands — P8 batch, 9 commands.
//!
//! ## Why these commands exist
//!
//! Upstream serves world info over the SillyTavern HTTP surface (`/api/worldinfo/*`):
//! `get`, `edit` (streamed body), `delete`, `import`. The Rust core already shipped the
//! domain model, the repository and `WorldInfoService`, but the OHOS host never exposed a
//! command for any of it — the native pane had no way to reach the feature at all. These
//! nine commands are the minimum complete surface:
//!
//! | command | upstream equivalent |
//! | --- | --- |
//! | `list_world_infos` | `GET /api/worldinfo/list` (was missing even in `WorldInfoService`) |
//! | `get_world_info` | `POST /api/worldinfo/get` |
//! | `world_info_begin_commit` / `_append_` / `_finish_` / `_abort_` | `POST /api/worldinfo/edit` |
//! | `delete_world_info` | `POST /api/worldinfo/delete` |
//! | `normalize_world_info_name` | client-side `sanitize_filename` on the JS side |
//! | `import_world_info` | `POST /api/worldinfo/import` |
//!
//! ## Wire differences (and why)
//!
//! - `get_world_info` returns the document as **JSON text in a string** instead of a binary
//!   body. `WorldInfoJsonDto` carries `Vec<u8>`; serialising that through the JSON command
//!   envelope would turn a 40 KB book into a 40 000-element number array. Returning String
//!   keeps the ArkTS side to one `JSON.parse`.
//! - The edit path is the same chunked commit protocol as settings/chats: upstream streams
//!   the raw body, NAPI has no raw body, so bytes go through base64 frames. The uploaded
//!   payload is the upstream edit request shape `{"name": ..., "data": {...}}` — the
//!   repository resolves the target file at `finish` (see `document::replacement`).
//!
//! ## Not covered here
//!
//! Keyword activation (which entries fire for a given chat) lives in
//! `prompt_assembly_service` / `world_info` domain scanning, which the chat-generation path
//! already runs. Per-character binding is `character.data.extensions.world` and is written
//! through the ordinary character update command, so no dedicated command is needed.

use base64::Engine;
use base64::engine::general_purpose::STANDARD as BASE64;

use tt_application::dto::world_info_dto::WorldInfoJsonDto;
use tt_contracts::byte_commit::CommitBegin;

use crate::host::Ctx;
use crate::presentation::dispatch::Args;
use crate::presentation::errors::CommandError;
use crate::presentation::helpers::{log_command, map_command_error};

/// `default-user/worlds/*.json` 的书籍名列表（上游 `/api/worldinfo/list`）。
pub async fn list_world_infos(ctx: &Ctx<'_>) -> Result<Vec<String>, CommandError> {
    log_command("list_world_infos");

    ctx.services
        .world_info_service
        .list_world_infos()
        .await
        .map_err(map_command_error("Failed to list world infos"))
}

/// 读取一本世界书的完整 JSON 文本；不存在时返回空书 `{"entries":{}}`。
pub async fn get_world_info(ctx: &Ctx<'_>, args: &Args) -> Result<String, CommandError> {
    let name: String = args.require("name")?;
    log_command(format!("get_world_info {}", name));

    let WorldInfoJsonDto { bytes } = ctx
        .services
        .world_info_service
        .get_world_info(&name)
        .await
        .map_err(map_command_error("Failed to get world info"))?;

    String::from_utf8(bytes)
        .map_err(|error| CommandError::InternalServerError(format!("World info is not valid UTF-8: {error}")))
}

pub async fn world_info_begin_commit(ctx: &Ctx<'_>) -> Result<CommitBegin, CommandError> {
    log_command("world_info_begin_commit");

    ctx.services
        .world_info_service
        .begin_commit()
        .await
        .map_err(map_command_error("Failed to begin world info commit"))
}

/// `{ sessionId, offset, chunkBase64 }` → 下一个字节偏移。
pub async fn world_info_append_commit_chunk(
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
        "world_info_append_commit_chunk session={} offset={} len={}",
        session_id,
        offset,
        bytes.len()
    ));

    ctx.services
        .world_info_service
        .append_commit(&session_id, offset, &bytes)
        .await
        .map_err(map_command_error("Failed to append world info commit chunk"))
}

pub async fn world_info_finish_commit(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let session_id: String = args.require("sessionId")?;
    let expected_size: u64 = args.require_u64("expectedSize")?;
    log_command(format!(
        "world_info_finish_commit session={} size={}",
        session_id, expected_size
    ));

    ctx.services
        .world_info_service
        .finish_commit(&session_id, expected_size)
        .await
        .map_err(map_command_error("Failed to finish world info commit"))
}

pub async fn world_info_abort_commit(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let session_id: String = args.require("sessionId")?;
    log_command(format!(
        "world_info_abort_commit session={}",
        session_id
    ));

    ctx.services
        .world_info_service
        .abort_commit(&session_id)
        .await
        .map_err(map_command_error("Failed to abort world info commit"))
}

pub async fn delete_world_info(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let name: String = args.require("name")?;
    log_command(format!("delete_world_info {}", name));

    ctx.services
        .world_info_service
        .delete_world_info(&name)
        .await
        .map_err(map_command_error("Failed to delete world info"))
}

/// 按上游规则把用户输入的书名洗成合法文件名（`importFilename=true` 走导入规则）。
pub async fn normalize_world_info_name(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<String, CommandError> {
    let name: String = args.require("name")?;
    let import_filename: bool = args.optional("importFilename")?.unwrap_or(false);
    log_command(format!(
        "normalize_world_info_name {} import={}",
        name, import_filename
    ));

    ctx.services
        .world_info_service
        .normalize_world_info_name(&name, import_filename)
        .map_err(map_command_error("Failed to normalize world info name"))
}

/// 从沙箱内文件导入世界书；`convertedData` 可直接给已转换好的 JSON 文本。
pub async fn import_world_info(ctx: &Ctx<'_>, args: &Args) -> Result<String, CommandError> {
    let file_path: String = args.optional("filePath")?.unwrap_or_default();
    let original_filename: String = args.require("originalFilename")?;
    let converted_data: Option<String> = args.optional("convertedData")?;
    log_command(format!(
        "import_world_info {} from {}",
        original_filename, file_path
    ));

    ctx.services
        .world_info_service
        .import_world_info(&file_path, &original_filename, converted_data)
        .await
        .map_err(map_command_error("Failed to import world info"))
}
