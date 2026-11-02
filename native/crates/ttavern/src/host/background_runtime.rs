//! Process-lifetime background tokio runtime for host-side async jobs.
//!
//! Why this exists: `DataArchiveService` (and P6.2 sync jobs) take a `tokio::runtime::Handle`
//! to spawn background work. Upstream passes `tauri::async_runtime::handle()` — a
//! process-lifetime runtime. In the real app the napi-ohos runtime is also process-lifetime,
//! so `Handle::current()` would be fine; but contract tests run on per-`#[tokio::test]`
//! runtimes, and the handle captured during `initialize` belongs to whichever test won the
//! `INIT_LOCK` — when that test finishes, its runtime shuts down and queued jobs are never
//! polled (observed: data-archive export stuck at `queued/pending` in the full suite).
//!
//! A dedicated, lazily-created runtime decouples background jobs from the calling runtime
//! and matches upstream's process-lifetime semantics in both production and tests.

use std::sync::OnceLock;

use tokio::runtime::{Handle, Runtime};

static BACKGROUND_RUNTIME: OnceLock<Runtime> = OnceLock::new();

/// Return a handle to the process-lifetime background runtime.
pub fn background_handle() -> Handle {
    BACKGROUND_RUNTIME
        .get_or_init(|| Runtime::new().expect("failed to create background tokio runtime"))
        .handle()
        .clone()
}
