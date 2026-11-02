//! The single NAPI entry point: `invoke(command, payloadJson)`.
//!
//! Wire contract (mirrors Tauri's `invoke` argument convention):
//! - ArkTS passes the object of named arguments exactly as the Tauri command declared them,
//!   e.g. `{"id":"..."}`, `{"dto":{...}}`, or `{}`.
//! - The result is always a JSON envelope — never a rejected Promise — so the ArkTS layer
//!   has one code path:
//!   `{"ok":true,"data":<command result>}` or
//!   `{"ok":false,"error":{"code":"not_found","message":"Not found: ..."}}`.

use serde::de::DeserializeOwned;
use serde_json::{Map, Value};

use crate::host::Ctx;
use crate::presentation::commands;

use super::errors::CommandError;

/// Named arguments of one command call (the Tauri `invoke` payload).
pub struct Args {
    map: Map<String, Value>,
}

impl Args {
    fn from_value(value: Value) -> Result<Self, CommandError> {
        match value {
            Value::Null => Ok(Self { map: Map::new() }),
            Value::Object(map) => Ok(Self { map }),
            other => Err(CommandError::BadRequest(format!(
                "Command payload must be a JSON object, got {}",
                json_type_name(&other)
            ))),
        }
    }

    /// Required string argument.
    pub fn require(&self, name: &str) -> Result<String, CommandError> {
        match self.map.get(name) {
            Some(Value::String(value)) => Ok(value.clone()),
            Some(other) => Err(CommandError::BadRequest(format!(
                "Argument `{name}` must be a string, got {}",
                json_type_name(other)
            ))),
            None => Err(CommandError::BadRequest(format!(
                "Missing argument `{name}`"
            ))),
        }
    }

    /// Required structured argument (DTO), deserialised exactly as Tauri would.
    pub fn typed<T: DeserializeOwned>(&self, name: &str) -> Result<T, CommandError> {
        let value = self
            .map
            .get(name)
            .ok_or_else(|| CommandError::BadRequest(format!("Missing argument `{name}`")))?;
        serde_json::from_value(value.clone()).map_err(|error| {
            CommandError::BadRequest(format!("Invalid argument `{name}`: {error}"))
        })
    }

    /// Optional boolean argument (`None` when absent or `null`).
    pub fn optional_bool(&self, name: &str) -> Result<Option<bool>, CommandError> {
        match self.map.get(name) {
            None | Some(Value::Null) => Ok(None),
            Some(Value::Bool(value)) => Ok(Some(*value)),
            Some(other) => Err(CommandError::BadRequest(format!(
                "Argument `{name}` must be a boolean, got {}",
                json_type_name(other)
            ))),
        }
    }

    /// Optional structured argument.
    pub fn optional_typed<T: DeserializeOwned>(
        &self,
        name: &str,
    ) -> Result<Option<T>, CommandError> {
        match self.map.get(name) {
            None | Some(Value::Null) => Ok(None),
            Some(value) => serde_json::from_value(value.clone())
                .map(Some)
                .map_err(|error| {
                    CommandError::BadRequest(format!("Invalid argument `{name}`: {error}"))
                }),
        }
    }

    /// Optional argument of any deserialisable shape (strings, numbers, arrays, objects).
    pub fn optional<T: DeserializeOwned>(&self, name: &str) -> Result<Option<T>, CommandError> {
        self.optional_typed(name)
    }

    /// Required argument of any deserialisable shape (e.g. `Vec<String>`).
    pub fn require_typed<T: DeserializeOwned>(&self, name: &str) -> Result<T, CommandError> {
        self.typed(name)
    }

    /// Required unsigned integer argument (JSON numbers arrive as `u64` when integral).
    pub fn require_u64(&self, name: &str) -> Result<u64, CommandError> {
        match self.map.get(name) {
            Some(Value::Number(number)) => number.as_u64().ok_or_else(|| {
                CommandError::BadRequest(format!(
                    "Argument `{name}` must be a non-negative integer"
                ))
            }),
            Some(other) => Err(CommandError::BadRequest(format!(
                "Argument `{name}` must be a number, got {}",
                json_type_name(other)
            ))),
            None => Err(CommandError::BadRequest(format!(
                "Missing argument `{name}`"
            ))),
        }
    }
}

fn json_type_name(value: &Value) -> &'static str {
    match value {
        Value::Null => "null",
        Value::Bool(_) => "boolean",
        Value::Number(_) => "number",
        Value::String(_) => "string",
        Value::Array(_) => "array",
        Value::Object(_) => "object",
    }
}

/// Handle one command call. Returns the JSON envelope (success or failure).
pub async fn invoke(command: &str, payload_json: Option<&str>) -> String {
    let payload: Value = match payload_json {
        None => Value::Null,
        Some(raw) if raw.trim().is_empty() => Value::Null,
        Some(raw) => match serde_json::from_str(raw) {
            Ok(value) => value,
            Err(error) => {
                return error_envelope(&CommandError::BadRequest(format!(
                    "Command payload is not valid JSON: {error}"
                )));
            }
        },
    };

    let Some(ctx) = Ctx::resolve() else {
        return error_envelope(&CommandError::InternalServerError(
            "Backend is not initialized; call initialize(pathsJson) first".to_string(),
        ));
    };
    let args = match Args::from_value(payload) {
        Ok(args) => args,
        Err(error) => return error_envelope(&error),
    };

    match route(command, &ctx, &args).await {
        Ok(data) => serde_json::json!({ "ok": true, "data": data }).to_string(),
        Err(error) => error_envelope(&error),
    }
}

fn error_envelope(error: &CommandError) -> String {
    serde_json::json!({
        "ok": false,
        "error": {
            "code": error.code(),
            "message": error.to_string(),
        },
    })
    .to_string()
}

/// Command table. Every entry maps one ArkTS-visible name to one ported handler.
async fn route(command: &str, ctx: &Ctx<'_>, args: &Args) -> Result<Value, CommandError> {
    let value = match command {
        // Bootstrap / readiness
        "get_bootstrap_metadata" => {
            to_value(commands::bootstrap::get_bootstrap_metadata(ctx).await?)?
        }
        "backend_error_bridge_ready" => {
            to_value(commands::bootstrap::backend_error_bridge_ready(ctx)?)?
        }
        "wait_for_backend_ready" => {
            to_value(commands::bootstrap::wait_for_backend_ready(ctx).await?)?
        }

        // Runtime paths
        "get_runtime_paths" => to_value(commands::runtime_paths::get_runtime_paths(ctx)?)?,
        "set_data_root" => {
            let data_root: String = args
                .require("dataRoot")
                .or_else(|_| args.require("data_root"))?;
            to_value(commands::runtime_paths::set_data_root(ctx, &data_root).await?)?
        }

        // Default content seeding
        "initialize_default_content" => {
            to_value(commands::content::initialize_default_content(ctx).await?)?
        }
        "is_default_content_initialized" => {
            to_value(commands::content::is_default_content_initialized(ctx).await?)?
        }

        // Users
        "get_all_users" => to_value(commands::user::get_all_users(ctx).await?)?,
        "get_user" => to_value(commands::user::get_user(ctx, args).await?)?,
        "get_user_by_username" => {
            to_value(commands::user::get_user_by_username(ctx, args).await?)?
        }
        "create_user" => to_value(commands::user::create_user(ctx, args).await?)?,
        "update_user" => to_value(commands::user::update_user(ctx, args).await?)?,
        "delete_user" => to_value(commands::user::delete_user(ctx, args).await?)?,

        // User directories
        "get_user_directory" => to_value(commands::user::get_user_directory(ctx, args).await?)?,
        "ensure_user_directories_exist" => {
            to_value(commands::user::ensure_user_directories_exist(ctx, args).await?)?
        }
        "ensure_default_user_directories_exist" => {
            to_value(commands::user::ensure_default_user_directories_exist(ctx).await?)?
        }

        // Characters
        "get_all_characters" => {
            to_value(commands::character::get_all_characters(ctx, args).await?)?
        }
        // ---- P8: 世界书（world info / lorebook），9 条 ----
        "list_world_infos" => to_value(commands::world_info::list_world_infos(ctx).await?)?,
        "get_world_info" => to_value(commands::world_info::get_world_info(ctx, args).await?)?,
        "world_info_begin_commit" => {
            to_value(commands::world_info::world_info_begin_commit(ctx).await?)?
        }
        "world_info_append_commit_chunk" => {
            to_value(commands::world_info::world_info_append_commit_chunk(ctx, args).await?)?
        }
        "world_info_finish_commit" => {
            to_value(commands::world_info::world_info_finish_commit(ctx, args).await?)?
        }
        "world_info_abort_commit" => {
            to_value(commands::world_info::world_info_abort_commit(ctx, args).await?)?
        }
        "delete_world_info" => to_value(commands::world_info::delete_world_info(ctx, args).await?)?,
        "normalize_world_info_name" => {
            to_value(commands::world_info::normalize_world_info_name(ctx, args).await?)?
        }
        "import_world_info" => to_value(commands::world_info::import_world_info(ctx, args).await?)?,
        // ---- P8: 群聊（group / group chat），12 条 ----
        "native_group_session" => commands::group::native_group_session(ctx, args).await?,
        "get_all_groups" => to_value(commands::group::get_all_groups(ctx).await?)?,
        "get_group" => to_value(commands::group::get_group(ctx, args).await?)?,
        "create_group" => to_value(commands::group::create_group(ctx, args).await?)?,
        "update_group" => to_value(commands::group::update_group(ctx, args).await?)?,
        "delete_group" => to_value(commands::group::delete_group(ctx, args).await?)?,
        "list_group_chat_summaries" => {
            to_value(commands::group::list_group_chat_summaries(ctx, args).await?)?
        }
        "search_group_chats" => to_value(commands::group::search_group_chats(ctx, args).await?)?,
        "get_group_chat_metadata" => {
            to_value(commands::group::get_group_chat_metadata(ctx, args).await?)?
        }
        "get_group_chat_payload_path" => {
            to_value(commands::group::get_group_chat_payload_path(ctx, args).await?)?
        }
        "rename_group_chat" => to_value(commands::group::rename_group_chat(ctx, args).await?)?,
        "delete_group_chat" => to_value(commands::group::delete_group_chat(ctx, args).await?)?,
        "clear_group_chat_cache" => {
            to_value(commands::group::clear_group_chat_cache(ctx).await?)?
        }
        "get_character" => to_value(commands::character::get_character(ctx, args).await?)?,
        "create_character" => to_value(commands::character::create_character(ctx, args).await?)?,
        "update_character" => to_value(commands::character::update_character(ctx, args).await?)?,
        "delete_character" => to_value(commands::character::delete_character(ctx, args).await?)?,
        "rename_character" => to_value(commands::character::rename_character(ctx, args).await?)?,
        "duplicate_character" => {
            to_value(commands::character::duplicate_character(ctx, args).await?)?
        }
        "update_avatar" => to_value(commands::character::update_avatar(ctx, args).await?)?,
        "get_character_chats_by_id" => {
            to_value(commands::character::get_character_chats_by_id(ctx, args).await?)?
        }
        "clear_character_cache" => {
            to_value(commands::character::clear_character_cache(ctx).await?)?
        }

        // Tokenization
        "count_openai_tokens_batch" => {
            to_value(commands::tokenizer::count_openai_tokens_batch(ctx, args).await?)?
        }
        "count_openai_token_prefixes" => {
            to_value(commands::tokenizer::count_openai_token_prefixes(ctx, args).await?)?
        }
        "encode_tokens" => to_value(commands::tokenizer::encode_tokens(ctx, args).await?)?,
        "decode_tokens" => to_value(commands::tokenizer::decode_tokens(ctx, args).await?)?,
        "build_openai_logit_bias" => {
            to_value(commands::tokenizer::build_openai_logit_bias(ctx, args).await?)?
        }

        // Settings
        "get_tauritavern_settings" => {
            to_value(commands::settings::get_tauritavern_settings(ctx).await?)?
        }
        "get_chat_backup_storage_stats" => {
            to_value(commands::settings::get_chat_backup_storage_stats(ctx).await?)?
        }
        "update_tauritavern_settings" => {
            to_value(commands::settings::update_tauritavern_settings(ctx, args).await?)?
        }
        "begin_settings_commit" => {
            to_value(commands::settings::begin_settings_commit(ctx, args).await?)?
        }
        "append_settings_commit_chunk" => {
            to_value(commands::settings::append_settings_commit_chunk(ctx, args).await?)?
        }
        "finish_settings_commit" => {
            to_value(commands::settings::finish_settings_commit(ctx, args).await?)?
        }
        "abort_settings_commit" => {
            to_value(commands::settings::abort_settings_commit(ctx, args).await?)?
        }
        "get_sillytavern_settings" => {
            to_value(commands::settings::get_sillytavern_settings(ctx).await?)?
        }
        "get_native_preferences" => commands::native_preferences::get(ctx).await?,
        "update_native_preferences" => commands::native_preferences::update(ctx, args).await?,
        "get_native_context" => commands::native_context::status(ctx, args).await?,
        "prepare_native_context" => commands::native_context::prepare(ctx, args).await?,
        "commit_native_context" => commands::native_context::commit(ctx, args).await?,
        "reset_native_context" => commands::native_context::reset(ctx, args).await?,
        "prepare_native_chat" => commands::native_preferences::prepare_chat(ctx, args).await?,
        "prepare_native_world_reply" => commands::native_world::prepare_reply(ctx, args).await?,
        "get_native_world_state" => commands::native_world::status(ctx, args).await?,
        "prepare_native_world_state" => commands::native_world::prepare(ctx, args).await?,
        "commit_native_world_state" => commands::native_world::commit(ctx, args).await?,
        "apply_native_world_item_action" => commands::native_world::item_action(ctx, args).await?,
        "get_native_usage_statistics" => to_value(commands::native_usage::get(ctx, args).await?)?,
        "get_native_story" => commands::native_story::get(ctx, args).await?,
        "save_native_story" => commands::native_story::save(ctx, args).await?,
        "create_native_story" => commands::native_story::create(ctx, args).await?,
        "commit_native_story_reply" => commands::native_story::commit_reply(ctx, args).await?,
        "get_native_story_choices" => commands::native_story::get_choices(ctx, args).await?,
        "prepare_native_story_choices" => commands::native_story::prepare_choices(ctx, args).await?,
        "commit_native_story_choices" => commands::native_story::commit_choices(ctx, args).await?,
        "get_native_identity_avatars" => commands::native_preferences::avatars(ctx).await?,
        "upload_native_identity_avatar" => commands::native_preferences::upload_avatar(ctx, args).await?,
        "create_settings_snapshot" => {
            to_value(commands::settings::create_settings_snapshot(ctx).await?)?
        }
        "get_settings_snapshots" => {
            to_value(commands::settings::get_settings_snapshots(ctx).await?)?
        }
        "load_settings_snapshot" => {
            to_value(commands::settings::load_settings_snapshot(ctx, args).await?)?
        }
        "restore_settings_snapshot" => {
            to_value(commands::settings::restore_settings_snapshot(ctx, args).await?)?
        }

        // User files
        "sanitize_filename" => to_value(commands::file::sanitize_filename(args).await?)?,
        "upload_user_file" => to_value(commands::file::upload_user_file(ctx, args).await?)?,
        "delete_user_file" => to_value(commands::file::delete_user_file(ctx, args).await?)?,
        "verify_user_files" => to_value(commands::file::verify_user_files(ctx, args).await?)?,

        // User images
        "upload_user_image" => to_value(commands::image::upload_user_image(ctx, args).await?)?,
        "list_user_images" => to_value(commands::image::list_user_images(ctx, args).await?)?,
        "list_user_image_folders" => {
            to_value(commands::image::list_user_image_folders(ctx).await?)?
        }
        "delete_user_image" => to_value(commands::image::delete_user_image(ctx, args).await?)?,

        // Character card import / export
        "import_character" => to_value(commands::character::import_character(ctx, args).await?)?,
        "replace_character" => to_value(commands::character::replace_character(ctx, args).await?)?,
        "export_character_content" => {
            to_value(commands::character::export_character_content(ctx, args).await?)?
        }
        "create_character_with_avatar" => {
            to_value(commands::character::create_character_with_avatar(ctx, args).await?)?
        }

        // External import + product info
        "download_external_import_url" => {
            to_value(commands::content::download_external_import_url(ctx, args).await?)?
        }
        "get_client_version" => to_value(commands::product::get_client_version().await?)?,

        // ---- P5: chat（24 条；`open_chat_payload_json` / `open_chat_backup_download`
        // 绑定 WebView 资源表，按 §11.3-D 不移植，改由游标分页命令替代）----
        "get_all_chats" => to_value(commands::chat::get_all_chats(ctx).await?)?,
        "get_chat" => to_value(commands::chat::get_chat(ctx, args).await?)?,
        "get_character_chats" => to_value(commands::chat::get_character_chats(ctx, args).await?)?,
        "create_chat" => to_value(commands::chat::create_chat(ctx, args).await?)?,
        "add_message" => to_value(commands::chat::add_message(ctx, args).await?)?,
        "rename_chat" => to_value(commands::chat::rename_chat(ctx, args).await?)?,
        "delete_chat" => to_value(commands::chat::delete_chat(ctx, args).await?)?,
        "search_chats" => to_value(commands::chat::search_chats(ctx, args).await?)?,
        "list_chat_summaries" => to_value(commands::chat::list_chat_summaries(ctx, args).await?)?,
        "list_recent_chat_summaries" => {
            to_value(commands::chat::list_recent_chat_summaries(ctx, args).await?)?
        }
        "import_chat" => to_value(commands::chat::import_chat(ctx, args).await?)?,
        "backup_chat" => to_value(commands::chat::backup_chat(ctx, args).await?)?,
        "list_chat_backups" => to_value(commands::chat::list_chat_backups(ctx).await?)?,
        "list_chat_backup_catalog" => {
            to_value(commands::chat::list_chat_backup_catalog(ctx).await?)?
        }
        "restore_character_chat_backup" => {
            to_value(commands::chat::restore_character_chat_backup(ctx, args).await?)?
        }
        "delete_chat_backup" => to_value(commands::chat::delete_chat_backup(ctx, args).await?)?,
        "clear_chat_cache" => to_value(commands::chat::clear_chat_cache(ctx).await?)?,
        "get_chat_payload_path" => {
            to_value(commands::chat::get_chat_payload_path(ctx, args).await?)?
        }
        "get_chat_payload_tail" => {
            to_value(commands::chat::get_chat_payload_tail(ctx, args).await?)?
        }
        "get_chat_payload_before" => {
            to_value(commands::chat::get_chat_payload_before(ctx, args).await?)?
        }
        "get_chat_payload_before_pages" => {
            to_value(commands::chat::get_chat_payload_before_pages(ctx, args).await?)?
        }
        "import_character_chats" => {
            to_value(commands::chat::import_character_chats(ctx, args).await?)?
        }
        "chat_history_generation_started" => {
            to_value(commands::chat::chat_history_generation_started(ctx, args).await?)?
        }
        "chat_history_generation_finished" => {
            to_value(commands::chat::chat_history_generation_finished(ctx, args).await?)?
        }

        // ---- P5: 角色聊天 store/metadata/search（11 条）----
        "get_character_chat_summary" => {
            to_value(commands::chat_api::get_character_chat_summary(ctx, args).await?)?
        }
        "get_character_chat_integrity" => {
            to_value(commands::chat_api::get_character_chat_integrity(ctx, args).await?)?
        }
        "get_character_chat_metadata" => {
            to_value(commands::chat_api::get_character_chat_metadata(ctx, args).await?)?
        }
        "get_character_chat_store_json" => {
            to_value(commands::chat_api::get_character_chat_store_json(ctx, args).await?)?
        }
        "set_character_chat_store_json" => {
            to_value(commands::chat_api::set_character_chat_store_json(ctx, args).await?)?
        }
        "update_character_chat_store_json" => {
            to_value(commands::chat_api::update_character_chat_store_json(ctx, args).await?)?
        }
        "rename_character_chat_store_key" => {
            to_value(commands::chat_api::rename_character_chat_store_key(ctx, args).await?)?
        }
        "delete_character_chat_store_json" => {
            to_value(commands::chat_api::delete_character_chat_store_json(ctx, args).await?)?
        }
        "list_character_chat_store_keys" => {
            to_value(commands::chat_api::list_character_chat_store_keys(ctx, args).await?)?
        }
        "find_last_character_chat_message" => {
            to_value(commands::chat_api::find_last_character_chat_message(ctx, args).await?)?
        }
        "search_character_chat_messages" => {
            to_value(commands::chat_api::search_character_chat_messages(ctx, args).await?)?
        }

        // ---- 明确不移植的命令（返回值是 Tauri WebView ResourceId，鸿蒙无对应物）----
        "open_chat_payload_json" => {
            return Err(commands::not_ported::webview_resource_bound("open_chat_payload_json"))
        }
        "open_chat_backup_download" => {
            return Err(commands::not_ported::webview_resource_bound(
                "open_chat_backup_download",
            ))
        }
        "open_cold_chat" => {
            return Err(commands::not_ported::webview_resource_bound("open_cold_chat"))
        }
        "open_cold_swipe_record" => {
            return Err(commands::not_ported::webview_resource_bound(
                "open_cold_swipe_record",
            ))
        }
        "begin_chat_commit" => {
            return Err(commands::not_ported::webview_resource_bound("begin_chat_commit"))
        }
        "append_chat_commit_chunk" => {
            return Err(commands::not_ported::webview_resource_bound(
                "append_chat_commit_chunk",
            ))
        }
        "finish_chat_commit" => {
            return Err(commands::not_ported::webview_resource_bound("finish_chat_commit"))
        }
        "abort_chat_commit" => {
            return Err(commands::not_ported::webview_resource_bound("abort_chat_commit"))
        }

        // ---- P6.1: extension store 不移植 5 条（Webview 资源表 / ipc::Request 分块通道）----
        "open_extension_store_entry" => {
            return Err(commands::not_ported::webview_resource_bound(
                "open_extension_store_entry",
            ))
        }
        "begin_extension_store_commit" => {
            return Err(commands::not_ported::extension_store_commit_bound(
                "begin_extension_store_commit",
            ))
        }
        "append_extension_store_commit_chunk" => {
            return Err(commands::not_ported::extension_store_commit_bound(
                "append_extension_store_commit_chunk",
            ))
        }
        "finish_extension_store_commit" => {
            return Err(commands::not_ported::extension_store_commit_bound(
                "finish_extension_store_commit",
            ))
        }
        "abort_extension_store_commit" => {
            return Err(commands::not_ported::extension_store_commit_bound(
                "abort_extension_store_commit",
            ))
        }

        // ---- P6.1: agent extension tool 不移植 3 条（Webview + Channel）----
        "register_agent_extension_tool" => {
            return Err(commands::not_ported::agent_extension_tool_bound(
                "register_agent_extension_tool",
            ))
        }
        "set_agent_extension_tool_enabled" => {
            return Err(commands::not_ported::agent_extension_tool_bound(
                "set_agent_extension_tool_enabled",
            ))
        }
        "resolve_agent_extension_tool" => {
            return Err(commands::not_ported::agent_extension_tool_bound(
                "resolve_agent_extension_tool",
            ))
        }

        // ---- P6.2: extension（8 条）----
        "get_extensions" => to_value(commands::extension::get_extensions(ctx).await?)?,
        "install_extension" => {
            to_value(commands::extension::install_extension(ctx, args).await?)?
        }
        "update_extension" => {
            to_value(commands::extension::update_extension(ctx, args).await?)?
        }
        "delete_extension" => {
            to_value(commands::extension::delete_extension(ctx, args).await?)?
        }
        "get_extension_version" => {
            to_value(commands::extension::get_extension_version(ctx, args).await?)?
        }
        "get_extension_branches" => {
            to_value(commands::extension::get_extension_branches(ctx, args).await?)?
        }
        "switch_extension_branch" => {
            to_value(commands::extension::switch_extension_branch(ctx, args).await?)?
        }
        "move_extension" => to_value(commands::extension::move_extension(ctx, args).await?)?,

        // ---- P6.2: agent（34 条）----
        "start_agent_run" => to_value(commands::agent::start_agent_run(ctx, args).await?)?,
        "read_agent_run_checkpoint" => {
            to_value(commands::agent::read_agent_run_checkpoint(ctx, args).await?)?
        }
        "resume_agent_run" => to_value(commands::agent::resume_agent_run(ctx, args).await?)?,
        "finish_agent_run_presentation" => {
            to_value(commands::agent::finish_agent_run_presentation(ctx, args).await?)?
        }
        "subscribe_agent_run_live_projection" => {
            to_value(commands::agent::subscribe_agent_run_live_projection(ctx, args).await?)?
        }
        "prepare_agent_prompt_assembly" => {
            to_value(commands::agent::prepare_agent_prompt_assembly(ctx, args).await?)?
        }
        "build_agent_current_model_connection_snapshot" => {
            to_value(commands::agent::build_agent_current_model_connection_snapshot(ctx, args).await?)?
        }
        "apply_agent_current_model_connection_snapshot" => {
            to_value(commands::agent::apply_agent_current_model_connection_snapshot(ctx, args).await?)?
        }
        "list_agent_profiles" => to_value(commands::agent::list_agent_profiles(ctx).await?)?,
        "list_agent_tools" => to_value(commands::agent::list_agent_tools(ctx, args).await?)?,
        "resolve_agent_system_prompt" => {
            to_value(commands::agent::resolve_agent_system_prompt(ctx, args).await?)?
        }
        "load_agent_profile" => {
            to_value(commands::agent::load_agent_profile(ctx, args).await?)?
        }
        "diagnose_agent_profile" => {
            to_value(commands::agent::diagnose_agent_profile(ctx, args).await?)?
        }
        "save_agent_profile" => {
            to_value(commands::agent::save_agent_profile(ctx, args).await?)?
        }
        "delete_agent_profile" => {
            to_value(commands::agent::delete_agent_profile(ctx, args).await?)?
        }
        "repair_agent_profile_file" => {
            to_value(commands::agent::repair_agent_profile_file(ctx, args).await?)?
        }
        "retarget_agent_profile_preset_refs" => {
            to_value(commands::agent::retarget_agent_profile_preset_refs(ctx, args).await?)?
        }
        "cancel_agent_run" => to_value(commands::agent::cancel_agent_run(ctx, args).await?)?,
        "submit_agent_run_guidance" => {
            to_value(commands::agent::submit_agent_run_guidance(ctx, args).await?)?
        }
        "list_active_agent_runs" => to_value(commands::agent::list_active_agent_runs(ctx).await?)?,
        "list_agent_runs" => to_value(commands::agent::list_agent_runs(ctx, args).await?)?,
        "plan_agent_run_prune" => {
            to_value(commands::agent::plan_agent_run_prune(ctx, args).await?)?
        }
        "apply_agent_run_prune" => {
            to_value(commands::agent::apply_agent_run_prune(ctx, args).await?)?
        }
        "read_agent_run_events" => {
            to_value(commands::agent::read_agent_run_events(ctx, args).await?)?
        }
        "read_agent_workspace_bytes" => {
            to_value(commands::agent::read_agent_workspace_bytes(ctx, args).await?)?
        }
        "read_agent_workspace_file" => {
            to_value(commands::agent::read_agent_workspace_file(ctx, args).await?)?
        }
        "read_agent_task_detail" => {
            to_value(commands::agent::read_agent_task_detail(ctx, args).await?)?
        }
        "read_agent_model_turn" => {
            to_value(commands::agent::read_agent_model_turn(ctx, args).await?)?
        }
        "read_agent_prompt_assembly_request" => {
            to_value(commands::agent::read_agent_prompt_assembly_request(ctx, args).await?)?
        }
        "resolve_agent_chat_commit" => {
            to_value(commands::agent::resolve_agent_chat_commit(ctx, args).await?)?
        }
        "resolve_agent_prompt_assembly" => {
            to_value(commands::agent::resolve_agent_prompt_assembly(ctx, args).await?)?
        }
        "resolve_agent_persistent_state_metadata_update" => {
            to_value(commands::agent::resolve_agent_persistent_state_metadata_update(ctx, args).await?)?
        }
        "prune_agent_chat_persistent_states" => {
            to_value(commands::agent::prune_agent_chat_persistent_states(ctx, args).await?)?
        }
        "copy_agent_chat_persistent_states" => {
            to_value(commands::agent::copy_agent_chat_persistent_states(ctx, args).await?)?
        }

        // ---- P6.2: agent session（9 条）----
        "load_agent_session_profile" => {
            to_value(commands::agent_session::load_agent_session_profile(ctx).await?)?
        }
        "save_agent_session_profile" => {
            to_value(commands::agent_session::save_agent_session_profile(ctx, args).await?)?
        }
        "create_agent_session" => {
            to_value(commands::agent_session::create_agent_session(ctx).await?)?
        }
        "list_agent_sessions" => {
            to_value(commands::agent_session::list_agent_sessions(ctx).await?)?
        }
        "rename_agent_session" => {
            to_value(commands::agent_session::rename_agent_session(ctx, args).await?)?
        }
        "delete_agent_session" => {
            to_value(commands::agent_session::delete_agent_session(ctx, args).await?)?
        }
        "read_agent_session" => {
            to_value(commands::agent_session::read_agent_session(ctx, args).await?)?
        }
        "prepare_agent_session_run" => {
            to_value(commands::agent_session::prepare_agent_session_run(ctx, args).await?)?
        }
        "start_agent_session_run" => {
            to_value(commands::agent_session::start_agent_session_run(ctx, args).await?)?
        }

        // ---- P6.2: lan_sync（17 条）----
        "lan_sync_get_status" => to_value(commands::lan_sync::lan_sync_get_status(ctx).await?)?,
        "lan_sync_start_server" => {
            to_value(commands::lan_sync::lan_sync_start_server(ctx).await?)?
        }
        "lan_sync_stop_server" => to_value(commands::lan_sync::lan_sync_stop_server(ctx).await?)?,
        "lan_sync_get_pairing_info" => {
            to_value(commands::lan_sync::lan_sync_get_pairing_info(ctx).await?)?
        }
        "lan_sync_request_pairing" => {
            to_value(commands::lan_sync::lan_sync_request_pairing(ctx, args).await?)?
        }
        "lan_sync_discover_devices" => {
            to_value(commands::lan_sync::lan_sync_discover_devices(ctx).await?)?
        }
        "lan_sync_connect_address" => {
            to_value(commands::lan_sync::lan_sync_connect_address(ctx, args).await?)?
        }
        "lan_sync_set_device_name" => {
            to_value(commands::lan_sync::lan_sync_set_device_name(ctx, args).await?)?
        }
        "lan_sync_pair_device" => {
            to_value(commands::lan_sync::lan_sync_pair_device(ctx, args).await?)?
        }
        "lan_sync_confirm_pairing" => {
            to_value(commands::lan_sync::lan_sync_confirm_pairing(ctx, args).await?)?
        }
        "lan_sync_list_devices" => to_value(commands::lan_sync::lan_sync_list_devices(ctx).await?)?,
        "lan_sync_remove_device" => {
            to_value(commands::lan_sync::lan_sync_remove_device(ctx, args).await?)?
        }
        "lan_sync_sync_from_device" => {
            to_value(commands::lan_sync::lan_sync_sync_from_device(ctx, args).await?)?
        }
        "lan_sync_push_to_device" => {
            to_value(commands::lan_sync::lan_sync_push_to_device(ctx, args).await?)?
        }
        "lan_sync_set_sync_mode" => {
            to_value(commands::lan_sync::lan_sync_set_sync_mode(ctx, args).await?)?
        }
        "lan_sync_clear_sync_mode_override" => {
            to_value(commands::lan_sync::lan_sync_clear_sync_mode_override(ctx).await?)?
        }
        "lan_sync_set_overwrite_policy" => {
            to_value(commands::lan_sync::lan_sync_set_overwrite_policy(ctx, args).await?)?
        }

        // ---- P6.2: tt_sync（5 条）----
        "tt_sync_pair" => to_value(commands::tt_sync::tt_sync_pair(ctx, args).await?)?,
        "tt_sync_list_servers" => {
            to_value(commands::tt_sync::tt_sync_list_servers(ctx).await?)?
        }
        "tt_sync_remove_server" => {
            to_value(commands::tt_sync::tt_sync_remove_server(ctx, args).await?)?
        }
        "tt_sync_pull" => to_value(commands::tt_sync::tt_sync_pull(ctx, args).await?)?,
        "tt_sync_push" => to_value(commands::tt_sync::tt_sync_push(ctx, args).await?)?,

        // ---- P6.2: sync（1 条，裸 DTO 返回，无 Result 包装）----
        "sync_get_dataset_catalog" => {
            to_value(commands::sync::sync_get_dataset_catalog(ctx).await)?
        }

        // ---- P6.2: sync_automation（3 条）----
        "sync_automation_get_config" => {
            to_value(commands::sync_automation::sync_automation_get_config(ctx).await?)?
        }
        "sync_automation_update_config" => {
            to_value(commands::sync_automation::sync_automation_update_config(ctx, args).await?)?
        }
        "sync_automation_get_status" => {
            to_value(commands::sync_automation::sync_automation_get_status(ctx).await?)?
        }

        // ---- P5: chat completion（6 条）----
        "get_chat_completions_status" => {
            to_value(commands::chat_completion::get_chat_completions_status(ctx, args).await?)?
        }
        "generate_chat_completion" => {
            to_value(commands::chat_completion::generate_chat_completion(ctx, args).await?)?
        }
        "start_chat_completion_stream" => {
            to_value(commands::chat_completion::start_chat_completion_stream(ctx, args).await?)?
        }
        "read_chat_completion_stream" => {
            to_value(commands::chat_completion::read_chat_completion_stream(ctx, args).await?)?
        }
        "read_chat_completion_stream_decoded" => {
            to_value(commands::chat_completion::read_chat_completion_stream_decoded(ctx, args).await?)?
        }
        "close_chat_completion_stream" => {
            to_value(commands::chat_completion::close_chat_completion_stream(ctx, args).await?)?
        }
        "cancel_chat_completion_generation" => {
            to_value(commands::chat_completion::cancel_chat_completion_generation(ctx, args).await?)?
        }
        // OHOS 专有：端点授权三步握手的第 ③ 步（上游没有这条，因为它在命令内部弹窗）。
        "grant_user_endpoint_access" => {
            to_value(commands::chat_completion::grant_user_endpoint_access(ctx, args).await?)?
        }

        // ---- P5: secrets（8 条）----
        "write_secret" => to_value(commands::secret::write_secret(ctx, args).await?)?,
        "read_secret_state" => to_value(commands::secret::read_secret_state(ctx).await?)?,
        "read_secret_settings" => to_value(commands::secret::read_secret_settings(ctx).await?)?,
        "view_secrets" => to_value(commands::secret::view_secrets(ctx).await?)?,
        "find_secret" => to_value(commands::secret::find_secret(ctx, args).await?)?,
        "delete_secret" => to_value(commands::secret::delete_secret(ctx, args).await?)?,
        "rotate_secret" => to_value(commands::secret::rotate_secret(ctx, args).await?)?,
        "rename_secret" => to_value(commands::secret::rename_secret(ctx, args).await?)?,

        // ---- P6.1: presets（8 条）----
        "save_preset" => to_value(commands::preset::save_preset(ctx, args).await?)?,
        "delete_preset" => to_value(commands::preset::delete_preset(ctx, args).await?)?,
        "restore_preset" => to_value(commands::preset::restore_preset(ctx, args).await?)?,
        "save_openai_preset" => to_value(commands::preset::save_openai_preset(ctx, args).await?)?,
        "delete_openai_preset" => {
            to_value(commands::preset::delete_openai_preset(ctx, args).await?)?
        }
        "list_presets" => to_value(commands::preset::list_presets(ctx, args).await?)?,
        "preset_exists" => to_value(commands::preset::preset_exists(ctx, args).await?)?,
        "get_preset" => to_value(commands::preset::get_preset(ctx, args).await?)?,

        // ---- P6.1: MCP（16 条）----
        "list_mcp_servers" => to_value(commands::mcp::list_mcp_servers(ctx, args).await?)?,
        "create_mcp_server" => to_value(commands::mcp::create_mcp_server(ctx, args).await?)?,
        "update_mcp_server" => to_value(commands::mcp::update_mcp_server(ctx, args).await?)?,
        "set_mcp_server_state" => to_value(commands::mcp::set_mcp_server_state(ctx, args).await?)?,
        "remove_mcp_server" => to_value(commands::mcp::remove_mcp_server(ctx, args).await?)?,
        "discover_mcp_tools" => to_value(commands::mcp::discover_mcp_tools(ctx, args).await?)?,
        "refresh_mcp_tools" => to_value(commands::mcp::refresh_mcp_tools(ctx, args).await?)?,
        "set_mcp_tool_permission" => {
            to_value(commands::mcp::set_mcp_tool_permission(ctx, args).await?)?
        }
        "set_mcp_tool_description_override" => {
            to_value(commands::mcp::set_mcp_tool_description_override(ctx, args).await?)?
        }
        "start_mcp_test_call" => to_value(commands::mcp::start_mcp_test_call(ctx, args).await?)?,
        "test_mcp_tool_call" => to_value(commands::mcp::test_mcp_tool_call(ctx, args).await?)?,
        "cancel_mcp_test_call" => to_value(commands::mcp::cancel_mcp_test_call(ctx, args).await?)?,
        "list_legacy_mcp_tools" => {
            to_value(commands::mcp::list_legacy_mcp_tools(ctx, args).await?)?
        }
        "start_legacy_mcp_tool_call" => {
            to_value(commands::mcp::start_legacy_mcp_tool_call(ctx, args).await?)?
        }
        "call_legacy_mcp_tool" => {
            to_value(commands::mcp::call_legacy_mcp_tool(ctx, args).await?)?
        }
        "cancel_legacy_mcp_tool_call" => {
            to_value(commands::mcp::cancel_legacy_mcp_tool_call(ctx, args).await?)?
        }

        // ---- P6.1: Agent Skills（13 条）----
        "download_skill_import_url" => {
            to_value(commands::skill::download_skill_import_url(ctx, args).await?)?
        }
        "list_skills" => to_value(commands::skill::list_skills(ctx, args).await?)?,
        "list_skill_files" => to_value(commands::skill::list_skill_files(ctx, args).await?)?,
        "discover_skill_imports" => {
            to_value(commands::skill::discover_skill_imports(ctx, args).await?)?
        }
        "discard_skill_import_archive" => {
            to_value(commands::skill::discard_skill_import_archive(ctx, args).await?)?
        }
        "preview_skill_import" => {
            to_value(commands::skill::preview_skill_import(ctx, args).await?)?
        }
        "install_skill_import" => {
            to_value(commands::skill::install_skill_import(ctx, args).await?)?
        }
        "read_skill_file" => to_value(commands::skill::read_skill_file(ctx, args).await?)?,
        "write_skill_file" => to_value(commands::skill::write_skill_file(ctx, args).await?)?,
        "export_skill" => to_value(commands::skill::export_skill(ctx, args).await?)?,
        "delete_skill" => to_value(commands::skill::delete_skill(ctx, args).await?)?,
        "move_skill" => to_value(commands::skill::move_skill(ctx, args).await?)?,
        "retarget_skill_scope" => {
            to_value(commands::skill::retarget_skill_scope(ctx, args).await?)?
        }

        // ---- P6.1: provider metadata（7 条）----
        "get_openrouter_model_providers" => {
            to_value(commands::provider_metadata::get_openrouter_model_providers(ctx, args).await?)?
        }
        "get_openrouter_credits" => {
            to_value(commands::provider_metadata::get_openrouter_credits(ctx, args).await?)?
        }
        "get_nanogpt_model_providers" => {
            to_value(commands::provider_metadata::get_nanogpt_model_providers(ctx, args).await?)?
        }
        "get_nanogpt_credits" => {
            to_value(commands::provider_metadata::get_nanogpt_credits(ctx, args).await?)?
        }
        "get_siliconflow_embedding_models" => {
            to_value(commands::provider_metadata::get_siliconflow_embedding_models(ctx, args).await?)?
        }
        "get_workers_ai_embedding_models" => {
            to_value(commands::provider_metadata::get_workers_ai_embedding_models(ctx, args).await?)?
        }
        "get_workers_ai_multimodal_models" => {
            to_value(commands::provider_metadata::get_workers_ai_multimodal_models(ctx, args).await?)?
        }

        // ---- P6.1: LLM connections（4 条）----
        "list_llm_connections" => {
            to_value(commands::llm_connection::list_llm_connections(ctx, args).await?)?
        }
        "load_llm_connection" => {
            to_value(commands::llm_connection::load_llm_connection(ctx, args).await?)?
        }
        "save_llm_connection" => {
            to_value(commands::llm_connection::save_llm_connection(ctx, args).await?)?
        }
        "delete_llm_connection" => {
            to_value(commands::llm_connection::delete_llm_connection(ctx, args).await?)?
        }

        // ---- P6.1: SearXNG / vector / database ----
        "search_searxng" => to_value(commands::searxng_search::search_searxng(ctx, args).await?)?,
        "vector_handle" => to_value(commands::vector::vector_handle(ctx, args).await?)?,
        "database_handle" => to_value(commands::database::database_handle(ctx, args).await?)?,

        // ---- P6.1: data archive（6 条）----
        "import_data_archive_from_picker" => {
            to_value(commands::data_archive::import_data_archive_from_picker(ctx, args).await?)?
        }
        "start_export_data_archive" => {
            to_value(commands::data_archive::start_export_data_archive(ctx, args).await?)?
        }
        "get_data_archive_job_status" => {
            to_value(commands::data_archive::get_data_archive_job_status(ctx, args).await?)?
        }
        "cancel_data_archive_job" => {
            to_value(commands::data_archive::cancel_data_archive_job(ctx, args).await?)?
        }
        "save_export_data_archive" => {
            to_value(commands::data_archive::save_export_data_archive(ctx, args).await?)?
        }
        "export_user_backup_archive" => {
            to_value(commands::data_archive::export_user_backup_archive(ctx, args).await?)?
        }

        // ---- P6.1: extension store（可移植 5 条）----
        "rename_extension_store_key" => {
            to_value(commands::extension_store::rename_extension_store_key(ctx, args).await?)?
        }
        "delete_extension_store_entry" => {
            to_value(commands::extension_store::delete_extension_store_entry(ctx, args).await?)?
        }
        "list_extension_store_keys" => {
            to_value(commands::extension_store::list_extension_store_keys(ctx, args).await?)?
        }
        "list_extension_store_tables" => {
            to_value(commands::extension_store::list_extension_store_tables(ctx, args).await?)?
        }
        "delete_extension_store_table" => {
            to_value(commands::extension_store::delete_extension_store_table(ctx, args).await?)?
        }

        other => {
            return Err(CommandError::NotFound(format!(
                "Unknown command `{other}` (not ported yet, or misspelled)"
            )));
        }
    };

    Ok(value)
}

fn to_value<T: serde::Serialize>(value: T) -> Result<Value, CommandError> {
    serde_json::to_value(value).map_err(|error| {
        CommandError::InternalServerError(format!("Failed to serialise command result: {error}"))
    })
}
