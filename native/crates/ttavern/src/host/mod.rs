//! NAPI host shell for HarmonyOS.
//!
//! Phase map:
//!   - P2: `initialize(pathsJson)` resolves the OHOS sandbox paths injected from ArkTS,
//!     creates the SillyTavern-compatible data directory, and starts tracing file logging;
//!     `getBackendStatus()` reports readiness.
//!   - P3.1 (this step): the pieces that replace Tauri — `HostContext` (for `AppHandle`
//!     managed state), `events` (for `emit`), `resources` (for the resource bundle), and an
//!     `AgentRunActivity` stub.
//!   - P3.2+: assemble the `tt-application` service graph onto `HostContext`, then expose it
//!     through the single `invoke(command, payloadJson)` entry point.

pub mod agent_extension_tools;
pub mod backend_errors;
pub mod backend_readiness;
pub mod background_runtime;
pub mod cache_reconciler;
pub mod content_repository;
pub mod context;
pub mod data_archive_adapters;
pub mod events;
pub mod external_import;
pub mod identity;
pub mod logging;
pub mod path_store;
pub mod paths;
pub mod preset_repository;
pub mod repositories;
pub mod resources;
pub mod runtime;
pub mod services;
pub mod sync_adapters;
pub mod skills;
pub mod startup;
pub mod usage_ledger;

use backend_errors::BackendErrorHub;
use backend_readiness::BackendReadiness;
use services::AppServices;
use startup::StartupProfile;

/// Everything a command handler may touch, borrowed from the global runtime.
///
/// Stands in for upstream's `State<'_, Arc<AppState>>` plus the separately managed
/// `BackendErrorHub` / `BackendReadiness` states.
pub struct Ctx<'a> {
    pub startup: &'a StartupProfile,
    pub services: &'a AppServices,
    pub backend_errors: &'a BackendErrorHub,
    pub backend_readiness: &'a BackendReadiness,
}

impl Ctx<'static> {
    /// `None` until `initialize` has published the runtime.
    pub fn resolve() -> Option<Self> {
        let runtime = runtime::runtime()?;
        Some(Self {
            startup: &runtime.startup,
            services: &runtime.services,
            backend_errors: &runtime.backend_errors,
            backend_readiness: &runtime.backend_readiness,
        })
    }
}
