//! 端到端命令契约测试：不接设备，直接把 `dispatch::invoke` 逐个打一遍。
//!
//! 为什么需要它：P4 在真机上只验了 **7 条**命令，其余 50 条的 payload 参数名
//! （`{}` / `{"name":…}` / `{"dto":{…}}` / `{"handle":…}`）从来没被真实调用过。
//! 参数名写错时后端返回 `bad_request`，而这种错误只在 UI 真正调用时才暴露 ——
//! 属于「编译通过、装机不崩、点开某个页面才炸」的一类。
//!
//! 对应 DevEco/工程路径：native/crates/ttavern/src/dispatch_contract_tests.rs
//!
//! 本测试的价值有三个，都不需要鸿蒙设备：
//!   1. 57 条路由**全部被识别**（打错名字会得到 `not_found`，测试立刻失败）。
//!   2. 每条命令在空 payload 下**不 panic**，且返回的是 8 个合法错误码之一。
//!   3. 信封格式与错误码契约在整个命令面上保持一致。
//!
//! 注意：`runtime::initialize` 是进程级全局状态，本文件只允许 initialize 一次。

use std::path::PathBuf;

use serde_json::Value;

/// 当前 dispatch.rs 注册的全部命令名。删掉或改名会让本测试失败 —— 这是故意的：
/// 命令面是对 ArkTS 的公开契约，任何增删都应当被显式看见。
const ROUTES: &[&str] = &[
    "get_native_usage_statistics",
    "get_native_world_state",
    "prepare_native_world_state",
    "commit_native_world_state",
    "apply_native_world_item_action",
    "prepare_native_world_reply",
    "get_bootstrap_metadata",
    "backend_error_bridge_ready",
    "wait_for_backend_ready",
    "get_runtime_paths",
    "set_data_root",
    "initialize_default_content",
    "is_default_content_initialized",
    "get_all_users",
    "get_user",
    "get_user_by_username",
    "create_user",
    "update_user",
    "delete_user",
    "get_user_directory",
    "ensure_user_directories_exist",
    "ensure_default_user_directories_exist",
    "get_all_characters",
    "get_character",
    "create_character",
    "update_character",
    "delete_character",
    "rename_character",
    "duplicate_character",
    "update_avatar",
    "get_character_chats_by_id",
    "clear_character_cache",
    "count_openai_tokens_batch",
    "count_openai_token_prefixes",
    "encode_tokens",
    "decode_tokens",
    "build_openai_logit_bias",
    "get_tauritavern_settings",
    "get_chat_backup_storage_stats",
    "update_tauritavern_settings",
    "begin_settings_commit",
    "append_settings_commit_chunk",
    "finish_settings_commit",
    "abort_settings_commit",
    "get_sillytavern_settings",
    "create_settings_snapshot",
    "get_settings_snapshots",
    "load_settings_snapshot",
    "restore_settings_snapshot",
    "sanitize_filename",
    "upload_user_file",
    "delete_user_file",
    "verify_user_files",
    "upload_user_image",
    "list_user_images",
    "list_user_image_folders",
    "delete_user_image",
    "import_character",
    "replace_character",
    "export_character_content",
    "create_character_with_avatar",
    "download_external_import_url",
    "get_client_version",
    // ---- P5: chat（24 条）----
    "get_all_chats",
    "get_chat",
    "get_character_chats",
    "create_chat",
    "add_message",
    "rename_chat",
    "delete_chat",
    "search_chats",
    "list_chat_summaries",
    "list_recent_chat_summaries",
    "import_chat",
    "backup_chat",
    "list_chat_backups",
    "list_chat_backup_catalog",
    "restore_character_chat_backup",
    "delete_chat_backup",
    "clear_chat_cache",
    "get_chat_payload_path",
    "get_chat_payload_tail",
    "get_chat_payload_before",
    "get_chat_payload_before_pages",
    "import_character_chats",
    "chat_history_generation_started",
    "chat_history_generation_finished",
    // ---- P5: 角色聊天 store/metadata/search（11 条）----
    "get_character_chat_summary",
    "get_character_chat_integrity",
    "get_character_chat_metadata",
    "get_character_chat_store_json",
    "set_character_chat_store_json",
    "update_character_chat_store_json",
    "rename_character_chat_store_key",
    "delete_character_chat_store_json",
    "list_character_chat_store_keys",
    "find_last_character_chat_message",
    "search_character_chat_messages",
    // ---- P5: chat completion（6 条 + OHOS 授权第 ③ 步）----
    "get_chat_completions_status",
    "generate_chat_completion",
    "start_chat_completion_stream",
    "read_chat_completion_stream",
    "read_chat_completion_stream_decoded",
    "close_chat_completion_stream",
    "cancel_chat_completion_generation",
    "grant_user_endpoint_access",
    // ---- P5: secrets（8 条）----
    "write_secret",
    "read_secret_state",
    "read_secret_settings",
    "view_secrets",
    "find_secret",
    "delete_secret",
    "rotate_secret",
    "rename_secret",
    // ---- 明确不移植的命令（返回值绑定 Tauri WebView ResourceId）----
    "open_chat_payload_json",
    "open_chat_backup_download",
    "open_cold_chat",
    "open_cold_swipe_record",
    "begin_chat_commit",
    "append_chat_commit_chunk",
    "finish_chat_commit",
    "abort_chat_commit",
    // ---- P6.1: presets（8 条）----
    "save_preset",
    "delete_preset",
    "restore_preset",
    "save_openai_preset",
    "delete_openai_preset",
    "list_presets",
    "preset_exists",
    "get_preset",
    // ---- P6.1: MCP（16 条）----
    "list_mcp_servers",
    "create_mcp_server",
    "update_mcp_server",
    "set_mcp_server_state",
    "remove_mcp_server",
    "discover_mcp_tools",
    "refresh_mcp_tools",
    "set_mcp_tool_permission",
    "set_mcp_tool_description_override",
    "start_mcp_test_call",
    "test_mcp_tool_call",
    "cancel_mcp_test_call",
    "list_legacy_mcp_tools",
    "start_legacy_mcp_tool_call",
    "call_legacy_mcp_tool",
    "cancel_legacy_mcp_tool_call",
    // ---- P6.1: Agent Skills（13 条）----
    "download_skill_import_url",
    "list_skills",
    "list_skill_files",
    "discover_skill_imports",
    "discard_skill_import_archive",
    "preview_skill_import",
    "install_skill_import",
    "read_skill_file",
    "write_skill_file",
    "export_skill",
    "delete_skill",
    "move_skill",
    "retarget_skill_scope",
    // ---- P6.1: provider metadata（7 条）----
    "get_openrouter_model_providers",
    "get_openrouter_credits",
    "get_nanogpt_model_providers",
    "get_nanogpt_credits",
    "get_siliconflow_embedding_models",
    "get_workers_ai_embedding_models",
    "get_workers_ai_multimodal_models",
    // ---- P6.1: LLM connections（4 条）----
    "list_llm_connections",
    "load_llm_connection",
    "save_llm_connection",
    "delete_llm_connection",
    // ---- P6.1: SearXNG / vector / database ----
    "search_searxng",
    "vector_handle",
    "database_handle",
    // ---- P6.1: data archive（6 条）----
    "import_data_archive_from_picker",
    "start_export_data_archive",
    "get_data_archive_job_status",
    "cancel_data_archive_job",
    "save_export_data_archive",
    "export_user_backup_archive",
    // ---- P6.1: extension store（可移植 5 条）----
    "rename_extension_store_key",
    "delete_extension_store_entry",
    "list_extension_store_keys",
    "list_extension_store_tables",
    "delete_extension_store_table",
    // ---- P6.1: 明确不移植（extension store 5 + agent extension tool 3）----
    "open_extension_store_entry",
    "begin_extension_store_commit",
    "append_extension_store_commit_chunk",
    "finish_extension_store_commit",
    "abort_extension_store_commit",
    "register_agent_extension_tool",
    "set_agent_extension_tool_enabled",
    "resolve_agent_extension_tool",
    // ---- P6.2: extension（8 条）----
    "get_extensions",
    "install_extension",
    "update_extension",
    "delete_extension",
    "get_extension_version",
    "get_extension_branches",
    "switch_extension_branch",
    "move_extension",
    // ---- P6.2: agent（34 条）----
    "start_agent_run",
    "read_agent_run_checkpoint",
    "resume_agent_run",
    "finish_agent_run_presentation",
    "subscribe_agent_run_live_projection",
    "prepare_agent_prompt_assembly",
    "build_agent_current_model_connection_snapshot",
    "apply_agent_current_model_connection_snapshot",
    "list_agent_profiles",
    "list_agent_tools",
    "resolve_agent_system_prompt",
    "load_agent_profile",
    "diagnose_agent_profile",
    "save_agent_profile",
    "delete_agent_profile",
    "repair_agent_profile_file",
    "retarget_agent_profile_preset_refs",
    "cancel_agent_run",
    "submit_agent_run_guidance",
    "list_active_agent_runs",
    "list_agent_runs",
    "plan_agent_run_prune",
    "apply_agent_run_prune",
    "read_agent_run_events",
    "read_agent_workspace_bytes",
    "read_agent_workspace_file",
    "read_agent_task_detail",
    "read_agent_model_turn",
    "read_agent_prompt_assembly_request",
    "resolve_agent_chat_commit",
    "resolve_agent_prompt_assembly",
    "resolve_agent_persistent_state_metadata_update",
    "prune_agent_chat_persistent_states",
    "copy_agent_chat_persistent_states",
    // ---- P6.2: agent session（9 条）----
    "load_agent_session_profile",
    "save_agent_session_profile",
    "create_agent_session",
    "list_agent_sessions",
    "rename_agent_session",
    "delete_agent_session",
    "read_agent_session",
    "prepare_agent_session_run",
    "start_agent_session_run",
    // ---- P6.2: lan_sync（17 条）----
    "lan_sync_get_status",
    "lan_sync_start_server",
    "lan_sync_stop_server",
    "lan_sync_get_pairing_info",
    "lan_sync_request_pairing",
    "lan_sync_discover_devices",
    "lan_sync_connect_address",
    "lan_sync_set_device_name",
    "lan_sync_pair_device",
    "lan_sync_confirm_pairing",
    "lan_sync_list_devices",
    "lan_sync_remove_device",
    "lan_sync_sync_from_device",
    "lan_sync_push_to_device",
    "lan_sync_set_sync_mode",
    "lan_sync_clear_sync_mode_override",
    "lan_sync_set_overwrite_policy",
    // ---- P6.2: tt_sync（5 条）----
    "tt_sync_pair",
    "tt_sync_list_servers",
    "tt_sync_remove_server",
    "tt_sync_pull",
    "tt_sync_push",
    // ---- P6.2: sync（1 条）----
    "sync_get_dataset_catalog",
    // ---- P6.2: sync_automation（3 条）----
    "sync_automation_get_config",
    "sync_automation_update_config",
    "sync_automation_get_status",
];

/// 明确不移植的命令：它们仍然注册在 dispatch 里，但**故意**返回 `not_found` + 原因说明。
const NOT_PORTED: &[&str] = &[
    "open_chat_payload_json",
    "open_chat_backup_download",
    "open_cold_chat",
    "open_cold_swipe_record",
    "begin_chat_commit",
    "append_chat_commit_chunk",
    "finish_chat_commit",
    "abort_chat_commit",
    // P6.1: extension store（Webview 资源表 / ipc::Request 分块通道）
    "open_extension_store_entry",
    "begin_extension_store_commit",
    "append_extension_store_commit_chunk",
    "finish_extension_store_commit",
    "abort_extension_store_commit",
    // P6.1: agent extension tool（Webview + Channel）
    "register_agent_extension_tool",
    "set_agent_extension_tool_enabled",
    "resolve_agent_extension_tool",
];

const VALID_CODES: &[&str] = &[
    "bad_request",
    "conflict",
    "not_found",
    "unauthorized",
    "cancelled",
    "too_many_requests",
    "upstream_failure",
    "internal",
];

fn temp_app_root() -> PathBuf {
    let root = std::env::temp_dir().join(format!(
        "ttavern-dispatch-contract-{}-{}",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_millis())
            .unwrap_or(0)
    ));
    std::fs::create_dir_all(&root).expect("create temp app root");
    root
}

/// 真实 HAP rawfile 里的 `default/` 目录（媒体 + 默认内容都在这里）。
/// 用它而不是造一棵假树，是为了让 initialize 走和真机完全一样的播种路径。
fn bundled_media_root() -> Option<String> {
    let candidate = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../../../entry/src/main/resources/rawfile/default");
    let normalized = candidate.canonicalize().ok()?;
    normalized.is_dir().then(|| normalized.to_string_lossy().into_owned())
}

fn paths_json(app_root: &PathBuf) -> String {
    let files = app_root.join("files");
    serde_json::json!({
        "filesDir": files.to_string_lossy(),
        "databaseDir": files.join("database").to_string_lossy(),
        "cacheDir": app_root.join("cache").to_string_lossy(),
        "bundleName": "com.example.harmonytavern",
        "versionName": "1.0.0",
        "bundledMediaDir": bundled_media_root(),
    })
    .to_string()
}

/// 断言信封形状：`{ok:true,data}` 或 `{ok:false,error:{code,message}}`。
fn assert_envelope(raw: &str, command: &str) -> Option<String> {
    let parsed: Value = serde_json::from_str(raw)
        .unwrap_or_else(|e| panic!("command `{command}` returned non-JSON ({e}): {raw}"));
    let ok = parsed
        .get("ok")
        .and_then(Value::as_bool)
        .unwrap_or_else(|| panic!("command `{command}` envelope has no boolean `ok`: {raw}"));

    if ok {
        assert!(
            parsed.get("data").is_some(),
            "command `{command}` returned ok without `data`: {raw}"
        );
        return None;
    }

    let error = parsed
        .get("error")
        .unwrap_or_else(|| panic!("command `{command}` returned !ok without `error`: {raw}"));
    let code = error
        .get("code")
        .and_then(Value::as_str)
        .unwrap_or_else(|| panic!("command `{command}` error has no `code`: {raw}"));
    assert!(
        VALID_CODES.contains(&code),
        "command `{command}` returned unknown error code `{code}` (allowed: {VALID_CODES:?})"
    );
    assert!(
        error.get("message").and_then(Value::as_str).is_some(),
        "command `{command}` error has no `message`: {raw}"
    );
    Some(code.to_string())
}

#[tokio::test(flavor = "multi_thread")]
async fn every_registered_command_is_dispatchable() {
    let root = temp_app_root();
    let init = crate::host::runtime::initialize(&paths_json(&root)).await;
    assert!(
        init.is_ok(),
        "initialize failed, cannot run dispatch contract: {:?}",
        init.err()
    );

    // 1. 未注册的命令必须是 not_found（而不是 internal 或 panic）。
    let unknown = crate::presentation::dispatch::invoke("definitely_not_a_command", None).await;
    assert_eq!(
        assert_envelope(&unknown, "definitely_not_a_command").as_deref(),
        Some("not_found"),
        "unknown command should be not_found, got: {unknown}"
    );

    // 2. 非法 JSON 必须是 bad_request。
    let bad_json =
        crate::presentation::dispatch::invoke("get_client_version", Some("{not json")).await;
    assert_eq!(
        assert_envelope(&bad_json, "get_client_version").as_deref(),
        Some("bad_request"),
        "invalid payload JSON should be bad_request, got: {bad_json}"
    );

    // 3. 每条已注册命令用空 payload 打一遍：必须被识别，不许 panic，错误码必须合法。
    let mut missing_arg = 0;
    let mut succeeded_with_empty_payload = 0;
    let mut not_ported = 0;
    let mut other_failures: Vec<(String, String)> = Vec::new();
    for command in ROUTES {
        let raw = crate::presentation::dispatch::invoke(command, Some("{}")).await;
        let code = assert_envelope(&raw, command);
        match code.as_deref() {
            None => succeeded_with_empty_payload += 1,
            Some("bad_request") => missing_arg += 1,
            Some("not_found") => {
                assert!(
                    NOT_PORTED.contains(&command),
                    "command `{command}` is listed in ROUTES but dispatch does not know it \
                     (registry drift?): {raw}"
                );
                assert!(
                    raw.contains("deliberately not ported"),
                    "not-ported command `{command}` must return the deliberate message, \
                     got: {raw}"
                );
                not_ported += 1;
            }
            Some(other) => other_failures.push((command.to_string(), other.to_string())),
        }
    }

    // 命令面画像：打印出来便于发现「某条命令突然行为变了」。
    println!(
        "routes={} ok_with_empty_payload={} bad_request(missing args)={} \
         not_ported={} other_failure={}",
        ROUTES.len(),
        succeeded_with_empty_payload,
        missing_arg,
        not_ported,
        other_failures.len()
    );
    for (command, code) in &other_failures {
        println!("other_failure: {command} -> {code}");
    }
    assert_eq!(
        succeeded_with_empty_payload + missing_arg + not_ported + other_failures.len(),
        ROUTES.len(),
        "every command must classify into exactly one bucket"
    );
    // 绝大多数命令需要参数；若这个数掉到 0，说明 Args 解析整体失效了。
    assert!(
        missing_arg > 0,
        "no command reported missing args with an empty payload - Args extraction may be broken"
    );

    // 唯一一个「其它失败」是安全语义，不是缺陷：`allow_keys_exposure` 默认 false 时
    // `view_secrets` 必须拒绝返回明文密钥。钉住它，防止哪天有人为了「调试方便」把
    // 闸门去掉而没有人发现。
    assert!(
        other_failures
            .iter()
            .any(|(command, code)| command == "view_secrets" && code == "unauthorized"),
        "view_secrets must refuse with `unauthorized` while allow_keys_exposure is false, \
         got: {other_failures:?}"
    );
    // 4. 已知需要参数的命令：错误信息里必须点名缺哪个字段（这是排查体验的关键）。
    let named = crate::presentation::dispatch::invoke("get_character", Some("{}")).await;
    let parsed: Value = serde_json::from_str(&named).expect("valid envelope");
    let message = parsed["error"]["message"].as_str().unwrap_or_default();
    assert!(
        message.contains("name") || message.contains("character"),
        "missing-argument message should name the expected field, got: {message}"
    );

    std::fs::remove_dir_all(&root).ok();
}
