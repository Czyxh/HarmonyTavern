//! 数据集目录命令（上游 `sync_commands.rs`，P6.2 可移植 1 条）。
//!
//! 该命令返回裸 DTO（无 Result 包装，与上游一致）。宿主重建 DTO：
//! `SyncDatasetCatalogDto`（p62-contract.md）。
//!
//! 对应 DevEco 工程路径：native/crates/ttavern/src/presentation/commands/sync.rs

use serde::Serialize;
use ttsync_contract::dataset::DATASET_POLICY_VERSION;
use ttsync_core::dataset::{
    supported_dataset_ids, supported_profile_ids, tauri_tavern_default_selection,
};

use crate::host::Ctx;
use crate::presentation::helpers::log_command;

#[derive(Debug, Clone, Serialize)]
pub struct SyncDatasetCatalogDto {
    pub policy_version: u32,
    pub supported_dataset_ids: Vec<String>,
    pub supported_profile_ids: Vec<String>,
    pub default_dataset_ids: Vec<String>,
}

pub async fn sync_get_dataset_catalog(ctx: &Ctx<'_>) -> SyncDatasetCatalogDto {
    let _ = ctx;
    log_command("sync_get_dataset_catalog");
    SyncDatasetCatalogDto {
        policy_version: DATASET_POLICY_VERSION,
        supported_dataset_ids: supported_dataset_ids(),
        supported_profile_ids: supported_profile_ids(),
        default_dataset_ids: tauri_tavern_default_selection().dataset_ids,
    }
}
