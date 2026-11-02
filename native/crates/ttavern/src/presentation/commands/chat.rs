//! Chat 命令（上游 `chat_commands.rs`，26 条里移植 24 条）。
//!
//! **哪两条不移植，为什么**：`open_chat_payload_json` 与 `open_chat_backup_download`
//! 的返回值是 Tauri 的 `ResourceId` —— 它不是业务结果，而是「把字节流挂到 WebView
//! 资源表、由前端 `convertFileSrc` 取走」这一套协议句柄。鸿蒙侧没有 WebView 资源表，
//! 照搬会得到一个无法消费的整数。真正需要「把大文件分页交给 UI」的地方，P5 用
//! `get_chat_payload_tail` / `get_chat_payload_before` / `get_chat_payload_before_pages`
//! 这套游标分页命令（它们返回真实数据），因此这两条不是缺失，而是被替代（§11.3-D）。
//!
//! 对应 DevEco 工程路径：native/crates/ttavern/src/presentation/commands/chat.rs

use tt_application::dto::chat_dto::{
    AddMessageDto, ChatDto, ChatSearchResultDto, CreateChatDto, ImportCharacterChatsDto,
    ImportChatDto, PinnedCharacterChatDto, RenameChatDto, RestoreCharacterChatBackupDto,
};
use tt_application::dto::chat_history_dto::ChatHistoryLocator;
use tt_application::errors::ApplicationError;
use tt_contracts::chat::ChatBackupCatalogEntry;
use tt_ports::repositories::chat_repository::{
    ChatPayloadChunk, ChatPayloadCursor, ChatPayloadTail,
};

use crate::host::Ctx;
use crate::presentation::dispatch::Args;
use crate::presentation::errors::CommandError;
use crate::presentation::helpers::{log_command, map_command_error};

pub async fn get_all_chats(ctx: &Ctx<'_>) -> Result<Vec<ChatDto>, CommandError> {
    log_command("get_all_chats");

    ctx.services
        .chat_service
        .get_all_chats()
        .await
        .map_err(map_command_error("Failed to get all chats"))
}

pub async fn get_chat(ctx: &Ctx<'_>, args: &Args) -> Result<ChatDto, CommandError> {
    let character_name: String = args.require("characterName")?;
    let file_name: String = args.require("fileName")?;
    log_command(format!("get_chat {}/{}", character_name, file_name));

    ctx.services
        .chat_service
        .get_chat(&character_name, &file_name)
        .await
        .map_err(map_command_error(format!(
            "Failed to get chat {}/{}",
            character_name, file_name
        )))
}

pub async fn get_character_chats(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<Vec<ChatDto>, CommandError> {
    let character_name: String = args.require("characterName")?;
    log_command(format!("get_character_chats {}", character_name));

    ctx.services
        .chat_service
        .get_character_chats(&character_name)
        .await
        .map_err(map_command_error(format!(
            "Failed to get chats for character {}",
            character_name
        )))
}

pub async fn create_chat(ctx: &Ctx<'_>, args: &Args) -> Result<ChatDto, CommandError> {
    let dto: CreateChatDto = args.typed("dto")?;
    log_command(format!("create_chat for character {}", dto.character_name));

    ctx.services
        .chat_service
        .create_chat(dto)
        .await
        .map_err(map_command_error("Failed to create chat"))
}

pub async fn add_message(ctx: &Ctx<'_>, args: &Args) -> Result<ChatDto, CommandError> {
    let dto: AddMessageDto = args.typed("dto")?;
    log_command(format!(
        "add_message to chat {}/{}",
        dto.character_name, dto.file_name
    ));

    ctx.services
        .chat_service
        .add_message(dto)
        .await
        .map_err(map_command_error("Failed to add message to chat"))
}

pub async fn rename_chat(ctx: &Ctx<'_>, args: &Args) -> Result<String, CommandError> {
    let dto: RenameChatDto = args.typed("dto")?;
    log_command(format!(
        "rename_chat {}/{} -> {}/{}",
        dto.character_name, dto.old_file_name, dto.character_name, dto.new_file_name
    ));

    ctx.services
        .chat_service
        .rename_chat(dto)
        .await
        .map_err(map_command_error("Failed to rename chat"))
}

pub async fn delete_chat(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let character_name: String = args.require("characterName")?;
    let file_name: String = args.require("fileName")?;
    log_command(format!("delete_chat {}/{}", character_name, file_name));

    ctx.services
        .chat_service
        .delete_chat(&character_name, &file_name)
        .await
        .map_err(map_command_error(format!(
            "Failed to delete chat {}/{}",
            character_name, file_name
        )))
}

pub async fn search_chats(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<Vec<ChatSearchResultDto>, CommandError> {
    let query: String = args.require("query")?;
    let character_filter: Option<String> = args.optional("characterFilter")?;
    log_command(format!("search_chats {}", query));

    ctx.services
        .chat_service
        .search_chats(&query, character_filter.as_deref())
        .await
        .map_err(map_command_error("Failed to search chats"))
}

pub async fn list_chat_summaries(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<Vec<ChatSearchResultDto>, CommandError> {
    let character_filter: Option<String> = args.optional("characterFilter")?;
    let include_metadata: bool = args.optional_bool("includeMetadata")?.unwrap_or(false);
    log_command("list_chat_summaries");

    ctx.services
        .chat_service
        .list_chat_summaries(character_filter.as_deref(), include_metadata)
        .await
        .map_err(map_command_error("Failed to list chat summaries"))
}

pub async fn list_recent_chat_summaries(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<Vec<ChatSearchResultDto>, CommandError> {
    let character_filter: Option<String> = args.optional("characterFilter")?;
    let include_metadata: bool = args.optional_bool("includeMetadata")?.unwrap_or(false);
    let max_entries: Option<usize> = args.optional("maxEntries")?;
    let pinned: Option<Vec<PinnedCharacterChatDto>> = args.optional_typed("pinned")?;
    log_command("list_recent_chat_summaries");

    let pinned = pinned.unwrap_or_default();
    let pinned_refs = pinned.into_iter().map(Into::into).collect::<Vec<_>>();

    ctx.services
        .chat_service
        .list_recent_chat_summaries(
            character_filter.as_deref(),
            include_metadata,
            max_entries.unwrap_or(usize::MAX),
            &pinned_refs,
        )
        .await
        .map_err(map_command_error("Failed to list recent chat summaries"))
}

pub async fn import_chat(ctx: &Ctx<'_>, args: &Args) -> Result<ChatDto, CommandError> {
    let dto: ImportChatDto = args.typed("dto")?;
    log_command(format!(
        "import_chat for character {} from {}",
        dto.character_name, dto.file_path
    ));

    ctx.services
        .chat_service
        .import_chat(dto)
        .await
        .map_err(map_command_error("Failed to import chat"))
}

pub async fn backup_chat(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let character_name: String = args.require("characterName")?;
    let file_name: String = args.require("fileName")?;
    log_command(format!("backup_chat {}/{}", character_name, file_name));

    ctx.services
        .chat_service
        .backup_chat(&character_name, &file_name)
        .await
        .map_err(map_command_error(format!(
            "Failed to backup chat {}/{}",
            character_name, file_name
        )))
}

pub async fn list_chat_backups(
    ctx: &Ctx<'_>,
) -> Result<Vec<ChatSearchResultDto>, CommandError> {
    log_command("list_chat_backups");

    ctx.services
        .chat_service
        .list_chat_backups()
        .await
        .map_err(map_command_error("Failed to list chat backups"))
}

pub async fn list_chat_backup_catalog(
    ctx: &Ctx<'_>,
) -> Result<Vec<ChatBackupCatalogEntry>, CommandError> {
    log_command("list_chat_backup_catalog");

    ctx.services
        .chat_service
        .list_chat_backup_catalog()
        .await
        .map_err(map_command_error("Failed to list chat backup catalog"))
}

pub async fn restore_character_chat_backup(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<Vec<String>, CommandError> {
    let dto: RestoreCharacterChatBackupDto = args.typed("dto")?;
    log_command(format!(
        "restore_character_chat_backup {} for {}",
        dto.backup_name, dto.character_name
    ));

    ctx.services
        .chat_service
        .restore_character_chat_backup(dto)
        .await
        .map_err(map_command_error("Failed to restore character chat backup"))
}

pub async fn delete_chat_backup(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let name: String = args.require("name")?;
    log_command(format!("delete_chat_backup {}", name));

    ctx.services
        .chat_service
        .delete_chat_backup(&name)
        .await
        .map_err(map_command_error("Failed to delete chat backup"))
}

pub async fn clear_chat_cache(ctx: &Ctx<'_>) -> Result<(), CommandError> {
    log_command("clear_chat_cache");

    ctx.services
        .chat_service
        .clear_cache()
        .await
        .map_err(map_command_error("Failed to clear chat cache"))
}

/// `allow_not_found` 为 true 时把 NotFound 折叠成空串 —— 前端在「聊天文件可能还没生成」
/// 的首屏探测里需要这个语义，不必区分「为空」和「不存在」。
pub async fn get_chat_payload_path(ctx: &Ctx<'_>, args: &Args) -> Result<String, CommandError> {
    let character_name: String = args.require("characterName")?;
    let file_name: String = args.require("fileName")?;
    let allow_not_found: bool = args.optional_bool("allowNotFound")?.unwrap_or(false);
    log_command(format!(
        "get_chat_payload_path {}/{}",
        character_name, file_name
    ));

    match ctx
        .services
        .chat_service
        .get_chat_payload_path(&character_name, &file_name)
        .await
    {
        Ok(path) => Ok(path),
        Err(ApplicationError::NotFound(_)) if allow_not_found => Ok(String::new()),
        Err(error) => Err(map_command_error(format!(
            "Failed to get chat payload path {}/{}",
            character_name, file_name
        ))(error)),
    }
}

pub async fn get_chat_payload_tail(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<ChatPayloadTail, CommandError> {
    let character_name: String = args.require("characterName")?;
    let file_name: String = args.require("fileName")?;
    let max_lines: usize = args.require_u64("maxLines")? as usize;
    let allow_not_found: bool = args.optional_bool("allowNotFound")?.unwrap_or(false);
    log_command(format!(
        "get_chat_payload_tail {}/{}",
        character_name, file_name
    ));

    match ctx
        .services
        .chat_service
        .get_chat_payload_tail_lines(&character_name, &file_name, max_lines)
        .await
    {
        Ok(result) => Ok(result),
        Err(ApplicationError::NotFound(_)) if allow_not_found => Ok(ChatPayloadTail {
            header: String::new(),
            lines: Vec::new(),
            cursor: ChatPayloadCursor {
                offset: 0,
                size: 0,
                modified_millis: 0,
            },
            has_more_before: false,
        }),
        Err(error) => Err(map_command_error(format!(
            "Failed to get chat payload tail {}/{}",
            character_name, file_name
        ))(error)),
    }
}

pub async fn get_chat_payload_before(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<ChatPayloadChunk, CommandError> {
    let character_name: String = args.require("characterName")?;
    let file_name: String = args.require("fileName")?;
    let cursor: ChatPayloadCursor = args.require_typed("cursor")?;
    let max_lines: usize = args.require_u64("maxLines")? as usize;
    log_command(format!(
        "get_chat_payload_before {}/{}",
        character_name, file_name
    ));

    ctx.services
        .chat_service
        .get_chat_payload_before_lines(&character_name, &file_name, cursor, max_lines)
        .await
        .map_err(map_command_error(format!(
            "Failed to get chat payload before {}/{}",
            character_name, file_name
        )))
}

pub async fn get_chat_payload_before_pages(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<Vec<ChatPayloadChunk>, CommandError> {
    let character_name: String = args.require("characterName")?;
    let file_name: String = args.require("fileName")?;
    let cursor: ChatPayloadCursor = args.require_typed("cursor")?;
    let max_lines: usize = args.require_u64("maxLines")? as usize;
    let max_pages: usize = args.require_u64("maxPages")? as usize;
    log_command(format!(
        "get_chat_payload_before_pages {}/{}",
        character_name, file_name
    ));

    ctx.services
        .chat_service
        .get_chat_payload_before_pages_lines(&character_name, &file_name, cursor, max_lines, max_pages)
        .await
        .map_err(map_command_error(format!(
            "Failed to get chat payload before pages {}/{}",
            character_name, file_name
        )))
}

pub async fn import_character_chats(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<Vec<String>, CommandError> {
    let dto: ImportCharacterChatsDto = args.typed("dto")?;
    log_command(format!("import_character_chats {}", dto.character_name));

    ctx.services
        .chat_service
        .import_character_chats(dto)
        .await
        .map_err(map_command_error("Failed to import character chats"))
}

/// 生成开始/结束的通知钩子。`ChatHistoryCoordinator` 靠它们把聊天文件标记为「正在生成」，
/// 从而让并发写与摘要缓存失效得到正确时序。上游同样把它们暴露成命令（而不是内部事件），
/// 因为决定「何时开始生成」的是前端。
pub async fn chat_history_generation_started(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<(), CommandError> {
    let locator: ChatHistoryLocator = args.require_typed("locator")?;
    log_command("chat_history_generation_started");

    ctx.services
        .chat_history_coordinator
        .generation_started(locator)
        .await
        .map_err(map_command_error("Failed to mark generation started"))
}

pub async fn chat_history_generation_finished(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<(), CommandError> {
    let locator: ChatHistoryLocator = args.require_typed("locator")?;
    log_command("chat_history_generation_finished");

    ctx.services
        .chat_history_coordinator
        .generation_finished(locator)
        .await
        .map_err(map_command_error("Failed to mark generation finished"))
}
