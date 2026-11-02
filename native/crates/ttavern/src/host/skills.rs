//! Builtin Skills materialization (rebuilt from upstream
//! `materialize_builtin_skills`, P6.1).
//!
//! Upstream names the immutable content directory with a build-time digest
//! (`env!("TAURITAVERN_BUILTIN_SKILLS_DIGEST")`). Here the digest is computed at
//! runtime over the embedded `default/skills/**` entries (paths + contents), which
//! preserves the same content-addressed publish-rename invariant without a build step.
//!
//! 对应 DevEco 工程路径：native/crates/ttavern/src/host/skills.rs

use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};
use std::path::{Path, PathBuf};

use tt_domain::errors::DomainError;

use super::resources::BundledResourceStore;

/// Runtime content digest for `default/skills/**` (FNV-style via `DefaultHasher`).
fn builtin_skills_digest(resources: &BundledResourceStore) -> String {
    let mut hasher = DefaultHasher::new();
    for relative in resources.list_under("skills") {
        relative.hash(&mut hasher);
        match resources.read_bytes(&format!("default/skills/{relative}")) {
            Ok(bytes) => bytes.hash(&mut hasher),
            Err(_) => relative.hash(&mut hasher),
        }
    }
    format!("v{:016x}", hasher.finish())
}

/// Materialize bundled builtin Skills into `data_root/_cache/builtin-skills/<digest>`,
/// publishing via an atomic rename. Returns the materialized root.
pub async fn materialize_builtin_skills(
    resources: &BundledResourceStore,
    data_root: &Path,
) -> Result<PathBuf, DomainError> {
    let cache_root = data_root.join("_cache").join("builtin-skills");
    let digest = builtin_skills_digest(resources);
    let target = cache_root.join(&digest);

    // The digest names immutable content; publishing the directory is the final write.
    if tokio::fs::try_exists(&target).await.map_err(|error| {
        DomainError::file_io("stat builtin Skills", target.display().to_string(), error)
    })? {
        return Ok(target);
    }

    let staging = cache_root.join(format!(".{digest}.tmp-{}", uuid::Uuid::new_v4().simple()));
    tokio::fs::create_dir_all(&staging).await.map_err(|error| {
        DomainError::file_io(
            "create builtin Skills staging",
            staging.display().to_string(),
            error,
        )
    })?;

    for relative in resources.list_under("skills") {
        resources.copy_to(&format!("default/skills/{relative}"), &staging.join(&relative))?;
    }

    tokio::fs::rename(&staging, &target).await.map_err(|error| {
        DomainError::file_io(
            "publish builtin Skills",
            target.display().to_string(),
            error,
        )
    })?;

    // Older copies are never read again; leftovers must not block startup.
    if let Err(error) = remove_other_entries(&cache_root, &target).await {
        tracing::warn!(
            "Failed to remove old builtin Skills in {}: {error}",
            cache_root.display()
        );
    }
    Ok(target)
}

async fn remove_other_entries(cache_root: &Path, keep: &Path) -> std::io::Result<()> {
    let mut entries = tokio::fs::read_dir(cache_root).await?;
    while let Some(entry) = entries.next_entry().await? {
        if entry.path() == keep {
            continue;
        }
        if entry.file_type().await?.is_dir() {
            tokio::fs::remove_dir_all(entry.path()).await?;
        } else {
            tokio::fs::remove_file(entry.path()).await?;
        }
    }
    Ok(())
}
