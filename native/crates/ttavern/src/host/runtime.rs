//! Global host runtime state (OnceLock) and the `initialize` / `get_backend_status` bodies.

use std::sync::OnceLock;

use tokio::sync::Mutex;

use tt_adapter_storage_core::file_system::DataDirectory;

use super::backend_errors::BackendErrorHub;
use super::backend_readiness::BackendReadiness;
use super::context::HostContext;
use super::paths::OhosAppPaths;
use super::repositories;
use super::services::{self, AppServices};
use super::startup::StartupProfile;

pub struct HostRuntime {
    pub context: HostContext,
    pub startup: StartupProfile,
    pub services: AppServices,
    pub backend_errors: BackendErrorHub,
    pub backend_readiness: BackendReadiness,
    pub initialized_at: chrono::DateTime<chrono::Utc>,
}

static RUNTIME: OnceLock<HostRuntime> = OnceLock::new();

/// 串行化整段初始化（2026-10-27 加）：`is_initialized()` 与 `OnceLock::set` 之间的
/// 重活（建目录/播种默认内容/装配服务）不是原子的 —— 并发的第二个 initialize 会重复
/// 执行并互相踩文件（真机侧只会调一次，但 dispatch 契约测试与 P6.1 聚焦测试在同一
/// 进程并发调用时实测触发过 `拒绝访问 (os error 5)`）。持锁跨 await 用 tokio Mutex，
/// 无取消死锁风险。
static INIT_LOCK: Mutex<()> = Mutex::const_new(());

pub fn is_initialized() -> bool {
    RUNTIME.get().is_some()
}

pub fn runtime() -> Option<&'static HostRuntime> {
    RUNTIME.get()
}

/// NAPI `initialize(pathsJson)`:
/// 1) parse the ArkTS-injected sandbox paths;
/// 2) create the runtime directory layout;
/// 3) initialize the SillyTavern-compatible data directory (tt-adapter-storage-core);
/// 4) start tracing file logging;
/// 5) load the one-shot startup snapshot;
/// 6) assemble the repository graph and the P3 service graph;
/// 7) publish everything globally.
///
/// Idempotent: a second call returns the current status instead of rebuilding state.
pub async fn initialize(paths_json: &str) -> Result<String, String> {
    // 串行化：见 INIT_LOCK 注释。整个初始化序列（含 await）都在锁内。
    let _guard = INIT_LOCK.lock().await;
    if is_initialized() {
        return Ok(status_json());
    }

    let app_paths: OhosAppPaths = serde_json::from_str(paths_json)
        .map_err(|e| format!("invalid paths payload: {e}"))?;

    let paths = app_paths.runtime_paths();
    paths
        .ensure_directories()
        .map_err(|e| format!("failed to create runtime directories: {e}"))?;

    let data_directory = DataDirectory::new(paths.data_root.clone());
    data_directory
        .initialize()
        .await
        .map_err(|e| format!("failed to initialize data directory: {e}"))?;

    super::logging::init(&paths.log_root).map_err(|e| format!("failed to init logging: {e}"))?;

    let bundled_media_root = app_paths.bundled_media_root();
    if let Some(root) = &bundled_media_root
        && !root.is_dir()
    {
        // Not fatal: the text content still seeds and media simply stays deferred.
        tracing::warn!(
            "bundled media root does not exist yet: {} (rawfile extraction not run?)",
            root.display()
        );
    }

    let context = HostContext::new(paths, data_directory, bundled_media_root);

    let startup = StartupProfile::load(&context.paths.data_root)
        .map_err(|e| format!("failed to load startup profile: {e}"))?;

    let repositories = repositories::build(&context, &startup)
        .await
        .map_err(|e| format!("failed to build repositories: {e}"))?;

    let services = services::build(&context, &startup, repositories)
        .await
        .map_err(|e| format!("failed to build services: {e}"))?;

    tracing::info!(
        data_root = %context.paths.data_root.display(),
        log_root = %context.paths.log_root.display(),
        bundled_resources = context.resources.len(),
        bundled_media_root = ?context.resources.media_root().map(|path| path.display().to_string()),
        bundled_media_files = context.resources.media_len(),
        services = AppServices::COUNT,
        "HarmonyOS host runtime initialized"
    );

    let backend_readiness = BackendReadiness::new();
    backend_readiness.mark_ready();

    let runtime = HostRuntime {
        context,
        startup,
        services,
        backend_errors: BackendErrorHub::new(),
        backend_readiness,
        initialized_at: chrono::Utc::now(),
    };
    let _ = RUNTIME.set(runtime);

    Ok(status_json())
}

/// NAPI `getBackendStatus()`: readiness JSON.
pub fn get_backend_status() -> String {
    status_json()
}

fn status_json() -> String {
    let version = env!("CARGO_PKG_VERSION");
    match runtime() {
        Some(rt) => serde_json::json!({
            "ready": true,
            "version": version,
            "platform": "ohos",
            "hostIdentity": super::identity::HOST_IDENTITY,
            "dataRoot": rt.context.paths.data_root,
            "logRoot": rt.context.paths.log_root,
            "bundledResources": rt.context.resources.len(),
            "bundledMediaRoot": rt
                .context
                .resources
                .media_root()
                .map(|path| path.display().to_string()),
            "bundledMediaFiles": rt.context.resources.media_len(),
            "services": AppServices::COUNT,
            "initializedAt": rt.initialized_at.to_rfc3339(),
        })
        .to_string(),
        None => serde_json::json!({
            "ready": false,
            "version": version,
            "platform": "ohos",
            "reason": "not initialized; call initialize(pathsJson) first",
        })
        .to_string(),
    }
}
