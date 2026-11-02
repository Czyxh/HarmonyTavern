//! Default content seeding (ported from upstream `infrastructure/repositories/file_content_repository.rs`).
//!
//! Upstream keeps this in the host crate because it needs the Tauri resource bundle. Here the
//! bundle is `BundledResourceStore` (compiled-in `default/**`), so the port drops `AppHandle`
//! entirely; it lives in the host for the same reason as upstream — it is the only repository
//! that reads bundled resources, and those are a host concern.
//!
//! ## Scope difference from upstream (deliberate, documented)
//!
//! Upstream copies `default/**` including binary assets (backgrounds ≈4.0 MB, sprite sheets,
//! avatars, character cards). P3 embeds only *text* assets in the `.so`; binary media ships as
//! HAP rawfiles and is materialised by P4. So when an index entry resolves to no embedded
//! text, this port logs it as deferred and leaves the item *out* of `content.log`; P4 re-runs
//! the seed and copies the binary remainder. Already-copied text files are skipped by the
//! `dest_path.exists()` guard, so re-running is idempotent — same invariant as upstream.

use std::path::{Path, PathBuf};

use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use tokio::fs;

use tt_domain::errors::DomainError;
use tt_ports::repositories::content_repository::{
    ContentItem, ContentRepository, ContentScope, ContentType,
};

use super::resources::BundledResourceStore;

/// Content index item from `default/content/index.json`.
#[derive(Debug, Clone, Serialize, Deserialize)]
struct ContentIndexItem {
    filename: String,
    #[serde(rename = "type")]
    content_type: String,
}

pub struct FileContentRepository {
    resources: BundledResourceStore,
    data_root: PathBuf,
    user_content_dir: PathBuf,
}

/// Outcome of one seed run (logged; used by tests and by the P3 acceptance checklist).
#[derive(Debug, Default, Clone, Copy, PartialEq, Eq)]
pub struct SeedReport {
    pub copied: usize,
    pub skipped_existing: usize,
    pub deferred_binary: usize,
}

impl FileContentRepository {
    /// `user_content_dir` is the complete user directory (`<data_root>/default-user`) and
    /// `data_root` the global data root (for the `_errors` / `_css` global scopes).
    pub fn new(
        resources: BundledResourceStore,
        data_root: PathBuf,
        user_content_dir: PathBuf,
    ) -> Self {
        Self {
            resources,
            data_root,
            user_content_dir,
        }
    }

    fn content_type_from_string(content_type: &str) -> Result<ContentType, DomainError> {
        match content_type {
            "settings" => Ok(ContentType::Settings),
            "character" => Ok(ContentType::Character),
            "sprites" => Ok(ContentType::Sprites),
            "background" => Ok(ContentType::Background),
            "world" => Ok(ContentType::World),
            "avatar" => Ok(ContentType::Avatar),
            "theme" => Ok(ContentType::Theme),
            "workflow" => Ok(ContentType::Workflow),
            "kobold_preset" => Ok(ContentType::KoboldPreset),
            "openai_preset" => Ok(ContentType::OpenAIPreset),
            "novel_preset" => Ok(ContentType::NovelPreset),
            "textgen_preset" => Ok(ContentType::TextGenPreset),
            "instruct" => Ok(ContentType::Instruct),
            "context" => Ok(ContentType::Context),
            "moving_ui" => Ok(ContentType::MovingUI),
            "quick_replies" => Ok(ContentType::QuickReplies),
            "sysprompt" => Ok(ContentType::SysPrompt),
            "reasoning" => Ok(ContentType::Reasoning),
            "error_page" => Ok(ContentType::ErrorPage),
            "stylesheet" => Ok(ContentType::Stylesheet),
            other => Err(DomainError::InvalidData(format!(
                "Unknown default content type: {other}"
            ))),
        }
    }

    fn get_target_directory(&self, content_type: &ContentType, user_dir: &Path) -> PathBuf {
        match content_type {
            ContentType::Settings => user_dir.to_path_buf(),
            ContentType::Character | ContentType::Sprites => user_dir.join("characters"),
            ContentType::Background => user_dir.join("backgrounds"),
            ContentType::World => user_dir.join("worlds"),
            ContentType::Avatar => user_dir.join("User Avatars"),
            ContentType::Theme => user_dir.join("themes"),
            ContentType::Workflow => user_dir.join("user").join("workflows"),
            ContentType::KoboldPreset => user_dir.join("KoboldAI Settings"),
            ContentType::OpenAIPreset => user_dir.join("OpenAI Settings"),
            ContentType::NovelPreset => user_dir.join("NovelAI Settings"),
            ContentType::TextGenPreset => user_dir.join("TextGen Settings"),
            ContentType::Instruct => user_dir.join("instruct"),
            ContentType::Context => user_dir.join("context"),
            ContentType::MovingUI => user_dir.join("movingUI"),
            ContentType::QuickReplies => user_dir.join("QuickReplies"),
            ContentType::SysPrompt => user_dir.join("sysprompt"),
            ContentType::Reasoning => user_dir.join("reasoning"),
            ContentType::ErrorPage => self.data_root.join("_errors"),
            ContentType::Stylesheet => self.data_root.join("_css"),
        }
    }

    /// Index entries without an extension name a directory inside `default/content`.
    fn is_directory_entry(path: &str) -> bool {
        Path::new(path).extension().is_none()
    }

    /// Expand one index entry into the concrete embedded files it covers.
    /// Returns paths relative to `default/content` (upstream `list_default_files_under` shape).
    fn expand_resource_entries(&self, filename: &str) -> Result<Vec<String>, DomainError> {
        if !Self::is_directory_entry(filename) {
            return Ok(vec![filename.to_string()]);
        }

        let entries: Vec<String> = self
            .resources
            .list_under(&format!("content/{}", filename.trim_matches('/')))
            .into_iter()
            .map(|path| path.trim_start_matches("content/").to_string())
            .collect();
        if entries.is_empty() {
            return Err(DomainError::NotFound(format!(
                "Resource directory is empty or missing: {filename}"
            )));
        }

        Ok(entries)
    }

    fn build_destination_path(
        &self,
        item: &ContentItem,
        resource_entry: &str,
        target_dir: &Path,
    ) -> Result<PathBuf, DomainError> {
        if Self::is_directory_entry(&item.filename) {
            let dir_name = Path::new(&item.filename).file_name().ok_or_else(|| {
                DomainError::InvalidData(format!("Invalid directory entry: {}", item.filename))
            })?;

            let prefix = format!("{}/", item.filename.trim_matches('/').replace('\\', "/"));
            let relative_entry = resource_entry
                .strip_prefix(&prefix)
                .unwrap_or(resource_entry);

            return Ok(target_dir.join(dir_name).join(relative_entry));
        }

        let base_filename = Path::new(&item.filename).file_name().ok_or_else(|| {
            DomainError::InvalidData(format!("Invalid filename: {}", item.filename))
        })?;

        Ok(target_dir.join(base_filename))
    }

    fn content_log_path(&self, scope: ContentScope, user_dir: &Path) -> PathBuf {
        match scope {
            ContentScope::User => user_dir.join("content.log"),
            ContentScope::Global => self.data_root.join("content.log"),
        }
    }

    async fn read_content_log(path: &Path) -> Result<Vec<String>, DomainError> {
        match fs::read_to_string(path).await {
            Ok(text) => Ok(text
                .lines()
                .map(str::trim)
                .filter(|line| !line.is_empty())
                .map(ToOwned::to_owned)
                .collect()),
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(Vec::new()),
            Err(error) => {
                tracing::error!("Failed to read content log {:?}: {}", path, error);
                Err(DomainError::InternalError(format!(
                    "Failed to read content log: {}",
                    error
                )))
            }
        }
    }

    async fn write_content_log(path: &Path, entries: &[String]) -> Result<(), DomainError> {
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).await.map_err(|error| {
                tracing::error!(
                    "Failed to create content log directory {:?}: {}",
                    parent,
                    error
                );
                DomainError::InternalError(format!(
                    "Failed to create content log directory: {}",
                    error
                ))
            })?;
        }

        fs::write(path, entries.join("\n")).await.map_err(|error| {
            tracing::error!("Failed to write content log {:?}: {}", path, error);
            DomainError::InternalError(format!("Failed to write content log: {}", error))
        })
    }

    async fn seed_content_scope(
        &self,
        scope: ContentScope,
        content_items: &[ContentItem],
        user_dir: &Path,
    ) -> Result<SeedReport, DomainError> {
        let mut report = SeedReport::default();
        let scoped_items = content_items
            .iter()
            .filter(|item| item.content_type.scope() == scope)
            .collect::<Vec<_>>();

        if scoped_items.is_empty() {
            return Ok(report);
        }

        let log_path = self.content_log_path(scope, user_dir);
        let mut content_log = Self::read_content_log(&log_path).await?;

        for item in scoped_items {
            if content_log.iter().any(|entry| entry == &item.filename) {
                tracing::debug!("Skipping content item {}, already in log", item.filename);
                continue;
            }

            let target_dir = self.get_target_directory(&item.content_type, user_dir);
            fs::create_dir_all(&target_dir).await.map_err(|error| {
                tracing::error!(
                    "Failed to create target directory {:?}: {}",
                    target_dir,
                    error
                );
                DomainError::InternalError(format!("Failed to create target directory: {}", error))
            })?;

            let resource_entries = self.expand_resource_entries(&item.filename)?;

            let mut entry_deferred = false;
            for resource_entry in resource_entries {
                let resource_path = format!("default/content/{}", resource_entry);
                let dest_path = self.build_destination_path(item, &resource_entry, &target_dir)?;

                if dest_path.exists() {
                    report.skipped_existing += 1;
                    tracing::debug!("Skipping copy, file already exists: {:?}", dest_path);
                    continue;
                }

                match self.resources.read_bytes(&resource_path) {
                    Ok(bytes) => {
                        if let Some(parent) = dest_path.parent() {
                            fs::create_dir_all(parent).await.map_err(|error| {
                                DomainError::InternalError(format!(
                                    "Failed to create content directory {}: {}",
                                    parent.display(),
                                    error
                                ))
                            })?;
                        }
                        fs::write(&dest_path, &bytes).await.map_err(|error| {
                            DomainError::InternalError(format!(
                                "Failed to write content file {}: {}",
                                dest_path.display(),
                                error
                            ))
                        })?;
                        report.copied += 1;
                    }
                    Err(DomainError::NotFound(_)) => {
                        // Binary asset missing from both sources: keep the item out of
                        // `content.log` so a later run seeds it once the media exists.
                        report.deferred_binary += 1;
                        entry_deferred = true;
                        tracing::warn!(
                            "Bundled content asset unavailable (text and media root): {}",
                            resource_path
                        );
                    }
                    Err(error) => return Err(error),
                }
            }

            // Only a fully seeded item is recorded, so P4 re-runs the remainder.
            if entry_deferred {
                tracing::info!(
                    "Content item {} partially seeded: binary assets deferred to P4",
                    item.filename
                );
            } else {
                content_log.push(item.filename.clone());
            }
        }

        Self::write_content_log(&log_path, &content_log).await?;
        Ok(report)
    }

    async fn content_log_contains_any(
        &self,
        scope: ContentScope,
        content_items: &[ContentItem],
        user_dir: &Path,
    ) -> Result<bool, DomainError> {
        let scoped_items = content_items
            .iter()
            .filter(|item| item.content_type.scope() == scope)
            .collect::<Vec<_>>();

        if scoped_items.is_empty() {
            return Ok(false);
        }

        let content_log = Self::read_content_log(&self.content_log_path(scope, user_dir)).await?;
        Ok(scoped_items
            .iter()
            .any(|item| content_log.iter().any(|entry| entry == &item.filename)))
    }

    /// Full seed pass; P3's `initialize_default_content` uses this to log the outcome.
    pub async fn copy_default_content_to_user_with_report(
        &self,
        user_handle: &str,
    ) -> Result<SeedReport, DomainError> {
        tracing::info!("Synchronizing default content for user: {}", user_handle);

        let content_items = self.get_content_index().await?;
        let user_dir = self.user_content_dir.clone();

        fs::create_dir_all(&user_dir).await.map_err(|error| {
            tracing::error!("Failed to create user directory {:?}: {}", user_dir, error);
            DomainError::InternalError(format!("Failed to create user directory: {}", error))
        })?;

        let mut report = self
            .seed_content_scope(ContentScope::Global, &content_items, &user_dir)
            .await?;
        let user_report = self
            .seed_content_scope(ContentScope::User, &content_items, &user_dir)
            .await?;
        report.copied += user_report.copied;
        report.skipped_existing += user_report.skipped_existing;
        report.deferred_binary += user_report.deferred_binary;

        tracing::info!(
            copied = report.copied,
            skipped_existing = report.skipped_existing,
            deferred_binary = report.deferred_binary,
            "Default content synchronized"
        );
        Ok(report)
    }
}

#[async_trait]
impl ContentRepository for FileContentRepository {
    async fn copy_default_content_to_user(&self, user_handle: &str) -> Result<(), DomainError> {
        self.copy_default_content_to_user_with_report(user_handle)
            .await
            .map(|_| ())
    }

    async fn get_content_index(&self) -> Result<Vec<ContentItem>, DomainError> {
        let index_items: Vec<ContentIndexItem> = serde_json::from_str(
            self.resources.read_text("default/content/index.json")?,
        )
        .map_err(|error| {
            DomainError::InvalidData(format!(
                "Bundled content index is invalid (default/content/index.json): {error}"
            ))
        })?;

        let mut content_items = Vec::with_capacity(index_items.len());
        for item in index_items {
            content_items.push(ContentItem {
                filename: item.filename,
                content_type: Self::content_type_from_string(&item.content_type)?,
            });
        }

        Ok(content_items)
    }

    async fn is_default_content_initialized(&self, user_handle: &str) -> Result<bool, DomainError> {
        tracing::debug!(
            "Checking if default content is initialized for user: {}",
            user_handle
        );

        let user_dir = self.user_content_dir.clone();
        let content_items = self.get_content_index().await?;

        self.content_log_contains_any(ContentScope::User, &content_items, &user_dir)
            .await
    }
}
