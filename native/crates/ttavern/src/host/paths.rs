//! OHOS runtime paths, mirroring upstream `tauritavern/src/infrastructure/paths.rs`
//! mobile branch semantics: data/log/archive roots are derived from the app sandbox root
//! (ArkTS `context.filesDir`) injected through NAPI `initialize`.

use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};

/// Paths injected from ArkTS (`UIAbilityContext` properties).
///
/// Wire format is camelCase (what ArkTS sends); snake_case aliases are accepted too
/// so the contract can't break if the ArkTS side is refactored.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct OhosAppPaths {
    /// `context.filesDir`
    #[serde(alias = "files_dir")]
    pub files_dir: String,
    /// `context.databaseDir`
    #[serde(alias = "database_dir")]
    pub database_dir: String,
    /// `context.cacheDir`
    #[serde(alias = "cache_dir")]
    pub cache_dir: String,
    #[serde(alias = "bundle_name")]
    pub bundle_name: String,
    #[serde(alias = "version_name")]
    pub version_name: String,
    /// Directory where ArkTS extracted the HAP `rawfile` media (see `BundledMedia.ets`).
    /// Optional: when absent the backend behaves exactly like P3 (text-only content).
    #[serde(default, alias = "bundled_media_dir")]
    pub bundled_media_dir: Option<String>,
}

#[derive(Debug, Clone)]
pub struct RuntimePaths {
    pub app_root: PathBuf,
    pub data_root: PathBuf,
    pub log_root: PathBuf,
    pub archive_imports_root: PathBuf,
    pub archive_exports_root: PathBuf,
}

impl RuntimePaths {
    /// Same layout as upstream `RuntimePaths::new(mode, app_root)` (mobile branch):
    ///   data root = <app_root>/data, logs = <app_root>/logs,
    ///   archives = <app_root>/.data-archive/{imports,exports}
    pub fn from_app_root(app_root: PathBuf) -> Self {
        let data_root = app_root.join("data");
        let log_root = app_root.join("logs");
        let archive_root = app_root.join(".data-archive");
        let archive_imports_root = archive_root.join("imports");
        let archive_exports_root = archive_root.join("exports");
        Self {
            app_root,
            data_root,
            log_root,
            archive_imports_root,
            archive_exports_root,
        }
    }

    /// Ensure the writable directory layout exists.
    pub fn ensure_directories(&self) -> std::io::Result<()> {
        for dir in [
            &self.data_root,
            &self.log_root,
            &self.archive_imports_root,
            &self.archive_exports_root,
        ] {
            std::fs::create_dir_all(dir)?;
        }
        Ok(())
    }
}

impl OhosAppPaths {
    pub fn runtime_paths(&self) -> RuntimePaths {
        RuntimePaths::from_app_root(Path::new(&self.files_dir).to_path_buf())
    }

    /// Extracted `rawfile` media root, ignoring blank values sent by ArkTS.
    pub fn bundled_media_root(&self) -> Option<PathBuf> {
        self.bundled_media_dir
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(PathBuf::from)
    }
}
