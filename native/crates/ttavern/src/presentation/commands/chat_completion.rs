//! Chat completion（LLM 生成）命令（上游 `chat_completion_commands.rs`，6 条）。
//!
//! 与上游的两点差异，都是被平台逼出来的，不是取舍：
//!
//! 1. **流式用游标轮询，不是事件推送**。上游就是 `start_stream` + `read_stream(after_seq)`
//!    的游标契约（§11.3-B），ArkTS 定时轮询即可，因此 P5 不需要 `ThreadsafeFunction`。
//! 2. **自定义端点授权改成三步握手**。上游在命令内部弹 Tauri 原生对话框并阻塞等待
//!    （`user_endpoint_access.rs` 的 `show_authorization_dialog`）。NAPI 调用期间无法
//!    在 Rust 侧弹 ArkUI 对话框，所以拆成：
//!      ① 命令返回 `unauthorized` + `endpoint_authorization_required|<endpoint>`；
//!      ② ArkTS 自己弹 `AlertDialog`（文案照搬上游，中/繁/英三套）；
//!      ③ 用户同意后调 `grant_user_endpoint_access`，再重试原命令。
//!    语义与上游一致：未授权时**拒绝执行**（不是静默放行），且 HTTP 明文端点有额外警告。
//!
//! 对应 DevEco 工程路径：native/crates/ttavern/src/presentation/commands/chat_completion.rs

use std::sync::OnceLock;

use serde::Serialize;
use serde_json::Value;

use tt_application::dto::chat_completion_dto::{
    ChatCompletionGenerateRequestDto, ChatCompletionStatusRequestDto,
    ChatCompletionStreamEventDto, ChatCompletionStreamReadResultDto,
    ChatCompletionStreamStatusDto,
};

use crate::host::Ctx;
use crate::presentation::chat_stream_decoder::{
    DecodedPart, StreamDecoderRegistry, StreamFormat,
};
use crate::presentation::dispatch::Args;
use crate::presentation::errors::CommandError;
use crate::presentation::helpers::{log_command, map_command_error};

/// 解码器状态表：跨读取轮次保留 Gemini Interactions 步类型和各协议的用量快照。
/// 状态按 stream_id 隔离；进程级单例即可，因为状态表本身是纯 Rust 结构。
static STREAM_DECODER_REGISTRY: OnceLock<StreamDecoderRegistry> = OnceLock::new();

fn decoder_registry() -> &'static StreamDecoderRegistry {
    STREAM_DECODER_REGISTRY.get_or_init(StreamDecoderRegistry::new)
}

/// 解码后的流事件：`Chunk` 的 `data` 已被解成 `parts`（文本/推理/工具），
/// `Done` / `Error` 原样保留，`status` 与 `ChatCompletionStreamReadResultDto` 相同。
#[derive(Debug, Clone, Serialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum DecodedStreamEventDto {
    Chunk {
        seq: u64,
        parts: Vec<DecodedPart>,
    },
    Done {
        seq: u64,
    },
    Error {
        seq: u64,
        message: String,
    },
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ChatCompletionStreamReadResultDecodedDto {
    pub events: Vec<DecodedStreamEventDto>,
    pub status: ChatCompletionStreamStatusDto,
}

/// ArkTS 侧的约定前缀：`error.message` 以它开头时，剩下的部分就是待授权的端点。
/// 用 `|` 而不是 `:` 分隔，因为端点自身含 `:`（`https://…`）。
pub const ENDPOINT_AUTH_REQUIRED_PREFIX: &str = "endpoint_authorization_required|";

/// 自定义端点授权闸门。返回 `Ok` 表示可以继续；返回 `Err(Unauthorized)` 表示
/// ArkTS 需要先弹窗征得用户同意。P6.1 的 `search_searxng` 也走这条（上游同样
/// 复用 `ensure_user_endpoint_access`）。
pub async fn ensure_user_endpoint_access(
    ctx: &Ctx<'_>,
    endpoint: Option<String>,
) -> Result<(), CommandError> {
    let Some(endpoint) = endpoint else {
        return Ok(());
    };

    if ctx
        .services
        .user_endpoint_access_service
        .is_granted(&endpoint)
        .await
    {
        return Ok(());
    }

    Err(CommandError::Unauthorized(format!(
        "{ENDPOINT_AUTH_REQUIRED_PREFIX}{endpoint}"
    )))
}

/// 第 ③ 步：用户在 ArkUI 对话框里点了「信任并连接」。
pub async fn grant_user_endpoint_access(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let endpoint: String = args.require("endpoint")?;
    let endpoint = endpoint.trim().to_string();
    if endpoint.is_empty() {
        return Err(CommandError::BadRequest(
            "Endpoint must not be empty".to_string(),
        ));
    }
    log_command(format!("grant_user_endpoint_access {}", endpoint));

    ctx.services
        .user_endpoint_access_service
        .grant(endpoint)
        .await;
    Ok(())
}

pub async fn get_chat_completions_status(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<Value, CommandError> {
    let dto: ChatCompletionStatusRequestDto = args.typed("dto")?;
    log_command("get_chat_completions_status");

    let endpoint = ctx
        .services
        .chat_completion_service
        .resolve_status_user_endpoint(&dto)?;
    ensure_user_endpoint_access(ctx, endpoint).await?;

    ctx.services
        .chat_completion_service
        .get_status(dto)
        .await
        .map_err(map_command_error("Failed to get chat completions status"))
}

pub async fn generate_chat_completion(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<Value, CommandError> {
    let request_id: String = args.require("requestId")?;
    let request_id = request_id.trim().to_string();
    validate_stream_id(&request_id)?;
    let mut dto: ChatCompletionGenerateRequestDto = args.typed("dto")?;
    tag_usage(&mut dto, &request_id, "background");
    log_command(format!("generate_chat_completion {}", request_id));

    let endpoint = ctx
        .services
        .chat_completion_service
        .resolve_generate_user_endpoint(&dto)?;
    ensure_user_endpoint_access(ctx, endpoint).await?;

    ctx.services
        .chat_completion_service
        .generate_request(&request_id, dto)
        .await
        .map_err(map_command_error("Failed to generate chat completion"))
}

pub async fn start_chat_completion_stream(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<(), CommandError> {
    let stream_id: String = args.require("streamId")?;
    let stream_id = stream_id.trim().to_string();
    validate_stream_id(&stream_id)?;
    let mut dto: ChatCompletionGenerateRequestDto = args.typed("dto")?;
    tag_usage(&mut dto, &stream_id, "chat");
    log_command(format!("start_chat_completion_stream {}", stream_id));

    let endpoint = ctx
        .services
        .chat_completion_service
        .resolve_generate_user_endpoint(&dto)?;
    ensure_user_endpoint_access(ctx, endpoint).await?;

    ctx.services
        .chat_completion_service
        .start_stream(stream_id, dto)
        .await
        .map_err(map_command_error("Failed to start chat completion stream"))
}

pub async fn read_chat_completion_stream(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<ChatCompletionStreamReadResultDto, CommandError> {
    let stream_id: String = args.require("streamId")?;
    let after_seq: u64 = args.require_u64("afterSeq")?;
    let stream_id = stream_id.trim().to_string();
    validate_stream_id(&stream_id)?;

    ctx.services
        .chat_completion_service
        .read_stream(&stream_id, after_seq)
        .await
        .map_err(map_command_error("Failed to read chat completion stream"))
}

/// 解码版读取：把 provider 原生 JSON 的 `Chunk.data` 解成文本/推理/工具三通道。
///
/// `format` 缺省 `openai_compatible`（DeepSeek/Kimi/GLM 等国产 provider 全走这条，
/// 与上游 `from_payload` 的兜底一致）。Claude/Gemini 系由 ArkTS 按所选来源显式传入；
/// 格式清单见 `chat_stream_decoder.rs` 的模块注释。
pub async fn read_chat_completion_stream_decoded(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<ChatCompletionStreamReadResultDecodedDto, CommandError> {
    let stream_id: String = args.require("streamId")?;
    let after_seq: u64 = args.require_u64("afterSeq")?;
    let format: Option<String> = args.optional("format")?;
    let stream_id = stream_id.trim().to_string();
    validate_stream_id(&stream_id)?;
    let format = StreamFormat::parse(format.as_deref())
        .map_err(CommandError::BadRequest)?;

    let read = ctx
        .services
        .chat_completion_service
        .read_stream(&stream_id, after_seq)
        .await
        .map_err(map_command_error("Failed to read chat completion stream"))?;

    let events = read
        .events
        .into_iter()
        .map(|event| match event {
            ChatCompletionStreamEventDto::Chunk { seq, data } => {
                let parts = decoder_registry().decode(&stream_id, format, &data);
                DecodedStreamEventDto::Chunk { seq, parts }
            }
            ChatCompletionStreamEventDto::Done { seq } => DecodedStreamEventDto::Done { seq },
            ChatCompletionStreamEventDto::Error { seq, message, .. } => {
                DecodedStreamEventDto::Error { seq, message }
            }
        })
        .collect();

    if read.status != ChatCompletionStreamStatusDto::Running {
        decoder_registry().remove(&stream_id);
    }

    Ok(ChatCompletionStreamReadResultDecodedDto {
        events,
        status: read.status,
    })
}

pub async fn close_chat_completion_stream(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<(), CommandError> {
    let stream_id: String = args.require("streamId")?;
    let stream_id = stream_id.trim().to_string();
    validate_stream_id(&stream_id)?;
    log_command(format!("close_chat_completion_stream {}", stream_id));

    ctx.services
        .chat_completion_service
        .close_stream(&stream_id)
        .await;
    Ok(())
}

pub async fn cancel_chat_completion_generation(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<(), CommandError> {
    let request_id: String = args.require("requestId")?;
    validate_stream_id(&request_id)?;
    log_command(format!("cancel_chat_completion_generation {}", request_id));

    ctx.services
        .chat_completion_service
        .cancel_generation(&request_id)
        .await;
    Ok(())
}

/// 上游同名校验：长度 ≤128 且只允许 `[A-Za-z0-9_-]`。
/// 这些 id 会直接成为流表/取消表的键，放开字符集会带来键注入与日志注入面。
fn validate_stream_id(stream_id: &str) -> Result<(), CommandError> {
    let stream_id = stream_id.trim();
    if stream_id.is_empty() || stream_id.len() > 128 {
        return Err(CommandError::BadRequest(
            "Invalid stream id length".to_string(),
        ));
    }

    if !stream_id
        .chars()
        .all(|ch| ch.is_ascii_alphanumeric() || ch == '-' || ch == '_')
    {
        return Err(CommandError::BadRequest(
            "Invalid stream id characters".to_string(),
        ));
    }

    Ok(())
}

fn tag_usage(dto: &mut ChatCompletionGenerateRequestDto, id: &str, fallback: &str) {
    let kind = if id.starts_with("compact_") { "compaction" } else if id.starts_with("world_ui_") { "world" }
        else if id.starts_with("group_") { "group" } else { fallback };
    dto.payload.insert("_harmony_usage_request".into(), Value::String(id.to_string()));
    dto.payload.entry("_harmony_usage_kind").or_insert_with(|| Value::String(kind.into()));
}
