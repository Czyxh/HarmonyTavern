//! Provider metadata 命令（上游 `provider_metadata_commands.rs`，7 条，P6.1）。
//!
//! 对应 DevEco 工程路径：native/crates/ttavern/src/presentation/commands/provider_metadata.rs

use serde_json::Value;

use tt_application::dto::provider_metadata_dto::{
    ProviderModelProvidersRequestDto, SiliconFlowEmbeddingModelsRequestDto, WorkersAiModelsRequestDto,
};
use tt_ports::repositories::provider_metadata_repository::{
    NanoGptCredits, NanoGptModelProviders, OpenRouterCredits,
};

use crate::host::Ctx;
use crate::presentation::dispatch::Args;
use crate::presentation::errors::CommandError;
use crate::presentation::helpers::{log_command, map_command_error};

pub async fn get_openrouter_model_providers(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<Vec<String>, CommandError> {
    let dto: ProviderModelProvidersRequestDto = args.typed("dto")?;
    log_command(format!("get_openrouter_model_providers {}", dto.model));

    ctx.services
        .provider_metadata_service
        .openrouter_model_providers(dto)
        .await
        .map_err(map_command_error("Failed to get OpenRouter model providers"))
}

pub async fn get_openrouter_credits(
    ctx: &Ctx<'_>,
    _args: &Args,
) -> Result<OpenRouterCredits, CommandError> {
    log_command("get_openrouter_credits");

    ctx.services
        .provider_metadata_service
        .openrouter_credits()
        .await
        .map_err(map_command_error("Failed to get OpenRouter credits"))
}

pub async fn get_nanogpt_model_providers(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<NanoGptModelProviders, CommandError> {
    let dto: ProviderModelProvidersRequestDto = args.typed("dto")?;
    log_command(format!("get_nanogpt_model_providers {}", dto.model));

    ctx.services
        .provider_metadata_service
        .nanogpt_model_providers(dto)
        .await
        .map_err(map_command_error("Failed to get NanoGPT model providers"))
}

pub async fn get_nanogpt_credits(
    ctx: &Ctx<'_>,
    _args: &Args,
) -> Result<NanoGptCredits, CommandError> {
    log_command("get_nanogpt_credits");

    ctx.services
        .provider_metadata_service
        .nanogpt_credits()
        .await
        .map_err(map_command_error("Failed to get NanoGPT credits"))
}

pub async fn get_siliconflow_embedding_models(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<Vec<Value>, CommandError> {
    let dto: SiliconFlowEmbeddingModelsRequestDto = args.typed("dto")?;
    log_command("get_siliconflow_embedding_models");

    ctx.services
        .provider_metadata_service
        .siliconflow_embedding_models(dto)
        .await
        .map_err(map_command_error("Failed to get SiliconFlow embedding models"))
}

pub async fn get_workers_ai_embedding_models(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<Vec<Value>, CommandError> {
    let dto: WorkersAiModelsRequestDto = args.typed("dto")?;
    log_command("get_workers_ai_embedding_models");

    ctx.services
        .provider_metadata_service
        .workers_ai_embedding_models(dto)
        .await
        .map_err(map_command_error(
            "Failed to get Cloudflare Workers AI embedding models",
        ))
}

pub async fn get_workers_ai_multimodal_models(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<Vec<String>, CommandError> {
    let dto: WorkersAiModelsRequestDto = args.typed("dto")?;
    log_command("get_workers_ai_multimodal_models");

    ctx.services
        .provider_metadata_service
        .workers_ai_multimodal_models(dto)
        .await
        .map_err(map_command_error(
            "Failed to get Cloudflare Workers AI multimodal models",
        ))
}
