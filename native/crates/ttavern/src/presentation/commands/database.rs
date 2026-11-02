//! Database 命令（上游 `database_commands.rs`，1 条，P6.1）。
//!
//! 对应 DevEco 工程路径：native/crates/ttavern/src/presentation/commands/database.rs

use tt_contracts::database::{DatabaseRequest, DatabaseResponse};

use crate::host::Ctx;
use crate::presentation::dispatch::Args;
use crate::presentation::errors::CommandError;
use crate::presentation::helpers::map_command_error;

pub async fn database_handle(ctx: &Ctx<'_>, args: &Args) -> Result<DatabaseResponse, CommandError> {
    let request: DatabaseRequest = args.typed("request")?;
    ctx.services
        .database_service
        .execute(request)
        .await
        .map_err(map_command_error("Database request failed"))
}
