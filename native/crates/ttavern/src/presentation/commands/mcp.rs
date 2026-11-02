//! MCP 命令（上游 `mcp_commands.rs`，16 条，P6.1）。
//!
//! 对应 DevEco 工程路径：native/crates/ttavern/src/presentation/commands/mcp.rs

use tt_application::dto::mcp_dto::{
    CallLegacyMcpToolDto, CreateMcpServerDto, ListLegacyMcpToolsResultDto, ListMcpServersResultDto,
    McpCallOutcomeDto, McpDiscoveryResultDto, McpExecutionCallIdDto, McpRegistrationIdDto,
    McpServerDto, McpTestCallIdDto, SetMcpServerStateDto, SetMcpToolDescriptionOverrideDto,
    SetMcpToolPermissionDto, TestMcpToolCallDto, UpdateMcpServerDto,
};

use crate::host::Ctx;
use crate::presentation::dispatch::Args;
use crate::presentation::errors::CommandError;
use crate::presentation::helpers::{log_command, map_command_error};

pub async fn list_mcp_servers(ctx: &Ctx<'_>, _args: &Args) -> Result<ListMcpServersResultDto, CommandError> {
    log_command("list_mcp_servers");
    ctx.services
        .mcp_service
        .list_servers()
        .await
        .map_err(map_command_error("Failed to list MCP servers"))
}

pub async fn create_mcp_server(ctx: &Ctx<'_>, args: &Args) -> Result<McpServerDto, CommandError> {
    let dto: CreateMcpServerDto = args.typed("dto")?;
    log_command("create_mcp_server");
    ctx.services
        .mcp_service
        .create_server(dto.display_name, dto.endpoint, dto.headers, dto.protocol_version)
        .await
        .map_err(map_command_error("Failed to create MCP server"))
}

pub async fn update_mcp_server(ctx: &Ctx<'_>, args: &Args) -> Result<McpServerDto, CommandError> {
    let dto: UpdateMcpServerDto = args.typed("dto")?;
    log_command("update_mcp_server");
    ctx.services
        .mcp_service
        .update_server(
            &dto.registration_id,
            dto.display_name,
            dto.endpoint,
            dto.headers,
            dto.protocol_version,
        )
        .await
        .map_err(map_command_error("Failed to update MCP server"))
}

pub async fn set_mcp_server_state(ctx: &Ctx<'_>, args: &Args) -> Result<McpServerDto, CommandError> {
    let dto: SetMcpServerStateDto = args.typed("dto")?;
    log_command("set_mcp_server_state");
    ctx.services
        .mcp_service
        .set_server_state(&dto.registration_id, dto.state)
        .await
        .map_err(map_command_error("Failed to update MCP server state"))
}

pub async fn remove_mcp_server(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let dto: McpRegistrationIdDto = args.typed("dto")?;
    log_command("remove_mcp_server");
    ctx.services
        .mcp_service
        .remove_server(&dto.registration_id)
        .await
        .map_err(map_command_error("Failed to remove MCP server"))
}

pub async fn discover_mcp_tools(ctx: &Ctx<'_>, args: &Args) -> Result<McpDiscoveryResultDto, CommandError> {
    let dto: McpRegistrationIdDto = args.typed("dto")?;
    log_command("discover_mcp_tools");
    ctx.services
        .mcp_service
        .discover_tools(&dto.registration_id)
        .await
        .map_err(map_command_error("Failed to discover MCP tools"))
}

pub async fn refresh_mcp_tools(ctx: &Ctx<'_>, args: &Args) -> Result<McpDiscoveryResultDto, CommandError> {
    let dto: McpRegistrationIdDto = args.typed("dto")?;
    log_command("refresh_mcp_tools");
    ctx.services
        .mcp_service
        .refresh_tools(&dto.registration_id)
        .await
        .map_err(map_command_error("Failed to refresh MCP tools"))
}

pub async fn set_mcp_tool_permission(ctx: &Ctx<'_>, args: &Args) -> Result<McpServerDto, CommandError> {
    let dto: SetMcpToolPermissionDto = args.typed("dto")?;
    log_command("set_mcp_tool_permission");
    ctx.services
        .mcp_service
        .set_tool_permission(&dto.registration_id, dto.native_name, dto.permission)
        .await
        .map_err(map_command_error("Failed to update MCP tool permission"))
}

pub async fn set_mcp_tool_description_override(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<McpServerDto, CommandError> {
    let dto: SetMcpToolDescriptionOverrideDto = args.typed("dto")?;
    log_command("set_mcp_tool_description_override");
    ctx.services
        .mcp_service
        .set_tool_description_override(&dto.registration_id, dto.native_name, dto.override_)
        .await
        .map_err(map_command_error(
            "Failed to update MCP tool description override",
        ))
}

pub async fn start_mcp_test_call(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let dto: McpTestCallIdDto = args.typed("dto")?;
    log_command("start_mcp_test_call");
    ctx.services
        .mcp_service
        .start_call(&dto.call_id)
        .await
        .map_err(map_command_error("Failed to prepare MCP test call"))
}

pub async fn test_mcp_tool_call(ctx: &Ctx<'_>, args: &Args) -> Result<McpCallOutcomeDto, CommandError> {
    let dto: TestMcpToolCallDto = args.typed("dto")?;
    log_command("test_mcp_tool_call");
    ctx.services
        .mcp_service
        .test_call(&dto.call_id, &dto.registration_id, dto.native_name, dto.arguments_json)
        .await
        .map_err(map_command_error("Failed to test MCP tool call"))
}

pub async fn cancel_mcp_test_call(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let dto: McpTestCallIdDto = args.typed("dto")?;
    log_command("cancel_mcp_test_call");
    ctx.services
        .mcp_service
        .cancel_call(&dto.call_id)
        .await
        .map_err(map_command_error("Failed to cancel MCP test call"))
}

pub async fn list_legacy_mcp_tools(
    ctx: &Ctx<'_>,
    _args: &Args,
) -> Result<ListLegacyMcpToolsResultDto, CommandError> {
    log_command("list_legacy_mcp_tools");
    ctx.services
        .mcp_service
        .list_legacy_tools_cached()
        .await
        .map_err(map_command_error("Failed to list Legacy MCP tools"))
}

pub async fn start_legacy_mcp_tool_call(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let dto: McpExecutionCallIdDto = args.typed("dto")?;
    log_command("start_legacy_mcp_tool_call");
    ctx.services
        .mcp_service
        .start_call(&dto.execution_call_id)
        .await
        .map_err(map_command_error("Failed to prepare Legacy MCP tool call"))
}

pub async fn call_legacy_mcp_tool(ctx: &Ctx<'_>, args: &Args) -> Result<McpCallOutcomeDto, CommandError> {
    let dto: CallLegacyMcpToolDto = args.typed("dto")?;
    log_command("call_legacy_mcp_tool");
    ctx.services
        .mcp_service
        .call_legacy_tool(&dto.execution_call_id, &dto.tool_id, dto.arguments_json)
        .await
        .map_err(map_command_error("Failed to call Legacy MCP tool"))
}

pub async fn cancel_legacy_mcp_tool_call(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let dto: McpExecutionCallIdDto = args.typed("dto")?;
    log_command("cancel_legacy_mcp_tool_call");
    ctx.services
        .mcp_service
        .cancel_call(&dto.execution_call_id)
        .await
        .map_err(map_command_error("Failed to cancel Legacy MCP tool call"))
}
