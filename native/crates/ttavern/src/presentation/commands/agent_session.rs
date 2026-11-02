//! Agent Session 命令（上游 `agent_session_commands.rs`，P6.2 可移植 9 条）。
//!
//! 顶层键为 camelCase 单一 `dto`（agent 域铁律）；零参命令只收 `ctx`。
//!
//! 对应 DevEco 工程路径：native/crates/ttavern/src/presentation/commands/agent_session.rs

use tt_application::dto::agent_dto::{
    AgentDeleteSessionDto, AgentListSessionsResultDto, AgentPrepareSessionRunDto,
    AgentPrepareSessionRunResultDto, AgentReadSessionDto, AgentReadSessionResultDto,
    AgentRenameSessionDto, AgentSaveProfileDto, AgentSessionProfileResultDto,
    AgentSessionResultDto, AgentSessionRunHandleDto, AgentStartSessionRunDto,
};

use crate::host::Ctx;
use crate::presentation::dispatch::Args;
use crate::presentation::errors::CommandError;
use crate::presentation::helpers::{log_command, map_command_error};

pub async fn load_agent_session_profile(
    ctx: &Ctx<'_>,
) -> Result<AgentSessionProfileResultDto, CommandError> {
    log_command("load_agent_session_profile");
    ctx.services
        .agent_runtime_service
        .load_session_profile()
        .await
        .map_err(map_command_error("Failed to load Session profile"))
}

pub async fn save_agent_session_profile(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let dto: AgentSaveProfileDto = args.typed("dto")?;
    log_command("save_agent_session_profile");
    ctx.services
        .agent_runtime_service
        .save_session_profile(dto)
        .await
        .map_err(map_command_error("Failed to save Session profile"))
}

pub async fn create_agent_session(ctx: &Ctx<'_>) -> Result<AgentSessionResultDto, CommandError> {
    log_command("create_agent_session");
    ctx.services
        .agent_runtime_service
        .create_session()
        .await
        .map_err(map_command_error("Failed to create Agent Session"))
}

pub async fn list_agent_sessions(
    ctx: &Ctx<'_>,
) -> Result<AgentListSessionsResultDto, CommandError> {
    log_command("list_agent_sessions");
    ctx.services
        .agent_runtime_service
        .list_sessions()
        .await
        .map_err(map_command_error("Failed to list Agent Sessions"))
}

pub async fn rename_agent_session(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<AgentSessionResultDto, CommandError> {
    let dto: AgentRenameSessionDto = args.typed("dto")?;
    log_command("rename_agent_session");
    ctx.services
        .agent_runtime_service
        .rename_session(dto)
        .await
        .map_err(map_command_error("Failed to rename Agent Session"))
}

pub async fn delete_agent_session(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let dto: AgentDeleteSessionDto = args.typed("dto")?;
    log_command("delete_agent_session");
    ctx.services
        .agent_runtime_service
        .delete_session(dto)
        .await
        .map_err(map_command_error("Failed to delete Agent Session"))
}

pub async fn read_agent_session(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<AgentReadSessionResultDto, CommandError> {
    let dto: AgentReadSessionDto = args.typed("dto")?;
    log_command("read_agent_session");
    ctx.services
        .agent_runtime_service
        .read_session(dto)
        .await
        .map_err(map_command_error("Failed to read Agent Session"))
}

pub async fn prepare_agent_session_run(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<AgentPrepareSessionRunResultDto, CommandError> {
    let dto: AgentPrepareSessionRunDto = args.typed("dto")?;
    log_command("prepare_agent_session_run");
    ctx.services
        .agent_runtime_service
        .prepare_session_run(dto)
        .await
        .map_err(map_command_error("Failed to prepare Agent Session run"))
}

pub async fn start_agent_session_run(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<AgentSessionRunHandleDto, CommandError> {
    let dto: AgentStartSessionRunDto = args.typed("dto")?;
    log_command("start_agent_session_run");
    ctx.services
        .agent_runtime_service
        .start_session_run(dto)
        .await
        .map_err(map_command_error("Failed to start Agent Session run"))
}
