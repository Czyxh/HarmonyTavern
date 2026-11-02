//! Host-owned `PresetRepository` (rebuilt from upstream
//! `infrastructure/repositories/file_preset_repository.rs`, 2026-10-27, P6.1).
//!
//! Upstream keeps this in the host crate because default presets are read through the Tauri
//! resource bundle. Here the bundle is `BundledResourceStore` (compiled-in `default/**`),
//! so `AppHandle` is dropped exactly like `FileContentRepository` does — the two repositories
//! share the same host-side resource concern.
//!
//! 对应 DevEco 工程路径：native/crates/ttavern/src/host/preset_repository.rs

use std::path::{Path, PathBuf};
use std::sync::Arc;

use async_trait::async_trait;
use serde_json::Value;

use tt_adapter_storage_core::file_system::{delete_file, read_json_file, write_json_file};
use tt_adapter_storage_core::preset_file_naming::{PresetFilePaths, load_named_preset_files};
use tt_domain::errors::DomainError;
use tt_domain::models::preset::{DefaultPreset, Preset, PresetType};
use tt_ports::repositories::content_repository::{ContentRepository, ContentType};
use tt_ports::repositories::preset_repository::PresetRepository;

use super::resources::BundledResourceStore;

/// File-based `PresetRepository`, identical to upstream except the resource bundle
/// replaces the Tauri `AppHandle`.
pub struct FilePresetRepository {
    /// Compiled-in `default/**` bundle (replaces upstream `AppHandle` + `read_resource_json`).
    resources: BundledResourceStore,
    /// Base user directory (e.g., `<data_root>/default-user`).
    user_dir: PathBuf,
    /// Content repository for default presets.
    content_repository: Arc<dyn ContentRepository>,
}

impl FilePresetRepository {
    pub fn new(
        resources: BundledResourceStore,
        user_dir: PathBuf,
        content_repository: Arc<dyn ContentRepository>,
    ) -> Self {
        Self {
            resources,
            user_dir,
            content_repository,
        }
    }

    /// Get the directory path for a specific preset type.
    fn get_preset_directory(&self, preset_type: &PresetType) -> PathBuf {
        self.user_dir.join(preset_type.directory_name())
    }

    /// Resolve canonical and deprecated legacy preset file paths for a logical preset name.
    fn get_preset_paths(
        &self,
        name: &str,
        preset_type: &PresetType,
    ) -> Result<PresetFilePaths, DomainError> {
        PresetFilePaths::new(
            name,
            &self.get_preset_directory(preset_type),
            preset_type.extension(),
        )
    }

    /// Ensure the preset directory exists.
    async fn ensure_directory_exists(&self, preset_type: &PresetType) -> Result<(), DomainError> {
        let directory = self.get_preset_directory(preset_type);

        if !directory.exists() {
            tokio::fs::create_dir_all(&directory).await.map_err(|e| {
                tracing::error!("Failed to create preset directory {:?}: {}", directory, e);
                DomainError::InternalError(format!("Failed to create preset directory: {e}"))
            })?;
        }

        Ok(())
    }

    fn content_type_to_preset_type(content_type: &ContentType) -> Option<PresetType> {
        match content_type {
            ContentType::KoboldPreset => Some(PresetType::Kobold),
            ContentType::NovelPreset => Some(PresetType::Novel),
            ContentType::OpenAIPreset => Some(PresetType::OpenAI),
            ContentType::TextGenPreset => Some(PresetType::TextGen),
            ContentType::Instruct => Some(PresetType::Instruct),
            ContentType::Context => Some(PresetType::Context),
            ContentType::SysPrompt => Some(PresetType::SysPrompt),
            ContentType::Reasoning => Some(PresetType::Reasoning),
            _ => None,
        }
    }

    /// Get default preset from the content system (bundled `default/content/**`).
    async fn get_default_preset_from_content(
        &self,
        name: &str,
        preset_type: &PresetType,
    ) -> Result<Option<DefaultPreset>, DomainError> {
        tracing::debug!("Looking for default preset: {} (type: {})", name, preset_type);

        let content_items = self.content_repository.get_content_index().await?;

        for item in content_items {
            let Some(item_type) = Self::content_type_to_preset_type(&item.content_type) else {
                continue;
            };
            if item_type != *preset_type {
                continue;
            }

            // Extract name from filename (remove extension).
            let item_name = Path::new(&item.filename)
                .file_stem()
                .and_then(|s| s.to_str())
                .unwrap_or(&item.filename);

            if item_name == name {
                // Found matching preset, load its bundled JSON.
                let text = self
                    .resources
                    .read_text(&format!("default/content/{}", item.filename))?;
                let data: Value = serde_json::from_str(&text).map_err(|error| {
                    DomainError::InvalidData(format!(
                        "Bundled default preset is invalid ({item_name}): {error}"
                    ))
                })?;

                return Ok(Some(DefaultPreset {
                    filename: item.filename,
                    name: name.to_string(),
                    preset_type: preset_type.clone(),
                    is_default: true,
                    data,
                }));
            }
        }

        tracing::debug!("Default preset not found: {} (type: {})", name, preset_type);
        Ok(None)
    }
}

#[async_trait]
impl PresetRepository for FilePresetRepository {
    async fn save_preset(&self, preset: &Preset) -> Result<(), DomainError> {
        tracing::debug!(
            "Saving preset: {} (type: {})",
            preset.name,
            preset.preset_type
        );

        self.ensure_directory_exists(&preset.preset_type).await?;

        let file_path = self
            .get_preset_paths(&preset.name, &preset.preset_type)?
            .prepare_for_save()
            .await?;

        // Prepare data with name included.
        let data_with_name = preset.data_with_name();

        write_json_file(&file_path, &data_with_name).await?;

        tracing::info!("Preset saved to {:?}", file_path);
        Ok(())
    }

    async fn delete_preset(&self, name: &str, preset_type: &PresetType) -> Result<(), DomainError> {
        tracing::debug!("Deleting preset: {} (type: {})", name, preset_type);

        let file_path = self
            .get_preset_paths(name, preset_type)?
            .resolve_existing()?
            .ok_or_else(|| DomainError::NotFound(format!("Preset not found: {name}")))?;

        delete_file(&file_path).await?;

        tracing::info!("Preset deleted: {:?}", file_path);
        Ok(())
    }

    async fn preset_exists(
        &self,
        name: &str,
        preset_type: &PresetType,
    ) -> Result<bool, DomainError> {
        Ok(self
            .get_preset_paths(name, preset_type)?
            .resolve_existing()?
            .is_some())
    }

    async fn get_preset(
        &self,
        name: &str,
        preset_type: &PresetType,
    ) -> Result<Option<Preset>, DomainError> {
        tracing::debug!("Getting preset: {} (type: {})", name, preset_type);

        let Some(file_path) = self
            .get_preset_paths(name, preset_type)?
            .resolve_existing()?
        else {
            return Ok(None);
        };

        let data: Value = read_json_file(&file_path).await?;

        let preset = Preset::new(name.to_string(), preset_type.clone(), data);

        Ok(Some(preset))
    }

    async fn list_presets(&self, preset_type: &PresetType) -> Result<Vec<String>, DomainError> {
        tracing::debug!("Listing presets of type: {}", preset_type);

        let directory = self.get_preset_directory(preset_type);

        if !directory.exists() {
            tracing::debug!("Preset directory does not exist: {:?}", directory);
            return Ok(vec![]);
        }

        let preset_names: Vec<String> = load_named_preset_files(&directory)
            .await?
            .into_iter()
            .map(|entry| entry.name)
            .collect();

        tracing::debug!(
            "Found {} presets of type {}",
            preset_names.len(),
            preset_type
        );

        Ok(preset_names)
    }

    async fn get_default_preset(
        &self,
        name: &str,
        preset_type: &PresetType,
    ) -> Result<Option<DefaultPreset>, DomainError> {
        self.get_default_preset_from_content(name, preset_type).await
    }
}
