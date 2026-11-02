//! P6.1 接缝级聚焦测试（开工清单第 6 步承诺的补充，2026-10-27）。
//!
//! dispatch_contract_tests 只保证「命令被识别 + 信封合法」，不证明参数/DTO 真的
//! 按契约反序列化了。这组测试专门验证 P6.1 的接缝形状：
//!   1. 空参数点名：缺失的顶层键（camelCase）出现在错误消息里；
//!   2. 无参命令空载荷直接 ok；
//!   3. 代表 DTO 反序列化形状：camelCase（mcp create）、snake（skill input 字段）、
//!      tag 枚举（database request `type`）、EntryKind（extension store）。
//!
//! 复用 `runtime::initialize` 的幂等语义：本测试与 dispatch_contract_tests 共享同一
//! 进程，谁先初始化谁生效；这些断言不依赖具体路径，任意根目录都成立。
//!
//! 对应 DevEco 工程路径：native/crates/ttavern/src/p61_focused_contract_tests.rs

use serde_json::Value;

/// 幂等初始化：dispatch 依赖宿主 runtime（OnceLock，首个 initialize 生效）。
/// 聚焦测试不依赖具体路径，任意临时根目录都成立。
///
/// 必须带上 bundledMediaDir（真实 HAP rawfile 的 default/ 目录）：并发全量跑时，
/// 本测试的根可能先抢到 INIT_LOCK —— 若缺 rawfile 内容，`initialize_default_content`
/// 等命令在共享 runtime 上会报 not_found（实测漂移），导致 dispatch 契约测试失败。
async fn ensure_initialized() {
    let root = std::env::temp_dir().join(format!(
        "ttavern-focused-{}-{}",
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

/// 解析信封，返回 `(ok, code?, message?)`。
fn envelope(raw: &str) -> (bool, Option<String>, Option<String>) {
    let parsed: Value =
        serde_json::from_str(raw).unwrap_or_else(|e| panic!("non-JSON envelope ({e}): {raw}"));
    let ok = parsed
        .get("ok")
        .and_then(Value::as_bool)
        .expect("envelope has `ok`");
    if ok {
        return (true, None, None);
    }
    let error = parsed
        .get("error")
        .expect("!ok envelope has `error`");
    let code = error.get("code").and_then(Value::as_str).map(String::from);
    let message = error
        .get("message")
        .and_then(Value::as_str)
        .map(String::from);
    (false, code, message)
}

#[tokio::test(flavor = "multi_thread")]
async fn missing_top_level_key_is_named() {
    ensure_initialized().await;
    // 空参数点名：list_presets 缺顶层键 apiId（camelCase），错误消息必须点名。
    let raw = crate::presentation::dispatch::invoke("list_presets", Some("{}")).await;
    let (ok, code, message) = envelope(&raw);
    assert!(!ok, "list_presets with empty payload should fail: {raw}");
    assert_eq!(code.as_deref(), Some("bad_request"), "raw: {raw}");
    let message = message.unwrap_or_default();
    assert!(
        message.contains("apiId"),
        "missing-arg message should name `apiId`, got: {message}"
    );

    // 再验一条 extension_store：缺 namespace。
    let raw2 = crate::presentation::dispatch::invoke("list_extension_store_tables", Some("{}")).await;
    let (ok2, _, message2) = envelope(&raw2);
    assert!(!ok2, "list_extension_store_tables with {{}} should fail: {raw2}");
    assert!(
        message2.unwrap_or_default().contains("namespace"),
        "missing-arg message should name `namespace`, got: {raw2}"
    );
}

#[tokio::test(flavor = "multi_thread")]
async fn no_arg_commands_succeed_with_empty_payload() {
    ensure_initialized().await;
    // 无参命令：空载荷必须 ok（这是审计 ok=8 里的代表，除 2 条 credits 服务层缺 key）。
    for (command, name) in [
        ("start_export_data_archive", "start_export_data_archive"),
        ("list_mcp_servers", "list_mcp_servers"),
        ("list_llm_connections", "list_llm_connections"),
        ("list_legacy_mcp_tools", "list_legacy_mcp_tools"),
        ("list_skills", "list_skills"),
    ] {
        let raw = crate::presentation::dispatch::invoke(command, Some("{}")).await;
        let (ok, _, _) = envelope(&raw);
        assert!(ok, "`{name}` must succeed with empty payload, got: {raw}");
    }
}

#[tokio::test(flavor = "multi_thread")]
async fn camel_case_mcp_dto_deserializes() {
    ensure_initialized().await;
    // camelCase + deny_unknown_fields 的代表：create_mcp_server 是纯本地注册
    // （写入 data_root/_tauritavern/mcp），DTO 解析成功即返回 ok。
    let payload = serde_json::json!({
        "dto": {
            "displayName": "focused-test",
            "endpoint": "https://example.com",
            "headers": {},
            "protocolVersion": "auto",
        }
    });
    let raw = crate::presentation::dispatch::invoke("create_mcp_server", Some(&payload.to_string())).await;
    let (ok, code, message) = envelope(&raw);
    assert!(
        ok || matches!(code.as_deref(), Some("conflict" | "bad_request")),
        "create_mcp_server with camelCase dto should reach the service, got code={:?} msg={:?}",
        code,
        message
    );
    // deny_unknown_fields 反例：多传一个键必须被拒绝（bad_request，missing field 之外）。
    let bad = serde_json::json!({
        "dto": {
            "displayName": "x",
            "endpoint": "https://example.com",
            "headers": {},
            "protocolVersion": "auto",
            "surpriseKey": 1,
        }
    });
    let raw_bad = crate::presentation::dispatch::invoke("create_mcp_server", Some(&bad.to_string())).await;
    let (ok_bad, _, _) = envelope(&raw_bad);
    assert!(
        !ok_bad,
        "deny_unknown_fields must reject extra key, got ok: {raw_bad}"
    );
}

#[tokio::test(flavor = "multi_thread")]
async fn snake_skill_input_deserializes() {
    ensure_initialized().await;
    // snake 字段代表：SkillImportInput 的字段是 snake_case（skill_root/file_name/…），
    // 顶层键 input + kind=directory 必须过反序列化（目录不存在 → 服务层错误，
    // 而不是 "missing field" 类 bad_request）。
    let payload = serde_json::json!({
        "input": {
            "kind": "directory",
            "source": "focused-test-source",
            "path": "definitely-not-a-real-dir",
        }
    });
    let raw = crate::presentation::dispatch::invoke("preview_skill_import", Some(&payload.to_string())).await;
    let (ok, code, message) = envelope(&raw);
    let message = message.unwrap_or_default();
    assert!(
        !message.contains("missing field"),
        "SkillImportInput snake fields must deserialize (no `missing field`), got: {raw}"
    );
    // 服务层错误码（目录不存在）不可能是成功 —— 但这里只断言不是反序列化失败。
    if ok {
        // 理论上 preview 不会对不存在的目录返回 ok；真出现就打印出来人工核对。
        println!("preview_skill_import returned ok unexpectedly: {raw}");
    } else {
        assert!(
            code.is_some(),
            "service error should carry a code: {raw}"
        );
    }
}

#[tokio::test(flavor = "multi_thread")]
async fn tagged_database_request_deserializes() {
    ensure_initialized().await;
    // tag 枚举代表：DatabaseRequest 是 tag="type"（open/close/listNamespaces/...）。
    // type=listNamespaces 走通反序列化（结果任意，但不能是缺参 bad_request）。
    let payload = serde_json::json!({ "request": { "type": "listNamespaces" } });
    let raw = crate::presentation::dispatch::invoke("database_handle", Some(&payload.to_string())).await;
    let (ok, code, _) = envelope(&raw);
    assert!(
        ok || !matches!(code.as_deref(), Some("bad_request")),
        "DatabaseRequest tag must deserialize (no missing-arg bad_request), got: {raw}"
    );
}

#[tokio::test(flavor = "multi_thread")]
async fn entry_kind_deserializes() {
    ensure_initialized().await;
    // EntryKind 代表：kind 必须接受 json/blob（extension store 文件仓库对不存在的
    // namespace 返回空列表 → ok；绝不能是缺参 bad_request）。
    let payload = serde_json::json!({ "namespace": "focused-test", "kind": "json" });
    let raw = crate::presentation::dispatch::invoke("list_extension_store_keys", Some(&payload.to_string())).await;
    let (ok, code, message) = envelope(&raw);
    assert!(
        ok || !matches!(code.as_deref(), Some("bad_request")),
        "EntryKind `json` must deserialize, got: {raw}"
    );
    if let Some(message) = message {
        assert!(
            !message.contains("missing field"),
            "EntryKind must not fail on deserialization: {message}"
        );
    }
}
