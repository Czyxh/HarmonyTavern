//! Preset 命令（上游 `preset_commands.rs`，8 条，P6.1）。
//!
//! 与上游一致：`delete_preset` / `delete_openai_preset` 在删预设后联动清理
//! 挂在该预设上的 Agent Skills（`skill_service.delete_skills_for_source`）。
//!
//! 对应 DevEco 工程路径：native/crates/ttavern/src/presentation/commands/preset.rs

use serde_json::Value;

use tt_application::dto::preset_dto::{
    DeleteOpenAIPresetDto, DeleteOpenAIPresetResponseDto, DeletePresetDto, RestorePresetDto,
    RestorePresetResponseDto, SaveOpenAIPresetDto, SavePresetDto, SavePresetResponseDto,
};
use tt_domain::models::preset::PresetType;

use crate::host::Ctx;
use crate::presentation::dispatch::Args;
use crate::presentation::errors::CommandError;
use crate::presentation::helpers::{log_command, map_command_error};

const SKILL_SOURCE_KIND_PRESET: &str = "preset";

/// Save a preset
pub async fn save_preset(ctx: &Ctx<'_>, args: &Args) -> Result<SavePresetResponseDto, CommandError> {
    let dto: SavePresetDto = args.typed("dto")?;
    log_command(format!("save_preset {} {}", dto.api_id, dto.name));

    // Validate input
    if dto.name.trim().is_empty() {
        tracing::warn!("Preset name is empty");
        return Err(CommandError::BadRequest(
            "Preset name cannot be empty".to_string(),
        ));
    }

    if dto.preset.is_null() {
        tracing::warn!("Preset data is null");
        return Err(CommandError::BadRequest(
            "Preset data cannot be null".to_string(),
        ));
    }

    // Create preset from DTO
    let preset = ctx
        .services
        .preset_service
        .create_preset(dto.name.clone(), &dto.api_id, dto.preset)
        .map_err(map_command_error("Failed to create preset"))?;

    // Save preset
    ctx.services
        .preset_service
        .save_preset(&preset)
        .await
        .map_err(map_command_error("Failed to save preset"))?;

    tracing::debug!("Preset saved successfully: {}", preset.name);
    Ok(SavePresetResponseDto::new(preset.name))
}

/// Delete a preset
pub async fn delete_preset(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let dto: DeletePresetDto = args.typed("dto")?;
    log_command(format!("delete_preset {} {}", dto.api_id, dto.name));

    // Validate input
    if dto.name.trim().is_empty() {
        tracing::warn!("Preset name is empty");
        return Err(CommandError::BadRequest(
            "Preset name cannot be empty".to_string(),
        ));
    }

    // Get preset type
    let preset_type = preset_type_from_api_id(&dto.api_id)?;

    // Delete preset
    ctx.services
        .preset_service
        .delete_preset(&dto.name, &preset_type)
        .await
        .map_err(map_command_error("Failed to delete preset"))?;

    let source_id = preset_skill_source_id(preset_type.to_api_id(), &dto.name);
    let deleted_skills = ctx
        .services
        .skill_service
        .delete_skills_for_source(SKILL_SOURCE_KIND_PRESET, &source_id)
        .await
        .map_err(map_command_error(format!(
            "Failed to delete Agent Skills linked to preset '{}'",
            dto.name
        )))?;
    if !deleted_skills.is_empty() {
        tracing::debug!(
            "Deleted {} Agent Skill(s) linked to preset '{}': {}",
            deleted_skills.len(),
            dto.name,
            deleted_skills.join(", ")
        );
    }

    tracing::debug!("Preset deleted successfully: {}", dto.name);
    Ok(())
}

/// Restore a default preset
pub async fn restore_preset(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<RestorePresetResponseDto, CommandError> {
    let dto: RestorePresetDto = args.typed("dto")?;
    log_command(format!("restore_preset {} {}", dto.api_id, dto.name));

    // Validate input
    if dto.name.trim().is_empty() {
        tracing::warn!("Preset name is empty");
        return Err(CommandError::BadRequest(
            "Preset name cannot be empty".to_string(),
        ));
    }

    // Get preset type
    let preset_type = preset_type_from_api_id(&dto.api_id)?;

    // Try to restore default preset
    match ctx
        .services
        .preset_service
        .restore_default_preset(&dto.name, &preset_type)
        .await
    {
        Ok(Some(default_preset)) => {
            tracing::debug!("Default preset found for restoration: {}", dto.name);
            Ok(RestorePresetResponseDto::new(true, default_preset.data))
        }
        Ok(None) => {
            tracing::debug!("Default preset not found: {}", dto.name);
            Ok(RestorePresetResponseDto::not_found())
        }
        Err(e) => Err(map_command_error("Failed to restore preset")(e)),
    }
}

/// Save an OpenAI preset (specialized endpoint)
pub async fn save_openai_preset(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<SavePresetResponseDto, CommandError> {
    let name: String = args.require("name")?;
    let dto: SaveOpenAIPresetDto = args.typed("dto")?;
    log_command(format!("save_openai_preset {}", name));

    // Validate input
    if name.trim().is_empty() {
        tracing::warn!("Preset name is empty");
        return Err(CommandError::BadRequest(
            "Preset name cannot be empty".to_string(),
        ));
    }

    // Create preset
    let preset = ctx
        .services
        .preset_service
        .create_preset(name.clone(), "openai", dto.preset)
        .map_err(map_command_error("Failed to create OpenAI preset"))?;

    // Save preset
    ctx.services
        .preset_service
        .save_preset(&preset)
        .await
        .map_err(map_command_error("Failed to save OpenAI preset"))?;

    tracing::debug!("OpenAI preset saved successfully: {}", preset.name);
    Ok(SavePresetResponseDto::new(preset.name))
}

/// Delete an OpenAI preset (specialized endpoint)
pub async fn delete_openai_preset(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<DeleteOpenAIPresetResponseDto, CommandError> {
    let dto: DeleteOpenAIPresetDto = args.typed("dto")?;
    log_command(format!("delete_openai_preset {}", dto.name));

    // Validate input
    if dto.name.trim().is_empty() {
        tracing::warn!("Preset name is empty");
        return Err(CommandError::BadRequest(
            "Preset name cannot be empty".to_string(),
        ));
    }

    // Delete preset
    match ctx
        .services
        .preset_service
        .delete_preset(&dto.name, &PresetType::OpenAI)
        .await
    {
        Ok(()) => {
            let source_id = preset_skill_source_id(PresetType::OpenAI.to_api_id(), &dto.name);
            if let Err(e) = ctx
                .services
                .skill_service
                .delete_skills_for_source(SKILL_SOURCE_KIND_PRESET, &source_id)
                .await
            {
                tracing::warn!(
                    "Failed to delete Agent Skills linked to OpenAI preset '{}': {}",
                    dto.name,
                    e
                );
                return Ok(DeleteOpenAIPresetResponseDto::error());
            }
            tracing::debug!("OpenAI preset deleted successfully: {}", dto.name);
            Ok(DeleteOpenAIPresetResponseDto::success())
        }
        Err(e) => {
            tracing::warn!("Failed to delete OpenAI preset: {}", e);
            Ok(DeleteOpenAIPresetResponseDto::error())
        }
    }
}

fn preset_type_from_api_id(api_id: &str) -> Result<PresetType, CommandError> {
    PresetType::from_api_id(api_id).ok_or_else(|| {
        let message = format!("Unknown API ID: {}", api_id);
        tracing::warn!("{message}");
        CommandError::BadRequest(message)
    })
}

fn preset_skill_source_id(api_id: &str, name: &str) -> String {
    format!("preset:{}:{}", api_id.trim(), name.trim())
}

/// List presets of a specific type
pub async fn list_presets(ctx: &Ctx<'_>, args: &Args) -> Result<Vec<String>, CommandError> {
    let api_id: String = args.require("apiId")?;
    log_command(format!("list_presets {}", api_id));

    // Get preset type
    let preset_type = preset_type_from_api_id(&api_id)?;

    // List presets
    let presets = ctx
        .services
        .preset_service
        .list_presets(&preset_type)
        .await
        .map_err(map_command_error("Failed to list presets"))?;

    tracing::debug!("Found {} presets of type {}", presets.len(), api_id);
    Ok(presets)
}

/// Check if a preset exists
pub async fn preset_exists(ctx: &Ctx<'_>, args: &Args) -> Result<bool, CommandError> {
    let name: String = args.require("name")?;
    let api_id: String = args.require("apiId")?;
    log_command(format!("preset_exists {} {}", api_id, name));

    // Get preset type
    let preset_type = preset_type_from_api_id(&api_id)?;

    // Check if preset exists
    let exists = ctx
        .services
        .preset_service
        .preset_exists(&name, &preset_type)
        .await
        .map_err(map_command_error("Failed to check preset existence"))?;

    tracing::debug!("Preset {} exists: {}", name, exists);
    Ok(exists)
}

/// Get a preset by name and type
pub async fn get_preset(ctx: &Ctx<'_>, args: &Args) -> Result<Option<Value>, CommandError> {
    let name: String = args.require("name")?;
    let api_id: String = args.require("apiId")?;
    log_command(format!("get_preset {} {}", api_id, name));

    // Get preset type
    let preset_type = preset_type_from_api_id(&api_id)?;

    // Get preset
    let preset = ctx
        .services
        .preset_service
        .get_preset(&name, &preset_type)
        .await
        .map_err(map_command_error("Failed to get preset"))?;

    match preset {
        Some(preset) => {
            tracing::debug!("Preset found: {}", name);
            Ok(Some(preset.data_with_name()))
        }
        None => {
            tracing::debug!("Preset not found: {}", name);
            Ok(None)
        }
    }
}
