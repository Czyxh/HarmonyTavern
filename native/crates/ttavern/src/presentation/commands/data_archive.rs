//! Data archive 命令（上游 `data_archive_commands.rs`，6 条，P6.1）。
//!
//! 三条 `[split]` 的落地决策（与 P4 的先例一致，2026-10-27）：
//!
//! - `import_data_archive_from_picker`：上游用 WebviewWindow 弹系统选择器。OHOS 的
//!   选择器只能在 ArkTS 侧弹（`DocumentViewPicker`），ArkTS 把选中的文件先拷到
//!   `<cacheDir>/imports/<uuid>.archive`（P4 同款模式），再以绝对路径调本命令。
//!   因此本命令新增必填顶层键 `path`（= 审计表里"仅注入"的窗口参数落地的位置）。
//! - `save_export_data_archive` / `export_user_backup_archive`：上游用系统保存对话框把
//!   归档写出去。OHOS 的保存选择器（`DocumentViewPicker` SAVE 模式）也只能在 ArkTS
//!   侧弹；本命令把产物路径 + 文件名交给 ArkTS（`DeliveryResult` 比上游多
//!   `path`/`fileName` 两个字段），ArkTS 用 `@ohos.file.fs` 读沙箱内归档并写入用户选择
//!   的位置。`finish_export_delivery` 在返回前调用（= Rust 侧视为已交付）。
//!
//! 对应 DevEco 工程路径：native/crates/ttavern/src/presentation/commands/data_archive.rs

use serde::Serialize;

use tt_application::dto::data_archive_dto::DataArchiveJobStatus;

use crate::host::Ctx;
use crate::presentation::dispatch::Args;
use crate::presentation::errors::CommandError;
use crate::presentation::helpers::{log_command, map_command_error};

#[derive(Serialize)]
pub struct ImportArchiveResult {
    cancelled: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    job_id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    file_name: Option<String>,
}

/// OHOS 落地：`delivered` 之外携带产物路径与文件名，供 ArkTS 读沙箱文件后
/// 用保存选择器写出（上游只有 `{delivered}`，因为保存对话框在 Rust 侧）。
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DeliveryResult {
    delivered: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    path: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    file_name: Option<String>,
}

pub async fn import_data_archive_from_picker(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<ImportArchiveResult, CommandError> {
    let path: String = args.require("path")?;
    let file_name: Option<String> = args.optional("fileName")?;
    log_command(format!("import_data_archive_from_picker {path}"));

    // ArkTS 已把用户选择的归档拷进 `<cacheDir>/imports/`，视为临时源：start_import
    // 会把文件移进任务工作区（上游 mobile 分支同语义）。
    let job_id = ctx
        .services
        .data_archive_service
        .start_import(std::path::Path::new(&path), true)
        .map_err(map_command_error("Failed to start data archive import"))?;

    Ok(ImportArchiveResult {
        cancelled: false,
        job_id: Some(job_id),
        file_name,
    })
}

pub async fn start_export_data_archive(ctx: &Ctx<'_>, _args: &Args) -> Result<String, CommandError> {
    log_command("start_export_data_archive");
    ctx.services
        .data_archive_service
        .start_export()
        .map_err(map_command_error("Failed to start data archive export"))
}

pub async fn get_data_archive_job_status(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<DataArchiveJobStatus, CommandError> {
    let job_id: String = args.require("jobId")?;
    ctx.services
        .data_archive_service
        .get_status(&job_id)
        .map_err(map_command_error("Failed to get data archive job status"))
}

pub async fn cancel_data_archive_job(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let job_id: String = args.require("jobId")?;
    ctx.services
        .data_archive_service
        .cancel(&job_id)
        .map_err(map_command_error("Failed to cancel data archive job"))
}

pub async fn save_export_data_archive(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<DeliveryResult, CommandError> {
    let job_id: String = args.require("jobId")?;
    log_command(format!("save_export_data_archive {job_id}"));

    let artifact = ctx
        .services
        .data_archive_service
        .claim_export_artifact(&job_id)
        .map_err(map_command_error("Failed to claim data archive export"))?;
    let delivered = artifact.archive_path.is_file();
    let path = artifact.archive_path.to_string_lossy().to_string();
    let file_name = artifact.file_name;
    ctx.services
        .data_archive_service
        .finish_export_delivery(&job_id)
        .map_err(map_command_error("Failed to finish data archive delivery"))?;

    Ok(DeliveryResult {
        delivered,
        path: Some(path),
        file_name: Some(file_name),
    })
}

pub async fn export_user_backup_archive(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<DeliveryResult, CommandError> {
    let handle: String = args.require("handle")?;
    let include_secrets: bool = args.require_typed("includeSecrets")?;
    log_command(format!(
        "export_user_backup_archive {handle} include_secrets={include_secrets}"
    ));

    let archive = ctx
        .services
        .data_archive_service
        .export_user_backup(handle, include_secrets)
        .await
        .map_err(map_command_error("Failed to export user backup archive"))?;

    Ok(DeliveryResult {
        delivered: std::path::Path::new(&archive.archive_path).is_file(),
        path: Some(archive.archive_path),
        file_name: Some(archive.file_name),
    })
}
