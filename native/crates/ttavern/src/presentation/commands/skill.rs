//! Agent Skill 命令（上游 `skill_commands.rs`，13 条，P6.1）。
//!
//! `SkillExportPayload` 为宿主侧重建：上游直接定义在命令层（`base64` 编码导出字节），
//! 属表示层形状，不属 tt-domain。
//!
//! 对应 DevEco 工程路径：native/crates/ttavern/src/presentation/commands/skill.rs

use base64::Engine;
use base64::engine::general_purpose::STANDARD as BASE64_STANDARD;
use serde::Serialize;

use tt_domain::models::skill::{
    DEFAULT_SKILL_READ_FALLBACK_MAX_CHARS, SkillFileRef, SkillImportInput, SkillImportPreview,
    SkillIndexEntry, SkillInstallRequest, SkillInstallResult, SkillMoveRequest, SkillReadRequest,
    SkillReadResult, SkillScope, SkillScopeFilter, SkillScopeRetargetRequest,
    SkillScopeRetargetResult, SkillWriteRequest,
};

use crate::host::Ctx;
use crate::presentation::dispatch::Args;
use crate::presentation::errors::CommandError;
use crate::presentation::helpers::{
    ensure_ios_policy_allows, log_command, map_command_error,
};

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SkillExportPayload {
    pub file_name: String,
    pub content_base64: String,
    pub sha256: String,
}

pub async fn download_skill_import_url(ctx: &Ctx<'_>, args: &Args) -> Result<SkillImportInput, CommandError> {
    let url: String = args.require("url")?;
    log_command("download_skill_import_url");

    ensure_ios_policy_allows(
        &ctx.startup.ios_policy,
        ctx.startup.ios_policy.capabilities.content.external_import,
        "content.external_import",
    )?;

    ctx.services
        .skill_service
        .download_import_url(&url)
        .await
        .map_err(map_command_error(
            "Failed to download Agent Skill import URL",
        ))
}

pub async fn list_skills(ctx: &Ctx<'_>, args: &Args) -> Result<Vec<SkillIndexEntry>, CommandError> {
    let scope: Option<SkillScopeFilter> = args.optional("scope")?;
    log_command("list_skills");

    ctx.services
        .skill_service
        .list_skills(scope.unwrap_or_default())
        .await
        .map_err(map_command_error("Failed to list Agent Skills"))
}

pub async fn list_skill_files(ctx: &Ctx<'_>, args: &Args) -> Result<Vec<SkillFileRef>, CommandError> {
    let name: String = args.require("name")?;
    let scope: Option<SkillScope> = args.optional("scope")?;
    log_command(format!("list_skill_files {}", name));

    ctx.services
        .skill_service
        .list_skill_files(scope.unwrap_or_default(), &name)
        .await
        .map_err(map_command_error("Failed to list Agent Skill files"))
}

pub async fn discover_skill_imports(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<Vec<SkillImportInput>, CommandError> {
    let input: SkillImportInput = args.typed("input")?;
    log_command("discover_skill_imports");

    ctx.services
        .skill_service
        .discover_imports(input)
        .await
        .map_err(map_command_error("Failed to discover Agent Skill imports"))
}

pub async fn discard_skill_import_archive(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let path: String = args.require("path")?;
    log_command("discard_skill_import_archive");

    ctx.services
        .skill_service
        .discard_import_archive(&path)
        .await
        .map_err(map_command_error("Failed to discard Agent Skill archive"))
}

pub async fn preview_skill_import(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<SkillImportPreview, CommandError> {
    let input: SkillImportInput = args.typed("input")?;
    let target_scope: Option<SkillScope> = args.optional("targetScope")?;
    log_command("preview_skill_import");

    ctx.services
        .skill_service
        .preview_import(input, target_scope.unwrap_or_default())
        .await
        .map_err(map_command_error("Failed to preview Agent Skill import"))
}

pub async fn install_skill_import(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<SkillInstallResult, CommandError> {
    let request: SkillInstallRequest = args.typed("request")?;
    log_command("install_skill_import");

    ctx.services
        .skill_service
        .install_import(request)
        .await
        .map_err(map_command_error("Failed to install Agent Skill"))
}

pub async fn read_skill_file(ctx: &Ctx<'_>, args: &Args) -> Result<SkillReadResult, CommandError> {
    let name: String = args.require("name")?;
    let path: String = args.require("path")?;
    let scope: Option<SkillScope> = args.optional("scope")?;
    let start_line: Option<usize> = args.optional("startLine")?;
    let line_count: Option<usize> = args.optional("lineCount")?;
    log_command(format!("read_skill_file {}/{}", name, path));

    ctx.services
        .skill_service
        .read_skill_file(SkillReadRequest {
            scope: scope.unwrap_or_default(),
            name,
            path,
            start_line,
            line_count,
            max_output_chars: DEFAULT_SKILL_READ_FALLBACK_MAX_CHARS,
        })
        .await
        .map_err(map_command_error("Failed to read Agent Skill file"))
}

pub async fn write_skill_file(ctx: &Ctx<'_>, args: &Args) -> Result<SkillReadResult, CommandError> {
    let name: String = args.require("name")?;
    let path: String = args.require("path")?;
    let content: String = args.require("content")?;
    let scope: Option<SkillScope> = args.optional("scope")?;
    let expected_sha256: Option<String> = args.optional("expectedSha256")?;
    log_command(format!("write_skill_file {}/{}", name, path));

    ctx.services
        .skill_service
        .write_skill_file(SkillWriteRequest {
            scope: scope.unwrap_or_default(),
            name,
            path,
            content,
            expected_sha256,
        })
        .await
        .map_err(map_command_error("Failed to write Agent Skill file"))
}

pub async fn export_skill(ctx: &Ctx<'_>, args: &Args) -> Result<SkillExportPayload, CommandError> {
    let name: String = args.require("name")?;
    let scope: Option<SkillScope> = args.optional("scope")?;
    log_command(format!("export_skill {}", name));

    let exported = ctx
        .services
        .skill_service
        .export_skill(scope.unwrap_or_default(), &name)
        .await
        .map_err(map_command_error("Failed to export Agent Skill"))?;

    Ok(SkillExportPayload {
        file_name: exported.file_name,
        content_base64: BASE64_STANDARD.encode(exported.bytes),
        sha256: exported.sha256,
    })
}

pub async fn delete_skill(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let name: String = args.require("name")?;
    let scope: Option<SkillScope> = args.optional("scope")?;
    log_command(format!("delete_skill {}", name));

    ctx.services
        .skill_service
        .delete_skill(scope.unwrap_or_default(), &name)
        .await
        .map_err(map_command_error("Failed to delete Agent Skill"))
}

pub async fn move_skill(ctx: &Ctx<'_>, args: &Args) -> Result<SkillInstallResult, CommandError> {
    let request: SkillMoveRequest = args.typed("request")?;
    log_command(format!("move_skill {}", request.name));

    ctx.services
        .skill_service
        .move_skill(request)
        .await
        .map_err(map_command_error("Failed to move Agent Skill"))
}

pub async fn retarget_skill_scope(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<SkillScopeRetargetResult, CommandError> {
    let request: SkillScopeRetargetRequest = args.typed("request")?;
    log_command(format!(
        "retarget_skill_scope {} -> {}",
        request.from_scope.label(),
        request.to_scope.label()
    ));

    ctx.services
        .skill_service
        .retarget_scope(request)
        .await
        .map_err(map_command_error("Failed to retarget Agent Skill scope"))
}
