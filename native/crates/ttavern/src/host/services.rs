//! Service graph (replaces upstream `composition/services/*`).
//!
//! Upstream builds 45 services. Each one is pure constructor injection over the
//! repositories from `host::repositories`:
//!
//! ```text
//! P3 batch (13):
//! UserService              (user_repository)
//! UserDirectoryService     (user_directory_repository)
//! AvatarService            (avatar_repository)
//! SecretService            (secret_repository, allow_keys_exposure)
//! TokenizationService      (tokenizer_repository)
//! ChatHistoryCoordinator   (chat_repository, group_chat_repository)
//! AgentWorkspaceLifecycle  (agent_workspace_lifecycle_repository, AgentRunActivity, Mutex)
//! CharacterService         (character_repository, chat_repository, world_info_repository,
//!                           agent_workspace_lifecycle_service, chat_history_coordinator)
//! GroupService             (group_repository, agent_workspace_lifecycle_service,
//!                           chat_history_coordinator)
//! SettingsService          (avatar_repository, settings_repository,
//!                           RequestProxyRuntime=HttpClientPool, ChatBackupRuntime=FileChatRepository)
//! ContentService, RuntimePathsService, UserMediaService
//!
//! P5 batch (+3):
//! ChatService              (chat_repository, character_repository,
//!                           agent_workspace_lifecycle_service, chat_history_coordinator)
//! ChatCompletionService    (chat_completion_repository, secret_repository, settings_repository,
//!                           prompt_cache_repository, generation_background_runtime=None on OHOS,
//!                           ios_policy)
//! UserEndpointAccessService(grant_repository, grant_runtime=HttpClientPool)  // async initialize()
//!
//! P6.2 agent batch (+7, upstream `composition/services/agent.rs`):
//! AgentProfileService, AgentProfileDiagnosticService, PromptAssemblyService,
//! AgentRuntimeService, AgentRunHistoryService, AgentRunRetentionAutomationService,
//! AgentWorkspaceLifecycleService (rebound to the real agent runtime; the P3 stub
//! `NoActiveAgentRuns` is dropped).
//! ```

use std::sync::Arc;

use tokio::sync::Semaphore;

use tt_adapter_archive::FileDataArchiveExecutor;
use tt_adapter_mcp::RmcpMcpGateway;
use tt_adapter_media::{FilesystemUserMediaStore, MediaToolImageNormalizer};
use tt_adapter_storage_core::file_system::DataDirectory;
use tt_adapter_storage_core::repositories::FileUserEndpointGrantRepository;
use tt_adapter_sync::{
    AxumLanServerControl, HttpLanPairingClient, HttpTtPairingClient, InfrastructureSyncJobExecutor,
    LanPeerDiscovery, LanPeerStore, LanSyncStore, LocalLanAddressDiscovery, SyncAutomationStore,
    TtSyncRuntime,
};
use tt_adapter_workspace_shell::WorkspaceShellEngine;
use tt_application::services::agent_model_gateway::ChatCompletionAgentModelGateway;
use tt_application::services::agent_profile_diagnostic_service::AgentProfileDiagnosticService;
use tt_application::services::agent_profile_service::AgentProfileService;
use tt_application::services::agent_run_history_service::AgentRunHistoryService;
use tt_application::services::agent_runtime_service::AgentRuntimeService;
use tt_application::services::agent_workspace_lifecycle_service::{
    AgentRunActivity, AgentWorkspaceLifecycleService,
};
use tt_application::services::avatar_service::AvatarService;
use tt_application::services::character_service::CharacterService;
use tt_application::services::chat_completion_service::ChatCompletionService;
use tt_application::services::chat_history_coordinator::ChatHistoryCoordinator;
use tt_application::services::chat_service::ChatService;
use tt_application::services::content_service::ContentService;
use tt_application::services::data_archive_service::{
    DataArchiveJobRegistry, DataArchiveService,
};
use tt_application::services::database_service::DatabaseService;
use tt_application::services::extension_service::ExtensionService;
use tt_application::services::extension_store_service::ExtensionStoreService;
use tt_application::services::group_chat_service::GroupChatService;
use tt_application::services::group_service::GroupService;
use tt_application::services::lan_sync_service::{
    LanInboundService, LanSyncRuntimeState, LanSyncService,
};
use tt_application::services::llm_connection_service::LlmConnectionService;
use tt_application::services::mcp_service::McpService;
use tt_application::services::preset_service::PresetService;
use tt_application::services::prompt_assembly_service::PromptAssemblyService;
use tt_application::services::provider_metadata_service::ProviderMetadataService;
use tt_application::services::runtime_paths_service::RuntimePathsService;
use tt_application::services::searxng_search_service::SearxngSearchService;
use tt_application::services::secret_service::SecretService;
use tt_application::services::settings_service::SettingsService;
use tt_application::services::skill_service::SkillService;
use tt_application::services::sync_automation_service::SyncAutomationService;
use tt_application::services::sync_job_coordinator::SyncJobCoordinator;
use tt_application::services::tokenization_service::TokenizationService;
use tt_application::services::tt_sync_service::TtSyncService;
use tt_application::services::user_directory_service::UserDirectoryService;
use tt_application::services::user_endpoint_access_service::UserEndpointAccessService;
use tt_application::services::user_media_service::UserMediaService;
use tt_application::services::user_service::UserService;
use tt_application::services::vector_service::VectorService;
use tt_application::services::world_info_service::WorldInfoService;
use tt_domain::errors::DomainError;
use tt_ports::extension_tools::ExtensionTools;
use tt_ports::lan_sync::{LanPeerRepository, LanServerControl, LanSyncSettingsRepository};
use tt_ports::repositories::user_endpoint_grant_repository::UserEndpointGrantRepository;
use tt_ports::sync::DataChangeReconciler;
use tt_ports::tool_images::ToolImageNormalizer;
use tt_ports::user_endpoint_access::UserEndpointGrantRuntime;
use tt_ports::workspace_shell::WorkspaceShell;

use super::agent_extension_tools::OhosExtensionTools;
use super::cache_reconciler::ServiceCacheReconciler;
use super::context::HostContext;
use super::data_archive_adapters::{DataDirectoryDataRootInitializer, HostDataArchiveFileGateway};
use super::external_import::HttpExternalImportDownloader;
use super::identity::{HOST_IDENTITY, USER_AGENT};
use super::path_store::build_runtime_paths_service;
use super::repositories::AppRepositories;
use super::startup::StartupProfile;
use super::sync_adapters;

pub struct AppServices {
    pub user_service: Arc<UserService>,
    pub user_directory_service: Arc<UserDirectoryService>,
    pub avatar_service: Arc<AvatarService>,
    pub secret_service: Arc<SecretService>,
    pub tokenization_service: Arc<TokenizationService>,
    pub chat_history_coordinator: Arc<ChatHistoryCoordinator>,
    pub character_service: Arc<CharacterService>,
    pub group_service: Arc<GroupService>,
    /// P8：群聊（GroupChatService 之前只在 CharacterService 里被间接持有，没暴露）。
    pub group_chat_service: Arc<GroupChatService>,
    pub settings_service: Arc<SettingsService>,
    pub content_service: Arc<ContentService>,
    pub runtime_paths_service: Arc<RuntimePathsService>,
    /// Upstream manages this one outside `AppState` (`app/host/resources.rs`); we keep the
    /// whole service graph in one place.
    pub user_media_service: Arc<UserMediaService>,
    /// 世界书（P8）：上游把这块放在 HTTP 路由里，OHOS 需要一个服务句柄供 9 条命令调用。
    pub world_info_service: Arc<WorldInfoService>,
    // ---- P5 ----
    pub chat_service: Arc<ChatService>,
    pub chat_completion_service: Arc<ChatCompletionService>,
    pub user_endpoint_access_service: Arc<UserEndpointAccessService>,
    // ---- P6.1 ----
    pub preset_service: Arc<PresetService>,
    pub mcp_service: Arc<McpService>,
    pub skill_service: Arc<SkillService>,
    pub vector_service: Arc<VectorService>,
    pub database_service: Arc<DatabaseService>,
    pub provider_metadata_service: Arc<ProviderMetadataService>,
    pub searxng_search_service: Arc<SearxngSearchService>,
    pub llm_connection_service: Arc<LlmConnectionService>,
    pub extension_store_service: Arc<ExtensionStoreService>,
    /// P6.2: 第三方扩展管理（安装/更新/分支/移动，见 `ExtensionService`）。
    pub extension_service: Arc<ExtensionService>,
    pub data_archive_service: Arc<DataArchiveService>,
    // ---- P6.2 agent ----
    pub agent_profile_service: Arc<AgentProfileService>,
    pub agent_profile_diagnostic_service: Arc<AgentProfileDiagnosticService>,
    pub prompt_assembly_service: Arc<PromptAssemblyService>,
    pub agent_runtime_service: Arc<AgentRuntimeService>,
    pub agent_run_history_service: Arc<AgentRunHistoryService>,
    // ---- P6.2 sync ----
    pub lan_sync_service: Arc<LanSyncService>,
    pub tt_sync_service: Arc<TtSyncService>,
    pub sync_automation_service: Arc<SyncAutomationService>,
}

impl AppServices {
    /// Number of assembled services (surfaced in `getBackendStatus` for acceptance runs).
    pub const COUNT: usize = 38;
}

pub async fn build(
    context: &HostContext,
    startup: &StartupProfile,
    repositories: AppRepositories,
) -> Result<AppServices, DomainError> {
    let chat_history_coordinator = Arc::new(ChatHistoryCoordinator::new(
        repositories.chat_repository.clone(),
        repositories.group_chat_repository.clone(),
    ));

    let settings_service = Arc::new(SettingsService::new(
        repositories.avatar_repository.clone(),
        repositories.settings_repository.clone(),
        context.http_client_pool.clone(),
        repositories.chat_backup_runtime.clone(),
    ));

    // `generation_background_runtime = None` on OHOS is upstream's own decision, not a
    // shortcut: their `platform/generation_background.rs` returns None for
    // `#[cfg(any(desktop, target_env = "ohos"))]` with the comment "OHOS has no native
    // generation-background adapter yet". Consequence: generation is foreground-only.
    let chat_completion_service = Arc::new(ChatCompletionService::new(
        repositories.chat_completion_repository.clone(),
        repositories.secret_repository.clone(),
        repositories.settings_repository.clone(),
        repositories.prompt_cache_repository.clone(),
        None,
        startup.ios_policy.clone(),
    ).with_usage_observer(super::usage_ledger::observer(context.paths.data_root.clone())));

    let grant_repository: Arc<dyn UserEndpointGrantRepository> = Arc::new(
        FileUserEndpointGrantRepository::new(
            context
                .paths
                .app_root
                .join("security")
                .join("user-endpoint-grants.json"),
        ),
    );
    let grant_runtime: Arc<dyn UserEndpointGrantRuntime> = context.http_client_pool.clone();
    let user_endpoint_access_service = Arc::new(
        UserEndpointAccessService::initialize(grant_repository, grant_runtime).await,
    );

    // ===== P6.1 services（构造与上游 `composition/services/mod.rs` 一致）=====
    // Hoisted here because the P6.1 cache reconciler needs it; upstream builds it before
    // the reconciler too.
    let secret_service = Arc::new(SecretService::new(
        repositories.secret_repository.clone(),
        startup.tauritavern_settings.allow_keys_exposure,
    ));

    // Shared external-import downloader: upstream builds one Arc and injects it into both
    // `ContentService` and `SkillService`.
    let external_import_downloader: Arc<dyn tt_ports::external_import::ExternalImportDownloader> =
        Arc::new(HttpExternalImportDownloader::new(
            context.http_client_pool.clone(),
        ));

    let preset_service = Arc::new(PresetService::new(repositories.preset_repository.clone()));

    let mcp_gateway = Arc::new(RmcpMcpGateway::new(context.http_client_pool.clone()));
    let mcp_service = Arc::new(McpService::new(
        repositories.mcp_server_repository.clone(),
        mcp_gateway,
    ));

    let skill_service = Arc::new(SkillService::with_external_import_downloader(
        repositories.skill_repository.clone(),
        external_import_downloader.clone(),
    ));

    let llm_connection_service = Arc::new(LlmConnectionService::new(
        repositories.llm_connection_repository.clone(),
        repositories.settings_repository.clone(),
    ));
    let extension_store_service = Arc::new(ExtensionStoreService::new(
        repositories.extension_store_repository.clone(),
    ));

    // 本地变更闸门：同一时刻只有一个「本地写盘」类操作在跑。上游只建一个
    // `Semaphore::new(1)` 并同时注入 ExtensionService 与 sync 装配；宿主保持同款共享。
    let local_mutation_gate = Arc::new(Semaphore::new(1));
    let extension_service = Arc::new(ExtensionService::new(
        repositories.extension_repository.clone(),
        local_mutation_gate.clone(),
    ));

    let provider_metadata_service = Arc::new(ProviderMetadataService::new(
        repositories.provider_metadata_repository.clone(),
        repositories.secret_repository.clone(),
        startup.ios_policy.clone(),
    ));
    let searxng_search_service = Arc::new(SearxngSearchService::new(
        repositories.searxng_search_repository.clone(),
    ));
    let vector_service = Arc::new(VectorService::new(
        repositories.vector_repository.clone(),
        repositories.remote_embedding_repository.clone(),
        repositories.local_embedding_repository.clone(),
        repositories.secret_repository.clone(),
        startup.ios_policy.clone(),
    ));
    let database_service = Arc::new(DatabaseService::new(repositories.database_backend.clone()));
    let tokenization_service = Arc::new(TokenizationService::new(
        repositories.tokenizer_repository.clone(),
    ));

    // ===== P6.2 agent services（构造与上游 `composition/services/agent.rs` 一致）=====
    let agent_profile_service = Arc::new(AgentProfileService::new(
        repositories.agent_profile_repository.clone(),
        repositories.agent_profile_storage_health_repository.clone(),
        repositories.preset_repository.clone(),
        repositories.agent_session_repository.clone(),
    ));
    let agent_profile_diagnostic_service = Arc::new(AgentProfileDiagnosticService::new(
        agent_profile_service.clone(),
        repositories.preset_repository.clone(),
        llm_connection_service.clone(),
    ));
    let prompt_assembly_service = Arc::new(PromptAssemblyService::new(
        agent_profile_service.clone(),
        repositories.preset_repository.clone(),
        llm_connection_service.clone(),
    ));

    let workspace_shell: Arc<dyn WorkspaceShell> = Arc::new(WorkspaceShellEngine);
    let extension_tools: Arc<dyn ExtensionTools> = Arc::new(OhosExtensionTools);
    let tool_image_normalizer: Arc<dyn ToolImageNormalizer> = Arc::new(MediaToolImageNormalizer);

    let agent_runtime_service = Arc::new(AgentRuntimeService::new(
        repositories.agent_run_repository.clone(),
        repositories.agent_session_repository.clone(),
        repositories.agent_invocation_repository.clone(),
        repositories.workspace_repository.clone(),
        repositories.chat_repository.clone(),
        repositories.group_chat_repository.clone(),
        skill_service.clone(),
        Arc::new(ChatCompletionAgentModelGateway::new(chat_completion_service.clone())),
        agent_profile_service.clone(),
        llm_connection_service.clone(),
        prompt_assembly_service.clone(),
        mcp_service.clone(),
        workspace_shell,
        extension_tools,
        tokenization_service.clone(),
        tool_image_normalizer,
    ));
    let agent_run_history_service = Arc::new(AgentRunHistoryService::new(
        repositories.agent_run_repository.clone(),
        repositories.settings_repository.clone(),
        agent_runtime_service.clone() as Arc<dyn AgentRunActivity>,
        agent_runtime_service.run_lifecycle_lock(),
    ));

    // P3's `NoActiveAgentRuns` stub is replaced by the real runtime-backed lifecycle
    // service (upstream wiring: repository + `AgentRunActivity` + run lifecycle lock).
    let agent_workspace_lifecycle_service = Arc::new(AgentWorkspaceLifecycleService::new(
        repositories.agent_workspace_lifecycle_repository.clone(),
        agent_runtime_service.clone() as Arc<dyn AgentRunActivity>,
        agent_runtime_service.run_lifecycle_lock(),
    ));

    // ---- Lifecycle-dependent services (must come after the agent runtime exists) ----
    let character_service = Arc::new(CharacterService::new(
        repositories.character_repository.clone(),
        repositories.chat_repository.clone(),
        repositories.world_info_repository.clone(),
        agent_workspace_lifecycle_service.clone(),
        chat_history_coordinator.clone(),
    ));

    let group_service = Arc::new(GroupService::new(
        repositories.group_repository.clone(),
        agent_workspace_lifecycle_service.clone(),
        chat_history_coordinator.clone(),
    ));

    let chat_service = Arc::new(ChatService::new(
        repositories.chat_repository.clone(),
        repositories.character_repository.clone(),
        agent_workspace_lifecycle_service.clone(),
        chat_history_coordinator.clone(),
    ));

    let group_chat_service = Arc::new(GroupChatService::new(
        repositories.group_chat_repository.clone(),
        agent_workspace_lifecycle_service.clone(),
        chat_history_coordinator.clone(),
    ));

    // Cache reconciler: data-archive apply invalidates runtime caches (upstream
    // `composition/adapters/cache_reconciler.rs`).
    let data_change_reconciler: Arc<dyn DataChangeReconciler> =
        Arc::new(ServiceCacheReconciler::new(
            character_service.clone(),
            chat_service.clone(),
            group_chat_service.clone(),
            group_service.clone(),
            secret_service.clone(),
            settings_service.clone(),
            mcp_service.clone(),
            chat_history_coordinator.clone(),
        ));

    // Data-archive service. Upstream takes `tauri::async_runtime::handle()` — a
    // process-lifetime runtime. The host uses a dedicated background runtime instead of
    // `Handle::current()` so jobs survive per-test runtimes in the contract suite (and are
    // independent of the napi-ohos calling runtime in production). See `background_runtime.rs`.
    let data_archive_service = Arc::new(DataArchiveService::new(
        database_service.clone(),
        Arc::new(DataArchiveJobRegistry::new()),
        super::background_runtime::background_handle(),
        Arc::new(FileDataArchiveExecutor {
            prepare_personas: tt_adapter_media::persona_cards::migrate_personas,
            read_personas: tt_adapter_media::persona_cards::read_personas,
        }),
        Arc::new(HostDataArchiveFileGateway::new(context.paths.clone())),
        Arc::new(DataDirectoryDataRootInitializer),
        data_change_reconciler.clone(),
    ));

    // ===== P6.2 sync services（构造与上游 `composition/services/sync.rs` 一致）=====
    // `lan_sync_allowed` 来自 ios_policy（OHOS 作用域 Ignored，能力全开）。本地变更闸门
    // `Semaphore::new(1)` 与上游 app 组装一致：同一时刻只有一个 sync job 落盘。
    let data_directory = DataDirectory::new(context.paths.data_root.clone());
    let lan_sync_allowed = startup.ios_policy.capabilities.sync.lan;

    let lan_runtime_state = Arc::new(LanSyncRuntimeState::new());
    let lan_settings_store = Arc::new(LanSyncStore::new(
        data_directory.default_user().to_path_buf(),
    ));
    let lan_peer_store = LanPeerStore::new(
        data_directory.default_user().to_path_buf(),
        HOST_IDENTITY.platform,
    );
    let lan_settings_repository: Arc<dyn LanSyncSettingsRepository> = lan_settings_store.clone();
    let lan_peer_repository: Arc<dyn LanPeerRepository> = Arc::new(lan_peer_store.clone());
    let sync_job_events = sync_adapters::sync_job_events();
    let pairing_approval = sync_adapters::pairing_approval();
    let lan_discovery = LanPeerDiscovery::new(sync_adapters::lan_discovery_host());
    let tt_runtime = Arc::new(TtSyncRuntime::new(
        data_directory.root().to_path_buf(),
        data_directory.default_user().to_path_buf(),
    ));
    let sync_job_executor = Arc::new(InfrastructureSyncJobExecutor::new(
        data_directory.root().to_path_buf(),
        sync_job_events.clone(),
        lan_peer_store.clone(),
        lan_discovery.clone(),
        tt_runtime.clone(),
        USER_AGENT,
        database_service.clone(),
        HOST_IDENTITY.kind,
    ));
    let sync_job_coordinator = Arc::new(SyncJobCoordinator::new(
        sync_job_executor,
        data_change_reconciler.clone(),
        sync_job_events,
        local_mutation_gate,
    ));
    let lan_inbound_service = Arc::new(LanInboundService::new(
        lan_runtime_state.clone(),
        lan_settings_repository.clone(),
        lan_peer_repository.clone(),
        sync_job_coordinator.clone(),
        pairing_approval.clone(),
    ));
    let lan_server_control: Arc<dyn LanServerControl> = Arc::new(AxumLanServerControl::new(
        data_directory.root().to_path_buf(),
        lan_peer_store.clone(),
        lan_inbound_service.clone(),
        sync_adapters::lan_server_events(),
        lan_discovery.clone(),
        database_service.clone(),
    ));
    let lan_sync_service = Arc::new(LanSyncService::new(
        lan_runtime_state,
        lan_settings_repository,
        lan_peer_repository,
        lan_server_control,
        Arc::new(LocalLanAddressDiscovery),
        Arc::new(lan_discovery),
        Arc::new(HttpLanPairingClient::new(USER_AGENT)),
        pairing_approval,
        sync_job_coordinator.clone(),
    ));
    let tt_sync_service = Arc::new(TtSyncService::new(
        tt_runtime.clone(),
        Arc::new(HttpTtPairingClient::new(USER_AGENT)),
        sync_job_coordinator.clone(),
    ));
    let sync_automation_service = Arc::new(SyncAutomationService::new(
        sync_adapters::sync_automation_events(),
        Arc::new(SyncAutomationStore::new(
            data_directory.default_user().to_path_buf(),
        )),
        lan_settings_store,
        sync_adapters::sync_automation_endpoint_catalog(
            lan_sync_service.clone(),
            tt_sync_service.clone(),
            lan_sync_allowed,
        ),
        sync_adapters::sync_automation_lan_server(lan_sync_service.clone(), lan_sync_allowed),
        sync_job_coordinator,
    ));

    Ok(AppServices {
        world_info_service: Arc::new(WorldInfoService::new(
            repositories.world_info_repository.clone(),
        )),
        user_service: Arc::new(UserService::new(repositories.user_repository.clone())),
        user_directory_service: Arc::new(UserDirectoryService::new(
            repositories.user_directory_repository.clone(),
        )),
        avatar_service: Arc::new(AvatarService::new(repositories.avatar_repository.clone())),
        // Upstream passes `tauritavern_settings.allow_keys_exposure` (default false).
        // When false the ArkTS side never receives stored API keys in clear; the backend
        // injects them into requests instead. Honouring the setting keeps parity with
        // upstream's `view_secrets` behaviour instead of hardcoding false.
        secret_service,
        tokenization_service,
        chat_history_coordinator,
        character_service,
        group_chat_service,
        group_service,
        settings_service,
        content_service: Arc::new(ContentService::new(
            repositories.content_repository.clone(),
            external_import_downloader,
        )),
        runtime_paths_service: build_runtime_paths_service(&context.paths),
        user_media_service: Arc::new(UserMediaService::new(Arc::new(
            FilesystemUserMediaStore::from_data_root(&context.paths.data_root),
        ))),
        chat_service,
        chat_completion_service,
        user_endpoint_access_service,
        preset_service,
        mcp_service,
        skill_service,
        vector_service,
        database_service,
        provider_metadata_service,
        searxng_search_service,
        llm_connection_service,
        extension_store_service,
        extension_service,
        data_archive_service,
        agent_profile_service,
        agent_profile_diagnostic_service,
        prompt_assembly_service,
        agent_runtime_service,
        agent_run_history_service,
        lan_sync_service,
        tt_sync_service,
        sync_automation_service,
    })
}
