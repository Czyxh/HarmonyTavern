//! Event channel: Rust → ArkTS, replacing Tauri's `AppHandle::emit`.
//!
//! Upstream services publish progress through `emit(event, payload)` (chat streaming, sync
//! status, generation lifecycle). On OHOS the ArkTS side registers one callback via
//! `setEventlistener`, and every emit is forwarded as a JSON envelope
//! `{"event": "<name>", "payload": <json>}` so a single listener can fan out by event name.
//!
//! Delivery is best-effort by design: emitting with no listener attached only logs
//! (Tauri behaves the same way — `emit` to a window that is gone is not an error).

use std::sync::{Mutex, OnceLock};

use napi_ohos::threadsafe_function::{ThreadsafeFunction, ThreadsafeFunctionCallMode};

/// JS callback type: receives the envelope JSON string.
pub type EventListener = ThreadsafeFunction<String>;

static LISTENER: OnceLock<Mutex<Option<EventListener>>> = OnceLock::new();

fn slot() -> &'static Mutex<Option<EventListener>> {
    LISTENER.get_or_init(|| Mutex::new(None))
}

/// Register (or replace) the ArkTS listener.
pub fn set_listener(listener: EventListener) {
    let mut guard = match slot().lock() {
        Ok(guard) => guard,
        Err(poisoned) => poisoned.into_inner(),
    };
    *guard = Some(listener);
}

/// Emit a JSON-serialisable payload under `event`.
pub fn emit(event: &str, payload: serde_json::Value) {
    let envelope = serde_json::json!({
        "event": event,
        "payload": payload,
    })
    .to_string();
    emit_raw(&envelope);
}

/// Emit already-serialised envelope JSON (avoids double encoding on hot paths).
pub fn emit_raw(envelope_json: &str) {
    let guard = match slot().lock() {
        Ok(guard) => guard,
        Err(poisoned) => poisoned.into_inner(),
    };
    let Some(listener) = guard.as_ref() else {
        tracing::debug!(envelope = envelope_json, "no event listener; dropping event");
        return;
    };
    let status = listener.call(
        Ok(envelope_json.to_string()),
        ThreadsafeFunctionCallMode::NonBlocking,
    );
    if status != napi_ohos::Status::Ok {
        tracing::warn!(?status, "failed to deliver event to ArkTS");
    }
}

#[cfg(test)]
mod tests {
    #[test]
    fn envelope_shape_is_stable() {
        let envelope = serde_json::json!({
            "event": "chat:chunk",
            "payload": { "text": "hi" },
        })
        .to_string();
        let parsed: serde_json::Value = serde_json::from_str(&envelope).expect("valid json");
        assert_eq!(parsed["event"], "chat:chunk");
        assert_eq!(parsed["payload"]["text"], "hi");
    }
}
