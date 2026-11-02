// P8-3/P8-4 新增命令的 DTO 与类型（对应 Rust 侧 tt-contracts）。
//
// 字段命名遵循各命令的既有约定（Rust serde 默认 snake_case，但少数命令
// 用 camelCase require，例如 delete_chat 的 characterName / fileName）。
// 对应 DevEco 工程路径：entry/src/main/ets/backend/AdminTypes.ets

/** 新建角色（create_character 的 dto）。 */
export interface CreateCharacterDto {
  name: string;
  description: string;
  personality: string;
  scenario: string;
  first_mes: string;
  mes_example: string;
  file_name?: string;
  creator?: string;
  creator_notes?: string;
  character_version?: string;
  tags?: string[];
  talkativeness?: number;
  alternate_greetings?: string[];
  system_prompt?: string;
  post_history_instructions?: string;
}

/** 更新角色（update_character 的 dto，全部可选）。 */
export interface UpdateCharacterDto {
  name?: string;
  description?: string;
  personality?: string;
  scenario?: string;
  first_mes?: string;
  mes_example?: string;
  creator?: string;
  creator_notes?: string;
  character_version?: string;
  tags?: string[];
  talkativeness?: number;
  fav?: boolean;
  alternate_greetings?: string[];
  system_prompt?: string;
  post_history_instructions?: string;
}

/** 删除角色。 */
export interface DeleteCharacterDto {
  name: string;
  delete_chats: boolean;
}

/** 重命名角色。 */
export interface RenameCharacterDto {
  old_name: string;
  new_name: string;
}

/** 复制角色。 */
export interface DuplicateCharacterDto {
  name: string;
}

/** 重命名会话。 */
export interface RenameChatDto {
  character_name: string;
  old_file_name: string;
  new_file_name: string;
}

/** 恢复会话备份。 */
export interface RestoreCharacterChatBackupDto {
  backup_name: string;
  character_name: string;
  character_display_name: string;
}

/** 导出角色内容（export_character_content 返回任意 JSON）。 */
export interface ExportCharacterContentDto {
  name: string;
  format: string;
}

/** 会话搜索结果（search_chats / list_chat_backups 共用）。 */
export interface ChatSearchResult {
  character_name: string;
  file_name: string;
  file_size?: string;
  message_count?: number;
  preview_message?: string;
  last_message?: string;
  last_mes?: string;
  create_date?: string;
  match_type?: string;
  score?: number;
}

/** list_chat_backup_catalog 的一项（Rust ChatBackupCatalogEntry，snake_case）。 */
export interface ChatBackupCatalogEntry {
  file_name: string;
  stored_size: number;
  backup_date: number;
  message_count?: number;
}
