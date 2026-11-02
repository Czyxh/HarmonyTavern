//! API key / secret commands（上游 `secret_commands.rs`，8 条）。
//!
//! 存储事实（不要误解）：`SecretRepository` 的唯一实现是 `FileSecretRepository`，
//! 落盘在 `<default-user>/secrets.json`。**上游本身就不是系统密钥库**（不是
//! Android Keystore / iOS Keychain / HarmonyOS Asset Store），P5 忠实沿用，
//! 因此不需要额外的鸿蒙密钥组件，也不能对外宣称「加密存储」。
//!
//! 对应 DevEco 工程路径：native/crates/ttavern/src/presentation/commands/secret.rs

use tt_application::dto::secret_dto::{
    AllSecretsDto, DeleteSecretDto, FindSecretDto, FindSecretResponseDto, RenameSecretDto,
    RotateSecretDto, SecretSettingsDto, SecretStateDto, WriteSecretDto,
};

use crate::host::Ctx;
use crate::presentation::dispatch::Args;
use crate::presentation::errors::CommandError;
use crate::presentation::helpers::{log_command, map_command_error};

pub async fn write_secret(ctx: &Ctx<'_>, args: &Args) -> Result<String, CommandError> {
    let dto: WriteSecretDto = args.typed("dto")?;
    log_command(format!("write_secret {}", dto.key));

    ctx.services
        .secret_service
        .write_secret(&dto.key, &dto.value, dto.label.as_deref())
        .await
        .map_err(map_command_error(format!(
            "Failed to write secret {}",
            dto.key
        )))
}

pub async fn read_secret_state(ctx: &Ctx<'_>) -> Result<SecretStateDto, CommandError> {
    log_command("read_secret_state");

    ctx.services
        .secret_service
        .read_secret_state()
        .await
        .map_err(map_command_error("Failed to read secret state"))
}

pub async fn read_secret_settings(ctx: &Ctx<'_>) -> Result<SecretSettingsDto, CommandError> {
    log_command("read_secret_settings");

    Ok(ctx.services.secret_service.read_settings())
}

pub async fn view_secrets(ctx: &Ctx<'_>) -> Result<AllSecretsDto, CommandError> {
    log_command("view_secrets");

    ctx.services
        .secret_service
        .view_secrets()
        .await
        .map_err(map_command_error("Failed to view secrets"))
}

pub async fn find_secret(ctx: &Ctx<'_>, args: &Args) -> Result<FindSecretResponseDto, CommandError> {
    let dto: FindSecretDto = args.typed("dto")?;
    log_command(format!("find_secret {}", dto.key));

    ctx.services
        .secret_service
        .find_secret(&dto.key, dto.id.as_deref())
        .await
        .map_err(map_command_error(format!("Failed to find secret {}", dto.key)))
}

pub async fn delete_secret(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let dto: DeleteSecretDto = args.typed("dto")?;
    log_command(format!("delete_secret {}", dto.key));

    ctx.services
        .secret_service
        .delete_secret(&dto.key, dto.id.as_deref())
        .await
        .map_err(map_command_error(format!(
            "Failed to delete secret {}",
            dto.key
        )))
}

pub async fn rotate_secret(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let dto: RotateSecretDto = args.typed("dto")?;
    log_command(format!("rotate_secret {}", dto.key));

    ctx.services
        .secret_service
        .rotate_secret(&dto.key, &dto.id)
        .await
        .map_err(map_command_error(format!(
            "Failed to rotate secret {}",
            dto.key
        )))
}

pub async fn rename_secret(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let dto: RenameSecretDto = args.typed("dto")?;
    log_command(format!("rename_secret {}", dto.key));

    ctx.services
        .secret_service
        .rename_secret(&dto.key, &dto.id, &dto.label)
        .await
        .map_err(map_command_error(format!(
            "Failed to rename secret {}",
            dto.key
        )))
}
