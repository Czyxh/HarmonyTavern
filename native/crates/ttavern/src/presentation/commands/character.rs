//! Character commands (P3 batch).
//!
//! Payload shapes are byte-identical to upstream `character_commands.rs`: `{ shallow }`,
//! `{ name }`, `{ dto }`, `{ name, dto }`.
//!
//! Deferred with their owning phase:
//! - `import_character` / `replace_character` / `export_character_content` / `create_character_with_avatar`
//!   鈫?P4 (file picker + binary response + avatar bytes)
//! - `adopt_character_lorebook` / `*_card_data` 鈫?P5 (world-info coordinator + card merge UI)

use base64::Engine as _;

use tt_application::dto::character_dto::{
    CharacterChatDto, CharacterDto, CreateCharacterDto, CreateCharacterWithAvatarResultDto,
    CreateWithAvatarDto, DeleteCharacterDto, DuplicateCharacterDto, ExportCharacterContentDto,
    GetCharacterChatsDto, ImportCharacterDto, ImportCharacterResultDto, RenameCharacterDto,
    ReplaceCharacterDto, UpdateAvatarDto, UpdateCharacterDto,
};

use crate::host::Ctx;
use crate::presentation::dispatch::Args;
use crate::presentation::errors::CommandError;
use crate::presentation::helpers::{log_command, map_command_error};

pub async fn get_all_characters(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<Vec<CharacterDto>, CommandError> {
    // Upstream default is a full (deep) snapshot when ArkTS omits `shallow`.
    let shallow: Option<bool> = args.optional_bool("shallow")?;
    let shallow = shallow.unwrap_or(false);
    log_command(format!("get_all_characters shallow={}", shallow));

    ctx.services
        .character_service
        .get_all_characters(shallow)
        .await
        .map_err(map_command_error("Failed to get all characters"))
}

pub async fn get_character(ctx: &Ctx<'_>, args: &Args) -> Result<CharacterDto, CommandError> {
    let name: String = args.require("name")?;
    log_command(format!("get_character {}", name));

    ctx.services
        .character_service
        .get_character(&name)
        .await
        .map_err(map_command_error(format!(
            "Failed to get character {}",
            name
        )))
}

pub async fn create_character(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<CharacterDto, CommandError> {
    let dto: CreateCharacterDto = args.typed("dto")?;
    log_command(format!("create_character {}", dto.name));

    ctx.services
        .character_service
        .create_character(dto)
        .await
        .map_err(map_command_error("Failed to create character"))
}

pub async fn update_character(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<CharacterDto, CommandError> {
    let name: String = args.require("name")?;
    let dto: UpdateCharacterDto = args.typed("dto")?;
    log_command(format!("update_character {}", name));

    ctx.services
        .character_service
        .update_character(&name, dto)
        .await
        .map_err(map_command_error(format!(
            "Failed to update character {}",
            name
        )))
}

pub async fn delete_character(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let dto: DeleteCharacterDto = args.typed("dto")?;
    log_command(format!("delete_character {}", dto.name));

    ctx.services
        .character_service
        .delete_character(dto)
        .await
        .map_err(map_command_error("Failed to delete character"))
}

pub async fn rename_character(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<CharacterDto, CommandError> {
    let dto: RenameCharacterDto = args.typed("dto")?;
    log_command(format!(
        "rename_character {} -> {}",
        dto.old_name, dto.new_name
    ));

    ctx.services
        .character_service
        .rename_character(dto)
        .await
        .map_err(map_command_error("Failed to rename character"))
}

pub async fn duplicate_character(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<CharacterDto, CommandError> {
    let dto: DuplicateCharacterDto = args.typed("dto")?;
    log_command(format!("duplicate_character {}", dto.name));

    ctx.services
        .character_service
        .duplicate_character(dto)
        .await
        .map_err(map_command_error("Failed to duplicate character"))
}

/// NOTE: `avatar_path` inside the DTO is an absolute path inside the app sandbox;
/// ArkTS obtains it from the P4 upload flow.
pub async fn update_avatar(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let dto: UpdateAvatarDto = args.typed("dto")?;
    log_command(format!("update_avatar {}", dto.name));

    ctx.services
        .character_service
        .update_avatar(dto)
        .await
        .map_err(map_command_error("Failed to update avatar"))
}

pub async fn get_character_chats_by_id(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<Vec<CharacterChatDto>, CommandError> {
    let dto: GetCharacterChatsDto = args.typed("dto")?;
    log_command(format!("get_character_chats_by_id {}", dto.name));

    ctx.services
        .character_service
        .get_character_chats(dto)
        .await
        .map_err(map_command_error("Failed to get character chats"))
}

pub async fn clear_character_cache(ctx: &Ctx<'_>) -> Result<(), CommandError> {
    log_command("clear_character_cache");

    ctx.services
        .character_service
        .clear_cache()
        .await
        .map_err(map_command_error("Failed to clear character cache"))
}

// --- Character card import / export (P4) ---
//
// `file_path` is an absolute path inside the app sandbox. ArkTS copies the file picked by the
// system file picker into `<cacheDir>/imports/<uuid>.<ext>` first, so multi-megabyte cards never
// travel through base64 JSON (the DTO was already path-based upstream).

pub async fn import_character(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<ImportCharacterResultDto, CommandError> {
    let dto: ImportCharacterDto = args.typed("dto")?;
    log_command(format!("import_character from {}", dto.file_path));

    ctx.services
        .character_service
        .import_character(dto)
        .await
        .map_err(map_command_error("Failed to import character"))
}

pub async fn replace_character(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<ImportCharacterResultDto, CommandError> {
    let dto: ReplaceCharacterDto = args.typed("dto")?;
    log_command(format!(
        "replace_character {} from {}",
        dto.name, dto.file_path
    ));

    ctx.services
        .character_service
        .replace_character(dto)
        .await
        .map_err(map_command_error("Failed to replace character"))
}

/// Upstream returns `tauri::ipc::Response::new(bytes)`; the JSON channel returns the same bytes
/// base64-encoded (`ExportCharacterContentResultDto` only carries `data`, so the file name is the
/// caller's choice 鈥?as it was upstream, where the WebView saved the blob).
pub async fn export_character_content(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<serde_json::Value, CommandError> {
    let dto: ExportCharacterContentDto = args.typed("dto")?;
    log_command(format!(
        "export_character_content {} format {}",
        dto.name, dto.format
    ));

    let exported = ctx
        .services
        .character_service
        .export_character_content(dto)
        .await
        .map_err(map_command_error("Failed to export character content"))?;

    Ok(serde_json::json!({
        "dataBase64": base64::engine::general_purpose::STANDARD.encode(&exported.data),
        "byteLength": exported.data.len(),
    }))
}

pub async fn create_character_with_avatar(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<CreateCharacterWithAvatarResultDto, CommandError> {
    let dto: CreateWithAvatarDto = args.typed("dto")?;
    log_command(format!(
        "create_character_with_avatar {}",
        dto.character.name
    ));

    ctx.services
        .character_service
        .create_with_avatar(dto)
        .await
        .map_err(map_command_error("Failed to create character with avatar"))
}
