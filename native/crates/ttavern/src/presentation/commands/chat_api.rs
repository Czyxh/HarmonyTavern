//! 角色聊天 store/metadata/search 命令（上游 `chat_api_commands.rs`，11 条，全部移植）。
//!
//! 对应 DevEco 工程路径：native/crates/ttavern/src/presentation/commands/chat_api.rs

use serde_json::Value;

use tt_application::dto::chat_dto::ChatSearchResultDto;
use tt_contracts::chat::{
    ChatMessageSearchHit, ChatMessageSearchQuery, FindLastMessageQuery, LocatedChatMessage,
};

use crate::host::Ctx;
use crate::presentation::dispatch::Args;
use crate::presentation::errors::CommandError;
use crate::presentation::helpers::{log_command, map_command_error};

fn char_and_file<'a>(args: &'a Args) -> Result<(String, String), CommandError> {
    let character_name: String = args.require("characterName")?;
    let file_name: String = args.require("fileName")?;
    Ok((character_name, file_name))
}

pub async fn get_character_chat_summary(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<ChatSearchResultDto, CommandError> {
    let (character_name, file_name) = char_and_file(args)?;
    let include_metadata: bool = args.optional_bool("includeMetadata")?.unwrap_or(false);
    log_command(format!(
        "get_character_chat_summary {}/{}",
        character_name, file_name
    ));

    ctx.services
        .chat_service
        .get_character_chat_summary(&character_name, &file_name, include_metadata)
        .await
        .map_err(map_command_error(format!(
            "Failed to get chat summary {}/{}",
            character_name, file_name
        )))
}

pub async fn get_character_chat_integrity(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<Option<String>, CommandError> {
    let (character_name, file_name) = char_and_file(args)?;
    log_command(format!(
        "get_character_chat_integrity {}/{}",
        character_name, file_name
    ));

    ctx.services
        .chat_service
        .get_character_chat_integrity(&character_name, &file_name)
        .await
        .map_err(map_command_error(format!(
            "Failed to check chat integrity {}/{}",
            character_name, file_name
        )))
}

pub async fn get_character_chat_metadata(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<Value, CommandError> {
    let (character_name, file_name) = char_and_file(args)?;
    log_command(format!(
        "get_character_chat_metadata {}/{}",
        character_name, file_name
    ));

    ctx.services
        .chat_service
        .get_character_chat_metadata(&character_name, &file_name)
        .await
        .map_err(map_command_error(format!(
            "Failed to get chat metadata {}/{}",
            character_name, file_name
        )))
}

fn char_file_namespace(args: &Args) -> Result<(String, String, String), CommandError> {
    let (character_name, file_name) = char_and_file(args)?;
    let namespace: String = args.require("namespace")?;
    Ok((character_name, file_name, namespace))
}

pub async fn get_character_chat_store_json(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<Value, CommandError> {
    let (character_name, file_name, namespace) = char_file_namespace(args)?;
    let key: String = args.require("key")?;
    log_command(format!(
        "get_character_chat_store_json {}/{} {} {}",
        character_name, file_name, namespace, key
    ));

    ctx.services
        .chat_service
        .get_character_chat_store_json(&character_name, &file_name, &namespace, &key)
        .await
        .map_err(map_command_error(format!(
            "Failed to get chat store json {}/{}",
            character_name, file_name
        )))
}

pub async fn set_character_chat_store_json(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<(), CommandError> {
    let (character_name, file_name, namespace) = char_file_namespace(args)?;
    let key: String = args.require("key")?;
    let value: Value = args.require_typed("value")?;
    log_command(format!(
        "set_character_chat_store_json {}/{} {} {}",
        character_name, file_name, namespace, key
    ));

    ctx.services
        .chat_service
        .set_character_chat_store_json(&character_name, &file_name, &namespace, &key, value)
        .await
        .map_err(map_command_error(format!(
            "Failed to set chat store json {}/{}",
            character_name, file_name
        )))
}

pub async fn update_character_chat_store_json(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<(), CommandError> {
    let (character_name, file_name, namespace) = char_file_namespace(args)?;
    let key: String = args.require("key")?;
    let value: Value = args.require_typed("value")?;
    log_command(format!(
        "update_character_chat_store_json {}/{} {} {}",
        character_name, file_name, namespace, key
    ));

    ctx.services
        .chat_service
        .update_character_chat_store_json(&character_name, &file_name, &namespace, &key, value)
        .await
        .map_err(map_command_error(format!(
            "Failed to update chat store json {}/{}",
            character_name, file_name
        )))
}

pub async fn rename_character_chat_store_key(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<(), CommandError> {
    let (character_name, file_name, namespace) = char_file_namespace(args)?;
    let key: String = args.require("key")?;
    let new_key: String = args.require("newKey")?;
    log_command(format!(
        "rename_character_chat_store_key {}/{} {} {} -> {}",
        character_name, file_name, namespace, key, new_key
    ));

    ctx.services
        .chat_service
        .rename_character_chat_store_key(&character_name, &file_name, &namespace, &key, &new_key)
        .await
        .map_err(map_command_error(format!(
            "Failed to rename chat store key {}/{}",
            character_name, file_name
        )))
}

pub async fn delete_character_chat_store_json(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<(), CommandError> {
    let (character_name, file_name, namespace) = char_file_namespace(args)?;
    let key: String = args.require("key")?;
    log_command(format!(
        "delete_character_chat_store_json {}/{} {} {}",
        character_name, file_name, namespace, key
    ));

    ctx.services
        .chat_service
        .delete_character_chat_store_json(&character_name, &file_name, &namespace, &key)
        .await
        .map_err(map_command_error(format!(
            "Failed to delete chat store json {}/{}",
            character_name, file_name
        )))
}

pub async fn list_character_chat_store_keys(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<Vec<String>, CommandError> {
    let (character_name, file_name, namespace) = char_file_namespace(args)?;
    log_command(format!(
        "list_character_chat_store_keys {}/{} {}",
        character_name, file_name, namespace
    ));

    ctx.services
        .chat_service
        .list_character_chat_store_keys(&character_name, &file_name, &namespace)
        .await
        .map_err(map_command_error(format!(
            "Failed to list chat store keys {}/{}",
            character_name, file_name
        )))
}

pub async fn find_last_character_chat_message(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<Option<LocatedChatMessage>, CommandError> {
    let (character_name, file_name) = char_and_file(args)?;
    let query: FindLastMessageQuery = args.require_typed("query")?;
    log_command(format!(
        "find_last_character_chat_message {}/{}",
        character_name, file_name
    ));

    ctx.services
        .chat_service
        .find_last_character_chat_message(&character_name, &file_name, query)
        .await
        .map_err(map_command_error(format!(
            "Failed to find last message {}/{}",
            character_name, file_name
        )))
}

pub async fn search_character_chat_messages(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<Vec<ChatMessageSearchHit>, CommandError> {
    let (character_name, file_name) = char_and_file(args)?;
    let query: ChatMessageSearchQuery = args.require_typed("query")?;
    log_command(format!(
        "search_character_chat_messages {}/{}",
        character_name, file_name
    ));

    ctx.services
        .chat_service
        .search_character_chat_messages(&character_name, &file_name, query)
        .await
        .map_err(map_command_error(format!(
            "Failed to search messages {}/{}",
            character_name, file_name
        )))
}
