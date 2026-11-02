//! Tracing targets that must stay stable across releases.
//!
//! Mirrors upstream `observability_targets.rs`: ArkTS log filters and the user-visible error
//! sink key off these names, not off module paths.

/// Every command boundary log line.
pub const COMMAND: &str = "harmonytavern::command";

/// Errors the user must be told about (surfaced in the UI).
pub const USER_VISIBLE_ERROR: &str = "harmonytavern::user_visible_error";
