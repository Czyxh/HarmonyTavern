//! Presentation layer: the command boundary.
//!
//! Upstream exposes 362 `#[tauri::command]` functions, each deserialised from the Tauri
//! `invoke` payload. OHOS keeps the *same* per-command payload shape (an object of named
//! arguments) but reaches the backend through a single NAPI entry point:
//!
//! ```text
//! ArkTS: native.invoke("create_user", JSON.stringify({ dto: {...} }))
//! Rust:  dispatch::invoke("create_user", payload) -> JSON envelope
//! ```
//!
//! One entry point instead of 362 NAPI functions keeps the ABI tiny (four NAPI symbols
//! total) and lets the ArkTS side carry a typed wrapper per command.

pub mod chat_stream_decoder;
pub mod token_usage;
pub mod commands;
pub mod dispatch;
pub mod errors;
pub mod helpers;
