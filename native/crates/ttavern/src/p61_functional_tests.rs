//! P6.1 功能往返测试（真机验收清单的宿主预演，2026-10-27）。
//!
//! 聚焦测试只证明「命令被识别 + DTO 能反序列化」；这组测试用**真实载荷**走通各域的
//! 完整往返，提前暴露服务层问题（仓库读写、后台任务、跨命令状态）：
//!   - preset：save → list → get → exists → delete；
//!   - mcp：create → list → set state → update → remove（本地注册，不联网）；
//!   - skill：install（inline files）→ list → list files → read → export → delete；
//!   - data archive：start export → 轮询 status → save export（claim+finish）；
//!   - extension store：list tables / list keys / delete table（写入通道未移植，只验读侧）；
//!   - llm_connection：list（空）；database：listNamespaces。
//!
//! 与其它契约测试共享同一进程内的 runtime（幂等 initialize）；操作共享根目录上的
//! 独立命名空间（func-*），互不干扰。
//!
//! 对应 DevEco 工程路径：native/crates/ttavern/src/p61_functional_tests.rs

use serde_json::Value;

/// 幂等初始化（与 p61_focused_contract_tests 同款；必须带 bundledMediaDir，
/// 否则并发下共享 runtime 缺默认内容，`initialize_default_content` 等命令报 not_found）。
async fn ensure_initialized() {
    let root = std::env::temp_dir().join(format!(
        "ttavern-functional-{}-{}",
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

/// 调用命令并返回信封的 `data`（失败时 panic 并打印 raw）。
async fn call_ok(command: &str, payload: &serde_json::Value) -> Value {
    let raw = crate::presentation::dispatch::invoke(command, Some(&payload.to_string())).await;
    let parsed: Value = serde_json::from_str(&raw).unwrap_or_else(|e| panic!("{command}: non-JSON ({e}): {raw}"));
    assert!(
        parsed["ok"].as_bool() == Some(true),
        "`{command}` should return ok: {raw}"
    );
    parsed["data"].clone()
}

/// 调用命令，返回信封原始串（供「预期失败」的断言）。
async fn call_raw(command: &str, payload: &serde_json::Value) -> String {
    crate::presentation::dispatch::invoke(command, Some(&payload.to_string())).await
}

#[tokio::test(flavor = "multi_thread")]
async fn preset_round_trip() {
    ensure_initialized().await;
    let name = "func-preset";
    let api_id = "openai";
    let preset = serde_json::json!({ "temperature": 0.7, "max_tokens": 256, "top_p": 0.95 });

    let data = call_ok("save_preset", &serde_json::json!({ "dto": { "name": name, "apiId": api_id, "preset": preset } })).await;
    assert_eq!(data["name"].as_str(), Some(name), "save_preset response: {data}");

    let list = call_ok("list_presets", &serde_json::json!({ "apiId": api_id })).await;
    let names: Vec<&str> = list.as_array().unwrap().iter().filter_map(|v| v.as_str()).collect();
    assert!(names.contains(&name), "list_presets should contain {name}: {list}");

    let exists = call_ok("preset_exists", &serde_json::json!({ "name": name, "apiId": api_id })).await;
    assert_eq!(exists.as_bool(), Some(true), "preset_exists: {exists}");

    let got = call_ok("get_preset", &serde_json::json!({ "name": name, "apiId": api_id })).await;
    assert!(
        got["temperature"].as_f64() == Some(0.7),
        "get_preset should return the saved JSON: {got}"
    );

    call_ok("delete_preset", &serde_json::json!({ "dto": { "name": name, "apiId": api_id } })).await;
    let exists_after = call_ok("preset_exists", &serde_json::json!({ "name": name, "apiId": api_id })).await;
    assert_eq!(exists_after.as_bool(), Some(false), "preset_exists after delete: {exists_after}");
}

#[tokio::test(flavor = "multi_thread")]
async fn mcp_round_trip() {
    ensure_initialized().await;
    let display = "func-mcp";
    let endpoint = "https://example.com";

    let created = call_ok("create_mcp_server", &serde_json::json!({
        "dto": { "displayName": display, "endpoint": endpoint, "headers": {}, "protocolVersion": "auto" }
    })).await;
    let registration_id = created["id"].as_str().expect("create returns id").to_string();

    let list = call_ok("list_mcp_servers", &serde_json::json!({})).await;
    let ids: Vec<&str> = list["servers"].as_array().unwrap().iter().filter_map(|s| s["id"].as_str()).collect();
    assert!(ids.iter().any(|id| *id == registration_id), "list_mcp_servers should contain new id: {list}");

    call_ok("set_mcp_server_state", &serde_json::json!({
        "dto": { "registrationId": registration_id, "state": "paused" }
    })).await;
    let updated = call_ok("update_mcp_server", &serde_json::json!({
        "dto": { "registrationId": registration_id, "displayName": "func-mcp-renamed", "endpoint": endpoint, "headers": {}, "protocolVersion": "auto" }
    })).await;
    assert_eq!(updated["displayName"].as_str(), Some("func-mcp-renamed"), "update: {updated}");

    call_ok("remove_mcp_server", &serde_json::json!({ "dto": { "registrationId": registration_id } })).await;
    let list_after = call_ok("list_mcp_servers", &serde_json::json!({})).await;
    let ids_after: Vec<&str> = list_after["servers"].as_array().unwrap().iter().filter_map(|s| s["id"].as_str()).collect();
    assert!(!ids_after.iter().any(|id| *id == registration_id), "remove should drop id: {list_after}");
}

#[tokio::test(flavor = "multi_thread")]
async fn skill_round_trip() {
    ensure_initialized().await;
    let file_path = "skills-test.md";
    let content = "# functional test skill\nHello from the host round-trip.";
    // SKILL.md 必须有 YAML frontmatter（name + description 非空），安装名取自 frontmatter。
    let skill_md = "---\nname: func-skill\ndescription: functional test skill\n---\n";

    let installed = call_ok("install_skill_import", &serde_json::json!({
        "request": {
            "input": { "kind": "inlineFiles", "files": [
                { "path": "SKILL.md", "content": skill_md },
                { "path": file_path, "content": content }
            ] },
            "targetScope": { "kind": "global" }
        }
    })).await;
    let name = installed["name"].as_str().expect("install returns name").to_string();
    assert_eq!(name, "func-skill", "install name comes from SKILL.md frontmatter: {installed}");

    let list = call_ok("list_skills", &serde_json::json!({})).await;
    let names: Vec<&str> = list.as_array().unwrap().iter().filter_map(|s| s["name"].as_str()).collect();
    assert!(names.iter().any(|n| *n == name), "list_skills should contain {name}: {list}");

    let files = call_ok("list_skill_files", &serde_json::json!({ "name": name, "scope": { "kind": "global" } })).await;
    let paths: Vec<&str> = files.as_array().unwrap().iter().filter_map(|f| f["path"].as_str()).collect();
    assert!(paths.iter().any(|p| *p == file_path), "list_skill_files should contain {file_path}: {files}");

    let read = call_ok("read_skill_file", &serde_json::json!({ "name": name, "path": file_path, "scope": { "kind": "global" } })).await;
    assert!(
        read["content"].as_str().unwrap_or("").contains("functional test skill"),
        "read_skill_file should return content: {read}"
    );

    let exported = call_ok("export_skill", &serde_json::json!({ "name": name, "scope": { "kind": "global" } })).await;
    assert!(
        exported["fileName"].as_str().is_some()
            && exported["contentBase64"].as_str().map(|s| !s.is_empty()).unwrap_or(false),
        "export_skill should return fileName + non-empty contentBase64: {exported}"
    );

    call_ok("delete_skill", &serde_json::json!({ "name": name, "scope": { "kind": "global" } })).await;
    let list_after = call_ok("list_skills", &serde_json::json!({})).await;
    let names_after: Vec<&str> = list_after.as_array().unwrap().iter().filter_map(|s| s["name"].as_str()).collect();
    assert!(!names_after.iter().any(|n| *n == name), "delete_skill should drop {name}: {list_after}");
}

#[tokio::test(flavor = "multi_thread")]
async fn data_archive_export_round_trip() {
    ensure_initialized().await;
    let job_id = call_ok("start_export_data_archive", &serde_json::json!({})).await;
    let job_id = job_id.as_str().expect("export returns job id").to_string();

    // 轮询直到导出产物可领取（claim + finish 成功 = 交付完成）。
    // 上限 60s：2026-10-28 观察到 30s 窗口在 `cargo test --workspace` 满负载并行下
    // 偶发超时（导出 job 与其余 ~40 条测试 + 19 个套件争 CPU，1 次/8 轮复现，套件 33.32s）。
    // 100ms 轮询在快速交付时立即退出，慢交付才吃预算；>60s 仍失败 = 导出链路真坏。
    let mut delivered = false;
    for _ in 0..600 {
        let raw = call_raw("save_export_data_archive", &serde_json::json!({ "jobId": job_id })).await;
        let parsed: Value = serde_json::from_str(&raw).expect("envelope");
        if parsed["ok"].as_bool() == Some(true) {
            let data = &parsed["data"];
            assert_eq!(data["delivered"].as_bool(), Some(true), "delivered flag: {data}");
            let path = data["path"].as_str().expect("delivery carries path");
            assert!(
                std::path::Path::new(path).is_file(),
                "delivered artifact must exist on disk: {path}"
            );
            assert!(data["fileName"].as_str().is_some(), "delivery carries fileName: {data}");
            delivered = true;
            break;
        }
        tokio::time::sleep(std::time::Duration::from_millis(100)).await;
    }
    assert!(
        delivered,
        "data archive export never reached delivery (job {job_id}); final status: {}",
        call_raw("get_data_archive_job_status", &serde_json::json!({ "jobId": job_id })).await
    );

    // 状态查询与取消是同步命令，顺带验一下（已完成的 job 取消返回 ok）。
    call_ok("get_data_archive_job_status", &serde_json::json!({ "jobId": job_id })).await;
    call_ok("cancel_data_archive_job", &serde_json::json!({ "jobId": job_id })).await;
}

#[tokio::test(flavor = "multi_thread")]
async fn extension_store_read_side() {
    ensure_initialized().await;
    let ns = "func-ext";
    call_ok("list_extension_store_tables", &serde_json::json!({ "namespace": ns })).await;
    call_ok("list_extension_store_keys", &serde_json::json!({ "namespace": ns, "kind": "json" })).await;
    // 删除不存在的表必须返回 not_found（真实行为钉住：文件仓库按表存在性校验）。
    let raw = call_raw("delete_extension_store_table", &serde_json::json!({ "namespace": ns, "table": "main" })).await;
    let parsed: Value = serde_json::from_str(&raw).expect("envelope");
    assert_eq!(
        parsed["error"]["code"].as_str(),
        Some("not_found"),
        "delete_extension_store_table on missing table should be not_found: {raw}"
    );
}

#[tokio::test(flavor = "multi_thread")]
async fn llm_connection_and_database_read_side() {
    ensure_initialized().await;
    let llm = call_ok("list_llm_connections", &serde_json::json!({})).await;
    assert!(
        llm["connections"].as_array().is_some(),
        "list_llm_connections should return a connections array: {llm}"
    );

    let db = call_ok("database_handle", &serde_json::json!({ "request": { "type": "listNamespaces" } })).await;
    assert!(db.is_array() || db.is_object(), "database listNamespaces: {db}");
}
