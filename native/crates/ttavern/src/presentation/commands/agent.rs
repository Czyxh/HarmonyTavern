//! Agent 命令（上游 `agent_commands.rs`，P6.2 可移植 34 条）。
//!
//! 两条 Tauri 专有的替换：
//! - `subscribe_agent_run_live_projection`：`ipc::Channel<AgentRunLiveUpdateDto>` 换成宿主
//!   事件总线（`host::events::emit("agent:run-live-update", …)`），循环跑在进程级后台
//!   runtime 上（`host::background_runtime`），presenter 逻辑与上游逐字一致。
//! - `read_agent_workspace_bytes`：`tauri::ipc::Response` 原始字节换成 base64 字符串返回
//!   （OHOS 无原始响应通道；ArkTS 侧解码还原 ArrayBuffer）。已写入 p62-contract.md。
//!
//! 顶层键为 camelCase 单一 `dto`（agent 域铁律）；零参命令只收 `ctx`。
//!
//! 对应 DevEco 工程路径：native/crates/ttavern/src/presentation/commands/agent.rs

use std::collections::BTreeSet;

use base64::Engine;
use serde_json::Value;

use tt_application::dto::agent_dto::{
    AgentActiveRunDto, AgentApplyCurrentModelConnectionSnapshotDto,
    AgentApplyCurrentModelConnectionSnapshotResultDto, AgentApplyRunPruneDto,
    AgentBuildCurrentModelConnectionSnapshotDto, AgentBuildCurrentModelConnectionSnapshotResultDto,
    AgentCancelRunDto, AgentCancelRunResultDto, AgentCopyChatPersistentStatesDto,
    AgentFinishRunPresentationDto, AgentListProfilesResultDto, AgentListRunsDto,
    AgentListRunsResultDto, AgentListToolsDto, AgentListToolsResultDto, AgentLoadProfileResultDto,
    AgentModelTurnDisplayDto, AgentPlanRunPruneDto, AgentPreparePromptAssemblyDto,
    AgentPreparePromptAssemblyResultDto, AgentProfileIdDto, AgentPromptAssemblyBrokerRequestDto,
    AgentPruneChatPersistentStatesDto, AgentPruneChatPersistentStatesResultDto, AgentReadEventsDto,
    AgentReadEventsResultDto, AgentReadModelTurnDto, AgentReadPromptAssemblyRequestDto,
    AgentReadRunCheckpointDto, AgentReadRunCheckpointResultDto, AgentReadTaskDetailDto,
    AgentReadWorkspaceFileDto, AgentRepairProfileFileDto, AgentResolveChatCommitDto,
    AgentResolvePersistentStateMetadataUpdateDto, AgentResolvePromptAssemblyDto,
    AgentResolveSystemPromptDto, AgentResolveSystemPromptResultDto, AgentResumeRunDto,
    AgentRetargetPresetRefsDto, AgentRetargetPresetRefsResultDto, AgentRunHandleDto,
    AgentRunLiveUpdateDto, AgentRunPruneApplyResultDto, AgentRunPrunePlanDto, AgentSaveProfileDto,
    AgentStartRunDto, AgentSubmitGuidanceDto, AgentSubmitGuidanceResultDto,
    AgentSubscribeRunLiveProjectionDto, AgentTaskDetailDto, AgentWorkspaceFileDto,
};
use tt_application::errors::ApplicationError;
use tt_application::services::agent_workspace_lifecycle_service::AgentChatWorkspaceTarget;
use tt_domain::models::agent::AgentChatRef;
use tt_domain::models::agent::profile_diagnostic::AgentProfileHealth;
use tt_ports::repositories::agent_workspace_lifecycle_repository::AgentPersistentStatePruneRequest;

use super::agent_live_projection::AgentRunLivePresenter;
use crate::host::Ctx;
use crate::host::background_runtime::background_handle;
use crate::host::events::emit;
use crate::presentation::dispatch::Args;
use crate::presentation::errors::CommandError;
use crate::presentation::helpers::{log_command, map_command_error};

pub async fn start_agent_run(ctx: &Ctx<'_>, args: &Args) -> Result<AgentRunHandleDto, CommandError> {
    let dto: AgentStartRunDto = args.typed("dto")?;
    log_command("start_agent_run");
    ctx.services
        .agent_runtime_service
        .start_run(dto)
        .await
        .map_err(map_command_error("Failed to start agent run"))
}

pub async fn read_agent_run_checkpoint(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<AgentReadRunCheckpointResultDto, CommandError> {
    let dto: AgentReadRunCheckpointDto = args.typed("dto")?;
    log_command("read_agent_run_checkpoint");
    ctx.services
        .agent_runtime_service
        .read_run_checkpoint(dto)
        .await
        .map_err(map_command_error("Failed to read agent run checkpoint"))
}

pub async fn resume_agent_run(ctx: &Ctx<'_>, args: &Args) -> Result<AgentRunHandleDto, CommandError> {
    let dto: AgentResumeRunDto = args.typed("dto")?;
    log_command("resume_agent_run");
    ctx.services
        .agent_runtime_service
        .resume_run(dto)
        .await
        .map_err(map_command_error("Failed to resume agent run"))
}

pub async fn finish_agent_run_presentation(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<(), CommandError> {
    let dto: AgentFinishRunPresentationDto = args.typed("dto")?;
    log_command("finish_agent_run_presentation");
    ctx.services
        .agent_runtime_service
        .finish_run_presentation(dto)
        .await
        .map_err(map_command_error("Failed to finish agent run presentation"))
}

/// Tauri 的 `Channel<AgentRunLiveUpdateDto>` 换成宿主事件总线：首次下发快照，之后每次
/// projection 变化由 presenter 算出增量并逐条 emit；循环在进程级后台 runtime 上运行，
/// 与 napi-ohos 调用线程解耦。
pub async fn subscribe_agent_run_live_projection(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<(), CommandError> {
    let dto: AgentSubscribeRunLiveProjectionDto = args.typed("dto")?;
    log_command("subscribe_agent_run_live_projection");

    let Some(mut receiver) = ctx
        .services
        .agent_runtime_service
        .subscribe_live_projection(&dto.run_id)
        .await
        .map_err(map_command_error(
            "Failed to subscribe to agent run live projection",
        ))?
    else {
        // 与上游一致：无 live projection 时发一次空快照后正常返回。
        let empty = AgentRunLiveUpdateDto::Snapshot {
            calls: Vec::new(),
            responses: Vec::new(),
        };
        emit(
            "agent:run-live-update",
            serde_json::to_value(empty).expect("live update snapshot is JSON"),
        );
        return Ok(());
    };

    let mut presenter = AgentRunLivePresenter::default();
    let snapshot = {
        let projection = receiver.borrow_and_update();
        presenter.snapshot(&projection)
    };
    emit(
        "agent:run-live-update",
        serde_json::to_value(snapshot).expect("live update snapshot is JSON"),
    );

    background_handle().spawn(async move {
        loop {
            if receiver.changed().await.is_err() {
                return;
            }
            let updates = {
                let projection = receiver.borrow_and_update();
                match presenter.updates(&projection) {
                    Ok(updates) => updates,
                    Err(error) => {
                        tracing::error!(?error, "agent live projection presenter failed");
                        return;
                    }
                }
            };
            for update in updates {
                let payload =
                    serde_json::to_value(update).expect("live update delta is JSON");
                emit("agent:run-live-update", payload);
            }
        }
    });
    Ok(())
}

pub async fn prepare_agent_prompt_assembly(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<AgentPreparePromptAssemblyResultDto, CommandError> {
    let dto: AgentPreparePromptAssemblyDto = args.typed("dto")?;
    log_command("prepare_agent_prompt_assembly");
    let profile = ctx
        .services
        .prompt_assembly_service
        .resolve_profile(
            dto.profile_id.as_deref(),
            ctx.services.agent_runtime_service.tool_catalog(),
        )
        .await
        .map_err(map_command_error(
            "Failed to resolve agent profile for prompt assembly",
        ))?;
    let visible_tools = ctx
        .services
        .agent_runtime_service
        .visible_model_tools(&profile)
        .await
        .map_err(map_command_error(
            "Failed to resolve agent prompt assembly tool surface",
        ))?;

    ctx.services
        .prompt_assembly_service
        .prepare_frontend_prompt_assembly(
            dto,
            profile,
            &visible_tools,
            tt_domain::models::agent::AgentInvocationExitPolicy::RunFinishAllowed,
        )
        .await
        .map_err(map_command_error("Failed to prepare agent prompt assembly"))
}

pub async fn build_agent_current_model_connection_snapshot(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<AgentBuildCurrentModelConnectionSnapshotResultDto, CommandError> {
    let dto: AgentBuildCurrentModelConnectionSnapshotDto = args.typed("dto")?;
    log_command("build_agent_current_model_connection_snapshot");
    ctx.services
        .prompt_assembly_service
        .build_current_model_connection_snapshot(&dto.settings, &dto.model, dto.secret_id.as_deref())
        .map(|current_model_connection| AgentBuildCurrentModelConnectionSnapshotResultDto {
            current_model_connection,
        })
        .map_err(map_command_error(
            "Failed to build current model connection snapshot",
        ))
}

pub async fn apply_agent_current_model_connection_snapshot(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<AgentApplyCurrentModelConnectionSnapshotResultDto, CommandError> {
    let dto: AgentApplyCurrentModelConnectionSnapshotDto = args.typed("dto")?;
    log_command("apply_agent_current_model_connection_snapshot");
    ctx.services
        .prompt_assembly_service
        .apply_current_model_connection_snapshot(dto.settings, &dto.current_model_connection)
        .map(|settings| AgentApplyCurrentModelConnectionSnapshotResultDto { settings })
        .map_err(map_command_error(
            "Failed to apply current model connection snapshot",
        ))
}

pub async fn list_agent_profiles(
    ctx: &Ctx<'_>,
) -> Result<AgentListProfilesResultDto, CommandError> {
    log_command("list_agent_profiles");
    ctx.services
        .agent_profile_service
        .list_profiles()
        .await
        .map(|list| AgentListProfilesResultDto {
            profiles: list.profiles,
            issues: list.issues,
        })
        .map_err(map_command_error("Failed to list agent profiles"))
}

pub async fn list_agent_tools(ctx: &Ctx<'_>, args: &Args) -> Result<AgentListToolsResultDto, CommandError> {
    let dto: Option<AgentListToolsDto> = args.optional_typed("dto")?;
    log_command("list_agent_tools");
    ctx.services
        .agent_runtime_service
        .tool_catalog_items(dto.unwrap_or_default().context)
        .await
        .map_err(map_command_error("Failed to list agent tools"))
}

pub async fn resolve_agent_system_prompt(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<AgentResolveSystemPromptResultDto, CommandError> {
    let dto: AgentResolveSystemPromptDto = args.typed("dto")?;
    log_command("resolve_agent_system_prompt");
    ctx.services
        .agent_runtime_service
        .resolve_agent_system_prompt(dto.profile_id.as_deref())
        .await
        .map(|agent_system_prompt| AgentResolveSystemPromptResultDto {
            agent_system_prompt,
        })
        .map_err(map_command_error("Failed to resolve agent system prompt"))
}

pub async fn load_agent_profile(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<AgentLoadProfileResultDto, CommandError> {
    let dto: AgentProfileIdDto = args.typed("dto")?;
    log_command("load_agent_profile");
    ctx.services
        .agent_profile_service
        .load_profile(&dto.profile_id)
        .await
        .map(|profile| AgentLoadProfileResultDto { profile })
        .map_err(map_command_error("Failed to load agent profile"))
}

pub async fn diagnose_agent_profile(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<AgentProfileHealth, CommandError> {
    let dto: AgentProfileIdDto = args.typed("dto")?;
    log_command("diagnose_agent_profile");
    ctx.services
        .agent_profile_diagnostic_service
        .diagnose_profile(&dto.profile_id, ctx.services.agent_runtime_service.tool_catalog())
        .await
        .map_err(map_command_error("Failed to diagnose agent profile"))
}

pub async fn save_agent_profile(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let dto: AgentSaveProfileDto = args.typed("dto")?;
    log_command("save_agent_profile");
    ctx.services
        .agent_runtime_service
        .save_profile(dto.profile)
        .await
        .map_err(map_command_error("Failed to save agent profile"))
}

pub async fn delete_agent_profile(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let dto: AgentProfileIdDto = args.typed("dto")?;
    log_command("delete_agent_profile");
    ctx.services
        .agent_profile_service
        .delete_profile(&dto.profile_id)
        .await
        .map_err(map_command_error("Failed to delete agent profile"))
}

pub async fn repair_agent_profile_file(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<(), CommandError> {
    let dto: AgentRepairProfileFileDto = args.typed("dto")?;
    log_command("repair_agent_profile_file");
    ctx.services
        .agent_profile_service
        .repair_profile_file(&dto.profile_id, dto.action)
        .await
        .map_err(map_command_error("Failed to repair agent profile file"))
}

pub async fn retarget_agent_profile_preset_refs(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<AgentRetargetPresetRefsResultDto, CommandError> {
    let dto: AgentRetargetPresetRefsDto = args.typed("dto")?;
    log_command(format!(
        "retarget_agent_profile_preset_refs {}/{} -> {}/{}",
        dto.from.api_id, dto.from.name, dto.to.api_id, dto.to.name
    ));
    ctx.services
        .agent_profile_service
        .retarget_preset_refs(dto.from, dto.to)
        .await
        .map(|result| AgentRetargetPresetRefsResultDto {
            updated: result.profile_ids.len() + usize::from(result.session_profile_updated),
            profile_ids: result
                .profile_ids
                .iter()
                .map(|id| id.as_str().to_string())
                .collect(),
            session_profile_updated: result.session_profile_updated,
        })
        .map_err(map_command_error("Failed to retarget agent profile preset refs"))
}

pub async fn cancel_agent_run(ctx: &Ctx<'_>, args: &Args) -> Result<AgentCancelRunResultDto, CommandError> {
    let dto: AgentCancelRunDto = args.typed("dto")?;
    log_command("cancel_agent_run");
    ctx.services
        .agent_runtime_service
        .cancel_run(dto)
        .await
        .map_err(map_command_error("Failed to cancel agent run"))
}

pub async fn submit_agent_run_guidance(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<AgentSubmitGuidanceResultDto, CommandError> {
    let dto: AgentSubmitGuidanceDto = args.typed("dto")?;
    log_command("submit_agent_run_guidance");
    ctx.services
        .agent_runtime_service
        .submit_guidance(dto)
        .await
        .map_err(map_command_error("Failed to submit agent run guidance"))
}

pub async fn list_active_agent_runs(
    ctx: &Ctx<'_>,
) -> Result<Vec<AgentActiveRunDto>, CommandError> {
    log_command("list_active_agent_runs");
    Ok(ctx.services.agent_runtime_service.list_active_runs().await)
}

pub async fn list_agent_runs(ctx: &Ctx<'_>, args: &Args) -> Result<AgentListRunsResultDto, CommandError> {
    let dto: AgentListRunsDto = args.typed("dto")?;
    log_command("list_agent_runs");
    ctx.services
        .agent_run_history_service
        .list_runs(dto)
        .await
        .map_err(map_command_error("Failed to list agent runs"))
}

pub async fn plan_agent_run_prune(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<AgentRunPrunePlanDto, CommandError> {
    let dto: AgentPlanRunPruneDto = args.typed("dto")?;
    log_command("plan_agent_run_prune");
    ctx.services
        .agent_run_history_service
        .plan_run_prune(dto)
        .await
        .map_err(map_command_error("Failed to plan agent run prune"))
}

pub async fn apply_agent_run_prune(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<AgentRunPruneApplyResultDto, CommandError> {
    let dto: AgentApplyRunPruneDto = args.typed("dto")?;
    log_command("apply_agent_run_prune");
    ctx.services
        .agent_run_history_service
        .apply_run_prune(dto)
        .await
        .map_err(map_command_error("Failed to apply agent run prune"))
}

pub async fn read_agent_run_events(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<AgentReadEventsResultDto, CommandError> {
    let dto: AgentReadEventsDto = args.typed("dto")?;
    log_command("read_agent_run_events");
    ctx.services
        .agent_runtime_service
        .read_events(dto)
        .await
        .map_err(map_command_error("Failed to read agent run events"))
}

/// `tauri::ipc::Response`（原始字节）换成 base64 字符串；ArkTS 侧解码还原。
pub async fn read_agent_workspace_bytes(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<String, CommandError> {
    let dto: AgentReadWorkspaceFileDto = args.typed("dto")?;
    log_command("read_agent_workspace_bytes");
    let bytes = ctx
        .services
        .agent_runtime_service
        .read_workspace_bytes(dto)
        .await
        .map_err(map_command_error("Failed to read agent workspace bytes"))?;
    Ok(base64::engine::general_purpose::STANDARD.encode(bytes))
}

pub async fn read_agent_workspace_file(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<AgentWorkspaceFileDto, CommandError> {
    let dto: AgentReadWorkspaceFileDto = args.typed("dto")?;
    log_command("read_agent_workspace_file");
    ctx.services
        .agent_runtime_service
        .read_workspace_file(dto)
        .await
        .map_err(map_command_error("Failed to read agent workspace file"))
}

pub async fn read_agent_task_detail(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<AgentTaskDetailDto, CommandError> {
    let dto: AgentReadTaskDetailDto = args.typed("dto")?;
    log_command("read_agent_task_detail");
    ctx.services
        .agent_runtime_service
        .read_task_detail(dto)
        .await
        .map_err(map_command_error("Failed to read agent task detail"))
}

pub async fn read_agent_model_turn(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<AgentModelTurnDisplayDto, CommandError> {
    let dto: AgentReadModelTurnDto = args.typed("dto")?;
    log_command("read_agent_model_turn");
    ctx.services
        .agent_runtime_service
        .read_model_turn(dto)
        .await
        .map_err(map_command_error("Failed to read agent model turn"))
}

pub async fn read_agent_prompt_assembly_request(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<Option<AgentPromptAssemblyBrokerRequestDto>, CommandError> {
    let dto: AgentReadPromptAssemblyRequestDto = args.typed("dto")?;
    log_command("read_agent_prompt_assembly_request");
    ctx.services
        .agent_runtime_service
        .read_prompt_assembly_request(dto)
        .await
        .map_err(map_command_error(
            "Failed to read agent prompt assembly request",
        ))
}

pub async fn resolve_agent_chat_commit(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let dto: AgentResolveChatCommitDto = args.typed("dto")?;
    log_command("resolve_agent_chat_commit");
    ctx.services
        .agent_runtime_service
        .resolve_chat_commit(dto)
        .await
        .map_err(map_command_error("Failed to resolve agent chat commit"))
}

pub async fn resolve_agent_prompt_assembly(ctx: &Ctx<'_>, args: &Args) -> Result<(), CommandError> {
    let dto: AgentResolvePromptAssemblyDto = args.typed("dto")?;
    log_command("resolve_agent_prompt_assembly");
    ctx.services
        .agent_runtime_service
        .resolve_prompt_assembly(dto)
        .await
        .map_err(map_command_error("Failed to resolve agent prompt assembly"))
}

pub async fn resolve_agent_persistent_state_metadata_update(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<(), CommandError> {
    let dto: AgentResolvePersistentStateMetadataUpdateDto = args.typed("dto")?;
    log_command("resolve_agent_persistent_state_metadata_update");
    ctx.services
        .agent_runtime_service
        .resolve_persistent_state_metadata_update(dto)
        .await
        .map_err(map_command_error(
            "Failed to resolve agent persistent state metadata update",
        ))
}

pub async fn prune_agent_chat_persistent_states(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<AgentPruneChatPersistentStatesResultDto, CommandError> {
    let dto: AgentPruneChatPersistentStatesDto = args.typed("dto")?;
    log_command("prune_agent_chat_persistent_states");

    let (character_id, file_name) = match &dto.chat_ref {
        AgentChatRef::Character {
            character_id,
            file_name,
        } => (character_id.as_str(), file_name.as_str()),
        AgentChatRef::Group { .. } => {
            return Err(
                map_command_error("Failed to prune agent persistent states")(
                    ApplicationError::ValidationError(
                        "agent.group_persistent_state_prune_unsupported".to_string(),
                    ),
                ),
            );
        }
    };

    let candidate_state_ids = dto.candidate_state_ids.ok_or_else(|| {
        map_command_error("Failed to prune agent persistent states")(
            ApplicationError::ValidationError(
                "agent.persistent_state_prune_candidates_required".to_string(),
            ),
        )
    })?;
    let payload = ctx
        .services
        .chat_service
        .get_chat_payload(character_id, file_name)
        .await
        .map_err(map_command_error("Failed to read chat payload for agent prune"))?;
    let retained_state_ids = collect_agent_persistent_state_ids(&payload);
    let target = AgentChatWorkspaceTarget {
        chat_ref: dto.chat_ref,
        stable_chat_id: dto.stable_chat_id,
    };

    ctx.services
        .chat_service
        .prune_agent_persistent_states(
            &target,
            AgentPersistentStatePruneRequest {
                retained_state_ids,
                candidate_state_ids,
            },
        )
        .await
        .map(|prune| AgentPruneChatPersistentStatesResultDto {
            workspace_id: prune.workspace_id,
            removed_state_ids: prune.removed_state_ids,
        })
        .map_err(map_command_error("Failed to prune agent persistent states"))
}

pub async fn copy_agent_chat_persistent_states(
    ctx: &Ctx<'_>,
    args: &Args,
) -> Result<(), CommandError> {
    let dto: AgentCopyChatPersistentStatesDto = args.typed("dto")?;
    log_command("copy_agent_chat_persistent_states");
    ctx.services
        .chat_service
        .copy_agent_persistent_states(
            &AgentChatWorkspaceTarget {
                chat_ref: dto.source_chat_ref,
                stable_chat_id: dto.source_stable_chat_id,
            },
            &AgentChatWorkspaceTarget {
                chat_ref: dto.target_chat_ref,
                stable_chat_id: dto.target_stable_chat_id,
            },
        )
        .await
        .map_err(map_command_error(
            "Failed to copy agent chat persistent states",
        ))
}

fn collect_agent_persistent_state_ids(payload: &[Value]) -> Vec<String> {
    let mut retained = BTreeSet::new();
    for item in payload {
        collect_agent_persistent_state_id_from_extra(item.get("extra"), &mut retained);
        if let Some(swipe_info) = item.get("swipe_info").and_then(Value::as_array) {
            for swipe in swipe_info {
                collect_agent_persistent_state_id_from_extra(swipe.get("extra"), &mut retained);
            }
        }
    }
    retained.into_iter().collect()
}

fn collect_agent_persistent_state_id_from_extra(
    extra: Option<&Value>,
    retained: &mut BTreeSet<String>,
) {
    let Some(state_id) = extra
        .and_then(|value| value.get("tauritavern"))
        .and_then(|value| value.get("agent"))
        .and_then(|value| value.get("persistStateId"))
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
    else {
        return;
    };
    retained.insert(state_id.to_string());
}
