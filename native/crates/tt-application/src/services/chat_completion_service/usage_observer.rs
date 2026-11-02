//! Provider-reported request usage only; missing counters are never invented as zero.
use serde::{Deserialize, Serialize};
use serde_json::Value;

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TokenUsage {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub prompt_tokens: Option<u64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub completion_tokens: Option<u64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub total_tokens: Option<u64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub cached_tokens: Option<u64>,
}

impl TokenUsage {
    pub fn is_empty(&self) -> bool {
        self.prompt_tokens.is_none() && self.completion_tokens.is_none() && self.total_tokens.is_none() && self.cached_tokens.is_none()
    }

    /// Stream counters are cumulative snapshots, not per-chunk deltas.
    pub fn merge(&mut self, update: Self) {
        let counts_changed = update.prompt_tokens.is_some() || update.completion_tokens.is_some();
        self.cached_tokens = update.cached_tokens.or(self.cached_tokens);
        self.prompt_tokens = update.prompt_tokens.or(self.prompt_tokens);
        self.completion_tokens = update.completion_tokens.or(self.completion_tokens);
        self.total_tokens = update.total_tokens.or_else(|| {
            if !counts_changed { return self.total_tokens; }
            self.prompt_tokens.zip(self.completion_tokens).and_then(|(input, output)| input.checked_add(output))
        }).or(self.total_tokens);
    }

    pub fn from_chunk(value: &Value) -> Option<Self> {
        let usage = value.get("usageMetadata")
            .or_else(|| value.get("usage"))
            .or_else(|| value.get("message").and_then(|v| v.get("usage")))
            .or_else(|| value.get("response").and_then(|v| v.get("usage")))
            .or_else(|| value.get("interaction").and_then(|v| v.get("usage")))?;
        if !usage.is_object() { return None; }
        let count = |key: &str| usage.get(key).and_then(Value::as_u64);
        let add = |left: Option<u64>, right: Option<u64>| left.and_then(|v| v.checked_add(right.unwrap_or(0)));
        let (prompt_tokens, completion_tokens, total_tokens) = if usage.get("promptTokenCount").is_some()
            || usage.get("totalTokenCount").is_some() || usage.get("candidatesTokenCount").is_some() {
            (count("promptTokenCount"), add(count("candidatesTokenCount"), count("thoughtsTokenCount")), count("totalTokenCount"))
        } else if usage.get("total_input_tokens").is_some() || usage.get("total_output_tokens").is_some() {
            (count("total_input_tokens"), add(count("total_output_tokens"), count("total_thought_tokens")), count("total_tokens"))
        } else if usage.get("input_tokens").is_some() || usage.get("output_tokens").is_some() {
            // Claude input_tokens excludes both cache creation and cache reads; Responses does not.
            let input = add(add(count("input_tokens"), count("cache_creation_input_tokens")), count("cache_read_input_tokens"));
            (input, count("output_tokens"), count("total_tokens"))
        } else {
            (count("prompt_tokens"), count("completion_tokens"), count("total_tokens"))
        };
        let cached_tokens = count("cache_read_input_tokens")
            .or_else(|| count("cachedContentTokenCount"))
            .or_else(|| count("total_cached_tokens"))
            .or_else(|| usage.pointer("/prompt_tokens_details/cached_tokens").and_then(Value::as_u64))
            .or_else(|| usage.pointer("/input_tokens_details/cached_tokens").and_then(Value::as_u64));
        let mut result = Self::default();
        result.merge(Self { prompt_tokens, completion_tokens, total_tokens, cached_tokens });
        (!result.is_empty()).then_some(result)
    }
}


/// Only request metadata and reported counters leave the generation service. No prompts, keys or responses.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UsageObservation {
    pub id: String,
    #[serde(default)]
    pub request_key: String,
    pub started_at: String,
    pub model: String,
    pub provider: String,
    pub kind: String,
    pub usage: TokenUsage,
    pub complete: bool,
}
pub type UsageObserver = std::sync::Arc<dyn Fn(UsageObservation) + Send + Sync>;
pub(super) struct UsageLease {
    observer: Option<UsageObserver>,
    event: UsageObservation,
}
impl UsageLease {
    pub(super) fn new(observer: Option<UsageObserver>, dto: &mut crate::dto::chat_completion_dto::ChatCompletionGenerateRequestDto) -> Self {
        let request_key = dto.payload.remove("_harmony_usage_request").and_then(|v| v.as_str().map(str::to_string)).unwrap_or_default();
        let kind = dto.payload.remove("_harmony_usage_kind").and_then(|v| v.as_str().map(str::to_string))
            .unwrap_or_else(|| "agent".into());
        Self { observer, event: UsageObservation { id: uuid::Uuid::new_v4().to_string(), request_key,
            started_at: chrono::Utc::now().to_rfc3339(), model: dto.get_string("model").unwrap_or("未知模型").chars().take(256).collect(),
            provider: dto.get_string("chat_completion_source").unwrap_or("openai").chars().take(64).collect(),
            kind, usage: TokenUsage::default(), complete: false } }
    }
    pub(super) fn feed(&mut self, value: &Value) {
        if let Some(usage) = TokenUsage::from_chunk(value) { self.event.usage.merge(usage); }
    }
    pub(super) fn finish(&mut self, complete: bool) { self.event.complete = complete; }
}
impl Drop for UsageLease {
    fn drop(&mut self) {
        if let Some(observer) = self.observer.take() { observer(self.event.clone()); }
    }
}

#[cfg(test)]
mod observer_tests {
    use super::*;
    use serde_json::json;
    #[test]
    fn usage_observer_records_once_without_prompt_and_merges_cache_snapshots() {
        let records = std::sync::Arc::new(std::sync::Mutex::new(vec![]));
        let sink = records.clone(); let observer: UsageObserver = std::sync::Arc::new(move |record| { sink.lock().unwrap().push(record); });
        let mut dto = crate::dto::chat_completion_dto::ChatCompletionGenerateRequestDto { payload: serde_json::from_value(json!({"model":"m","messages":[{"content":"private"}],"_harmony_usage_kind":"chat"})).unwrap() };
        { let mut lease = UsageLease::new(Some(observer), &mut dto);
          assert!(!dto.payload.contains_key("_harmony_usage_kind"));
          let chunk = json!({"usage":{"prompt_tokens":100,"completion_tokens":20,"total_tokens":120,"prompt_tokens_details":{"cached_tokens":40}}});
          lease.feed(&chunk);lease.feed(&chunk);lease.finish(true); }
        let rows=records.lock().unwrap();assert_eq!(rows.len(),1);assert_eq!(rows[0].usage.total_tokens,Some(120));assert_eq!(rows[0].usage.cached_tokens,Some(40));assert!(rows[0].complete);
        assert!(!serde_json::to_string(&rows[0]).unwrap().contains("private"));
    }
    #[test]
    fn usage_observer_cancelled_unknown_and_provider_cache_formats() {
        let values=vec![json!({"usage":{"input_tokens":5,"cache_creation_input_tokens":10,"cache_read_input_tokens":20,"output_tokens":3}}),
            json!({"usageMetadata":{"promptTokenCount":35,"candidatesTokenCount":3,"cachedContentTokenCount":20}}),
            json!({"response":{"usage":{"input_tokens":35,"output_tokens":3,"input_tokens_details":{"cached_tokens":20}}}})];
        for value in values {let usage=TokenUsage::from_chunk(&value).unwrap();assert_eq!(usage.prompt_tokens,Some(35));assert_eq!(usage.cached_tokens,Some(20));assert_eq!(usage.total_tokens,Some(38));}
        let mut usage=TokenUsage{total_tokens:Some(50), ..Default::default()};
        usage.merge(TokenUsage{cached_tokens:Some(0),..Default::default()});assert_eq!(usage.total_tokens,Some(50));
        assert!(TokenUsage::from_chunk(&json!({"usage":{"cached_tokens":-1}})).is_none());
    }
}
