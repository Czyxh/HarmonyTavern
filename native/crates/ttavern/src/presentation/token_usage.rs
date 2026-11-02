pub use tt_application::services::chat_completion_service::usage_observer::TokenUsage;
#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn token_usage_openai_zero_and_missing_are_distinct() {
        assert_eq!(TokenUsage::from_chunk(&json!({"usage":null})), None);
        assert_eq!(TokenUsage::from_chunk(&json!({"usage":{}})), None);
        assert_eq!(TokenUsage::from_chunk(&json!({"choices":[]})), None);
        let usage = TokenUsage::from_chunk(&json!({"usage":{"prompt_tokens":0,"completion_tokens":0,"total_tokens":0}})).unwrap();
        assert_eq!(usage.total_tokens, Some(0));
        let partial = TokenUsage::from_chunk(&json!({"usage":{"completion_tokens":9}})).unwrap();
        assert_eq!(partial.prompt_tokens, None);
        assert_eq!(partial.total_tokens, None);
        assert_eq!(serde_json::to_value(partial).unwrap(), json!({"completion_tokens":9}));
    }

    #[test]
    fn token_usage_stream_snapshots_do_not_accumulate_twice() {
        let update = TokenUsage::from_chunk(&json!({"usage":{"prompt_tokens":100,"completion_tokens":20,"total_tokens":120}})).unwrap();
        let mut usage = TokenUsage::default();
        usage.merge(update.clone()); usage.merge(update);
        assert_eq!(usage.total_tokens, Some(120));
        usage.merge(TokenUsage { completion_tokens:Some(25), ..Default::default() });
        assert_eq!(usage.total_tokens, Some(125));
    }

    #[test]
    fn token_usage_claude_partial_events_include_cache_input() {
        let mut usage = TokenUsage::from_chunk(&json!({"message":{"usage":{
            "input_tokens":10,"cache_creation_input_tokens":20,"cache_read_input_tokens":70,"output_tokens":0
        }}})).unwrap();
        usage.merge(TokenUsage::from_chunk(&json!({"usage":{"output_tokens":12}})).unwrap());
        assert_eq!(usage.prompt_tokens, Some(100));
        assert_eq!(usage.completion_tokens, Some(12));
        assert_eq!(usage.total_tokens, Some(112));
    }

    #[test]
    fn token_usage_responses_and_gemini_keep_reported_totals() {
        let response = TokenUsage::from_chunk(&json!({"response":{"usage":{"input_tokens":100,"output_tokens":30,"total_tokens":130}}})).unwrap();
        assert_eq!(response.total_tokens, Some(130));
        let gemini = TokenUsage::from_chunk(&json!({"usageMetadata":{"promptTokenCount":100,"candidatesTokenCount":10,"thoughtsTokenCount":20,"totalTokenCount":140}})).unwrap();
        assert_eq!(gemini.completion_tokens, Some(30));
        assert_eq!(gemini.total_tokens, Some(140));
        let interactions = TokenUsage::from_chunk(&json!({"interaction":{"usage":{"total_input_tokens":100,"total_output_tokens":10,"total_thought_tokens":20,"total_tokens":130}}})).unwrap();
        assert_eq!(interactions, response);
    }

    #[test]
    fn token_usage_invalid_counts_are_not_presented_as_zero() {
        let usage = TokenUsage::from_chunk(&json!({"usage":{"prompt_tokens":-1,"completion_tokens":"12","total_tokens":1.2}}));
        assert_eq!(usage, None);
    }
}
