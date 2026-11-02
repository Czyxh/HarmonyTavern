//! Provider chunk 解码：把 `Chunk.data`（provider 原生 JSON 字符串）解成文本/推理/工具调用。
//!
//! 为什么必须做：`ChatCompletionStreamEventDto::Chunk.data` 不是纯文本，而是 provider 原样返回的
//! JSON（`sender.send(payload.to_string())`，见 `chat_completion_service`）。上游是**前端**在解它
//! （`src/scripts/sse-stream.js`、`src/scripts/tauritavern/claude-native-stream.js`）。这一层 ArkTS
//! 要重写，如果照搬就得让 ArkTS 懂 5 种 provider 格式；放在 Rust 里，ArkTS 只认三种输出（文本/
//! 推理/工具），换 provider 不动 UI。
//!
//! 格式清单来自 `tt-application/src/services/chat_completion_service/exchange.rs` 的
//! `ChatCompletionProviderFormat`（该枚举是 `pub(crate)`，宿主拿不到，所以这里按同样的 5 个
//! 变体重新声明，并由 ArkTS 显式传格式化串）：
//!
//! ```text
//! openai_compatible    DeepSeek / Kimi(Moonshot) / GLM(Zai) / SiliconFlow / Groq / Xai /
//!                      OpenRouter / NanoGpt / Chutes / MiniMax / Pollinations / 绝大多数自定义
//! openai_responses     OpenAI 自家新协议（gpt-6 起）与兼容实现
//! claude_messages      Anthropic，以及 AwsBedrock / VertexAi 上的 Claude
//! gemini               Makersuite / VertexAi 的 Gemini
//! gemini_interactions  Gemini Interactions API（`event_type` 事件流）
//! ```
//!
//! **未知形状一律降级成 `Raw`，绝不丢弃**。上游前端遇到不认识的块会报错中断；这里选择把原文交给
//! UI，宁可显示一段 JSON 也不要让用户看到一个空回复且没有线索。
//!
//! 对应 DevEco 工程路径：native/crates/ttavern/src/presentation/chat_stream_decoder.rs

use std::collections::HashMap;

use serde::Serialize;
use serde_json::Value;
use super::token_usage::TokenUsage;

/// ArkTS 传入的格式化串。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum StreamFormat {
    OpenAiCompatible,
    OpenAiResponses,
    ClaudeMessages,
    Gemini,
    GeminiInteractions,
}

impl StreamFormat {
    /// 缺省为 `openai_compatible`：绝大多数国产 provider（DeepSeek/Kimi/GLM 等）都走这条，
    /// 与上游 `from_payload` 的 `_ => Self::OpenAiCompatible` 兜底一致。
    pub fn parse(raw: Option<&str>) -> Result<Self, String> {
        match raw.map(str::trim) {
            None | Some("") | Some("openai_compatible") => Ok(Self::OpenAiCompatible),
            Some("openai_responses") => Ok(Self::OpenAiResponses),
            Some("claude_messages") => Ok(Self::ClaudeMessages),
            Some("gemini") => Ok(Self::Gemini),
            Some("gemini_interactions") => Ok(Self::GeminiInteractions),
            Some(other) => Err(format!(
                "Unknown stream format `{other}` (expected one of: openai_compatible, \
                 openai_responses, claude_messages, gemini, gemini_interactions)"
            )),
        }
    }
}

/// 一个 chunk 解出来的片段。分通道是必要的：「推理内容」不能混进正文，
/// 否则上游的 thinking 折叠、以及「正文里不该出现思维链」的规则都会被破坏。
#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum DecodedPart {
    Text {
        text: String,
    },
    Reasoning {
        text: String,
    },
    ToolCall {
        index: usize,
        name: String,
        arguments_fragment: String,
    },
    Stop {
        reason: String,
    },
    Usage {
        usage: TokenUsage,
    },
    /// 认不出的形状：原文照给，便于排查而不是静默吞掉。
    Raw {
        data: String,
    },
}

/// 解码跨批次需要的极少量状态。
///
/// Gemini Interactions 的 `step.delta` 需要此前声明的 step 类型；
/// 各类协议的用量计数还可能分多批到达，需要按流保留累计快照。
#[derive(Debug, Default)]
pub struct DecoderState {
    /// steps 与 delta 通常同一个 chunk 到达（`step.start` 紧跟 `step.delta`），
    /// 但仍可能被 SSE 边界切开，所以按 index 记住 step 类型。
    step_types: HashMap<u64, String>,
    usage: TokenUsage,
}

impl DecoderState {
    /// 契约/功能测试在非流式路径构造状态；流式命令用 `Default`。
    #[cfg(test)]
    pub fn new() -> Self {
        Self::default()
    }
}

pub fn decode(format: StreamFormat, data: &str, state: &mut DecoderState) -> Vec<DecodedPart> {
    // 服务层已经把 `[DONE]` 哨兵过滤成 Done 事件，这里再挡一层：有的 provider 会把
    // 文本里的 `[DONE]` 原样送出，若在这里当哨兵处理会吃掉真实内容。
    let Ok(value) = serde_json::from_str::<Value>(data) else {
        return vec![DecodedPart::Raw {
            data: data.to_string(),
        }];
    };

    let mut parts = match format {
        StreamFormat::OpenAiCompatible => decode_openai(&value),
        StreamFormat::OpenAiResponses => decode_openai_responses(&value),
        StreamFormat::ClaudeMessages => decode_claude(&value),
        StreamFormat::Gemini => decode_gemini(&value),
        StreamFormat::GeminiInteractions => decode_gemini_interactions(&value, state),
    };

    if let Some(update) = TokenUsage::from_chunk(&value) {
        state.usage.merge(update);
        parts.push(DecodedPart::Usage { usage: state.usage.clone() });
    }

    if parts.is_empty() {
        // 解析成功但没有任何可显示内容（如纯 usage / ping 事件）——这不是异常，
        // 但也不能返回空数组让调用方以为命令失败，因此明确标记为 Raw 之外的空壳。
        parts.push(DecodedPart::Raw {
            data: data.to_string(),
        });
    }

    parts
}

fn decode_openai(value: &Value) -> Vec<DecodedPart> {
    let mut parts = Vec::new();

    // 少数兼容实现把文本放在 choices[0].text（completion 风格）
    if let Some(text) = value
        .get("choices")
        .and_then(Value::as_array)
        .and_then(|choices| choices.first())
        .and_then(|choice| choice.get("text"))
        .and_then(Value::as_str)
    {
        push_text(&mut parts, text);
    }

    let Some(choice) = value
        .get("choices")
        .and_then(Value::as_array)
        .and_then(|choices| choices.first())
    else {
        return parts;
    };

    if let Some(finish) = choice.get("finish_reason").and_then(Value::as_str) {
        parts.push(DecodedPart::Stop {
            reason: finish.to_string(),
        });
    }

    let Some(delta) = choice.get("delta") else {
        return parts;
    };

    // 推理通道：DeepSeek 用 reasoning_content，部分实现用 reasoning
    for key in ["reasoning_content", "reasoning"] {
        if let Some(text) = delta.get(key).and_then(Value::as_str) {
            if !text.is_empty() {
                parts.push(DecodedPart::Reasoning {
                    text: text.to_string(),
                });
            }
        }
    }

    match delta.get("content") {
        Some(Value::String(text)) => push_text(&mut parts, text),
        // 多模态/分段内容：[{"type":"text","text":"..."}]
        Some(Value::Array(blocks)) => {
            for block in blocks {
                if let Some(text) = block.get("text").and_then(Value::as_str) {
                    push_text(&mut parts, text);
                }
            }
        }
        _ => {}
    }

    if let Some(calls) = delta.get("tool_calls").and_then(Value::as_array) {
        for (position, call) in calls.iter().enumerate() {
            let index = call
                .get("index")
                .and_then(Value::as_u64)
                .map(|v| v as usize)
                .unwrap_or(position);
            let function = call.get("function");
            let name = function
                .and_then(|f| f.get("name"))
                .and_then(Value::as_str)
                .unwrap_or_default();
            let arguments_fragment = function
                .and_then(|f| f.get("arguments"))
                .and_then(Value::as_str)
                .unwrap_or_default();
            parts.push(DecodedPart::ToolCall {
                index,
                name: name.to_string(),
                arguments_fragment: arguments_fragment.to_string(),
            });
        }
    }

    parts
}

fn decode_openai_responses(value: &Value) -> Vec<DecodedPart> {
    let mut parts = Vec::new();
    let event_type = value.get("type").and_then(Value::as_str).unwrap_or_default();

    match event_type {
        "response.output_text.delta" => {
            if let Some(text) = value.get("delta").and_then(Value::as_str) {
                push_text(&mut parts, text);
            }
        }
        "response.reasoning_summary_text.delta" | "response.reasoning_text.delta" => {
            if let Some(text) = value.get("delta").and_then(Value::as_str) {
                if !text.is_empty() {
                    parts.push(DecodedPart::Reasoning {
                        text: text.to_string(),
                    });
                }
            }
        }
        "response.output_item.added" | "response.output_item.done" => {
            // 工具调用以 item 形式出现：{"item":{"type":"function_call","name":..,"arguments":..}}
            if let Some(item) = value.get("item") {
                if item.get("type").and_then(Value::as_str) == Some("function_call") {
                    parts.push(DecodedPart::ToolCall {
                        index: value
                            .get("output_index")
                            .and_then(Value::as_u64)
                            .unwrap_or(0) as usize,
                        name: item
                            .get("name")
                            .and_then(Value::as_str)
                            .unwrap_or_default()
                            .to_string(),
                        arguments_fragment: item
                            .get("arguments")
                            .and_then(Value::as_str)
                            .unwrap_or_default()
                            .to_string(),
                    });
                }
            }
        }
        "response.completed" | "response.incomplete" => {
            let reason = value
                .get("response")
                .and_then(|r| r.get("status"))
                .and_then(Value::as_str)
                .unwrap_or("completed");
            parts.push(DecodedPart::Stop {
                reason: reason.to_string(),
            });
        }
        _ => {}
    }

    parts
}

fn decode_claude(value: &Value) -> Vec<DecodedPart> {
    let mut parts = Vec::new();
    let event_type = value.get("type").and_then(Value::as_str).unwrap_or_default();

    match event_type {
        "content_block_delta" => {
            let Some(delta) = value.get("delta") else {
                return parts;
            };
            match delta.get("type").and_then(Value::as_str).unwrap_or_default() {
                "text_delta" => {
                    if let Some(text) = delta.get("text").and_then(Value::as_str) {
                        push_text(&mut parts, text);
                    }
                }
                "thinking_delta" => {
                    if let Some(text) = delta.get("thinking").and_then(Value::as_str) {
                        if !text.is_empty() {
                            parts.push(DecodedPart::Reasoning {
                                text: text.to_string(),
                            });
                        }
                    }
                }
                "input_json_delta" => {
                    parts.push(DecodedPart::ToolCall {
                        index: value.get("index").and_then(Value::as_u64).unwrap_or(0) as usize,
                        name: String::new(),
                        arguments_fragment: delta
                            .get("partial_json")
                            .and_then(Value::as_str)
                            .unwrap_or_default()
                            .to_string(),
                    });
                }
                // signature_delta 是加密签名，不是可显示内容，故意忽略。
                _ => {}
            }
        }
        "content_block_start" => {
            let block = value.get("content_block");
            if block.and_then(|b| b.get("type")).and_then(Value::as_str) == Some("tool_use") {
                parts.push(DecodedPart::ToolCall {
                    index: value.get("index").and_then(Value::as_u64).unwrap_or(0) as usize,
                    name: block
                        .and_then(|b| b.get("name"))
                        .and_then(Value::as_str)
                        .unwrap_or_default()
                        .to_string(),
                    arguments_fragment: String::new(),
                });
            }
        }
        "message_delta" => {
            if let Some(reason) = value
                .get("delta")
                .and_then(|d| d.get("stop_reason"))
                .and_then(Value::as_str)
            {
                parts.push(DecodedPart::Stop {
                    reason: reason.to_string(),
                });
            }
        }
        _ => {}
    }

    parts
}

fn decode_gemini(value: &Value) -> Vec<DecodedPart> {
    let mut parts = Vec::new();

    let Some(candidates) = value.get("candidates").and_then(Value::as_array) else {
        return parts;
    };
    let Some(candidate) = candidates.first() else {
        return parts;
    };

    if let Some(reason) = candidate.get("finishReason").and_then(Value::as_str) {
        parts.push(DecodedPart::Stop {
            reason: reason.to_string(),
        });
    }

    let Some(content_parts) = candidate
        .get("content")
        .and_then(|c| c.get("parts"))
        .and_then(Value::as_array)
    else {
        return parts;
    };

    for part in content_parts {
        if let Some(text) = part.get("text").and_then(Value::as_str) {
            // thought: true 的 part 属于推理内容
            if part.get("thought").and_then(Value::as_bool).unwrap_or(false) {
                if !text.is_empty() {
                    parts.push(DecodedPart::Reasoning {
                        text: text.to_string(),
                    });
                }
            } else {
                push_text(&mut parts, text);
            }
        }
        if let Some(call) = part.get("functionCall") {
            parts.push(DecodedPart::ToolCall {
                index: parts
                    .iter()
                    .filter(|p| matches!(p, DecodedPart::ToolCall { .. }))
                    .count(),
                name: call
                    .get("name")
                    .and_then(Value::as_str)
                    .unwrap_or_default()
                    .to_string(),
                arguments_fragment: call
                    .get("args")
                    .map(|args| args.to_string())
                    .unwrap_or_default(),
            });
        }
    }

    parts
}

fn decode_gemini_interactions(value: &Value, state: &mut DecoderState) -> Vec<DecodedPart> {
    let mut parts = Vec::new();
    let event_type = value.get("event_type").and_then(Value::as_str).unwrap_or_default();
    let index = value.get("index").and_then(Value::as_u64).unwrap_or(0);

    match event_type {
        "step.start" => {
            if let Some(step_type) = value
                .get("step")
                .and_then(|s| s.get("type"))
                .and_then(Value::as_str)
            {
                state.step_types.insert(index, step_type.to_string());
            }
        }
        "step.delta" => {
            let Some(delta) = value.get("delta") else {
                return parts;
            };
            let delta_type = delta.get("type").and_then(Value::as_str).unwrap_or_default();
            match delta_type {
                "text" => {
                    let Some(text) = delta.get("text").and_then(Value::as_str) else {
                        return parts;
                    };
                    // 只有 model_output 步的 text 才算正文；thought 步里的 text 是思维链。
                    let step_type = state
                        .step_types
                        .get(&index)
                        .map(String::as_str)
                        .unwrap_or("model_output");
                    if step_type == "thought" {
                        parts.push(DecodedPart::Reasoning {
                            text: text.to_string(),
                        });
                    } else {
                        push_text(&mut parts, text);
                    }
                }
                "thought_summary" => {
                    if let Some(text) = delta
                        .get("content")
                        .and_then(|c| c.get("text"))
                        .and_then(Value::as_str)
                    {
                        parts.push(DecodedPart::Reasoning {
                            text: text.to_string(),
                        });
                    }
                }
                _ => {}
            }
        }
        "interaction.completed" => {
            parts.push(DecodedPart::Stop {
                reason: "completed".to_string(),
            });
        }
        _ => {}
    }

    parts
}

fn push_text(parts: &mut Vec<DecodedPart>, text: &str) {
    if text.is_empty() {
        return;
    }
    // 连续文本合并，减少 ArkTS 侧的拼接次数（一帧里常见多个 text part）。
    if let Some(DecodedPart::Text { text: existing }) = parts.last_mut() {
        existing.push_str(text);
        return;
    }
    parts.push(DecodedPart::Text {
        text: text.to_string(),
    });
}

/// 按 streamId 保留解码器的跨批次状态。
///
/// 只有 Gemini Interactions 需要它（`step.start` 与 `step.delta` 可能被 SSE 边界切开，
/// 落在不同的 `read_chat_completion_stream_decoded` 轮次里）；用量快照也按流保留。
/// 流结束时（`status != running`）由命令层调用 `remove` 清掉，防止无限增长。
pub struct StreamDecoderRegistry {
    states: std::sync::Mutex<std::collections::HashMap<String, DecoderState>>,
}

impl StreamDecoderRegistry {
    pub fn new() -> Self {
        Self {
            states: std::sync::Mutex::new(std::collections::HashMap::new()),
        }
    }

    /// 取（或新建）某个流的状态并解码一个 chunk。
    pub fn decode(
        &self,
        stream_id: &str,
        format: StreamFormat,
        data: &str,
    ) -> Vec<DecodedPart> {
        let mut states = self
            .states
            .lock()
            .expect("stream decoder registry lock poisoned");
        // 容量上限：被遗忘的流不能无限占内存。达到上限时清空整个表 —— 流间状态互不
        // 依赖，清掉旧的只会让 Gemini Interactions 的 step 类型退化回默认（正文），
        // 不会错乱。上限取 64：一个 App 同时活跃的流远到不了这个数。
        if states.len() >= 64 && !states.contains_key(stream_id) {
            states.clear();
        }
        decode(format, data, states.entry(stream_id.to_string()).or_default())
    }

    /// 流进入终态后调用，释放该流的状态。
    pub fn remove(&self, stream_id: &str) {
        self.states
            .lock()
            .expect("stream decoder registry lock poisoned")
            .remove(stream_id);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn texts(parts: &[DecodedPart]) -> String {
        parts
            .iter()
            .filter_map(|part| match part {
                DecodedPart::Text { text } => Some(text.as_str()),
                _ => None,
            })
            .collect()
    }

    fn reasonings(parts: &[DecodedPart]) -> String {
        parts
            .iter()
            .filter_map(|part| match part {
                DecodedPart::Reasoning { text } => Some(text.as_str()),
                _ => None,
            })
            .collect()
    }

    #[test]
    fn token_usage_only_chunks_are_typed_and_streams_stay_isolated() {
        let registry = StreamDecoderRegistry::new();
        let first = registry.decode("usage-a", StreamFormat::ClaudeMessages,
            r#"{"type":"message_start","message":{"usage":{"input_tokens":100,"output_tokens":0}}}"#);
        assert!(matches!(first.as_slice(), [DecodedPart::Usage { usage }] if usage.prompt_tokens == Some(100)));
        let end = registry.decode("usage-a", StreamFormat::ClaudeMessages,
            r#"{"type":"message_delta","usage":{"output_tokens":12}}"#);
        assert!(matches!(end.as_slice(), [DecodedPart::Usage { usage }] if usage.total_tokens == Some(112)));
        let second = registry.decode("usage-b", StreamFormat::OpenAiCompatible,
            r#"{"choices":[],"usage":{"completion_tokens":9}}"#);
        assert!(matches!(second.as_slice(), [DecodedPart::Usage { usage }] if usage.prompt_tokens.is_none() && usage.total_tokens.is_none()));
        registry.remove("usage-a");
        let reused = registry.decode("usage-a", StreamFormat::OpenAiCompatible,
            r#"{"choices":[],"usage":{"completion_tokens":0}}"#);
        assert!(matches!(reused.as_slice(), [DecodedPart::Usage { usage }] if usage.prompt_tokens.is_none() && usage.completion_tokens == Some(0)));
    }

    #[test]
    fn openai_compatible_extracts_text_and_reasoning() {
        let mut state = DecoderState::new();
        let parts = decode(
            StreamFormat::OpenAiCompatible,
            r#"{"choices":[{"delta":{"content":"你好","reasoning_content":"想想"}}]}"#,
            &mut state,
        );
        assert_eq!(texts(&parts), "你好");
        assert_eq!(reasonings(&parts), "想想");
    }

    #[test]
    fn openai_compatible_handles_tool_call_fragments() {
        let mut state = DecoderState::new();
        let parts = decode(
            StreamFormat::OpenAiCompatible,
            r#"{"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"name":"f","arguments":"{\"a\""}}]}}]}"#,
            &mut state,
        );
        assert!(matches!(
            parts.as_slice(),
            [DecodedPart::ToolCall { index: 0, name, arguments_fragment }]
                if name == "f" && arguments_fragment == "{\"a\""
        ));
    }

    #[test]
    fn openai_compatible_keeps_finish_reason() {
        let mut state = DecoderState::new();
        let parts = decode(
            StreamFormat::OpenAiCompatible,
            r#"{"choices":[{"delta":{},"finish_reason":"length"}]}"#,
            &mut state,
        );
        assert!(parts.contains(&DecodedPart::Stop {
            reason: "length".to_string()
        }));
    }

    #[test]
    fn openai_responses_extracts_output_text_delta() {
        let mut state = DecoderState::new();
        let parts = decode(
            StreamFormat::OpenAiResponses,
            r#"{"type":"response.output_text.delta","delta":"hello"}"#,
            &mut state,
        );
        assert_eq!(texts(&parts), "hello");
    }

    #[test]
    fn claude_extracts_text_thinking_and_stop() {
        let mut state = DecoderState::new();
        let text = decode(
            StreamFormat::ClaudeMessages,
            r#"{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"hello"}}"#,
            &mut state,
        );
        assert_eq!(texts(&text), "hello");

        let thinking = decode(
            StreamFormat::ClaudeMessages,
            r#"{"type":"content_block_delta","index":1,"delta":{"type":"thinking_delta","thinking":"now"}}"#,
            &mut state,
        );
        assert_eq!(reasonings(&thinking), "now");

        let stop = decode(
            StreamFormat::ClaudeMessages,
            r#"{"type":"message_delta","delta":{"stop_reason":"max_tokens"},"usage":{"output_tokens":8}}"#,
            &mut state,
        );
        assert!(stop.contains(&DecodedPart::Stop {
            reason: "max_tokens".to_string()
        }));

        // 加密签名不是可显示内容，必须不产生任何 part。
        let signature = decode(
            StreamFormat::ClaudeMessages,
            r#"{"type":"content_block_delta","index":3,"delta":{"type":"signature_delta","signature":"opaque"}}"#,
            &mut state,
        );
        assert_eq!(signature.len(), 1);
        assert!(matches!(signature[0], DecodedPart::Raw { .. }));
    }

    #[test]
    fn gemini_splits_thought_parts_from_text() {
        let mut state = DecoderState::new();
        let parts = decode(
            StreamFormat::Gemini,
            r#"{"candidates":[{"content":{"parts":[{"text":"think","thought":true},{"text":"答案"}]},"finishReason":"STOP"}]}"#,
            &mut state,
        );
        assert_eq!(texts(&parts), "答案");
        assert_eq!(reasonings(&parts), "think");
    }

    #[test]
    fn gemini_interactions_needs_step_type_state() {
        let mut state = DecoderState::new();
        // 没有 step.start 时按正文处理（缺省假设），这是可接受的降级。
        let defaulted = decode(
            StreamFormat::GeminiInteractions,
            r#"{"event_type":"step.delta","index":0,"delta":{"type":"text","text":"hi"}}"#,
            &mut state,
        );
        assert_eq!(texts(&defaulted), "hi");

        // 声明为 thought 步之后，同样的 text delta 必须落到推理通道。
        let _ = decode(
            StreamFormat::GeminiInteractions,
            r#"{"event_type":"step.start","index":1,"step":{"type":"thought"}}"#,
            &mut state,
        );
        let thought = decode(
            StreamFormat::GeminiInteractions,
            r#"{"event_type":"step.delta","index":1,"delta":{"type":"text","text":"hm"}}"#,
            &mut state,
        );
        assert_eq!(reasonings(&thought), "hm");
        assert_eq!(texts(&thought), "");
    }

    #[test]
    fn unknown_payload_is_preserved_not_dropped() {
        let mut state = DecoderState::new();
        let parts = decode(StreamFormat::OpenAiCompatible, "not json at all", &mut state);
        assert!(matches!(&parts[0], DecodedPart::Raw { data } if data == "not json at all"));
    }

    #[test]
    fn empty_content_string_produces_no_text_part() {
        let mut state = DecoderState::new();
        let parts = decode(
            StreamFormat::OpenAiCompatible,
            r#"{"choices":[{"delta":{"content":""}}]}"#,
            &mut state,
        );
        assert_eq!(texts(&parts), "");
    }
}
