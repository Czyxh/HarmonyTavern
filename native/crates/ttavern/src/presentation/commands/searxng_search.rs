//! SearXNG 搜索命令（上游 `searxng_search_commands.rs`，1 条，P6.1）。
//!
//! 与 P5 相同的原因做三步握手：上游在命令内部弹 Tauri 原生对话框
//! （`ensure_user_endpoint_access(base_url, locale, app_handle, …)`），NAPI 调用期间
//! 无法在 Rust 侧弹 ArkUI 对话框，所以返回 `unauthorized` + `endpoint_authorization_required|`
//! 前缀，ArkTS 弹窗、调用 `grant_user_endpoint_access` 后重试（同 chat_completion.rs）。
//!
//! 对应 DevEco 工程路径：native/crates/ttavern/src/presentation/commands/searxng_search.rs

use tt_application::dto::searxng_search_dto::SearxngSearchRequestDto;

use crate::host::Ctx;
use crate::presentation::commands::chat_completion::ensure_user_endpoint_access;
use crate::presentation::dispatch::Args;
use crate::presentation::errors::CommandError;
use crate::presentation::helpers::{log_command, map_command_error};

pub async fn search_searxng(ctx: &Ctx<'_>, args: &Args) -> Result<String, CommandError> {
    let dto: SearxngSearchRequestDto = args.typed("dto")?;
    let _locale: String = args.require("locale")?;
    log_command("search_searxng");

    let request = ctx
        .services
        .searxng_search_service
        .prepare_request(dto)
        .map_err(map_command_error("SearXNG search request is invalid"))?;
    ensure_user_endpoint_access(ctx, Some(request.base_url.to_string())).await?;

    ctx.services
        .searxng_search_service
        .search(request)
        .await
        .map_err(map_command_error("SearXNG search failed"))
}
