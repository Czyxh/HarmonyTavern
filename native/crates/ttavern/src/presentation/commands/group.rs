//! Group (群聊) commands — P8 batch, 12 commands.
//!
//! ## Why these exist
//!
//! Same story as world info: `GroupService` (create/update/delete/list groups) and
//! `GroupChatService` (summaries, metadata, payload path, rename/delete, search) are fully
//! implemented in `tt-application`, but the OHOS host exposes **zero** commands for them.
//! Upstream reached this through `POST /api/groups/*` and `/api/chats/group/*`.
//!
//! | command | upstream |
//! | --- | --- |
//! | `get_all_groups` | `POST /api/groups/all` |
//! | `get_group` | `POST /api/groups/get` |
//! | `create_group` | `POST /api/groups/create` |
//! | `update_group` | `POST /api/groups/edit`（整包写回） |
//! | `delete_group` | `POST /api/groups/delete` |
//! | `list_group_chat_summaries` | `POST /api/chats/group/get` |
//! | `search_group_chats` | 群聊搜索 |
//! | `get_group_chat_metadata` | 群聊首行 metadata |
//! | `get_group_chat_payload_path` | 群聊 `.jsonl` 绝对路径（原生侧直接读行） |
//! | `rename_group_chat` | `POST /api/chats/group/rename` |
//! | `delete_group_chat` | `POST /api/chats/group/delete` |
//! | `clear_group_chat_cache` | 上游 chat cache 失效 |
//!
//! ## Wire notes
//!
//! Payload keys are camelCase on the way in (`groupId`, `chatId`, `includeMetadata`), while
//! the group DTO itself stays the SillyTavern payload shape (`hideMutedSprites` alias kept).
//! `update_group` accepts the **whole** `GroupDto` because upstream `groups/edit` writes the
//! full group payload back to disk.
//!
//! ## What is *not* here
//!
//! Who-speaks-next orchestration is front-end logic in SillyTavern; Rust only persists the
//! group config (`activation_strategy`, `generation_mode`). Generating a group reply reuses
//! the ordinary `generate_chat_completion` command with the group's chat ref.

use tt_application::dto::chat_dto::{DeleteGroupChatDto, RenameGroupChatDto};
use tt_application::dto::group_dto::{CreateGroupDto, DeleteGroupDto, GroupDto, UpdateGroupDto};

use crate::host::Ctx;
use crate::presentation::dispatch::Args;
use crate::presentation::errors::CommandError;
use crate::presentation::helpers::{log_command, map_command_error};

// Serialize native session mutations; optimistic message count rejects stale UI appends.
static SESSION_LOCK: tokio::sync::Mutex<()> = tokio::sync::Mutex::const_new(());

pub async fn native_group_session(ctx: &Ctx<'_>, args: &Args) -> Result<serde_json::Value, CommandError> {
    use serde_json::json;
    use tokio::io::AsyncWriteExt;
    let _guard = SESSION_LOCK.lock().await;
    let group_id: String = args.require("groupId")?;
    let operation: String = args.require("operation")?;
    let group = ctx.services.group_service.get_group(&group_id).await
        .map_err(map_command_error("Read group"))?
        .ok_or_else(|| CommandError::BadRequest("Group no longer exists".into()))?;
    let mut group = GroupDto::from(group);
    let chat_id: String = if operation == "create" { uuid::Uuid::new_v4().to_string() }
        else { args.require("chatId")?.trim_end_matches(".jsonl").to_string() };
    if chat_id.is_empty() || chat_id.contains(['/', '\\']) || chat_id == "." || chat_id == ".." {
        return Err(CommandError::BadRequest("Invalid group chat id".into()));
    }
    if operation != "create" && !group.chats.iter().any(|id| id.trim_end_matches(".jsonl") == chat_id) {
        return Err(CommandError::BadRequest("Chat does not belong to this group".into()));
    }
    let runtime = crate::host::runtime::runtime().ok_or_else(|| CommandError::BadRequest("Backend not ready".into()))?;
    let directory = runtime.context.data_directory.group_chats();
    let path = directory.join(format!("{chat_id}.jsonl"));
    let mut raw = if operation == "create" { format!("{}\n", json!({"chat_metadata":{},"group_id":group_id})) }
        else { tokio::fs::read_to_string(&path).await.map_err(|e| CommandError::BadRequest(e.to_string()))? };
    let mut messages: Vec<serde_json::Value> = raw.lines().skip(1).filter(|line| !line.trim().is_empty())
        .map(serde_json::from_str).collect::<Result<_, _>>()
        .map_err(|e| CommandError::BadRequest(format!("Invalid chat JSONL: {e}")))?;
    match operation.as_str() {
        "read" => return Ok(json!({"chatId":chat_id,"messages":messages})),
        "create" => {},
        "append" => {
            let expected: usize = args.typed("expectedCount")?;
            if expected != messages.len() { return Err(CommandError::BadRequest("Chat changed; refresh before retrying".into())); }
            let message: serde_json::Value = args.typed("message")?;
            if message["mes"].as_str().is_none_or(|s| s.trim().is_empty() || s.len() > 1_048_576)
                || !message["is_user"].is_boolean() || !message["name"].is_string() {
                return Err(CommandError::BadRequest("Invalid group message".into()));
            }
            if !raw.ends_with('\n') { raw.push('\n'); }
            raw.push_str(&message.to_string()); raw.push('\n'); messages.push(message);
        },
        _ => return Err(CommandError::BadRequest("Unknown session operation".into()))
    }
    let temporary = directory.join(format!(".native-{}.tmp", uuid::Uuid::new_v4()));
    let mut file = tokio::fs::OpenOptions::new().write(true).create_new(true).open(&temporary).await
        .map_err(|e| CommandError::InternalServerError(e.to_string()))?;
    file.write_all(raw.as_bytes()).await.map_err(|e| CommandError::InternalServerError(e.to_string()))?;
    tt_adapter_storage_core::file_system::persist_file(file, &temporary, &path).await
        .map_err(map_command_error("Save group chat"))?;
    if operation == "create" {
        group.chat_id = chat_id.clone(); group.chats.push(chat_id.clone());
        if let Err(error) = ctx.services.group_service.update_group(group).await {
            let _ = tokio::fs::remove_file(&path).await;
            return Err(map_command_error("Attach group chat")(error));
        }
    }
    ctx.services.group_chat_service.clear_cache().await.map_err(map_command_error("Refresh group cache"))?;
    Ok(json!({"chatId":chat_id,"messages":messages}))
}

fn to_value<T: serde::Serialize>(value: T) -> Result<serde_json::Value, CommandError> {
    serde_json::to_value(value)
        .map_err(|error| CommandError::InternalServerError(format!("serialize: {error}")))
}

pub async fn get_all_groups(ctx: &Ctx<'_>) -> Result<Vec<GroupDto>, CommandError> {
    log_command("get_all_groups");

    let groups = ctx
        .services
        .group_service
        .get_all_groups()
        .await
        .map_err(map_command_error("Failed to get groups"))?;

    Ok(groups.into_iter().map(GroupDto::from).collect())
}

pub async fn get_group(ctx: &Ctx<'_>, args: &Args) -> Result<Option<GroupDto>, CommandError> {
    let id: String = args.require("id")?;
    log_command(format!("get_group {}", id));

    let group = ctx
        .services
        .group_service
        .get_group(&id)
        .await
        .map_err(map_command_error("Failed to get group"))?;

    Ok(group.map(GroupDto::from))
}

pub async fn create_group(ctx: &Ctx<'_>, args: &Args) -> Result<GroupDto, CommandError> {
    let dto: CreateGroupDto = args.typed("dto")?;
    log_command(format!("create_group {}", dto.name));

    let group = ctx
        .services
        .group_service
        .create_group(dto)
        .await
        .map_err(map_command_error("Failed to create group"))?;

    Ok(GroupDto::from(group))
}

/// 上游 `groups/edit` 整包写回，所以这里也吃完整 `GroupDto`。
pub async fn update_group(ctx: &Ctx<'_>, args: &Args) -> Result<GroupDto, CommandError> {
    let dto: UpdateGroupDto = args.typed("dto")?;
    log_command(format!("update_group {}", dto.id));

    let group = ctx
        .services
        .group_service
        .update_group(dto)
        .await
        .map_err(map_command_error("Failed to update group"))?;

    Ok(GroupDto::from(group))
}

pub async fn delete_group(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let dto: DeleteGroupDto = args.typed("dto")?;
    log_command(format!("delete_group {}", dto.id));

    ctx.services
        .group_service
        .delete_group(dto)
        .await
        .map_err(map_command_error("Failed to delete group"))
}

/// `{ chatIds?: string[], includeMetadata?: bool }` → 群聊摘要列表。
pub async fn list_group_chat_summaries(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<serde_json::Value, CommandError> {
    let chat_ids: Option<Vec<String>> = args.optional("chatIds")?;
    let include_metadata: bool = args.optional("includeMetadata")?.unwrap_or(false);
    log_command(format!(
        "list_group_chat_summaries n={:?} metadata={}",
        chat_ids.as_ref().map(|ids| ids.len()),
        include_metadata
    ));

    let summaries = ctx
        .services
        .group_chat_service
        .list_group_chat_summaries(chat_ids.as_deref(), include_metadata)
        .await
        .map_err(map_command_error("Failed to list group chat summaries"))?;

    to_value(summaries)
}

pub async fn search_group_chats(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<serde_json::Value, CommandError> {
    let query: String = args.require("query")?;
    let chat_ids: Option<Vec<String>> = args.optional("chatIds")?;
    log_command(format!("search_group_chats {}", query));

    let hits = ctx
        .services
        .group_chat_service
        .search_group_chats(&query, chat_ids.as_deref())
        .await
        .map_err(map_command_error("Failed to search group chats"))?;

    to_value(hits)
}

pub async fn get_group_chat_metadata(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<serde_json::Value, CommandError> {
    let chat_id: String = args.require("chatId")?;
    log_command(format!("get_group_chat_metadata {}", chat_id));

    ctx.services
        .group_chat_service
        .get_group_chat_metadata(&chat_id)
        .await
        .map_err(map_command_error("Failed to get group chat metadata"))
}

pub async fn get_group_chat_payload_path(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<String, CommandError> {
    let chat_id: String = args.require("chatId")?;
    log_command(format!("get_group_chat_payload_path {}", chat_id));

    ctx.services
        .group_chat_service
        .get_group_chat_payload_path(&chat_id)
        .await
        .map_err(map_command_error("Failed to get group chat payload path"))
}

pub async fn rename_group_chat(ctx: &Ctx<'_>, args: &Args) -> Result<String, CommandError> {
    let dto: RenameGroupChatDto = args.typed("dto")?;
    log_command(format!(
        "rename_group_chat {} -> {}",
        dto.old_file_name, dto.new_file_name
    ));

    ctx.services
        .group_chat_service
        .rename_group_chat(dto)
        .await
        .map_err(map_command_error("Failed to rename group chat"))
}

pub async fn delete_group_chat(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let dto: DeleteGroupChatDto = args.typed("dto")?;
    log_command(format!("delete_group_chat {}", dto.id));

    ctx.services
        .group_chat_service
        .delete_group_chat(dto)
        .await
        .map_err(map_command_error("Failed to delete group chat"))
}

pub async fn clear_group_chat_cache(ctx: &Ctx<'_>) -> Result<(), CommandError> {
    log_command("clear_group_chat_cache");

    ctx.services
        .group_chat_service
        .clear_cache()
        .await
        .map_err(map_command_error("Failed to clear group chat cache"))
}

#[cfg(test)]
mod native_session_tests {
    use serde_json::{Value, json};
    async fn invoke(command: &str, payload: Value) -> Value {
        let raw = crate::presentation::dispatch::invoke(command, Some(&payload.to_string())).await;
        serde_json::from_str(&raw).unwrap()
    }
    #[tokio::test]
    async fn native_group_session_roundtrip_rejects_stale_and_foreign_chat() {
        let root = std::env::temp_dir().join(format!("native-group-session-{}", uuid::Uuid::new_v4()));
        let media = std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../../../entry/src/main/resources/rawfile/default");
        crate::host::runtime::initialize(&json!({"filesDir":root.join("files"),
            "databaseDir":root.join("database"), "cacheDir":root.join("cache"),
            "bundleName":"com.example.harmonytavern", "versionName":"1.0.0", "bundledMediaDir":media
        }).to_string()).await.unwrap();
        let group = invoke("create_group", json!({"dto":{"name":"Session test","members":[]}})).await;
        assert_eq!(group["ok"], true, "{group}");
        let id = group["data"]["id"].as_str().unwrap();
        let session = invoke("native_group_session", json!({"groupId":id,"operation":"create"})).await;
        assert_eq!(session["ok"], true, "{session}");
        let chat = session["data"]["chatId"].as_str().unwrap();
        let append = json!({"groupId":id,"chatId":chat,"operation":"append","expectedCount":0,
            "message":{"name":"测试用户","is_user":true,"is_system":false,"send_date":"2026-11-01", "mes":"中文群聊消息", "extension":{"keep":true}}});
        let saved = invoke("native_group_session", append.clone()).await;
        assert_eq!(saved["ok"], true, "{saved}");
        let stale = invoke("native_group_session", append).await;
        assert_eq!(stale["ok"], false, "{stale}");
        let read = invoke("native_group_session", json!({"groupId":id,"chatId":format!("{chat}.jsonl"),"operation":"read"})).await;
        assert_eq!(read["data"]["messages"].as_array().unwrap().len(), 1);
        assert_eq!(read["data"]["messages"][0]["extension"]["keep"], true);
        assert_eq!(read["data"]["messages"][0]["mes"], "中文群聊消息");
        let foreign = invoke("native_group_session", json!({"groupId":id,"chatId":"unrelated","operation":"read"})).await;
        assert_eq!(foreign["ok"], false);
        let traversal = invoke("native_group_session", json!({"groupId":id,"chatId":"../settings","operation":"read"})).await;
        assert_eq!(traversal["ok"], false);
        let empty = invoke("native_group_session", json!({"groupId":id,"chatId":chat,"operation":"append","expectedCount":1,
            "message":{"name":"User","is_user":true,"mes":" "}})).await;
        assert_eq!(empty["ok"], false);
    }
}
