//! Vector 命令（上游 `vector_commands.rs`，1 条，P6.1）。
//!
//! 对应 DevEco 工程路径：native/crates/ttavern/src/presentation/commands/vector.rs

use tt_application::dto::vector_dto::{VectorRouteRequestDto, VectorRouteResponseDto};

use crate::host::Ctx;
use crate::presentation::dispatch::Args;
use crate::presentation::errors::CommandError;
use crate::presentation::helpers::{log_command, map_command_error};

pub async fn vector_handle(ctx: &Ctx<'_>, args: &Args) -> Result<VectorRouteResponseDto, CommandError> {
    let path: String = args.require("path")?;
    let request: VectorRouteRequestDto = args.typed("request")?;
    log_command(format!("vector_handle {}", path.trim()));
    ctx.services
        .vector_service
        .handle_request(&path, request)
        .await
        .map_err(map_command_error("Vector request failed"))
}
