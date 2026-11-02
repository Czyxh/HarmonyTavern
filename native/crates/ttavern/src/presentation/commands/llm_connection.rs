//! LLM connection 命令（上游 `llm_connection_commands.rs`，4 条，P6.1）。
//!
//! 对应 DevEco 工程路径：native/crates/ttavern/src/presentation/commands/llm_connection.rs

use tt_application::dto::llm_connection_dto::{
    ListLlmConnectionsResultDto, LlmConnectionIdDto, LoadLlmConnectionResultDto,
    SaveLlmConnectionDto,
};

use crate::host::Ctx;
use crate::presentation::dispatch::Args;
use crate::presentation::errors::CommandError;
use crate::presentation::helpers::{log_command, map_command_error};

pub async fn list_llm_connections(
    ctx: &Ctx<'_>,
    _args: &Args,
) -> Result<ListLlmConnectionsResultDto, CommandError> {
    log_command("list_llm_connections");

    ctx.services
        .llm_connection_service
        .list_connections()
        .await
        .map(|connections| ListLlmConnectionsResultDto { connections })
        .map_err(map_command_error("Failed to list LLM connections"))
}

pub async fn load_llm_connection(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<LoadLlmConnectionResultDto, CommandError> {
    let dto: LlmConnectionIdDto = args.typed("dto")?;
    log_command("load_llm_connection");

    ctx.services
        .llm_connection_service
        .load_connection(&dto.connection_id)
        .await
        .map(|connection| LoadLlmConnectionResultDto { connection })
        .map_err(map_command_error("Failed to load LLM connection"))
}

pub async fn save_llm_connection(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let dto: SaveLlmConnectionDto = args.typed("dto")?;
    log_command("save_llm_connection");

    ctx.services
        .llm_connection_service
        .save_connection(dto.connection)
        .await
        .map_err(map_command_error("Failed to save LLM connection"))
}

pub async fn delete_llm_connection(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let dto: LlmConnectionIdDto = args.typed("dto")?;
    log_command("delete_llm_connection");

    ctx.services
        .llm_connection_service
        .delete_connection(&dto.connection_id)
        .await
        .map_err(map_command_error("Failed to delete LLM connection"))
}
