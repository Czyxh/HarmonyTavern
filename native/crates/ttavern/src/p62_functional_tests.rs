//! P6.2 功能往返测试（2026-10-27，整阶段批准后于模拟器点验前的宿主预演）。
//!
//! 只选**确定性、离线**路径（不联网、不依赖双设备）：
//!   - extension：get_extensions（空）；缺键 → bad_request；
//!   - agent：list_agent_profiles / list_active_agent_runs / list_agent_tools / list_agent_sessions；
//!     read_agent_workspace_bytes（未知 run → not_found）；subscribe_agent_run_live_projection
//!     （未知 run → 空 Snapshot + ok，事件桥走通）；缺 dto → bad_request；
//!   - agent session：load_agent_session_profile / create_agent_session（返回 session）；
//!   - sync：sync_get_dataset_catalog（policy_version + 非空数据集目录）；lan_sync_get_status
//!     （未启动 running=false）；tt_sync_list_servers（空）；sync_automation_get_config /
//!     get_status；缺键/非法枚举 → bad_request。
//!
//! 与其它契约测试共享同一进程 runtime（幂等 initialize）；功能命名空间前缀 `p62-`。
//!
//! 对应 DevEco 工程路径：native/crates/ttavern/src/p62_functional_tests.rs

use serde_json::Value;

/// 幂等初始化（与 p61_functional_tests 同款，必须带 bundledMediaDir）。
async fn ensure_initialized() {
    let root = std::env::temp_dir().join(format!(
        "ttavern-p62-{}-{}",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_millis())
            .unwrap_or(0)
    ));
    std::fs::create_dir_all(&root).ok();
    let files = root.join("files");
    let bundled_media = std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../../../entry/src/main/resources/rawfile/default");
    let paths = serde_json::json!({
        "filesDir": files.to_string_lossy(),
        "databaseDir": files.join("database").to_string_lossy(),
        "cacheDir": root.join("cache").to_string_lossy(),
        "bundleName": "com.example.harmonytavern",
        "versionName": "1.0.0",
        "bundledMediaDir": bundled_media.to_string_lossy(),
    })
    .to_string();
    let result = crate::host::runtime::initialize(&paths).await;
    assert!(result.is_ok(), "initialize failed: {:?}", result.err());
}

/// 调用命令返回信封 `data`（失败 panic 并打印 raw）。
async fn call_ok(command: &str, payload: &serde_json::Value) -> Value {
    let raw = crate::presentation::dispatch::invoke(command, Some(&payload.to_string())).await;
    let parsed: Value = serde_json::from_str(&raw)
        .unwrap_or_else(|e| panic!("{command}: non-JSON ({e}): {raw}"));
    assert!(
        parsed["ok"].as_bool() == Some(true),
        "`{command}` should return ok: {raw}"
    );
    parsed["data"].clone()
}

/// 调用命令返回原始信封（供「预期失败」断言 code）。
async fn call_fail_code(command: &str, payload: &serde_json::Value) -> String {
    let raw = crate::presentation::dispatch::invoke(command, Some(&payload.to_string())).await;
    let parsed: Value = serde_json::from_str(&raw).expect("envelope JSON");
    assert!(
        parsed["ok"].as_bool() == Some(false),
        "`{command}` should fail: {raw}"
    );
    parsed["error"]["code"].as_str().unwrap_or("").to_string()
}

#[tokio::test(flavor = "multi_thread")]
async fn extension_management_offline_paths() {
    ensure_initialized().await;

    let list = call_ok("get_extensions", &serde_json::json!({})).await;
    assert!(list.is_array(), "get_extensions should be an array: {list}");

    // 未知扩展 → not_found（ExtensionService 对不存在扩展的查询路径）。
    let code = call_fail_code(
        "get_extension_version",
        &serde_json::json!({ "extension_name": "p62-nonexistent", "global": false }),
    )
    .await;
    assert_eq!(code, "not_found", "unknown extension should be not_found");

    // 缺 url → bad_request（require 缺键）。
    let code = call_fail_code("install_extension", &serde_json::json!({ "global": false })).await;
    assert_eq!(code, "bad_request", "missing url should be bad_request");
}

#[tokio::test(flavor = "multi_thread")]
async fn agent_read_side_offline_paths() {
    ensure_initialized().await;

    let profiles = call_ok("list_agent_profiles", &serde_json::json!({})).await;
    assert!(profiles.is_object(), "list_agent_profiles shape: {profiles}");

    let active = call_ok("list_active_agent_runs", &serde_json::json!({})).await;
    assert!(active.is_array(), "list_active_agent_runs should be array: {active}");

    let tools = call_ok("list_agent_tools", &serde_json::json!({})).await;
    assert!(tools.is_object(), "list_agent_tools shape: {tools}");

    // 未知 run 的 workspace 读 → not_found。
    let code = call_fail_code(
        "read_agent_workspace_bytes",
        &serde_json::json!({ "dto": { "runId": "p62-missing-run", "path": "x" } }),
    )
    .await;
    assert_eq!(code, "not_found", "unknown run workspace read: {code}");

    // 订阅未知 run → not_found（服务层先于订阅查 run 文件；ArkTS 侧以该 code 判定 run 已不存在）。
    let code = call_fail_code(
        "subscribe_agent_run_live_projection",
        &serde_json::json!({ "dto": { "runId": "p62-missing-run" } }),
    )
    .await;
    assert_eq!(code, "not_found", "subscribe unknown run: {code}");

    // 缺 dto → bad_request。
    let code = call_fail_code("start_agent_run", &serde_json::json!({})).await;
    assert_eq!(code, "bad_request", "missing dto: {code}");
}

#[tokio::test(flavor = "multi_thread")]
async fn agent_session_offline_paths() {
    ensure_initialized().await;

    let profile = call_ok("load_agent_session_profile", &serde_json::json!({})).await;
    assert!(profile.is_object(), "load_agent_session_profile shape: {profile}");

    let sessions = call_ok("list_agent_sessions", &serde_json::json!({})).await;
    assert!(sessions.is_object(), "list_agent_sessions shape: {sessions}");

    let created = call_ok("create_agent_session", &serde_json::json!({})).await;
    assert!(
        created["session"].is_object(),
        "create_agent_session returns session: {created}"
    );

    let code = call_fail_code("delete_agent_session", &serde_json::json!({})).await;
    assert_eq!(code, "bad_request", "missing dto: {code}");
}

#[tokio::test(flavor = "multi_thread")]
async fn sync_offline_paths() {
    ensure_initialized().await;

    // sync_get_dataset_catalog：裸 DTO，非空目录 + policy_version。
    let catalog = call_ok("sync_get_dataset_catalog", &serde_json::json!({})).await;
    assert!(
        catalog["policy_version"].as_u64().unwrap_or(0) > 0,
        "policy_version present: {catalog}"
    );
    assert!(
        catalog["supported_dataset_ids"].as_array().map_or(false, |a| !a.is_empty()),
        "dataset catalog non-empty: {catalog}"
    );

    // lan_sync 未启动 → running=false。
    let status = call_ok("lan_sync_get_status", &serde_json::json!({})).await;
    assert_eq!(
        status["running"].as_bool(),
        Some(false),
        "lan_sync_get_status idle: {status}"
    );

    let servers = call_ok("tt_sync_list_servers", &serde_json::json!({})).await;
    assert!(servers.is_array(), "tt_sync_list_servers array: {servers}");

    let config = call_ok("sync_automation_get_config", &serde_json::json!({})).await;
    assert!(config.is_object(), "sync_automation_get_config: {config}");

    let autom_status = call_ok("sync_automation_get_status", &serde_json::json!({})).await;
    assert!(autom_status.is_object(), "sync_automation_get_status: {autom_status}");

    // 错误路径：缺键 / 非法枚举值 → bad_request。
    let code = call_fail_code("lan_sync_confirm_pairing", &serde_json::json!({})).await;
    assert_eq!(code, "bad_request", "missing request_id: {code}");

    let code = call_fail_code(
        "lan_sync_set_sync_mode",
        &serde_json::json!({ "mode": "bogus-mode", "persist": false }),
    )
    .await;
    assert_eq!(code, "bad_request", "invalid SyncMode: {code}");

    let code = call_fail_code("tt_sync_pair", &serde_json::json!({})).await;
    assert_eq!(code, "bad_request", "missing pair_uri: {code}");

    let code = call_fail_code(
        "sync_automation_update_config",
        &serde_json::json!({ "config": 42 }),
    )
    .await;
    assert_eq!(code, "bad_request", "bad config type: {code}");
}

/// 空载荷 dispatch 分类扫描（p62-contract.md 审计表实测化）。
///
/// 59 条必填键命令：`{}` 载荷必须回 bad_request；15 条无参/全可选命令：`{}` 必须回 ok。
/// 3 条变异/网络类命令（lan_sync_start_server / get_pairing_info / discover_devices）不在此
/// 实测（会绑定端口 / 发起 mdns 浏览，且与 sync_offline_paths 的空闲态断言存在并行竞态），
/// 其「无必填键」分类由签名审计覆盖（p62-contract.md 备注真机点验）。
#[tokio::test(flavor = "multi_thread")]
async fn payload_shape_sweep() {
    ensure_initialized().await;

    // ---- 59 条：空载荷 → bad_request ----
    let bad_request: &[&str] = &[
        // agent 31
        "start_agent_run", "read_agent_run_checkpoint", "resume_agent_run",
        "finish_agent_run_presentation", "subscribe_agent_run_live_projection",
        "prepare_agent_prompt_assembly", "build_agent_current_model_connection_snapshot",
        "apply_agent_current_model_connection_snapshot", "resolve_agent_system_prompt",
        "load_agent_profile", "diagnose_agent_profile", "save_agent_profile",
        "delete_agent_profile", "repair_agent_profile_file",
        "retarget_agent_profile_preset_refs", "cancel_agent_run",
        "submit_agent_run_guidance", "list_agent_runs", "plan_agent_run_prune",
        "apply_agent_run_prune", "read_agent_run_events", "read_agent_workspace_bytes",
        "read_agent_workspace_file", "read_agent_task_detail", "read_agent_model_turn",
        "read_agent_prompt_assembly_request", "resolve_agent_chat_commit",
        "resolve_agent_prompt_assembly", "resolve_agent_persistent_state_metadata_update",
        "prune_agent_chat_persistent_states", "copy_agent_chat_persistent_states",
        // agent_session 6
        "save_agent_session_profile", "rename_agent_session", "delete_agent_session",
        "read_agent_session", "prepare_agent_session_run", "start_agent_session_run",
        // extension 7
        "install_extension", "update_extension", "delete_extension",
        "get_extension_version", "get_extension_branches", "switch_extension_branch",
        "move_extension",
        // lan_sync 10
        "lan_sync_request_pairing", "lan_sync_connect_address", "lan_sync_set_device_name",
        "lan_sync_pair_device", "lan_sync_confirm_pairing", "lan_sync_remove_device",
        "lan_sync_sync_from_device", "lan_sync_push_to_device", "lan_sync_set_sync_mode",
        "lan_sync_set_overwrite_policy",
        // tt_sync 4
        "tt_sync_pair", "tt_sync_remove_server", "tt_sync_pull", "tt_sync_push",
        // sync_automation 1
        "sync_automation_update_config",
    ];
    assert_eq!(bad_request.len(), 59, "audit: bad_request=59");

    let mut mismatches: Vec<String> = Vec::new();
    for command in bad_request {
        let raw = crate::presentation::dispatch::invoke(command, Some("{}")).await;
        let parsed: Value = serde_json::from_str(&raw).expect("envelope JSON");
        if parsed["ok"].as_bool() != Some(false)
            || parsed["error"]["code"].as_str() != Some("bad_request")
        {
            mismatches.push(format!("{command}: {raw}"));
        }
    }
    assert!(
        mismatches.is_empty(),
        "{} bad_request commands deviated:\n{}",
        mismatches.len(),
        mismatches.join("\n")
    );

    // ---- 15 条：空载荷 → ok（服务可跑的无副作用读/幂等命令）----
    let ok: &[&str] = &[
        // agent 3
        "list_agent_profiles", "list_agent_tools", "list_active_agent_runs",
        // agent_session 3
        "load_agent_session_profile", "create_agent_session", "list_agent_sessions",
        // extension 1
        "get_extensions",
        // lan_sync 4（stop/clear 幂等、list 空读、get_status 空闲态）
        "lan_sync_get_status", "lan_sync_stop_server", "lan_sync_list_devices",
        "lan_sync_clear_sync_mode_override",
        // tt_sync 1
        "tt_sync_list_servers",
        // sync 1
        "sync_get_dataset_catalog",
        // sync_automation 2
        "sync_automation_get_config", "sync_automation_get_status",
    ];
    assert_eq!(ok.len(), 15, "audit: ok=18 实测 15 + 3 结构跳过");

    let mut ok_failures: Vec<String> = Vec::new();
    for command in ok {
        let raw = crate::presentation::dispatch::invoke(command, Some("{}")).await;
        let parsed: Value = serde_json::from_str(&raw).expect("envelope JSON");
        if parsed["ok"].as_bool() != Some(true) {
            ok_failures.push(format!("{command}: {raw}"));
        }
    }
    assert!(
        ok_failures.is_empty(),
        "{} ok commands deviated:\n{}",
        ok_failures.len(),
        ok_failures.join("\n")
    );
}
