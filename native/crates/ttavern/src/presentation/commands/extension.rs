//! 第三方扩展命令（上游 `extension_commands.rs`，P6.2 可移植 8 条）。
//!
//! iOS 策略过滤跳过：宿主 ios_policy 作用域为 `Ignored`，`ensure_ios_policy_allows`
//! 与 `get_extensions` 的系统白名单过滤都不适用（与 P6.1 各域一致）。
//!
//! 顶层键为 snake 字面量（`url` / `global` / `extension_name` / `branch` / `source` /
//! `destination`），bool 必填参数用 `require_typed::<bool>`。
//!
//! 对应 DevEco 工程路径：native/crates/ttavern/src/presentation/commands/extension.rs

use tt_domain::models::extension::{
    Extension, ExtensionBranch, ExtensionInstallResult, ExtensionUpdateResult, ExtensionVersion,
};

use crate::host::Ctx;
use crate::presentation::dispatch::Args;
use crate::presentation::errors::CommandError;
use crate::presentation::helpers::{log_command, map_command_error};

pub async fn get_extensions(ctx: &Ctx<'_>) -> Result<Vec<Extension>, CommandError> {
    log_command("get_extensions");
    ctx.services
        .extension_service
        .get_extensions()
        .await
        .map_err(map_command_error("Failed to get extensions"))
}

pub async fn install_extension(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<ExtensionInstallResult, CommandError> {
    let url: String = args.require("url")?;
    let global: bool = args.require_typed("global")?;
    let branch: Option<String> = args.optional("branch")?;
    log_command(format!("install_extension {url} global={global}"));
    ctx.services
        .extension_service
        .install_extension(&url, global, branch)
        .await
        .map_err(map_command_error("Failed to install extension"))
}

pub async fn update_extension(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<ExtensionUpdateResult, CommandError> {
    let extension_name: String = args.require("extension_name")?;
    let global: bool = args.require_typed("global")?;
    log_command(format!("update_extension {extension_name} global={global}"));
    ctx.services
        .extension_service
        .update_extension(&extension_name, global)
        .await
        .map_err(map_command_error("Failed to update extension"))
}

pub async fn delete_extension(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let extension_name: String = args.require("extension_name")?;
    let global: bool = args.require_typed("global")?;
    log_command(format!("delete_extension {extension_name} global={global}"));
    ctx.services
        .extension_service
        .delete_extension(&extension_name, global)
        .await
        .map_err(map_command_error("Failed to delete extension"))
}

pub async fn get_extension_version(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<ExtensionVersion, CommandError> {
    let extension_name: String = args.require("extension_name")?;
    let global: bool = args.require_typed("global")?;
    log_command(format!("get_extension_version {extension_name} global={global}"));
    ctx.services
        .extension_service
        .get_extension_version(&extension_name, global)
        .await
        .map_err(map_command_error("Failed to get extension version"))
}

pub async fn get_extension_branches(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<Vec<ExtensionBranch>, CommandError> {
    let extension_name: String = args.require("extension_name")?;
    let global: bool = args.require_typed("global")?;
    log_command(format!("get_extension_branches {extension_name} global={global}"));
    ctx.services
        .extension_service
        .get_extension_branches(&extension_name, global)
        .await
        .map_err(map_command_error("Failed to get extension branches"))
}

pub async fn switch_extension_branch(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<(), CommandError> {
    let extension_name: String = args.require("extension_name")?;
    let branch: String = args.require("branch")?;
    let global: bool = args.require_typed("global")?;
    log_command(format!(
        "switch_extension_branch {extension_name} to {branch} global={global}"
    ));
    ctx.services
        .extension_service
        .switch_extension_branch(&extension_name, &branch, global)
        .await
        .map_err(map_command_error("Failed to switch extension branch"))
}

pub async fn move_extension(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let extension_name: String = args.require("extension_name")?;
    let source: String = args.require("source")?;
    let destination: String = args.require("destination")?;
    log_command(format!(
        "move_extension {extension_name} from {source} to {destination}"
    ));
    ctx.services
        .extension_service
        .move_extension(&extension_name, &source, &destination)
        .await
        .map_err(map_command_error("Failed to move extension"))
}
