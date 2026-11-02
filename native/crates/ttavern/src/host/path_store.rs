//! Runtime path config store for the OHOS sandbox (port impl for `RuntimePathConfigStore`).
//!
//! Upstream persists an optional `runtime.json` sidecar to support portable mode (a data
//! root next to the executable, user-relocatable). The OHOS sandbox has neither a
//! user-chosen sibling directory nor a restartable process, so:
//! - `load_config` always reports "no override" → `RuntimePathsService` reports `standard`;
//! - `request_data_root_change` fails with an explanatory `InvalidData` instead of pretending.

use std::path::Path;
use std::sync::Arc;

use async_trait::async_trait;

use tt_application::services::runtime_paths_service::{
    RuntimeModeInfo, RuntimePathConfigInfo, RuntimePathConfigStore, RuntimePathsService,
    RuntimePathsSnapshot,
};
use tt_domain::errors::DomainError;

use super::paths::RuntimePaths;

pub struct SandboxRuntimePathConfigStore;

#[async_trait]
impl RuntimePathConfigStore for SandboxRuntimePathConfigStore {
    fn load_config(&self, _app_root: &Path) -> Result<Option<RuntimePathConfigInfo>, DomainError> {
        Ok(None)
    }

    async fn request_data_root_change(
        &self,
        _app_root: &Path,
        _current_data_root: &Path,
        _raw_target: &str,
    ) -> Result<(), DomainError> {
        Err(DomainError::InvalidData(
            "Changing the data root is not supported on HarmonyOS: application data can only \
             live inside the app sandbox"
                .to_string(),
        ))
    }
}

pub fn build_runtime_paths_service(paths: &RuntimePaths) -> Arc<RuntimePathsService> {
    Arc::new(RuntimePathsService::new(
        RuntimePathsSnapshot {
            mode: RuntimeModeInfo::Standard,
            app_root: paths.app_root.clone(),
            data_root: paths.data_root.clone(),
        },
        Arc::new(SandboxRuntimePathConfigStore),
    ))
}
