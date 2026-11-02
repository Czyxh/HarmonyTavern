//! Host context: the OHOS replacement for Tauri's managed state (`AppHandle::state`).
//!
//! Upstream `composition` reaches into `AppHandle` for exactly five kinds of state:
//!   - `Arc<HttpClientPool>`      → `HostContext::http_client_pool`
//!   - `Arc<PageGeneration>`      → `HostContext::page_generation`
//!   - `RuntimePaths`             → `HostContext::paths`
//!   - Tauri resource bundle      → `HostContext::resources` (`BundledResourceStore`)
//!   - `AppHandle::emit`          → `host::events` (ThreadsafeFunction to ArkTS)
//!
//! Everything else the services need is plain constructor injection, so `HostContext`
//! is passed by reference into the composition functions instead of an `AppHandle`.
//!
//! P3.2 adds the assembled `AppServices` to this struct; P3.1 only carries the
//! host-level singletons so the composition layer can be written against it.

use std::path::PathBuf;
use std::sync::Arc;

use tt_adapter_http::HttpClientPool;
use tt_adapter_storage_core::commit_stage::PageGeneration;
use tt_adapter_storage_core::file_system::DataDirectory;

use super::paths::RuntimePaths;
use super::resources::BundledResourceStore;

/// HTTP `User-Agent` for every request the backend makes on the user's behalf.
/// Mirrors upstream `product::USER_AGENT` (`concat!("TauriTavern/", version)`).
pub const USER_AGENT: &str = concat!("HarmonyTavern/", env!("CARGO_PKG_VERSION"));

pub struct HostContext {
    /// Sandbox-derived paths (data/log/archive roots).
    pub paths: RuntimePaths,
    /// SillyTavern-compatible data directory layout (`<data_root>/default-user/...`).
    pub data_directory: DataDirectory,
    /// Shared connection pool; also implements `RequestProxyRuntime`.
    pub http_client_pool: Arc<HttpClientPool>,
    /// Cache-invalidation generation owned by the host (upstream: managed state).
    pub page_generation: Arc<PageGeneration>,
    /// Bundled `default/**` assets: compiled-in text + extracted media root.
    pub resources: BundledResourceStore,
}

impl HostContext {
    pub fn new(
        paths: RuntimePaths,
        data_directory: DataDirectory,
        bundled_media_root: Option<PathBuf>,
    ) -> Self {
        Self {
            paths,
            data_directory,
            http_client_pool: Arc::new(HttpClientPool::new(USER_AGENT)),
            page_generation: Arc::new(PageGeneration::default()),
            resources: BundledResourceStore::with_media_root(bundled_media_root),
        }
    }
}
