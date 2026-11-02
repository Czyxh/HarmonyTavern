//! User + user-directory commands.
//!
//! Upstream file split (`user_commands.rs` / `user_directory_commands.rs`) is merged here
//! because both are the same repository story and neither needs its own dependencies.

use tt_application::dto::user_dto::{CreateUserDto, UpdateUserDto, UserDto};
use tt_application::dto::user_directory_dto::UserDirectoryDto;

use crate::host::Ctx;
use crate::presentation::dispatch::Args;
use crate::presentation::errors::CommandError;
use crate::presentation::helpers::{log_command, map_command_error};

pub async fn get_all_users(ctx: &Ctx<'_>) -> Result<Vec<UserDto>, CommandError> {
    log_command("get_all_users");

    ctx.services
        .user_service
        .get_all_users()
        .await
        .map_err(map_command_error("Failed to get all users"))
}

pub async fn get_user(ctx: &Ctx<'_>, args: &Args) -> Result<UserDto, CommandError> {
    let id: String = args.require("id")?;
    log_command(format!("get_user {}", id));

    ctx.services
        .user_service
        .get_user(&id)
        .await
        .map_err(map_command_error(format!("Failed to get user {}", id)))
}

pub async fn get_user_by_username(ctx: &Ctx<'_>, args: &Args) -> Result<UserDto, CommandError> {
    let username: String = args.require("username")?;
    log_command(format!("get_user_by_username {}", username));

    ctx.services
        .user_service
        .get_user_by_username(&username)
        .await
        .map_err(map_command_error(format!(
            "Failed to get user by username {}",
            username
        )))
}

pub async fn create_user(ctx: &Ctx<'_>, args: &Args) -> Result<UserDto, CommandError> {
    let dto: CreateUserDto = args.typed("dto")?;
    log_command(format!("create_user {}", dto.username));

    ctx.services
        .user_service
        .create_user(dto)
        .await
        .map_err(map_command_error("Failed to create user"))
}

pub async fn update_user(ctx: &Ctx<'_>, args: &Args) -> Result<UserDto, CommandError> {
    let dto: UpdateUserDto = args.typed("dto")?;
    log_command(format!("update_user {}", dto.id));

    ctx.services
        .user_service
        .update_user(dto)
        .await
        .map_err(map_command_error("Failed to update user"))
}

pub async fn delete_user(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let id: String = args.require("id")?;
    log_command(format!("delete_user {}", id));

    ctx.services
        .user_service
        .delete_user(&id)
        .await
        .map_err(map_command_error(format!("Failed to delete user {}", id)))
}

pub async fn get_user_directory(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<UserDirectoryDto, CommandError> {
    let handle: String = args.require("handle")?;
    log_command(format!("get_user_directory {}", handle));

    ctx.services
        .user_directory_service
        .get_user_directory(&handle)
        .await
        .map_err(map_command_error(format!(
            "Failed to get user directory for {}",
            handle
        )))
}

pub async fn ensure_user_directories_exist(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<(), CommandError> {
    let handle: String = args.require("handle")?;
    log_command(format!("ensure_user_directories_exist {}", handle));

    ctx.services
        .user_directory_service
        .ensure_user_directories_exist(&handle)
        .await
        .map_err(map_command_error(format!(
            "Failed to ensure user directories for {}",
            handle
        )))
}

pub async fn ensure_default_user_directories_exist(ctx: &Ctx<'_>) -> Result<(), CommandError> {
    log_command("ensure_default_user_directories_exist");

    ctx.services
        .user_directory_service
        .ensure_default_user_directories_exist()
        .await
        .map_err(map_command_error(
            "Failed to ensure default user directories",
        ))
}
