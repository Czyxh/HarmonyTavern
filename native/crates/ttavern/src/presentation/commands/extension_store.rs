//! Extension store 命令（上游 `extension_store_commands.rs`，可移植 5 条，P6.1）。
//!
//! 不移植的 5 条（进 `not_ported`）：`open_extension_store_entry`（Tauri
//! `Webview` 资源表字节流）+ `begin/append/finish/abort_extension_store_commit`
//! （分块写入通道，`append` 依赖 `tauri::ipc::Request` 原始体，离开 Tauri 无法落地；
//! 4 条成一组，缺一不可用）。
//!
//! 对应 DevEco 工程路径：native/crates/ttavern/src/presentation/commands/extension_store.rs

use tt_contracts::extension_store::EntryKind;

use crate::host::Ctx;
use crate::presentation::dispatch::Args;
use crate::presentation::errors::CommandError;
use crate::presentation::helpers::{log_command, map_command_error};

pub async fn rename_extension_store_key(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let namespace: String = args.require("namespace")?;
    let key: String = args.require("key")?;
    let new_key: String = args.require("newKey")?;
    let table: Option<String> = args.optional("table")?;
    log_command(format!(
        "rename_extension_store_key {}:{}/{} -> {}",
        namespace,
        table.as_deref().unwrap_or("main"),
        key,
        new_key,
    ));
    ctx.services
        .extension_store_service
        .rename_json_key(&namespace, table.as_deref(), &key, &new_key)
        .await
        .map_err(map_command_error(
            "Failed to rename extension store JSON key",
        ))
}

pub async fn delete_extension_store_entry(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let namespace: String = args.require("namespace")?;
    let key: String = args.require("key")?;
    let table: Option<String> = args.optional("table")?;
    let kind: EntryKind = args.require_typed("kind")?;
    log_command(format!(
        "delete_extension_store_entry {}:{}/{} ({kind:?})",
        namespace,
        table.as_deref().unwrap_or("main"),
        key,
    ));
    ctx.services
        .extension_store_service
        .delete_entry(&namespace, table.as_deref(), &key, kind)
        .await
        .map_err(map_command_error("Failed to delete extension store entry"))
}

pub async fn list_extension_store_keys(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<Vec<String>, CommandError> {
    let namespace: String = args.require("namespace")?;
    let table: Option<String> = args.optional("table")?;
    let kind: EntryKind = args.require_typed("kind")?;
    log_command(format!(
        "list_extension_store_keys {}:{} ({kind:?})",
        namespace,
        table.as_deref().unwrap_or("main"),
    ));
    ctx.services
        .extension_store_service
        .list_keys(&namespace, table.as_deref(), kind)
        .await
        .map_err(map_command_error("Failed to list extension store keys"))
}

pub async fn list_extension_store_tables(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<Vec<String>, CommandError> {
    let namespace: String = args.require("namespace")?;
    log_command(format!("list_extension_store_tables {namespace}"));
    ctx.services
        .extension_store_service
        .list_tables(&namespace)
        .await
        .map_err(map_command_error("Failed to list extension store tables"))
}

pub async fn delete_extension_store_table(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let namespace: String = args.require("namespace")?;
    let table: String = args.require("table")?;
    log_command(format!("delete_extension_store_table {namespace}:{table}"));
    ctx.services
        .extension_store_service
        .delete_table(&namespace, &table)
        .await
        .map_err(map_command_error("Failed to delete extension store table"))
}
