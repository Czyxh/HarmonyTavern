//! Repository graph for the P3 command batch (replaces upstream `composition/repositories.rs`).
//!
//! Every implementation here already lives in the migrated `tt-adapter-*` crates; this module
//! only wires paths from `DataDirectory` plus the host singletons into constructors. No Tauri
//! types are involved 鈥?upstream's `app_handle` uses were three: `HttpClientPool`,
//! `PageGeneration` and the resource bundle, and all three now come from `HostContext`.
//!
//! Not built yet (arrives with its owning phase):
//! - sprite/extension/theme/update/prompt-vector repos (P4/P6.2/P7)

use std::sync::Arc;

use tt_adapter_extension::FileExtensionRepository;
use tt_adapter_media::FileAvatarRepository;
use tt_adapter_provider_http::{
    HttpChatCompletionRepository, HttpEmbeddingRepository, HttpProviderMetadataRepository,
    HttpSearxngSearchRepository,
};
use tt_adapter_storage_core::chat_directory_identity::new_shared_chat_alias_store_for_user_dir;
use tt_adapter_storage_core::repositories::{
    FileChatRepository, FileExtensionStoreRepository, FileGroupRepository,
    FileLlmConnectionRepository, FileMcpServerRepository, FilePromptCacheRepository,
    FileSecretRepository, FileSettingsRepository, FileUserDirectoryRepository, FileUserRepository,
};
use tt_adapter_storage_userdata::{
    FileAgentProfileRepository, FileAgentRepository, FileCharacterRepository, FileSkillRepository,
    FileWorldInfoRepository,
};
use tt_adapter_tokenization::MiktikTokenizerRepository;
use tt_adapter_triviumdb::TriviumDatabaseBackend;
use tt_adapter_vector::{CandleLocalEmbeddingRepository, RedbVectorRepository};
use tt_domain::errors::DomainError;
use tt_domain::models::settings::UserSettings;
use tt_ports::database::DatabaseBackend;
use tt_ports::repositories::{
    agent_invocation_repository::AgentInvocationRepository,
    agent_profile_repository::AgentProfileRepository,
    agent_profile_storage_health_repository::AgentProfileStorageHealthRepository,
    agent_run_repository::AgentRunRepository, agent_session_repository::AgentSessionRepository,
    agent_workspace_lifecycle_repository::AgentWorkspaceLifecycleRepository,
    avatar_repository::AvatarRepository, character_repository::CharacterRepository,
    chat_completion_repository::ChatCompletionRepository, chat_repository::ChatRepository,
    content_repository::ContentRepository,
    extension_repository::ExtensionRepository,
    group_chat_repository::GroupChatRepository, group_repository::GroupRepository,
    llm_connection_repository::LlmConnectionRepository,
    mcp_server_repository::McpServerRepository, preset_repository::PresetRepository,
    prompt_cache_repository::PromptCacheRepository,
    provider_metadata_repository::ProviderMetadataRepository,
    searxng_search_repository::SearxngSearchRepository, secret_repository::SecretRepository,
    settings_repository::SettingsRepository, skill_repository::SkillRepository,
    tokenizer_repository::TokenizerRepository, user_directory_repository::UserDirectoryRepository,
    user_repository::UserRepository, vector_repository::{
        LocalEmbeddingRepository, RemoteEmbeddingRepository, VectorRepository,
    },
    workspace_repository::WorkspaceRepository, world_info_repository::WorldInfoRepository,
};
use tt_ports::settings::ChatBackupRuntime;

use super::content_repository::FileContentRepository;
use super::context::HostContext;
use super::identity::COMMIT_FRAME_BYTES;
use super::preset_repository::FilePresetRepository;
use super::skills::materialize_builtin_skills;
use super::startup::StartupProfile;

pub struct AppRepositories {
    pub user_repository: Arc<dyn UserRepository>,
    pub user_directory_repository: Arc<dyn UserDirectoryRepository>,
    pub avatar_repository: Arc<dyn AvatarRepository>,
    pub settings_repository: Arc<dyn SettingsRepository>,
    pub secret_repository: Arc<dyn SecretRepository>,
    pub character_repository: Arc<dyn CharacterRepository>,
    pub chat_repository: Arc<dyn ChatRepository>,
    pub group_chat_repository: Arc<dyn GroupChatRepository>,
    pub group_repository: Arc<dyn GroupRepository>,
    pub world_info_repository: Arc<dyn WorldInfoRepository>,
    /// P6.2: agent 域仓库（与上游共用同一个 `FileAgentRepository` 克隆出 5 个 trait；
    /// agent-profile 用 `FileAgentProfileRepository` 克隆出 2 个）。
    pub agent_profile_repository: Arc<dyn AgentProfileRepository>,
    pub agent_profile_storage_health_repository: Arc<dyn AgentProfileStorageHealthRepository>,
    pub agent_run_repository: Arc<dyn AgentRunRepository>,
    pub agent_session_repository: Arc<dyn AgentSessionRepository>,
    pub agent_invocation_repository: Arc<dyn AgentInvocationRepository>,
    pub workspace_repository: Arc<dyn WorkspaceRepository>,
    pub agent_workspace_lifecycle_repository: Arc<dyn AgentWorkspaceLifecycleRepository>,
    pub chat_backup_runtime: Arc<dyn ChatBackupRuntime>,
    pub tokenizer_repository: Arc<dyn TokenizerRepository>,
    pub content_repository: Arc<dyn ContentRepository>,
    /// P5: LLM 调用通道（`ChatCompletionService` 第一参数）。上游外面还包了一层
    /// `LoggingChatCompletionRepository` 记录 LLM API 日志，那属于宿主侧 observability
    /// （`infrastructure/logging/llm_api_logs`），没随 P5 移植，详见 §11.3-K。
    pub chat_completion_repository: Arc<dyn ChatCompletionRepository>,
    /// P5: prompt caching（`ChatCompletionService` 第四参数）。
    pub prompt_cache_repository: Arc<dyn PromptCacheRepository>,
    /// P6.1: preset 域（FilePresetRepository 为宿主自有重建，见 preset_repository.rs）。
    pub preset_repository: Arc<dyn PresetRepository>,
    /// P6.1: MCP 服务器注册表（`<data_root>/_tauritavern/mcp`）。
    pub mcp_server_repository: Arc<dyn McpServerRepository>,
    /// P6.1: skills（用户 + 内置，`<data_root>/_tauritavern/skills`，内置由 skills.rs 材料化）。
    pub skill_repository: Arc<dyn SkillRepository>,
    /// P6.1: 向量库（`<default_user>/vectors/tauritavern-v1.redb`）。
    pub vector_repository: Arc<dyn VectorRepository>,
    /// P6.1: 远程 embedding（HTTP，随 http_client_pool）。
    pub remote_embedding_repository: Arc<dyn RemoteEmbeddingRepository>,
    /// P6.1: 本地 embedding（Candle，`<data_root>/_cache/embedding-models`，惰性加载）。
    pub local_embedding_repository: Arc<dyn LocalEmbeddingRepository>,
    /// P6.1: triviumdb 后端（`<data_root>/_tauritavern/databases`）。
    pub database_backend: Arc<dyn DatabaseBackend>,
    /// P6.1: 供应商元数据（HTTP）。
    pub provider_metadata_repository: Arc<dyn ProviderMetadataRepository>,
    /// P6.1: SearXNG 搜索（HTTP）。
    pub searxng_search_repository: Arc<dyn SearxngSearchRepository>,
    /// P6.1: LLM 连接（`<data_root>/_tauritavern/llm-connections`）。
    pub llm_connection_repository: Arc<dyn LlmConnectionRepository>,
    /// P6.1: 扩展商店（base + staging，见 `FileExtensionStoreRepository`）。
    pub extension_store_repository: Arc<FileExtensionStoreRepository>,
    /// P6.2: 第三方扩展（用户 + 全局 + 源码区，见 `FileExtensionRepository`）。
    pub extension_repository: Arc<dyn ExtensionRepository>,
}

pub async fn build(
    context: &HostContext,
    startup: &StartupProfile,
) -> Result<AppRepositories, DomainError> {
    let data_directory = &context.data_directory;
    let data_root = data_directory.root().to_path_buf();
    let default_user_dir = data_directory.default_user().to_path_buf();

    // The persisted settings block, not `TauriTavernSettings::default()`: the chat
    // repository needs the *user's* backup policy, and services need `allow_keys_exposure`.
    let tauritavern_settings = startup.tauritavern_settings.clone();

    // P5: the full constructor, not `new()`. `new()` is documented upstream as
    // "for tests and standalone tools"; runtime composition must inject the shared
    // alias store, the user's backup settings, the page-generation tracker and the
    // commit frame budget, otherwise chat backups and cache invalidation silently
    // diverge from upstream behaviour.
    let file_chat_repository = Arc::new(FileChatRepository::with_chat_aliases_and_backup_settings(
        data_directory.characters().to_path_buf(),
        data_directory.chats().to_path_buf(),
        data_directory.group_chats().to_path_buf(),
        data_directory.backups().to_path_buf(),
        new_shared_chat_alias_store_for_user_dir(&default_user_dir),
        tauritavern_settings.chat_backups.clone(),
        context.page_generation.clone(),
        COMMIT_FRAME_BYTES,
    ));
    file_chat_repository
        .cleanup_orphaned_chat_commit_staging()
        .await;

    let chat_repository: Arc<dyn ChatRepository> = file_chat_repository.clone();
    let group_chat_repository: Arc<dyn GroupChatRepository> = file_chat_repository.clone();
    let chat_backup_runtime: Arc<dyn ChatBackupRuntime> = file_chat_repository.clone();

    let character_repository: Arc<dyn CharacterRepository> =
        Arc::new(FileCharacterRepository::new(
            data_directory.characters().to_path_buf(),
            data_directory.chats().to_path_buf(),
            data_directory.default_avatar().to_path_buf(),
        ));

    let user_repository: Arc<dyn UserRepository> = Arc::new(FileUserRepository::new(
        data_directory.user_data().to_path_buf(),
    ));
    let user_directory_repository: Arc<dyn UserDirectoryRepository> =
        Arc::new(FileUserDirectoryRepository::new(data_root.clone()));

    let avatar_repository: Arc<dyn AvatarRepository> = Arc::new(FileAvatarRepository::new(
        default_user_dir.join("User Avatars"),
    ));

    // Default SillyTavern settings seed: embedded `default/content/settings.json`.
    // Upstream reads it through the Tauri resource bundle (`read_resource_json`).
    let default_user_settings: UserSettings = serde_json::from_str(
        context
            .resources
            .read_text("default/content/settings.json")?,
    )
    .map_err(|error| {
        DomainError::InvalidData(format!("bundled default user settings are invalid: {error}"))
    })?;

    let settings_repository = Arc::new(FileSettingsRepository::new(
        data_directory.settings().to_path_buf(),
        default_user_settings,
        tauritavern_settings.clone(),
        context.page_generation.clone(),
        COMMIT_FRAME_BYTES,
    ));
    settings_repository.cleanup_orphaned_commit_staging().await;
    // Materialize settings sections before any service can scan the data directory.
    settings_repository.load_user_settings().await?;

    let persona_root = default_user_dir.clone();
    tokio::task::spawn_blocking(move || {
        tt_adapter_media::persona_cards::migrate_personas(&persona_root, &persona_root)
    })
    .await
    .map_err(|error| DomainError::InternalError(error.to_string()))??;

    let secret_repository: Arc<dyn SecretRepository> = Arc::new(FileSecretRepository::new(
        default_user_dir.join("secrets.json"),
    ));
    let group_repository: Arc<dyn GroupRepository> = Arc::new(FileGroupRepository::new(
        data_directory.groups().to_path_buf(),
        data_directory.group_chats().to_path_buf(),
    ));
    let world_info_repository: Arc<dyn WorldInfoRepository> =
        Arc::new(FileWorldInfoRepository::new(
            default_user_dir.join("worlds"),
            context.page_generation.clone(),
            COMMIT_FRAME_BYTES,
        ));
    // P6.2: agent 域仓库。路径与上游 `composition/repositories.rs` 一致：
    // `FileAgentProfileRepository::new(<data_root>/_tauritavern/agent-profiles)`，
    // `FileAgentRepository::new(<data_root>/_tauritavern/agent-workspaces)` 克隆出 5 个 trait。
    let agent_profile_file_repository = Arc::new(FileAgentProfileRepository::new(
        data_root.join("_tauritavern").join("agent-profiles"),
    ));
    let agent_profile_repository: Arc<dyn AgentProfileRepository> =
        agent_profile_file_repository.clone();
    let agent_profile_storage_health_repository: Arc<dyn AgentProfileStorageHealthRepository> =
        agent_profile_file_repository;
    let file_agent_repository = Arc::new(FileAgentRepository::new(
        data_root.join("_tauritavern").join("agent-workspaces"),
    ));
    let agent_run_repository: Arc<dyn AgentRunRepository> = file_agent_repository.clone();
    let agent_session_repository: Arc<dyn AgentSessionRepository> = file_agent_repository.clone();
    let agent_invocation_repository: Arc<dyn AgentInvocationRepository> =
        file_agent_repository.clone();
    let workspace_repository: Arc<dyn WorkspaceRepository> = file_agent_repository.clone();
    let agent_workspace_lifecycle_repository: Arc<dyn AgentWorkspaceLifecycleRepository> =
        file_agent_repository;
    let tokenizer_repository: Arc<dyn TokenizerRepository> =
        Arc::new(MiktikTokenizerRepository::new(
            data_root.join("_tauritavern").join("tokenizers"),
            context.http_client_pool.clone(),
        ));

    // P5: LLM 生成通道与 prompt cache。路径与上游 `composition/repositories.rs` 一致
    // （`<data_root>/_tauritavern/prompt-cache`）。
    let chat_completion_repository: Arc<dyn ChatCompletionRepository> = Arc::new(
        HttpChatCompletionRepository::new(context.http_client_pool.clone()),
    );
    let prompt_cache_repository: Arc<dyn PromptCacheRepository> = Arc::new(
        FilePromptCacheRepository::new(data_root.join("_tauritavern").join("prompt-cache")),
    );

    // Seeds `default/content/**` into the user directory; reads the embedded bundle
    // instead of the Tauri resource dir (`context.resources`).
    let content_repository: Arc<dyn ContentRepository> = Arc::new(FileContentRepository::new(
        context.resources.clone(),
        data_root.clone(),
        default_user_dir.clone(),
    ));

    // ===== P6.1 repositories（路径与上游 `composition/repositories.rs` 一致）=====
    let preset_repository: Arc<dyn PresetRepository> = Arc::new(FilePresetRepository::new(
        context.resources.clone(),
        default_user_dir.clone(),
        content_repository.clone(),
    ));

    let mcp_server_repository: Arc<dyn McpServerRepository> = Arc::new(
        FileMcpServerRepository::new(data_root.join("_tauritavern").join("mcp")),
    );

    let skill_repository: Arc<dyn SkillRepository> = Arc::new(FileSkillRepository::new(
        data_root.join("_tauritavern").join("skills"),
        materialize_builtin_skills(&context.resources, &data_root).await?,
    ));

    let extension_store_repository = Arc::new(FileExtensionStoreRepository::new(
        data_root.join("_tauritavern").join("extension-store"),
        data_root.join(".staging").join("extension-store"),
        context.page_generation.clone(),
        COMMIT_FRAME_BYTES,
    ));
    extension_store_repository
        .cleanup_orphaned_commit_staging()
        .await;

    // P6.2: 第三方扩展仓库，路径与上游一致：
    // `<default-user>/extensions` + `<data_root>/extensions/third-party`（全局）+
    // `<data_root>/_tauritavern/extension-sources`（源码区），共享宿主 http 客户端池。
    let extension_repository: Arc<dyn ExtensionRepository> = Arc::new(
        FileExtensionRepository::new(
            default_user_dir.join("extensions"),
            data_directory.global_extensions().to_path_buf(),
            data_directory.extension_sources().to_path_buf(),
            context.http_client_pool.clone(),
        ),
    );

    let vector_repository: Arc<dyn VectorRepository> = Arc::new(RedbVectorRepository::new(
        default_user_dir.join("vectors").join("tauritavern-v1.redb"),
    ));
    let remote_embedding_repository: Arc<dyn RemoteEmbeddingRepository> =
        Arc::new(HttpEmbeddingRepository::new(context.http_client_pool.clone()));
    let local_embedding_repository: Arc<dyn LocalEmbeddingRepository> = Arc::new(
        CandleLocalEmbeddingRepository::new(data_root.join("_cache").join("embedding-models")),
    );

    let database_backend: Arc<dyn DatabaseBackend> =
        Arc::new(TriviumDatabaseBackend::new(
            data_root.join("_tauritavern").join("databases"),
        ));

    let provider_metadata_repository: Arc<dyn ProviderMetadataRepository> =
        Arc::new(HttpProviderMetadataRepository::new(context.http_client_pool.clone()));
    let searxng_search_repository: Arc<dyn SearxngSearchRepository> =
        Arc::new(HttpSearxngSearchRepository::new(context.http_client_pool.clone()));
    let llm_connection_repository: Arc<dyn LlmConnectionRepository> =
        Arc::new(FileLlmConnectionRepository::new(
            data_root.join("_tauritavern").join("llm-connections"),
        ));

    Ok(AppRepositories {
        user_repository,
        user_directory_repository,
        avatar_repository,
        settings_repository: settings_repository as Arc<dyn SettingsRepository>,
        secret_repository,
        character_repository,
        chat_repository,
        group_chat_repository,
        group_repository,
        world_info_repository,
        agent_profile_repository,
        agent_profile_storage_health_repository,
        agent_run_repository,
        agent_session_repository,
        agent_invocation_repository,
        workspace_repository,
        agent_workspace_lifecycle_repository,
        chat_backup_runtime,
        tokenizer_repository,
        content_repository,
        chat_completion_repository,
        prompt_cache_repository,
        preset_repository,
        mcp_server_repository,
        skill_repository,
        vector_repository,
        remote_embedding_repository,
        local_embedding_repository,
        database_backend,
        provider_metadata_repository,
        searxng_search_repository,
        llm_connection_repository,
        extension_store_repository,
        extension_repository,
    })
}
