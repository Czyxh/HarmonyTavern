//! Cache reconciler after external data changes (rebuilt from upstream
//! `app/composition/adapters/cache_reconciler.rs`, P6.1).
//!
//! 对应 DevEco 工程路径：native/crates/ttavern/src/host/cache_reconciler.rs

use std::sync::Arc;

use async_trait::async_trait;

use tt_application::services::character_service::CharacterService;
use tt_application::services::chat_history_coordinator::ChatHistoryCoordinator;
use tt_application::services::chat_service::ChatService;
use tt_application::services::group_chat_service::GroupChatService;
use tt_application::services::group_service::GroupService;
use tt_application::services::mcp_service::McpService;
use tt_application::services::secret_service::SecretService;
use tt_application::services::settings_service::SettingsService;
use tt_domain::errors::DomainError;
use tt_ports::sync::DataChangeReconciler;

pub struct ServiceCacheReconciler {
    character_service: Arc<CharacterService>,
    chat_service: Arc<ChatService>,
    group_chat_service: Arc<GroupChatService>,
    group_service: Arc<GroupService>,
    secret_service: Arc<SecretService>,
    settings_service: Arc<SettingsService>,
    mcp_service: Arc<McpService>,
    chat_history_coordinator: Arc<ChatHistoryCoordinator>,
}

impl ServiceCacheReconciler {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        character_service: Arc<CharacterService>,
        chat_service: Arc<ChatService>,
        group_chat_service: Arc<GroupChatService>,
        group_service: Arc<GroupService>,
        secret_service: Arc<SecretService>,
        settings_service: Arc<SettingsService>,
        mcp_service: Arc<McpService>,
        chat_history_coordinator: Arc<ChatHistoryCoordinator>,
    ) -> Self {
        Self {
            character_service,
            chat_service,
            group_chat_service,
            group_service,
            secret_service,
            settings_service,
            mcp_service,
            chat_history_coordinator,
        }
    }
}

#[async_trait]
impl DataChangeReconciler for ServiceCacheReconciler {
    async fn reconcile(&self, reason: &str) -> Result<(), DomainError> {
        tracing::info!(
            reason = reason,
            "Refreshing runtime caches after external data change"
        );

        self.chat_history_coordinator.invalidate_all_pending().await;
        self.mcp_service.clear_catalog_memory();

        self.character_service.clear_cache().await?;
        self.chat_service.clear_cache().await?;
        self.group_chat_service.clear_cache().await?;
        self.group_service.clear_cache().await?;
        self.secret_service.clear_cache().await?;
        self.settings_service.reload().await?;

        Ok(())
    }
}
