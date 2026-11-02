//! User image commands (P4) — port of upstream `presentation/commands/image_commands.rs`.
//!
//! Everything goes through `UserMediaService` (`tt-application`), backed by
//! `FilesystemUserMediaStore::from_data_root(<data_root>)`, i.e. files land in
//! `<data_root>/default-user/user/images/...`. `image_base64` in the payload matches the
//! upstream wire shape (Tauri also carried base64 in JSON here).
//!
//! Note for the ArkTS side: the returned `path` is a SillyTavern-style URL (`/user/images/…`),
//! not a filesystem path. Combine it with the backend `dataRoot` from `getBackendStatus`
//! (`<dataRoot>/default-user` + path) to render with `Image('file://' + absolute)`.

use tt_application::services::user_media_service::{
    ListUserImagesInput, UploadUserImageInput, UserImageUploadResult,
};

use crate::host::Ctx;
use crate::presentation::dispatch::Args;
use crate::presentation::errors::CommandError;
use crate::presentation::helpers::{log_command, map_command_error};

pub async fn upload_user_image(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<UserImageUploadResult, CommandError> {
    let image_base64: String = args.require("imageBase64")?;
    let format: String = args.require("format")?;
    let filename: Option<String> = args.optional("filename")?;
    let ch_name: Option<String> = args.optional("chName")?;
    log_command("upload_user_image");

    ctx.services
        .user_media_service
        .upload_user_image(UploadUserImageInput {
            image_base64,
            format,
            filename,
            ch_name,
        })
        .await
        .map_err(map_command_error("Failed to upload user image"))
}

pub async fn list_user_images(ctx: &Ctx<'_>, args: &Args) -> Result<Vec<String>, CommandError> {
    let folder: String = args.require("folder")?;
    let sort_field: Option<String> = args.optional("sortField")?;
    let sort_order: Option<String> = args.optional("sortOrder")?;
    let media_type: Option<u32> = args.optional("mediaType")?;
    log_command("list_user_images");

    ctx.services
        .user_media_service
        .list_user_images(ListUserImagesInput {
            folder,
            sort_field,
            sort_order,
            media_type,
        })
        .await
        .map_err(map_command_error("Failed to list user images"))
}

pub async fn list_user_image_folders(ctx: &Ctx<'_>) -> Result<Vec<String>, CommandError> {
    log_command("list_user_image_folders");

    ctx.services
        .user_media_service
        .list_user_image_folders()
        .await
        .map_err(map_command_error("Failed to list user image folders"))
}

pub async fn delete_user_image(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let path: String = args.require("path")?;
    log_command("delete_user_image");

    ctx.services
        .user_media_service
        .delete_user_image(&path)
        .await
        .map_err(map_command_error("Failed to delete user image"))
}
