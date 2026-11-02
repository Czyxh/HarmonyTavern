// TauriTavern 应用层设置（对应 Rust TauriTavernSettingsDto / UpdateTauriTavernSettingsDto）。
//
// 这些是"壳层"设置（备份、代理、日志、性能开关），与 SillyTavern 自身的
// 模型/密钥设置不同——原项目把它们放在独立的 Settings 应用里，这里一比一对照。
//
// 对应 DevEco 工程路径：entry/src/main/ets/backend/SettingsTypes.ets

/** 备份设置。 */
export interface ChatBackupSettings {
  automatic_enabled: boolean;
  zstd_compression_enabled: boolean;
  max_files_per_prefix: number;
  max_total_files: number;
  max_total_bytes: number;
}

export interface UpdateChatBackupSettings {
  automatic_enabled?: boolean;
  zstd_compression_enabled?: boolean;
  max_files_per_prefix?: number;
  max_total_files?: number;
  max_total_bytes?: number;
}

/** 请求代理设置。 */
export interface RequestProxySettings {
  enabled: boolean;
  url: string;
  bypass: string[];
}

/** 开发日志设置。 */
export interface DevLoggingSettings {
  frontend_console_capture: boolean;
  llm_api_keep: number;
}

export interface UpdateDevLoggingSettings {
  frontend_console_capture?: boolean;
  llm_api_keep?: number;
}

/** 动态主题与壁纸。 */
export interface DynamicThemeSettings {
  enabled: boolean;
  day_theme: string;
  night_theme: string;
  wallpaper_enabled: boolean;
  day_wallpaper: string;
  night_wallpaper: string;
}

export interface UpdateDynamicThemeSettings {
  enabled?: boolean;
  day_theme?: string;
  night_theme?: string;
  wallpaper_enabled?: boolean;
  day_wallpaper?: string;
  night_wallpaper?: string;
}

/** Claude 模型设置（prompt cache TTL: off | 5m | 1h）。 */
export interface ClaudeModelSettings {
  prompt_cache_ttl: string;
}

export interface ModelSettings {
  claude: ClaudeModelSettings;
}

export interface UpdateModelSettings {
  claude?: ClaudeModelSettings;
}

/** Agent 运行保留策略。 */
export interface AgentRunRetentionSettings {
  auto_prune_enabled: boolean;
  keep_recent_terminal_runs: number;
  keep_full_recent_runs: number;
}

export interface AgentSettings {
  retention: AgentRunRetentionSettings;
}

export interface UpdateAgentSettings {
  retention?: AgentRunRetentionSettings;
}

/** 启动更新弹窗设置。 */
export interface StartupUpdatePopupSettings {
  enabled: boolean;
}

export interface TauriTavernUpdateSettings {
  channel: string;
  startup_popup: StartupUpdatePopupSettings;
}

export interface UpdateTauriTavernSettings {
  updates?: TauriTavernUpdateSettings;
  perf_profile?: string;
  panel_runtime_profile?: string;
  embedded_runtime_profile?: string;
  chat_virtualization_enabled?: boolean;
  cold_swipes_enabled?: boolean;
  codemirror_editor_enabled?: boolean;
  chat_backups?: UpdateChatBackupSettings;
  close_to_tray_on_close?: boolean;
  request_proxy?: RequestProxySettings;
  allow_keys_exposure?: boolean;
  avatar_persona_original_images_enabled?: boolean;
  dev?: UpdateDevLoggingSettings;
  dynamic_theme?: UpdateDynamicThemeSettings;
  models?: UpdateModelSettings;
  agent?: UpdateAgentSettings;
}

/** 完整设置快照（get_tauritavern_settings）。 */
export interface TauriTavernSettings {
  updates: TauriTavernUpdateSettings;
  perf_profile: string;
  panel_runtime_profile: string;
  embedded_runtime_profile: string;
  chat_virtualization_enabled: boolean;
  cold_swipes_enabled: boolean;
  codemirror_editor_enabled: boolean;
  chat_backups: ChatBackupSettings;
  close_to_tray_on_close: boolean;
  request_proxy: RequestProxySettings;
  allow_keys_exposure: boolean;
  avatar_persona_original_images_enabled: boolean;
  dev: DevLoggingSettings;
  dynamic_theme: DynamicThemeSettings;
  models: ModelSettings;
  agent: AgentSettings;
}

/** 备份占用统计（get_chat_backup_storage_stats）。 */
export interface ChatBackupStorageStats {
  original_bytes: number;
  stored_bytes: number;
}
