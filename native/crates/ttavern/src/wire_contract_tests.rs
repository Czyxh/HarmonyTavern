//! P5 线格式契约回归测试（缺陷驱动，2026-10-26）。
//!
//! 背景：tt-application 的 DTO **没有** `#[serde(rename_all = "camelCase")]`，
//! 线上 JSON 是 snake_case。ArkTS 侧一度误按 camelCase 建模（Types.ets /
//! Backend.ets 包装），真机上所有字段取到 undefined、add_message 反序列化失败
//! （「api key 不行」同一轮暴露的整类问题，§11.3-N 更正 3/4）。
//!
//! 这两个测试把「线上必须是 snake_case」钉死：camelCase 变体必须反序列化失败，
//! 防止未来 ArkTS 侧（或任何命令层）再退回去。它们不重复领域层测试 —— 领域层
//! 测行为，这里测**命令边界的线格式**。
//!
//! P6.2 补充（agent 域）：agent DTO（tt-application/src/dto/agent_dto.rs，74 类型）
//! **全部** `#[serde(rename_all = "camelCase")]` —— 与 P5 chat 域相反。ArkTS 侧
//! Types.ets 按 camelCase 建模（profileId/runId 等），故反向钉死：agent 请求 DTO
//! 线上必须 camelCase，snake 变体必须反序列化失败，防止 agent DTO 被改回 snake
//! 静默打断 ArkTS 侧模型。
//!
//! 对应 DevEco 工程路径：native/crates/ttavern/src/wire_contract_tests.rs

use serde_json::json;

use tt_application::dto::chat_dto::{AddMessageDto, ChatDto};

#[test]
fn add_message_dto_is_flat_snake_case() {
    // 序列化形状：平铺、snake_case。
    let dto = AddMessageDto {
        character_name: "A".to_string(),
        file_name: "B.json".to_string(),
        is_user: true,
        content: "hi".to_string(),
        extra: None,
    };
    let value = serde_json::to_value(&dto).unwrap();
    assert_eq!(
        value,
        json!({
            "character_name": "A",
            "file_name": "B.json",
            "is_user": true,
            "content": "hi",
            "extra": null,
        })
    );

    // 曾经的错误形态：camelCase + 嵌套 message —— 必须失败（缺必需字段）。
    assert!(
        serde_json::from_str::<AddMessageDto>(
            r#"{"characterName":"A","fileName":"B.json","message":{"name":"A","isUser":true,"mes":"hi"}}"#
        )
        .is_err(),
        "camelCase 嵌套形态必须反序列化失败"
    );

    // 正确的缺省形态：extra 可省略（Option）。
    let minimal = serde_json::from_str::<AddMessageDto>(
        r#"{"character_name":"A","file_name":"B.json","is_user":true,"content":"hi"}"#,
    )
    .unwrap();
    assert_eq!(minimal.character_name, "A");
    assert!(minimal.extra.is_none());
}

#[test]
fn chat_dto_wire_keys_are_snake_case() {
    // snake_case 形态必须成功，字段值正确。
    let chat = serde_json::from_str::<ChatDto>(
        r#"{
            "character_name": "A",
            "user_name": "u",
            "file_name": "B.json",
            "create_date": "t",
            "chat_metadata": {},
            "messages": [],
            "message_count": 0,
            "chat_id": 1
        }"#,
    )
    .unwrap();
    assert_eq!(chat.character_name, "A");
    assert_eq!(chat.user_name, "u");
    assert_eq!(chat.file_name, "B.json");
    assert_eq!(chat.message_count, 0);
    assert_eq!(chat.chat_id, 1);
    assert!(chat.messages.is_empty());

    // camelCase 形态缺所有必需键 —— 必须失败。
    assert!(
        serde_json::from_str::<ChatDto>(
            r#"{"characterName":"A","userName":"u","fileName":"B.json","createDate":"t","chatMetadata":{},"messages":[],"messageCount":0,"chatId":1}"#
        )
        .is_err(),
        "camelCase 形态必须反序列化失败"
    );
}

/// P6.2 agent 域请求 DTO：线上必须 camelCase（与 ArkTS Types.ets 的
/// profileId/runId 一致）；snake 变体必须反序列化失败（与 P5 chat 域反向钉死，
/// 防止 agent DTO 被改回 snake 静默打断 ArkTS 侧模型）。
#[test]
fn agent_request_dtos_are_camel_case() {
    use tt_application::dto::agent_dto::{
        AgentProfileIdDto, AgentSubscribeRunLiveProjectionDto,
    };

    // AgentProfileIdDto（load/diagnose/delete/repair profile 共用）：
    // camelCase 形态必须成功，snake 形态必须失败（缺必需键）。
    let profile: AgentProfileIdDto =
        serde_json::from_str(r#"{"profileId":"p1"}"#).expect("camelCase 形态必须成功");
    assert_eq!(profile.profile_id, "p1");
    assert!(
        serde_json::from_str::<AgentProfileIdDto>(r#"{"profile_id":"p1"}"#).is_err(),
        "agent DTO snake_case 形态必须反序列化失败"
    );

    // AgentSubscribeRunLiveProjectionDto（订阅快照+增量事件，ArkTS 发 runId）。
    let sub: AgentSubscribeRunLiveProjectionDto =
        serde_json::from_str(r#"{"runId":"r1"}"#).expect("camelCase 形态必须成功");
    assert_eq!(sub.run_id, "r1");
    assert!(
        serde_json::from_str::<AgentSubscribeRunLiveProjectionDto>(r#"{"run_id":"r1"}"#).is_err(),
        "agent DTO snake_case 形态必须反序列化失败"
    );
}

/// 端点授权错误的消息格式（缺陷驱动，2026-10-27 14:55）。
///
/// 背景：errors.rs 用 `#[error("Unauthorized: {0}")]`，信封 message 是
/// `"Unauthorized: endpoint_authorization_required|<端点>"`。ArkTS 一度用
/// `startsWith("endpoint_authorization_required|")` 判断握手信号 —— 前缀前还有
/// "Unauthorized: "，永远不匹配，三步握手从未触发（真机红字
/// `Unauthorized: endpoint_authorization_required|…` 就是现场）。修复改为 indexOf。
/// 本测试钉死这个格式，防止未来有人改动 Display 前缀/内容导致握手再次失效。
#[test]
fn endpoint_auth_error_message_contains_handshake_prefix() {
    use crate::presentation::commands::chat_completion::ENDPOINT_AUTH_REQUIRED_PREFIX;
    use crate::presentation::errors::CommandError;

    let endpoint = "https://api.example.com/v1";
    let error = CommandError::Unauthorized(format!("{ENDPOINT_AUTH_REQUIRED_PREFIX}{endpoint}"));

    // code 必须是 ArkTS 分支用的 "unauthorized"。
    assert_eq!(error.code(), "unauthorized");
    // message（Display）必须以 "Unauthorized: " 开头（errors.rs 的 #[error(...)] 前缀），
    // 且必须包含握手前缀 —— ArkTS 用 indexOf(prefix) 定位。
    let message = error.to_string();
    assert!(message.starts_with("Unauthorized: "), "got: {message}");
    assert!(
        message.contains(ENDPOINT_AUTH_REQUIRED_PREFIX),
        "message must contain the handshake prefix, got: {message}"
    );
    assert!(
        message.contains(endpoint),
        "message must carry the endpoint, got: {message}"
    );
}
