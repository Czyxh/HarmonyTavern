//! Tokenization commands (P3 batch) — pure computation, no platform coupling.
//!
//! Every command takes `{ dto }` whose `model` field is normalised by the service
//! (`normalize_model`), so ArkTS may pass `"gpt-4o"`, `"claude"`, etc.

use tt_application::dto::tokenization_dto::{
    DecodeTokensRequestDto, DecodeTokensResponseDto, EncodeTokensRequestDto,
    EncodeTokensResponseDto, OpenAiLogitBiasRequestDto, OpenAiLogitBiasResponseDto,
    OpenAiTokenCountBatchRequestDto, OpenAiTokenCountBatchResponseDto,
    OpenAiTokenPrefixCountRequestDto,
};

use crate::host::Ctx;
use crate::presentation::dispatch::Args;
use crate::presentation::errors::CommandError;
use crate::presentation::helpers::{log_command, map_command_error};

pub async fn count_openai_tokens_batch(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<OpenAiTokenCountBatchResponseDto, CommandError> {
    let dto: OpenAiTokenCountBatchRequestDto = args.typed("dto")?;
    log_command(format!(
        "count_openai_tokens_batch model={} n={}",
        dto.model,
        dto.requests.len()
    ));

    ctx.services
        .tokenization_service
        .count_openai_tokens_batch(dto)
        .await
        .map_err(map_command_error("Failed to count tokens"))
}

pub async fn count_openai_token_prefixes(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<OpenAiTokenCountBatchResponseDto, CommandError> {
    let dto: OpenAiTokenPrefixCountRequestDto = args.typed("dto")?;
    log_command(format!(
        "count_openai_token_prefixes model={}",
        dto.model
    ));

    ctx.services
        .tokenization_service
        .count_openai_token_prefixes(dto)
        .await
        .map_err(map_command_error("Failed to count token prefixes"))
}

pub async fn encode_tokens(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<EncodeTokensResponseDto, CommandError> {
    let dto: EncodeTokensRequestDto = args.typed("dto")?;
    log_command(format!("encode_tokens model={}", dto.model));

    ctx.services
        .tokenization_service
        .encode_tokens(dto)
        .await
        .map_err(map_command_error("Failed to encode tokens"))
}

pub async fn decode_tokens(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<DecodeTokensResponseDto, CommandError> {
    let dto: DecodeTokensRequestDto = args.typed("dto")?;
    log_command(format!("decode_tokens model={}", dto.model));

    ctx.services
        .tokenization_service
        .decode_tokens(dto)
        .await
        .map_err(map_command_error("Failed to decode tokens"))
}

pub async fn build_openai_logit_bias(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<OpenAiLogitBiasResponseDto, CommandError> {
    let dto: OpenAiLogitBiasRequestDto = args.typed("dto")?;
    log_command(format!("build_openai_logit_bias model={}", dto.model));

    ctx.services
        .tokenization_service
        .build_openai_logit_bias(dto)
        .await
        .map_err(map_command_error("Failed to build logit bias"))
}
