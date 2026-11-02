/**
 * 后端门面（ArkTS 侧唯一的 Rust 调用入口）。
 *
 * 设计：Rust 只暴露 5 个 NAPI 符号，业务全部走 `invoke(command, payloadJson)`。
 * 本模块承担三件事：
 *  1. 生命周期：采集沙箱路径 → initialize(pathsJson) → 轮询 getBackendStatus 直到 ready；
 *  2. 命令调用：把 JSON 信封拆开，成功返回强类型数据，失败抛 BackendError（带 code）；
 *  3. 事件订阅：把 setEventListener 的原始信封分发给按事件名注册的处理器。
 *
 * 对应 DevEco 工程路径：entry/src/main/ets/backend/Backend.ets
 * 原生库：entry/libs/{x86_64,arm64-v8a}/libttavern.so（由 native/scripts/build.ps1 产出）
 */

import native from 'libttavern.so';
import { CallLog } from './CallLog';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { util } from '@kit.ArkTS';
import {
  ChatSearchResult,
  CreateCharacterDto,
  DeleteCharacterDto,
  DuplicateCharacterDto,
  ExportCharacterContentDto,
  RenameCharacterDto,
  ChatBackupCatalogEntry,
  RenameChatDto,
  RestoreCharacterChatBackupDto,
  UpdateCharacterDto
} from './AdminTypes';
import {
  ChatBackupStorageStats,
  TauriTavernSettings,
  UpdateTauriTavernSettings
} from './SettingsTypes';
import {
  BackendEventEnvelope,
  BackendStatus,
  BootstrapMetadata,
  CallLegacyMcpToolDto,
  CharacterDto,
  ChatCompletionStreamReadResultDecodedDto,
  ChatDto,
  ChatMessageInput,
  ChatSearchResultDto,
  ClientVersion,
  CommandEnvelope,
  CreateMcpServerDto,
  CreateUserInput,
  DataArchiveJobStatus,
  DatabaseRequest,
  DeleteOpenAIPresetDto,
  DeleteOpenAIPresetResponseDto,
  DeletePresetDto,
  DeliveryResult,
  EntryKind,
  ExportedCharacterContent,
  ExternalImportDownload,
  GenerateRequestDto,
  ProviderRequestDto,
  ImportArchiveResult,
  ImportCharacterResult,
  ListImagesInput,
  ListLlmConnectionsResultDto,
  ListMcpServersResultDto,
  ListLegacyMcpToolsResultDto,
  LoadLlmConnectionResultDto,
  LlmConnectionIdDto,
  McpCallOutcomeDto,
  McpDiscoveryResultDto,
  McpExecutionCallIdDto,
  McpRegistrationIdDto,
  McpServerDto,
  McpTestCallIdDto,
  ProviderModelProvidersRequestDto,
  RestorePresetDto,
  RestorePresetResponseDto,
  RuntimePathsDto,
  SaveLlmConnectionDto,
  SavePresetDto,
  SavePresetResponseDto,
  SearxngSearchRequestDto,
  SetMcpServerStateDto,
  SetMcpToolDescriptionOverrideDto,
  SetMcpToolPermissionDto,
  SiliconFlowEmbeddingModelsRequestDto,
  SkillExportPayload,
  SkillFileRef,
  SkillImportInput,
  SkillImportPreview,
  SkillIndexEntry,
  SkillInstallRequest,
  SkillInstallResult,
  SkillMoveRequest,
  SkillReadResult,
  SkillScope,
  SkillScopeFilter,
  SkillScopeRetargetRequest,
  SkillScopeRetargetResult,
  TestMcpToolCallDto,
  UpdateMcpServerDto,
  UploadImageInput,
  UserDirectoryDto,
  UserDto,
  UserFileUploadResult,
  UserImageUploadResult,
  VectorRouteRequestDto,
  VectorRouteResponseDto,
  WorkersAiModelsRequestDto
} from './Types';

// P6.2 类型（agent / extension / sync 域，见 Types.ets 同名定义）。
import {
  AgentActiveRunDto,
  AgentApplyCurrentModelConnectionSnapshotDto,
  AgentApplyCurrentModelConnectionSnapshotResultDto,
  AgentApplyRunPruneDto,
  AgentBuildCurrentModelConnectionSnapshotDto,
  AgentBuildCurrentModelConnectionSnapshotResultDto,
  AgentCancelRunDto,
  AgentCopyChatPersistentStatesDto,
  AgentDeleteSessionDto,
  AgentFinishRunPresentationDto,
  AgentListProfilesResultDto,
  AgentListRunsDto,
  AgentListRunsResultDto,
  AgentListToolsDto,
  AgentPlanRunPruneDto,
  AgentPreparePromptAssemblyDto,
  AgentRunPruneApplyResultDto,
  AgentRunPrunePlanDto,
  AgentPrepareSessionRunDto,
  AgentPruneChatPersistentStatesDto,
  AgentPruneChatPersistentStatesResultDto,
  AgentProfileIdDto,
  AgentReadEventsDto,
  AgentReadEventsResultDto,
  AgentReadModelTurnDto,
  AgentReadPromptAssemblyRequestDto,
  AgentReadRunCheckpointDto,
  AgentReadRunCheckpointResultDto,
  AgentReadSessionDto,
  AgentReadTaskDetailDto,
  AgentReadWorkspaceFileDto,
  AgentRenameSessionDto,
  AgentRepairProfileFileDto,
  AgentResolveChatCommitDto,
  AgentResolvePersistentStateMetadataUpdateDto,
  AgentResolvePromptAssemblyDto,
  AgentResolveSystemPromptDto,
  AgentResolveSystemPromptResultDto,
  AgentResumeRunDto,
  AgentRetargetPresetRefsDto,
  AgentRetargetPresetRefsResultDto,
  AgentRunHandleDto,
  AgentSaveProfileDto,
  AgentSessionProfileResultDto,
  AgentSessionResultDto,
  AgentSessionRunHandleDto,
  AgentStartRunDto,
  AgentStartSessionRunDto,
  AgentSubmitGuidanceDto,
  AgentSubmitGuidanceResultDto,
  AgentSubscribeRunLiveProjectionDto,
  AgentWorkspaceFileDto,
  Extension,
  ExtensionBranch,
  ExtensionInstallResult,
  ExtensionUpdateResult,
  ExtensionVersion,
  LanSyncPairedDeviceDto,
  LanSyncPairingInfoDto,
  OverwritePolicy,
  SyncDatasetCatalogDto,
  SyncMode,
  SyncOperationOptions,
  TtSyncPairedServerDto
} from './Types';

const DOMAIN: number = 0x0001;
const TAG: string = 'HarmonyTavern';

/** 命令失败：`code` 与 Rust 侧 CommandError::code() 一致，可直接用于 UI 分支。 */
export class BackendError extends Error {
  code: string;

  constructor(code: string, message: string) {
    super(message);
    this.name = 'BackendError';
    this.code = code;
  }
}

export type EventHandler = (payload: ESObject) => void;

class BackendFacade {
  private initialized: boolean = false;
  private statusJson: string = '';
  private handlers: Map<string, EventHandler[]> = new Map<string, EventHandler[]>();
  // 初始化进行中的 Promise（不 reject，失败时置 initFailed）—— 供 call() 等待，避免竞态。
  private initPromise: Promise<void> | null = null;
  private initFailed: boolean = false;

  /** 是否已完成 initialize 且后端 ready。 */
  isReady(): boolean {
    return this.initialized;
  }

  /**
   * 命令就绪闸门：未初始化时，若初始化正在进行则等待其完成；
   * 若从未有人初始化则抛明确错误（正常流程里 Index 总会先调 initialize）。
   */
  private ensureReady(): Promise<void> {
    if (this.initialized) {
      return Promise.resolve();
    }
    if (this.initFailed) {
      return Promise.reject(new BackendError('internal',
        'Backend initialization failed; see Index page for the failing step'));
    }
    if (this.initPromise !== null) {
      return this.initPromise;
    }
    return Promise.reject(new BackendError('internal',
      'Backend is not initialized; call initialize(pathsJson) first'));
  }

  /**
   * 规范化端点基址。Rust 侧 `parse_endpoint_base`（tt-domain endpoint_url.rs）要求：
   * 绝对 URL（无协议头报 "relative URL without a base"）、无 query/fragment（会被拒绝）。
   * 这里补协议头、去 query/fragment、去尾部斜杠、去掉误粘贴的完整 /chat/completions 路径
   * （OpenAI 兼容 builder 会自行拼接该路径）。
   */
  normalizeBaseUrl(raw: string): string {
    let url: string = raw.trim();
    if (url === '') {
      return '';
    }
    if (!/^[a-zA-Z][a-zA-Z0-9+.-]*:\/\//.test(url)) {
      url = 'https://' + url;
    }
    const cut: number = url.search(/[?#]/);
    if (cut >= 0) {
      url = url.substring(0, cut);
    }
    if (url.endsWith('/chat/completions')) {
      url = url.substring(0, url.length - '/chat/completions'.length);
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  // ---- P1 桥接自检（不依赖 initialize，直接验证 .so 加载与 NAPI 注册）----
  //
  // 这两个函数是 objective 第一阶段的验收物：ArkTS 调 Rust 返回 Hello。
  // 它们必须始终可达，否则「NAPI 桥接可用」这件事就只存在于历史记录里，
  // 一旦哪天 .so 加载或符号注册出问题，最早的报警信号反而消失了。

  /** 返回 Rust 侧字符串（预期 "Hello from Rust" 一类）。 */
  hello(): string {
    return native.hello();
  }

  /** 返回 Rust 侧求和（用于验证参数/返回值双向传递）。 */
  add(a: number, b: number): number {
    return native.add(a, b);
  }

  /**
   * 初始化原生后端。可重复调用（Rust 侧幂等）。
   * @param payload 沙箱路径（必须全是绝对路径，来自 UIAbilityContext）
   */
  async initialize(payload: OhosPathsPayloadLike): Promise<BackendStatus> {
    const task = (async (): Promise<BackendStatus> => {
      const json: string = JSON.stringify(payload);
      const raw: string = await native.initialize(json);
      const status: BackendStatus = JSON.parse(raw) as BackendStatus;
      this.statusJson = raw;
      this.initialized = status.ready;
      this.attachEventListener();
      hilog.info(DOMAIN, TAG, 'backend initialized: ready=%{public}s version=%{public}s',
        String(status.ready), status.version);
      return status;
    })();
    // 供 ensureReady() 等待；永远 resolve，失败只置标记（真实结果由 task 抛给调用方）。
    this.initPromise = task.then((): void => {
    }).catch((err: ESObject): void => {
      this.initFailed = true;
      hilog.error(DOMAIN, TAG, 'initialize failed: %{public}s', String(err));
    });
    return task;
  }

  /** 最近一次状态 JSON（未初始化时为空串）。 */
  lastStatusJson(): string {
    return this.statusJson;
  }

  /** 主动查询状态。 */
  async status(): Promise<BackendStatus> {
    const raw: string = await native.getBackendStatus();
    return JSON.parse(raw) as BackendStatus;
  }

  /**
   * 调用后端命令。
   * @param command 命令名（与上游 TauriTavern 同名）
   * @param payload 命名参数对象；无参命令传 undefined
   */
  async call<T>(command: string, payload?: ESObject): Promise<T> {
    // 就绪闸门：等 Index 的 initialize 完成（或失败时报明确错误），杜绝竞态/恢复页未初始化。
    await this.ensureReady();
    const payloadJson: string = payload === undefined ? '' : JSON.stringify(payload);
    const started: number = Date.now();
    // 调用日志：给「应用内活动日志」页提供真实数据（等价原项目 LiveLogPanel）。
    try {
      const raw: string = await native.invoke(command, payloadJson);
      const elapsed: number = Date.now() - started;
      const envelope: CommandEnvelope = JSON.parse(raw) as CommandEnvelope;
      if (!envelope.ok) {
        const code: string = envelope.error !== undefined ? envelope.error.code : 'internal';
        const message: string = envelope.error !== undefined ? envelope.error.message : 'command failed';
        CallLog.record(command, false, elapsed, payloadJson.length, `[${code}] ${message}`);
        hilog.error(DOMAIN, TAG, 'command %{public}s failed [%{public}s]: %{public}s',
          command, code, message);
        throw new BackendError(code, message);
      }
      CallLog.record(command, true, elapsed, payloadJson.length,
        `data ${envelope.data === undefined || envelope.data === null ? 'null' : typeof envelope.data}`);
      return envelope.data as T;
    } catch (err) {
      if (err instanceof BackendError) {
        throw err;
      }
      CallLog.record(command, false, Date.now() - started, payloadJson.length,
        `bridge error: ${(err as Error).message}`);
      throw new BackendError('bridge', (err as Error).message);
    }
  }

  /** 订阅某个事件名（可多次订阅，返回取消函数）。 */
  on(event: string, handler: EventHandler): () => void {
    const list: EventHandler[] = this.handlers.get(event) ?? [];
    list.push(handler);
    this.handlers.set(event, list);
    return () => {
      const current: EventHandler[] = this.handlers.get(event) ?? [];
      const index: number = current.indexOf(handler);
      if (index >= 0) {
        current.splice(index, 1);
        this.handlers.set(event, current);
      }
    };
  }

  private attachEventListener(): void {
    // 只注册一次；Rust 侧 setListener 会替换旧回调。
    native.setEventListener((envelope: string) => {
      try {
        const parsed: BackendEventEnvelope = JSON.parse(envelope) as BackendEventEnvelope;
        const list: EventHandler[] = this.handlers.get(parsed.event) ?? [];
        list.forEach((handler: EventHandler) => {
          try {
            handler(parsed.payload);
          } catch (inner) {
            hilog.error(DOMAIN, TAG, 'event handler threw for %{public}s', parsed.event);
          }
        });
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'failed to parse event envelope');
      }
    });
  }

  // ---- 业务命令（P3 批次） ----

  getBootstrapMetadata(): Promise<BootstrapMetadata> {
    return this.call<BootstrapMetadata>('get_bootstrap_metadata', undefined);
  }

  waitForBackendReady(): Promise<void> {
    return this.call<void>('wait_for_backend_ready', undefined);
  }

  backendErrorBridgeReady(): Promise<string[]> {
    return this.call<string[]>('backend_error_bridge_ready', undefined);
  }

  getRuntimePaths(): Promise<RuntimePathsDto> {
    return this.call<RuntimePathsDto>('get_runtime_paths', undefined);
  }

  getAllUsers(): Promise<UserDto[]> {
    return this.call<UserDto[]>('get_all_users', undefined);
  }

  createUser(input: CreateUserInput): Promise<UserDto> {
    const payload: CreateUserPayload = { dto: input };
    return this.call<UserDto>('create_user', payload);
  }

  deleteUser(id: string): Promise<void> {
    const payload: DeleteUserPayload = { id: id };
    return this.call<void>('delete_user', payload);
  }

  getUserDirectory(handle: string): Promise<UserDirectoryDto> {
    const payload: HandlePayload = { handle: handle };
    return this.call<UserDirectoryDto>('get_user_directory', payload);
  }

  // ---- 用户 / persona（P8-12 补齐）----

  getUser(id: string): Promise<ESObject> {
    return this.call<ESObject>('get_user', { id: id });
  }

  /** 部分更新：只传要改的字段。 */
  updateUser(dto: ESObject): Promise<ESObject> {
    return this.call<ESObject>('update_user', { dto: dto });
  }

  // ---- 密钥管理（P8-13 补齐）----

  /** 返回 { key: 掩码值 }。需要 allowKeysExposure 打开才能真正看到明文。 */
  viewSecrets(): Promise<ESObject> {
    return this.call<ESObject>('view_secrets', undefined);
  }

  /** { key, id? } → { value }。 */
  findSecret(key: string, id?: string): Promise<ESObject> {
    const dto: SecretKeyIdDto = id === undefined ? { key: key } : { key: key, id: id };
    return this.call<ESObject>('find_secret', { dto: dto });
  }

  /** 改名（label），需要 key + id + label。 */
  renameSecret(key: string, id: string, label: string): Promise<void> {
    const dto: SecretKeyIdLabelDto = { key: key, id: id, label: label };
    return this.call<void>('rename_secret', { dto: dto });
  }

  deleteSecret(key: string, id?: string): Promise<void> {
    const dto: SecretKeyIdDto = id === undefined ? { key: key } : { key: key, id: id };
    return this.call<void>('delete_secret', { dto: dto });
  }

  /** 轮换：同一 key 下换到另一个 id 生效。 */
  rotateSecret(key: string, id: string): Promise<void> {
    const dto: SecretKeyIdOnlyDto = { key: key, id: id };
    return this.call<void>('rotate_secret', { dto: dto });
  }

  /** { allowKeysExposure } */
  readSecretSettings(): Promise<ESObject> {
    return this.call<ESObject>('read_secret_settings', undefined);
  }

  initializeDefaultContent(): Promise<void> {
    return this.call<void>('initialize_default_content', undefined);
  }

  isDefaultContentInitialized(): Promise<boolean> {
    return this.call<boolean>('is_default_content_initialized', undefined);
  }

  // ---- P4 批次：文件 / 图片 / 角色卡 / 版本 ----

  getClientVersion(): Promise<ClientVersion> {
    return this.call<ClientVersion>('get_client_version', undefined);
  }

  sanitizeFilename(fileName: string): Promise<string> {
    const payload: FileNamePayload = { fileName: fileName };
    return this.call<string>('sanitize_filename', payload);
  }

  /** 上传到 default-user/user/files/，返回 SillyTavern 风格路径 /user/files/<name>。 */
  uploadUserFile(name: string, dataBase64: string): Promise<UserFileUploadResult> {
    const payload: UploadFilePayload = { name: name, dataBase64: dataBase64 };
    return this.call<UserFileUploadResult>('upload_user_file', payload);
  }

  deleteUserFile(path: string): Promise<void> {
    const payload: PathPayload = { path: path };
    return this.call<void>('delete_user_file', payload);
  }

  verifyUserFiles(urls: string[]): Promise<Record<string, boolean>> {
    const payload: UrlsPayload = { urls: urls };
    return this.call<Record<string, boolean>>('verify_user_files', payload);
  }

  /** 换角色头像（P8-17）：avatarPath 传 uploadUserImage 返回的 path。 */
  updateAvatar(name: string, avatarPath: string): Promise<void> {
    const dto: UpdateAvatarDtoShape = { name: name, avatar_path: avatarPath };
    return this.call<void>('update_avatar', { dto: dto });
  }

  /** 建角色并同时设头像。 */
  createCharacterWithAvatar(character: ESObject, avatarPath?: string): Promise<ESObject> {
    const dto: ESObject = avatarPath === undefined
      ? { character: character }
      : { character: character, avatar_path: avatarPath };
    return this.call<ESObject>('create_character_with_avatar', { dto: dto });
  }

  uploadUserImage(input: UploadImageInput): Promise<UserImageUploadResult> {
    const payload: UploadImagePayload = {
      imageBase64: input.imageBase64,
      format: input.format,
      filename: input.filename,
      chName: input.chName
    };
    return this.call<UserImageUploadResult>('upload_user_image', payload);
  }

  listUserImages(input: ListImagesInput): Promise<string[]> {
    const payload: ListImagesPayload = {
      folder: input.folder,
      sortField: input.sortField,
      sortOrder: input.sortOrder,
      mediaType: input.mediaType
    };
    return this.call<string[]>('list_user_images', payload);
  }

  listUserImageFolders(): Promise<string[]> {
    return this.call<string[]>('list_user_image_folders', undefined);
  }

  deleteUserImage(path: string): Promise<void> {
    const payload: PathPayload = { path: path };
    return this.call<void>('delete_user_image', payload);
  }

  /**
   * 导入角色卡。ilePath 必须是沙箱内绝对路径：ArkTS 先用文件选择器选中，
   * 拷贝到 <cacheDir>/imports/<uuid>.<ext>，避免把十几 MB 的卡片塞进 base64 JSON。
   */
  importCharacter(filePath: string, preserveFileName?: string): Promise<ImportCharacterResult> {
    const payload: ImportCharacterPayload = {
      dto: { file_path: filePath, preserve_file_name: preserveFileName }
    };
    return this.call<ImportCharacterResult>('import_character', payload);
  }

  replaceCharacter(name: string, filePath: string): Promise<ImportCharacterResult> {
    const payload: ReplaceCharacterPayload = {
      dto: { name: name, file_path: filePath }
    };
    return this.call<ImportCharacterResult>('replace_character', payload);
  }

  /** 导出角色卡：返回 base64（上游走二进制响应，这里走 JSON 通道）。 */
  exportCharacterContent(name: string, format: string): Promise<ExportedCharacterContent> {
    const payload: ExportCharacterPayload = { dto: { name: name, format: format } };
    return this.call<ExportedCharacterContent>('export_character_content', payload);
  }

  /** 从公网下载待导入文件（返回 base64 + 文件名 + MIME）。 */
  downloadExternalImportUrl(url: string): Promise<ExternalImportDownload> {
    const payload: UrlPayload = { url: url };
    return this.call<ExternalImportDownload>('download_external_import_url', payload);
  }

  // ---- P5 批次：聊天 / 生成 / 密钥 ----

  getAllChats(): Promise<ChatDto[]> {
    return this.call<ChatDto[]>('get_all_chats', undefined);
  }

  /**
   * 导入单个聊天文件（P8-16）。
   * format：sillytavern | ooba | agnai | caitools | koboldlite | risuai
   * filePath 必须是后端可见的沙箱路径（ArkTS 先把选择器 URI 拷到 filesDir 再传）。
   */
  importChat(characterName: string, filePath: string, format: string): Promise<ChatDto> {
    const dto: ImportChatDtoShape = {
      character_name: characterName,
      file_path: filePath,
      format: format
    };
    return this.call<ChatDto>('import_chat', { dto: dto });
  }

  /** 导入角色的聊天文件，fileType 传 jsonl / json。 */
  importCharacterChats(characterName: string, filePath: string, fileType: string): Promise<string[]> {
    const dto: ImportCharacterChatsDtoShape = {
      character_name: characterName,
      file_path: filePath,
      file_type: fileType
    };
    return this.call<string[]>('import_character_chats', { dto: dto });
  }

  /** 聊天正文 .jsonl 的绝对沙箱路径（P8-18 消息编辑用）。 */
  getChatPayloadPath(characterName: string, fileName: string, allowNotFound: boolean): Promise<string> {
    return this.call<string>('get_chat_payload_path', {
      characterName: characterName,
      fileName: fileName,
      allow_not_found: allowNotFound
    });
  }

  /** 清空聊天缓存（直接改过 jsonl 之后必须调用）。 */
  clearChatCache(): Promise<void> {
    return this.call<void>('clear_chat_cache', undefined);
  }

  getChat(characterName: string, fileName: string): Promise<ChatDto> {
    const payload: ChatLocatorPayload = { characterName: characterName, fileName: fileName };
    return this.call<ChatDto>('get_chat', payload);
  }

  getCharacterChats(characterName: string): Promise<ChatDto[]> {
    const payload: CharacterNamePayload = { characterName: characterName };
    return this.call<ChatDto[]>('get_character_chats', payload);
  }

  /** 取角色聊天摘要（preview 字段即摘要文本；chat_id 可能为 null）。 */
  getCharacterChatSummary(characterName: string, fileName: string): Promise<ChatSearchResultDto> {
    const payload: ChatLocatorPayload = { characterName: characterName, fileName: fileName };
    return this.call<ChatSearchResultDto>('get_character_chat_summary', payload);
  }

  // ---- P8-3 角色管理（补齐 create/update/delete/rename/duplicate/export）----

  getCharacter(name: string): Promise<CharacterDto> {
    return this.call<CharacterDto>('get_character', { name: name });
  }

  createCharacter(dto: CreateCharacterDto): Promise<CharacterDto> {
    return this.call<CharacterDto>('create_character', { dto: dto });
  }

  updateCharacter(name: string, dto: UpdateCharacterDto): Promise<CharacterDto> {
    return this.call<CharacterDto>('update_character', { name: name, dto: dto });
  }

  deleteCharacter(dto: DeleteCharacterDto): Promise<void> {
    return this.call<void>('delete_character', { dto: dto });
  }

  renameCharacter(dto: RenameCharacterDto): Promise<CharacterDto> {
    return this.call<CharacterDto>('rename_character', { dto: dto });
  }

  duplicateCharacter(dto: DuplicateCharacterDto): Promise<CharacterDto> {
    return this.call<CharacterDto>('duplicate_character', { dto: dto });
  }


  // ---- P8-4 会话管理（重命名 / 删除 / 搜索 / 备份）----

  renameChat(dto: RenameChatDto): Promise<string> {
    return this.call<string>('rename_chat', { dto: dto });
  }

  /** 注意：delete_chat 的参数是 camelCase（Rust 侧 args.require("characterName")）。 */
  deleteChat(characterName: string, fileName: string): Promise<void> {
    return this.call<void>('delete_chat', { characterName: characterName, fileName: fileName });
  }

  searchChats(query: string, characterFilter?: string): Promise<ChatSearchResult[]> {
    const payload: SearchChatsPayload = { query: query };
    if (characterFilter !== undefined && characterFilter !== '') {
      payload.characterFilter = characterFilter;
    }
    return this.call<ChatSearchResult[]>('search_chats', payload);
  }

  backupChat(characterName: string, fileName: string): Promise<void> {
    return this.call<void>('backup_chat', { characterName: characterName, fileName: fileName });
  }

  listChatBackups(): Promise<ChatSearchResult[]> {
    return this.call<ChatSearchResult[]>('list_chat_backups', undefined);
  }

  deleteChatBackup(name: string): Promise<void> {
    return this.call<void>('delete_chat_backup', { name: name });
  }

  restoreCharacterChatBackup(dto: RestoreCharacterChatBackupDto): Promise<string> {
    return this.call<string>('restore_character_chat_backup', { dto: dto });
  }

  // ---- 壳层设置（原项目 TauriTavern Settings 应用，P8-5）----

  getTauriTavernSettings(): Promise<TauriTavernSettings> {
    return this.call<TauriTavernSettings>('get_tauritavern_settings', undefined);
  }

  /** 部分更新：只传要改的字段（Rust 侧是 Option 字段）。 */
  updateTauriTavernSettings(dto: UpdateTauriTavernSettings): Promise<void> {
    return this.call<void>('update_tauritavern_settings', { dto: dto });
  }

  /** Rust 侧返回 Option：没有备份时是 null，必须按可空处理（否则 UI 取值会崩）。 */
  getChatBackupStorageStats(): Promise<ChatBackupStorageStats | null> {
    return this.call<ChatBackupStorageStats | null>('get_chat_backup_storage_stats', undefined);
  }

  listChatBackupCatalog(): Promise<ChatBackupCatalogEntry[]> {
    return this.call<ChatBackupCatalogEntry[]>('list_chat_backup_catalog', undefined);
  }

  /** 备份文件名 → 恢复（原项目 Settings 里的备份管理）。 */
  // ---- 设置提交协议（P8-19）：整份 settings.json 分块上传 ----

  /** 开始一次设置提交；expectedRevision 传上次保存返回的 revision 可做乐观并发校验。 */
  beginSettingsCommit(expectedRevision?: UserSettingsRevisionShape): Promise<CommitBeginDto> {
    const payload: ESObject = expectedRevision === undefined
      ? {}
      : { expectedRevision: expectedRevision };
    return this.call<CommitBeginDto>('begin_settings_commit', payload);
  }

  /** 追加一块（base64），返回下一块的 offset。 */
  appendSettingsCommitChunk(sessionId: string, offset: number, chunkBase64: string): Promise<number> {
    const payload: SettingsChunkPayload = {
      sessionId: sessionId,
      offset: offset,
      chunkBase64: chunkBase64
    };
    return this.call<number>('append_settings_commit_chunk', payload);
  }

  /** 结束提交，expectedSize 必须等于总字节数。 */
  finishSettingsCommit(sessionId: string, expectedSize: number): Promise<UserSettingsSaveResultDto> {
    const payload: SettingsFinishPayload = {
      sessionId: sessionId,
      expectedSize: expectedSize
    };
    return this.call<UserSettingsSaveResultDto>('finish_settings_commit', payload);
  }

  /** 放弃提交。 */
  abortSettingsCommit(sessionId: string): Promise<void> {
    const payload: SettingsSessionPayload = { sessionId: sessionId };
    return this.call<void>('abort_settings_commit', payload);
  }

  // ---- P8-21：设置快照 / 聊天搜索 / token 计数 ----

  /** 创建一份设置快照（ST 的「备份当前设置」）。 */
  createSettingsSnapshot(): Promise<void> {
    return this.call<void>('create_settings_snapshot', undefined);
  }

  /** 列出所有设置快照。 */
  getSettingsSnapshots(): Promise<SettingsSnapshotDto[]> {
    return this.call<SettingsSnapshotDto[]>('get_settings_snapshots', undefined);
  }

  /** 读取某份快照内容（不恢复）。 */
  loadSettingsSnapshot(name: string): Promise<ESObject> {
    return this.call<ESObject>('load_settings_snapshot', { name: name });
  }

  /** 用某份快照覆盖当前设置。 */
  restoreSettingsSnapshot(name: string): Promise<void> {
    return this.call<void>('restore_settings_snapshot', { name: name });
  }


  /**
   * 统计一段文本在指定模型下的 token 数。
   * 走 count_openai_tokens_batch：请求体是 OpenAI chat 格式 messages。
   */
  countTokens(model: string, text: string): Promise<number> {
    const message: ESObject = { role: 'user', content: text };
    const messages: ESObject[] = [message];
    const item: TokenCountItemShape = { messages: messages };
    const items: TokenCountItemShape[] = [item];
    const dto: TokenCountRequestShape = { model: model, requests: items };
    return this.call<ESObject>('count_openai_tokens_batch', { dto: dto }).then((result: ESObject) => {
      const counts: number[] = result.token_counts as number[];
      return counts === undefined || counts === null || counts.length === 0 ? 0 : counts[0];
    });
  }

  // ---- P8-22：世界书（world info / lorebook），9 条 ----

  /** default-user/worlds/*.json 的书名列表。 */
  listWorldInfos(): Promise<string[]> {
    return this.call<string[]>('list_world_infos', undefined);
  }

  /** 读一本书；后端返回 JSON 文本，这里直接给出解析后的对象。 */
  getWorldInfo(name: string): Promise<ESObject> {
    return this.call<string>('get_world_info', { name: name }).then((text: string): ESObject => {
      return JSON.parse(text) as ESObject;
    });
  }

  /** 读一本书的原始 JSON 文本（编辑页用来做文本比对）。 */
  getWorldInfoText(name: string): Promise<string> {
    return this.call<string>('get_world_info', { name: name });
  }

  /**
   * 保存一本世界书。上游的 edit 接口吃 `{name, data}` 整包，所以这里也一样：
   * 走 begin → 分块 base64 → finish，最后按 `data` 里的名字落盘。
   */
  async saveWorldInfo(name: string, data: ESObject): Promise<void> {
    const request: WorldInfoSaveShape = { name: name, data: data };
    const text: string = JSON.stringify(request);
    const begin: CommitBeginDto = await this.beginWorldInfoCommit();
    try {
      const chunks: string[] = BackendFacade.splitBase64Frames(text);
      let offset: number = 0;
      for (let i = 0; i < chunks.length; i++) {
        offset = await this.appendWorldInfoCommitChunk(begin.sessionId, offset, chunks[i]);
      }
      await this.finishWorldInfoCommit(begin.sessionId, offset);
    } catch (err) {
      await this.abortWorldInfoCommit(begin.sessionId);
      throw err as Error;
    }
  }

  beginWorldInfoCommit(): Promise<CommitBeginDto> {
    return this.call<CommitBeginDto>('world_info_begin_commit', undefined);
  }

  appendWorldInfoCommitChunk(sessionId: string, offset: number, chunkBase64: string): Promise<number> {
    const payload: SettingsChunkPayload = {
      sessionId: sessionId,
      offset: offset,
      chunkBase64: chunkBase64
    };
    return this.call<number>('world_info_append_commit_chunk', payload);
  }

  finishWorldInfoCommit(sessionId: string, expectedSize: number): Promise<void> {
    const payload: SettingsFinishPayload = { sessionId: sessionId, expectedSize: expectedSize };
    return this.call<void>('world_info_finish_commit', payload);
  }

  abortWorldInfoCommit(sessionId: string): Promise<void> {
    const payload: SettingsSessionPayload = { sessionId: sessionId };
    return this.call<void>('world_info_abort_commit', payload);
  }

  deleteWorldInfo(name: string): Promise<void> {
    return this.call<void>('delete_world_info', { name: name });
  }

  normalizeWorldInfoName(name: string, importFilename?: boolean): Promise<string> {
    const payload: ESObject = importFilename === undefined
      ? { name: name }
      : { name: name, importFilename: importFilename };
    return this.call<string>('normalize_world_info_name', payload);
  }

  /** 从沙箱内文件导入；convertedData 可直接给已转换好的 JSON 文本。 */
  importWorldInfo(originalFilename: string, filePath?: string, convertedData?: string): Promise<string> {
    const payload: ESObject = {
      originalFilename: originalFilename,
      filePath: filePath === undefined ? '' : filePath,
      convertedData: convertedData === undefined ? '' : convertedData
    };
    return this.call<string>('import_world_info', payload);
  }

  /** 分块字节数：与设置/聊天提交一致，128KB 一帧。 */
  static readonly COMMIT_FRAME_BYTES: number = 128 * 1024;

  /** 把一段文本按字节切片后逐片 base64，供 begin/append/finish 提交协议使用。 */
  static splitBase64Frames(text: string): string[] {
    const bytes: Uint8Array = new util.TextEncoder().encodeInto(text);
    const frames: string[] = [];
    const encoder: util.Base64Helper = new util.Base64Helper();
    let cursor: number = 0;
    while (cursor < bytes.length) {
      const end: number = Math.min(cursor + BackendFacade.COMMIT_FRAME_BYTES, bytes.length);
      frames.push(encoder.encodeToStringSync(bytes.slice(cursor, end)));
      cursor = end;
    }
    if (frames.length === 0) {
      frames.push('');
    }
    return frames;
  }

  // ---- P8-23：群聊（group / group chat），12 条 ----

  /** 群组列表（含成员、当前 chat、聊天延迟等上游字段）。 */
  getAllGroups(): Promise<ESObject[]> {
    return this.call<ESObject[]>('get_all_groups', undefined);
  }

  getGroup(id: string): Promise<ESObject> {
    return this.call<ESObject>('get_group', { id: id });
  }

  /** 建群：dto 用上游 GroupDto 形状（name / members / activationStrategy / generationMode …）。 */
  createGroup(dto: ESObject): Promise<ESObject> {
    return this.call<ESObject>('create_group', { dto: dto });
  }

  /** 改群：整包写回，所以要把整个 group 对象传回来。 */
  updateGroup(dto: ESObject): Promise<ESObject> {
    return this.call<ESObject>('update_group', { dto: dto });
  }

  deleteGroup(id: string): Promise<void> {
    const dto: IdShape = { id: id };
    return this.call<void>('delete_group', { dto: dto });
  }

  /** 群聊会话摘要；chatIds 可只查某几个会话。 */
  listGroupChatSummaries(chatIds?: string[], includeMetadata?: boolean): Promise<ESObject[]> {
    const payload: ESObject = {
      chatIds: chatIds === undefined ? null : chatIds,
      includeMetadata: includeMetadata === true
    };
    return this.call<ESObject[]>('list_group_chat_summaries', payload);
  }

  searchGroupChats(query: string, chatIds?: string[]): Promise<ESObject[]> {
    const payload: ESObject = {
      query: query,
      chatIds: chatIds === undefined ? null : chatIds
    };
    return this.call<ESObject[]>('search_group_chats', payload);
  }

  getGroupChatMetadata(chatId: string): Promise<ESObject> {
    return this.call<ESObject>('get_group_chat_metadata', { chatId: chatId });
  }

  /** 群聊 .jsonl 的绝对路径（读消息行用）。 */
  getGroupChatPayloadPath(chatId: string): Promise<string> {
    return this.call<string>('get_group_chat_payload_path', { chatId: chatId });
  }

  renameGroupChat(oldFileName: string, newFileName: string): Promise<string> {
    const dto: RenameGroupChatShape = {
      old_file_name: oldFileName,
      new_file_name: newFileName
    };
    return this.call<string>('rename_group_chat', { dto: dto });
  }

  deleteGroupChat(chatId: string): Promise<void> {
    const dto: IdShape = { id: chatId };
    return this.call<void>('delete_group_chat', { dto: dto });
  }

  clearGroupChatCache(): Promise<void> {
    return this.call<void>('clear_group_chat_cache', undefined);
  }

  /** 会话内消息检索：命中返回 {index, score, snippet, role, text}。 */
  searchCharacterChatMessages(characterName: string, fileName: string, query: string, limit: number): Promise<ESObject[]> {
    const payload: ChatSearchQueryShape = { query: query, limit: limit };
    return this.call<ESObject[]>('search_character_chat_messages', {
      characterName: characterName,
      fileName: fileName,
      query: payload
    });
  }

  // ---- P8-29：聊天级 KV（extension store，namespace + key）----

  /** 列出某会话某命名空间下的所有 key。 */
  listCharacterChatStoreKeys(characterName: string, fileName: string, namespace: string): Promise<string[]> {
    return this.call<string[]>('list_character_chat_store_keys', {
      characterName: characterName,
      fileName: fileName,
      namespace: namespace
    });
  }

  getCharacterChatStoreJson(characterName: string, fileName: string, namespace: string, key: string): Promise<ESObject> {
    return this.call<ESObject>('get_character_chat_store_json', {
      characterName: characterName,
      fileName: fileName,
      namespace: namespace,
      key: key
    });
  }

  setCharacterChatStoreJson(characterName: string, fileName: string, namespace: string, key: string, value: ESObject): Promise<void> {
    return this.call<void>('set_character_chat_store_json', {
      characterName: characterName,
      fileName: fileName,
      namespace: namespace,
      key: key,
      value: value
    });
  }

  updateCharacterChatStoreJson(characterName: string, fileName: string, namespace: string, key: string, value: ESObject): Promise<void> {
    return this.call<void>('update_character_chat_store_json', {
      characterName: characterName,
      fileName: fileName,
      namespace: namespace,
      key: key,
      value: value
    });
  }

  deleteCharacterChatStoreJson(characterName: string, fileName: string, namespace: string, key: string): Promise<void> {
    return this.call<void>('delete_character_chat_store_json', {
      characterName: characterName,
      fileName: fileName,
      namespace: namespace,
      key: key
    });
  }

  renameCharacterChatStoreKey(characterName: string, fileName: string, namespace: string, key: string, newKey: string): Promise<void> {
    return this.call<void>('rename_character_chat_store_key', {
      characterName: characterName,
      fileName: fileName,
      namespace: namespace,
      key: key,
      newKey: newKey
    });
  }

  /** 会话头 chat_metadata.integrity（扩展 store 的目录名）；没有返回 null。 */
  getCharacterChatIntegrity(characterName: string, fileName: string): Promise<string | null> {
    return this.call<string | null>('get_character_chat_integrity', {
      characterName: characterName,
      fileName: fileName
    });
  }

  /** 会话首行 metadata 整包（诊断用，结构上游自己定）。 */
  getCharacterChatMetadata(characterName: string, fileName: string): Promise<ESObject> {
    return this.call<ESObject>('get_character_chat_metadata', {
      characterName: characterName,
      fileName: fileName
    });
  }

  /** 会话尾部窗口：长聊天先只读最后 N 行，避免整包读盘。 */
  getChatPayloadTail(characterName: string, fileName: string, maxLines: number, allowNotFound: boolean): Promise<ESObject> {
    const payload: ESObject = {
      characterName: characterName,
      fileName: fileName,
      maxLines: maxLines,
      allowNotFound: allowNotFound
    };
    return this.call<ESObject>('get_chat_payload_tail', payload);
  }

  getSillyTavernSettings(): Promise<ESObject> {
    return this.call<ESObject>('get_sillytavern_settings', undefined);
  }


  /**
   * 取全部角色（deep 快照，含 first_mes——新建聊天时用作开场白）。
   * 对应 dispatch `get_all_characters`：可选 polling `shallow`（缺省 false=deep）。
   */
  getAllCharacters(): Promise<CharacterDto[]> {
    const payload: ShallowPayload = { shallow: false };
    return this.call<CharacterDto[]>('get_all_characters', payload);
  }

  /**
   * 新建聊天。Rust `CreateChatDto` 平铺 snake_case：
   * {character_name, user_name, first_message?}，整体包在 {dto: ...} 里（同 add_message）。
   * 返回 ChatDto（含服务端生成 file_name），可直接作为 openChat。
   */
  createChat(characterName: string, userName: string, firstMessage: string): Promise<ChatDto> {
    const payload: CreateChatPayload = {
      dto: {
        character_name: characterName,
        user_name: userName,
        first_message: firstMessage === '' ? null : firstMessage
      }
    };
    return this.call<ChatDto>('create_chat', payload);
  }

  /** 列出全部聊天摘要（list_chat_summaries，无过滤）。 */
  listChatSummaries(): Promise<ChatSearchResultDto[]> {
    return this.call<ChatSearchResultDto[]>('list_chat_summaries', undefined);
  }

  /**
   * 新增消息。Rust `AddMessageDto` 是平铺 snake_case：
   * {character_name, file_name, is_user, content, extra?} —— 这里把便利类型
   * ChatMessageInput 重新整形；sendDate/isSystem 由服务端落库时设置。
   */
  addMessage(characterName: string, fileName: string, message: ChatMessageInput): Promise<ChatDto> {
    const payload: AddMessagePayload = {
      dto: {
        character_name: characterName,
        file_name: fileName,
        is_user: message.isUser,
        content: message.mes
      }
    };
    return this.call<ChatDto>('add_message', payload);
  }

  /**
   * 开始一次流式生成。payload 是「命名参数对象包一层 dto」，与上游
   * `ChatCompletionGenerateRequestDto` 的扁平 payload 一致：`chat_completion_source`
   * 决定走哪个 provider，其余字段（model/messages/temperature/…）按 provider 传。
   */
  startChatCompletionStream(streamId: string, dto: GenerateRequestDto): Promise<void> {
    const payload: StartStreamPayload = { streamId: streamId, dto: dto };
    return this.call<void>('start_chat_completion_stream', payload);
  }

  /**
   * 读取流（游标轮询）。format 缺省 openai_compatible；Claude/Gemini 系显式传入。
   * 返回的事件里 chunk.parts 已是解码后的三通道片段。
   */
  readChatCompletionStreamDecoded(
    streamId: string,
    afterSeq: number,
    format?: string
  ): Promise<ChatCompletionStreamReadResultDecodedDto> {
    const payload: ReadStreamPayload = {
      streamId: streamId,
      afterSeq: afterSeq,
      format: format
    };
    return this.call<ChatCompletionStreamReadResultDecodedDto>(
      'read_chat_completion_stream_decoded', payload);
  }

  closeChatCompletionStream(streamId: string): Promise<void> {
    const payload: StreamIdPayload = { streamId: streamId };
    return this.call<void>('close_chat_completion_stream', payload);
  }

  cancelChatCompletionGeneration(requestId: string): Promise<void> {
    const payload: RequestIdPayload = { requestId: requestId };
    return this.call<void>('cancel_chat_completion_generation', payload);
  }

  /** 端点授权三步握手第 ③ 步：用户已在 ArkUI 对话框里点了「信任并连接」。 */
  grantUserEndpointAccess(endpoint: string): Promise<void> {
    const payload: EndpointPayload = { endpoint: endpoint };
    return this.call<void>('grant_user_endpoint_access', payload);
  }

  /**
   * 写入密钥。字段名必须与 Rust `WriteSecretDto` 一致（`key`/`value`/`label`）——
   * 之前误用 `name`，serde 反序列化直接报 "missing field `key`"，密钥从未写成功
   * （真机反馈「api key 不行」的根因，2026-10-26 23:46 修复）。
   */
  writeSecret(name: string, value: string, label?: string): Promise<string> {
    const payload: SecretPayload = { dto: { key: name, value: value, label: label } };
    return this.call<string>('write_secret', payload);
  }

  /**
   * 非流式生成（设置页「测试连接」用）。requestId 是顶层 Args 键（camelCase），
   * dto 是扁平 snake payload：{chat_completion_source, model, stream:false,
   * temperature, max_tokens, messages:[{role,content}]}。
   */
  generateChatCompletion(requestId: string, dto: GenerateRequestDto): Promise<ESObject> {
    const payload: GenerateCompletionPayload = { requestId: requestId, dto: dto };
    return this.call<ESObject>('generate_chat_completion', payload);
  }

  readSecretState(): Promise<ESObject> {
    return this.call<ESObject>('read_secret_state', undefined);
  }

  getChatCompletionModels(dto: ProviderRequestDto): Promise<ESObject> {
    const payload: ProviderStatusPayload = { dto: dto };
    return this.call<ESObject>('get_chat_completions_status', payload);
  }

  // ---- P6.1 批次：presets / MCP / Skills / provider 元数据 / LLM 连接 / SearXNG /
  //      vector / database / data archive / extension store（62 条）----
  // 顶层键一律 camelCase；DTO 体字段按各 Rust DTO 的 serde（见 Types.ets 注释）。

  // ---- 预设（8）----

  savePreset(dto: SavePresetDto): Promise<SavePresetResponseDto> {
    return this.call<SavePresetResponseDto>('save_preset', { dto: dto });
  }

  deletePreset(dto: DeletePresetDto): Promise<void> {
    return this.call<void>('delete_preset', { dto: dto });
  }

  restorePreset(dto: RestorePresetDto): Promise<RestorePresetResponseDto> {
    return this.call<RestorePresetResponseDto>('restore_preset', { dto: dto });
  }

  /** name 是顶层键，preset 作为扁平 dto 体（Rust SaveOpenAIPresetDto flatten）。 */
  saveOpenAIPreset(name: string, preset: ESObject): Promise<void> {
    return this.call<void>('save_openai_preset', { name: name, dto: preset });
  }

  deleteOpenAIPreset(dto: DeleteOpenAIPresetDto): Promise<DeleteOpenAIPresetResponseDto> {
    return this.call<DeleteOpenAIPresetResponseDto>('delete_openai_preset', { dto: dto });
  }

  listPresets(apiId: string): Promise<string[]> {
    return this.call<string[]>('list_presets', { apiId: apiId });
  }

  presetExists(name: string, apiId: string): Promise<boolean> {
    return this.call<boolean>('preset_exists', { name: name, apiId: apiId });
  }

  /** 未找到返回 null（Rust Option<Value>）。 */
  getPreset(name: string, apiId: string): Promise<ESObject> {
    return this.call<ESObject>('get_preset', { name: name, apiId: apiId });
  }

  // ---- MCP（16；请求 DTO deny_unknown_fields，只发 Types.ets 里声明的精确字段）----

  listMcpServers(): Promise<ListMcpServersResultDto> {
    return this.call<ListMcpServersResultDto>('list_mcp_servers', undefined);
  }

  createMcpServer(dto: CreateMcpServerDto): Promise<McpServerDto> {
    return this.call<McpServerDto>('create_mcp_server', { dto: dto });
  }

  updateMcpServer(dto: UpdateMcpServerDto): Promise<McpServerDto> {
    return this.call<McpServerDto>('update_mcp_server', { dto: dto });
  }

  setMcpServerState(dto: SetMcpServerStateDto): Promise<McpServerDto> {
    return this.call<McpServerDto>('set_mcp_server_state', { dto: dto });
  }

  removeMcpServer(dto: McpRegistrationIdDto): Promise<void> {
    return this.call<void>('remove_mcp_server', { dto: dto });
  }

  discoverMcpTools(dto: McpRegistrationIdDto): Promise<McpDiscoveryResultDto> {
    return this.call<McpDiscoveryResultDto>('discover_mcp_tools', { dto: dto });
  }

  refreshMcpTools(dto: McpRegistrationIdDto): Promise<McpDiscoveryResultDto> {
    return this.call<McpDiscoveryResultDto>('refresh_mcp_tools', { dto: dto });
  }

  setMcpToolPermission(dto: SetMcpToolPermissionDto): Promise<McpServerDto> {
    return this.call<McpServerDto>('set_mcp_tool_permission', { dto: dto });
  }

  setMcpToolDescriptionOverride(dto: SetMcpToolDescriptionOverrideDto): Promise<McpServerDto> {
    return this.call<McpServerDto>('set_mcp_tool_description_override', { dto: dto });
  }

  startMcpTestCall(dto: TestMcpToolCallDto): Promise<void> {
    return this.call<void>('start_mcp_test_call', { dto: dto });
  }

  testMcpToolCall(dto: TestMcpToolCallDto): Promise<McpCallOutcomeDto> {
    return this.call<McpCallOutcomeDto>('test_mcp_tool_call', { dto: dto });
  }

  cancelMcpTestCall(dto: McpTestCallIdDto): Promise<void> {
    return this.call<void>('cancel_mcp_test_call', { dto: dto });
  }

  listLegacyMcpTools(): Promise<ListLegacyMcpToolsResultDto> {
    return this.call<ListLegacyMcpToolsResultDto>('list_legacy_mcp_tools', undefined);
  }

  startLegacyMcpToolCall(dto: CallLegacyMcpToolDto): Promise<void> {
    return this.call<void>('start_legacy_mcp_tool_call', { dto: dto });
  }

  callLegacyMcpTool(dto: McpExecutionCallIdDto): Promise<McpCallOutcomeDto> {
    return this.call<McpCallOutcomeDto>('call_legacy_mcp_tool', { dto: dto });
  }

  cancelLegacyMcpToolCall(dto: McpExecutionCallIdDto): Promise<void> {
    return this.call<void>('cancel_legacy_mcp_tool_call', { dto: dto });
  }

  // ---- Agent Skills（13）----

  /** 从 URL 下载技能导入包，返回解析出的 SkillImportInput（kind=archiveFile 或 archiveBase64）。 */
  downloadSkillImportUrl(url: string): Promise<SkillImportInput> {
    return this.call<SkillImportInput>('download_skill_import_url', { url: url });
  }

  listSkills(scope?: SkillScopeFilter): Promise<SkillIndexEntry[]> {
    const payload: ESObject = {};
    if (scope !== undefined) {
      payload['scope'] = scope;
    }
    return this.call<SkillIndexEntry[]>('list_skills', payload);
  }

  listSkillFiles(name: string, scope?: SkillScope): Promise<SkillFileRef[]> {
    const payload: ESObject = { name: name };
    if (scope !== undefined) {
      payload['scope'] = scope;
    }
    return this.call<SkillFileRef[]>('list_skill_files', payload);
  }

  discoverSkillImports(input: SkillImportInput): Promise<SkillImportPreview[]> {
    return this.call<SkillImportPreview[]>('discover_skill_imports', { input: input });
  }

  discardSkillImportArchive(path: string): Promise<void> {
    return this.call<void>('discard_skill_import_archive', { path: path });
  }

  previewSkillImport(input: SkillImportInput, targetScope?: SkillScope): Promise<SkillImportPreview> {
    const payload: ESObject = { input: input };
    if (targetScope !== undefined) {
      payload['targetScope'] = targetScope;
    }
    return this.call<SkillImportPreview>('preview_skill_import', payload);
  }

  installSkillImport(request: SkillInstallRequest): Promise<SkillInstallResult> {
    return this.call<SkillInstallResult>('install_skill_import', { request: request });
  }

  readSkillFile(name: string, path: string, scope?: SkillScope,
    startLine?: number, lineCount?: number): Promise<SkillReadResult> {
    const payload: ESObject = { name: name, path: path };
    if (scope !== undefined) {
      payload['scope'] = scope;
    }
    if (startLine !== undefined) {
      payload['startLine'] = startLine;
    }
    if (lineCount !== undefined) {
      payload['lineCount'] = lineCount;
    }
    return this.call<SkillReadResult>('read_skill_file', payload);
  }

  writeSkillFile(name: string, path: string, content: string, scope?: SkillScope,
    expectedSha256?: string): Promise<SkillReadResult> {
    const payload: ESObject = { name: name, path: path, content: content };
    if (scope !== undefined) {
      payload['scope'] = scope;
    }
    if (expectedSha256 !== undefined) {
      payload['expectedSha256'] = expectedSha256;
    }
    return this.call<SkillReadResult>('write_skill_file', payload);
  }

  /** 导出技能为 base64 载荷（fileName + contentBase64 + sha256）。 */
  exportSkill(name: string, scope?: SkillScope): Promise<SkillExportPayload> {
    const payload: ESObject = { name: name };
    if (scope !== undefined) {
      payload['scope'] = scope;
    }
    return this.call<SkillExportPayload>('export_skill', payload);
  }

  deleteSkill(name: string, scope?: SkillScope): Promise<void> {
    const payload: ESObject = { name: name };
    if (scope !== undefined) {
      payload['scope'] = scope;
    }
    return this.call<void>('delete_skill', payload);
  }

  moveSkill(request: SkillMoveRequest): Promise<SkillInstallResult> {
    return this.call<SkillInstallResult>('move_skill', { request: request });
  }

  retargetSkillScope(request: SkillScopeRetargetRequest): Promise<SkillScopeRetargetResult> {
    return this.call<SkillScopeRetargetResult>('retarget_skill_scope', { request: request });
  }

  // ---- provider 元数据（7；注意请求 DTO 字段是 snake_case）----

  getOpenrouterModelProviders(dto: ProviderModelProvidersRequestDto): Promise<ESObject> {
    return this.call<ESObject>('get_openrouter_model_providers', { dto: dto });
  }

  getOpenrouterCredits(): Promise<ESObject> {
    return this.call<ESObject>('get_openrouter_credits', undefined);
  }

  getNanogptModelProviders(dto: ProviderModelProvidersRequestDto): Promise<ESObject> {
    return this.call<ESObject>('get_nanogpt_model_providers', { dto: dto });
  }

  getNanogptCredits(): Promise<ESObject> {
    return this.call<ESObject>('get_nanogpt_credits', undefined);
  }

  getSiliconflowEmbeddingModels(dto: SiliconFlowEmbeddingModelsRequestDto): Promise<ESObject> {
    return this.call<ESObject>('get_siliconflow_embedding_models', { dto: dto });
  }

  getWorkersAiEmbeddingModels(dto: WorkersAiModelsRequestDto): Promise<ESObject> {
    return this.call<ESObject>('get_workers_ai_embedding_models', { dto: dto });
  }

  getWorkersAiMultimodalModels(dto: WorkersAiModelsRequestDto): Promise<ESObject> {
    return this.call<ESObject>('get_workers_ai_multimodal_models', { dto: dto });
  }

  // ---- LLM 连接（4）----

  listLlmConnections(): Promise<ListLlmConnectionsResultDto> {
    return this.call<ListLlmConnectionsResultDto>('list_llm_connections', undefined);
  }

  loadLlmConnection(dto: LlmConnectionIdDto): Promise<LoadLlmConnectionResultDto> {
    return this.call<LoadLlmConnectionResultDto>('load_llm_connection', { dto: dto });
  }

  saveLlmConnection(dto: SaveLlmConnectionDto): Promise<void> {
    return this.call<void>('save_llm_connection', { dto: dto });
  }

  deleteLlmConnection(dto: LlmConnectionIdDto): Promise<void> {
    return this.call<void>('delete_llm_connection', { dto: dto });
  }

  /**
   * SearXNG 搜索。端点授权三步握手与 generate/start_stream 一致：
   * 失败 message 以 "endpoint_authorization_required|" 开头时，先弹授权对话框，
   * 用户确认后调 grantUserEndpointAccess(endpoint) 再重试本调用。
   */
  searchSearxng(dto: SearxngSearchRequestDto, locale: string): Promise<string> {
    return this.call<string>('search_searxng', { dto: dto, locale: locale });
  }

  vectorHandle(path: string, request: VectorRouteRequestDto): Promise<VectorRouteResponseDto> {
    return this.call<VectorRouteResponseDto>('vector_handle', { path: path, request: request });
  }

  databaseHandle(request: DatabaseRequest): Promise<ESObject> {
    return this.call<ESObject>('database_handle', { request: request });
  }

  // ---- data archive（6；三条 [split]：ArkTS 弹选择器 + 沙箱路径/base64 桥）----

  /**
   * 导入归档 [split]。ArkTS 先用 DocumentViewPicker 选文件并拷到
   * `<cacheDir>/imports/<uuid>.archive`，再把该绝对路径传进来（P4 同款模式）。
   */
  importDataArchiveFromPicker(path: string, fileName?: string): Promise<ImportArchiveResult> {
    const payload: ESObject = { path: path };
    if (fileName !== undefined) {
      payload['fileName'] = fileName;
    }
    return this.call<ImportArchiveResult>('import_data_archive_from_picker', payload);
  }

  /** 开始导出归档，返回 jobId（用 getDataArchiveJobStatus 轮询）。 */
  startExportDataArchive(): Promise<string> {
    return this.call<string>('start_export_data_archive', undefined);
  }

  getDataArchiveJobStatus(jobId: string): Promise<DataArchiveJobStatus> {
    return this.call<DataArchiveJobStatus>('get_data_archive_job_status', { jobId: jobId });
  }

  cancelDataArchiveJob(jobId: string): Promise<void> {
    return this.call<void>('cancel_data_archive_job', { jobId: jobId });
  }

  /**
   * 保存导出归档 [split]。Rust 侧 claim + finish 交付，返回 {delivered, path, fileName}；
   * ArkTS 用 @ohos.file.fs 读 path（沙箱内）再写入 DocumentViewPicker(SAVE) 用户选择的位置。
   */
  saveExportDataArchive(jobId: string): Promise<DeliveryResult> {
    return this.call<DeliveryResult>('save_export_data_archive', { jobId: jobId });
  }

  /** 导出用户备份 [split]，语义同 saveExportDataArchive（产物路径由返回携带）。 */
  exportUserBackupArchive(handle: string, includeSecrets: boolean): Promise<DeliveryResult> {
    return this.call<DeliveryResult>('export_user_backup_archive',
      { handle: handle, includeSecrets: includeSecrets });
  }

  // ---- extension store（可移植 5 条）----

  renameExtensionStoreKey(namespace: string, key: string, newKey: string, table?: string): Promise<void> {
    const payload: ESObject = { namespace: namespace, key: key, newKey: newKey };
    if (table !== undefined) {
      payload['table'] = table;
    }
    return this.call<void>('rename_extension_store_key', payload);
  }

  deleteExtensionStoreEntry(namespace: string, key: string, kind: EntryKind, table?: string): Promise<void> {
    const payload: ESObject = { namespace: namespace, key: key, kind: kind };
    if (table !== undefined) {
      payload['table'] = table;
    }
    return this.call<void>('delete_extension_store_entry', payload);
  }

  listExtensionStoreKeys(namespace: string, kind: EntryKind, table?: string): Promise<string[]> {
    const payload: ESObject = { namespace: namespace, kind: kind };
    if (table !== undefined) {
      payload['table'] = table;
    }
    return this.call<string[]>('list_extension_store_keys', payload);
  }

  listExtensionStoreTables(namespace: string): Promise<string[]> {
    return this.call<string[]>('list_extension_store_tables', { namespace: namespace });
  }

  deleteExtensionStoreTable(namespace: string, table: string): Promise<void> {
    return this.call<void>('delete_extension_store_table', { namespace: namespace, table: table });
  }

  // ---- P6.2: extension（8）----

  getExtensions(): Promise<Extension[]> {
    return this.call<Extension[]>('get_extensions', undefined);
  }

  installExtension(url: string, global: boolean, branch?: string): Promise<ExtensionInstallResult> {
    const payload: ESObject = { url: url, global: global };
    if (branch !== undefined) {
      payload['branch'] = branch;
    }
    return this.call<ExtensionInstallResult>('install_extension', payload);
  }

  updateExtension(extensionName: string, global: boolean): Promise<ExtensionUpdateResult> {
    return this.call<ExtensionUpdateResult>('update_extension',
      { extension_name: extensionName, global: global });
  }

  deleteExtension(extensionName: string, global: boolean): Promise<void> {
    return this.call<void>('delete_extension',
      { extension_name: extensionName, global: global });
  }

  getExtensionVersion(extensionName: string, global: boolean): Promise<ExtensionVersion> {
    return this.call<ExtensionVersion>('get_extension_version',
      { extension_name: extensionName, global: global });
  }

  getExtensionBranches(extensionName: string, global: boolean): Promise<ExtensionBranch[]> {
    return this.call<ExtensionBranch[]>('get_extension_branches',
      { extension_name: extensionName, global: global });
  }

  switchExtensionBranch(extensionName: string, branch: string, global: boolean): Promise<void> {
    return this.call<void>('switch_extension_branch',
      { extension_name: extensionName, branch: branch, global: global });
  }

  moveExtension(extensionName: string, source: string, destination: string): Promise<void> {
    return this.call<void>('move_extension',
      { extension_name: extensionName, source: source, destination: destination });
  }

  // ---- P6.2: agent（34；顶层键一律 `dto`，camelCase）----

  startAgentRun(dto: AgentStartRunDto): Promise<AgentRunHandleDto> {
    return this.call<AgentRunHandleDto>('start_agent_run', { dto: dto });
  }

  readAgentRunCheckpoint(dto: AgentReadRunCheckpointDto): Promise<AgentReadRunCheckpointResultDto> {
    return this.call<AgentReadRunCheckpointResultDto>('read_agent_run_checkpoint', { dto: dto });
  }

  resumeAgentRun(dto: AgentResumeRunDto): Promise<AgentRunHandleDto> {
    return this.call<AgentRunHandleDto>('resume_agent_run', { dto: dto });
  }

  finishAgentRunPresentation(dto: AgentFinishRunPresentationDto): Promise<void> {
    return this.call<void>('finish_agent_run_presentation', { dto: dto });
  }

  /** 订阅 run 的 live projection：快照 + 增量事件经 `agent:run-live-update` 推送。 */
  subscribeAgentRunLiveProjection(dto: AgentSubscribeRunLiveProjectionDto): Promise<void> {
    return this.call<void>('subscribe_agent_run_live_projection', { dto: dto });
  }

  prepareAgentPromptAssembly(dto: AgentPreparePromptAssemblyDto): Promise<ESObject> {
    return this.call<ESObject>('prepare_agent_prompt_assembly', { dto: dto });
  }

  buildAgentCurrentModelConnectionSnapshot(
    dto: AgentBuildCurrentModelConnectionSnapshotDto): Promise<AgentBuildCurrentModelConnectionSnapshotResultDto> {
    return this.call<AgentBuildCurrentModelConnectionSnapshotResultDto>(
      'build_agent_current_model_connection_snapshot', { dto: dto });
  }

  applyAgentCurrentModelConnectionSnapshot(
    dto: AgentApplyCurrentModelConnectionSnapshotDto): Promise<AgentApplyCurrentModelConnectionSnapshotResultDto> {
    return this.call<AgentApplyCurrentModelConnectionSnapshotResultDto>(
      'apply_agent_current_model_connection_snapshot', { dto: dto });
  }

  listAgentProfiles(): Promise<AgentListProfilesResultDto> {
    return this.call<AgentListProfilesResultDto>('list_agent_profiles', undefined);
  }

  listAgentTools(dto?: AgentListToolsDto): Promise<ESObject> {
    const payload: ESObject = {};
    if (dto !== undefined) {
      payload['dto'] = dto;
    }
    return this.call<ESObject>('list_agent_tools', payload);
  }

  resolveAgentSystemPrompt(dto: AgentResolveSystemPromptDto): Promise<AgentResolveSystemPromptResultDto> {
    return this.call<AgentResolveSystemPromptResultDto>('resolve_agent_system_prompt', { dto: dto });
  }

  loadAgentProfile(dto: AgentProfileIdDto): Promise<ESObject> {
    return this.call<ESObject>('load_agent_profile', { dto: dto });
  }

  diagnoseAgentProfile(dto: AgentProfileIdDto): Promise<ESObject> {
    return this.call<ESObject>('diagnose_agent_profile', { dto: dto });
  }

  saveAgentProfile(dto: AgentSaveProfileDto): Promise<void> {
    return this.call<void>('save_agent_profile', { dto: dto });
  }

  deleteAgentProfile(dto: AgentProfileIdDto): Promise<void> {
    return this.call<void>('delete_agent_profile', { dto: dto });
  }

  repairAgentProfileFile(dto: AgentRepairProfileFileDto): Promise<void> {
    return this.call<void>('repair_agent_profile_file', { dto: dto });
  }

  retargetAgentProfilePresetRefs(dto: AgentRetargetPresetRefsDto): Promise<AgentRetargetPresetRefsResultDto> {
    return this.call<AgentRetargetPresetRefsResultDto>('retarget_agent_profile_preset_refs', { dto: dto });
  }

  /** 返回 untagged 联合（Chat run handle 或 Session run handle），ArkTS 按字段判别。 */
  cancelAgentRun(dto: AgentCancelRunDto): Promise<ESObject> {
    return this.call<ESObject>('cancel_agent_run', { dto: dto });
  }

  submitAgentRunGuidance(dto: AgentSubmitGuidanceDto): Promise<AgentSubmitGuidanceResultDto> {
    return this.call<AgentSubmitGuidanceResultDto>('submit_agent_run_guidance', { dto: dto });
  }

  listActiveAgentRuns(): Promise<AgentActiveRunDto[]> {
    return this.call<AgentActiveRunDto[]>('list_active_agent_runs', undefined);
  }

  listAgentRuns(dto: AgentListRunsDto): Promise<AgentListRunsResultDto> {
    return this.call<AgentListRunsResultDto>('list_agent_runs', { dto: dto });
  }

  planAgentRunPrune(dto: AgentPlanRunPruneDto): Promise<AgentRunPrunePlanDto> {
    return this.call<AgentRunPrunePlanDto>('plan_agent_run_prune', { dto: dto });
  }

  applyAgentRunPrune(dto: AgentApplyRunPruneDto): Promise<AgentRunPruneApplyResultDto> {
    return this.call<AgentRunPruneApplyResultDto>('apply_agent_run_prune', { dto: dto });
  }

  readAgentRunEvents(dto: AgentReadEventsDto): Promise<AgentReadEventsResultDto> {
    return this.call<AgentReadEventsResultDto>('read_agent_run_events', { dto: dto });
  }

  /** 返回 base64 字符串（Rust `ipc::Response` 的 OHOS 替代），ArkTS 解码还原字节。 */
  readAgentWorkspaceBytes(dto: AgentReadWorkspaceFileDto): Promise<string> {
    return this.call<string>('read_agent_workspace_bytes', { dto: dto });
  }

  readAgentWorkspaceFile(dto: AgentReadWorkspaceFileDto): Promise<AgentWorkspaceFileDto> {
    return this.call<AgentWorkspaceFileDto>('read_agent_workspace_file', { dto: dto });
  }

  readAgentTaskDetail(dto: AgentReadTaskDetailDto): Promise<ESObject> {
    return this.call<ESObject>('read_agent_task_detail', { dto: dto });
  }

  readAgentModelTurn(dto: AgentReadModelTurnDto): Promise<ESObject> {
    return this.call<ESObject>('read_agent_model_turn', { dto: dto });
  }

  /** Rust 侧返回 Option：无请求时 data 为 null。 */
  readAgentPromptAssemblyRequest(dto: AgentReadPromptAssemblyRequestDto): Promise<ESObject | null> {
    return this.call<ESObject | null>('read_agent_prompt_assembly_request', { dto: dto });
  }

  resolveAgentChatCommit(dto: AgentResolveChatCommitDto): Promise<void> {
    return this.call<void>('resolve_agent_chat_commit', { dto: dto });
  }

  resolveAgentPromptAssembly(dto: AgentResolvePromptAssemblyDto): Promise<void> {
    return this.call<void>('resolve_agent_prompt_assembly', { dto: dto });
  }

  resolveAgentPersistentStateMetadataUpdate(
    dto: AgentResolvePersistentStateMetadataUpdateDto): Promise<void> {
    return this.call<void>('resolve_agent_persistent_state_metadata_update', { dto: dto });
  }

  pruneAgentChatPersistentStates(
    dto: AgentPruneChatPersistentStatesDto): Promise<AgentPruneChatPersistentStatesResultDto> {
    return this.call<AgentPruneChatPersistentStatesResultDto>(
      'prune_agent_chat_persistent_states', { dto: dto });
  }

  copyAgentChatPersistentStates(dto: AgentCopyChatPersistentStatesDto): Promise<void> {
    return this.call<void>('copy_agent_chat_persistent_states', { dto: dto });
  }

  // ---- P6.2: agent session（9）----

  loadAgentSessionProfile(): Promise<AgentSessionProfileResultDto> {
    return this.call<AgentSessionProfileResultDto>('load_agent_session_profile', undefined);
  }

  saveAgentSessionProfile(dto: AgentSaveProfileDto): Promise<void> {
    return this.call<void>('save_agent_session_profile', { dto: dto });
  }

  createAgentSession(): Promise<AgentSessionResultDto> {
    return this.call<AgentSessionResultDto>('create_agent_session', undefined);
  }

  listAgentSessions(): Promise<ESObject> {
    return this.call<ESObject>('list_agent_sessions', undefined);
  }

  renameAgentSession(dto: AgentRenameSessionDto): Promise<AgentSessionResultDto> {
    return this.call<AgentSessionResultDto>('rename_agent_session', { dto: dto });
  }

  deleteAgentSession(dto: AgentDeleteSessionDto): Promise<void> {
    return this.call<void>('delete_agent_session', { dto: dto });
  }

  readAgentSession(dto: AgentReadSessionDto): Promise<ESObject> {
    return this.call<ESObject>('read_agent_session', { dto: dto });
  }

  prepareAgentSessionRun(dto: AgentPrepareSessionRunDto): Promise<ESObject> {
    return this.call<ESObject>('prepare_agent_session_run', { dto: dto });
  }

  startAgentSessionRun(dto: AgentStartSessionRunDto): Promise<AgentSessionRunHandleDto> {
    return this.call<AgentSessionRunHandleDto>('start_agent_session_run', { dto: dto });
  }

  // ---- P6.2: lan_sync（17；snake 字面量键）----

  lanSyncGetStatus(): Promise<ESObject> {
    return this.call<ESObject>('lan_sync_get_status', undefined);
  }

  lanSyncStartServer(): Promise<ESObject> {
    return this.call<ESObject>('lan_sync_start_server', undefined);
  }

  lanSyncStopServer(): Promise<void> {
    return this.call<void>('lan_sync_stop_server', undefined);
  }

  lanSyncGetPairingInfo(): Promise<LanSyncPairingInfoDto> {
    return this.call<LanSyncPairingInfoDto>('lan_sync_get_pairing_info', undefined);
  }

  lanSyncRequestPairing(pairUri: string): Promise<LanSyncPairedDeviceDto> {
    return this.call<LanSyncPairedDeviceDto>('lan_sync_request_pairing', { pair_uri: pairUri });
  }

  lanSyncDiscoverDevices(): Promise<ESObject[]> {
    return this.call<ESObject[]>('lan_sync_discover_devices', undefined);
  }

  lanSyncConnectAddress(address: string): Promise<void> {
    return this.call<void>('lan_sync_connect_address', { address: address });
  }

  lanSyncSetDeviceName(name: string): Promise<void> {
    return this.call<void>('lan_sync_set_device_name', { name: name });
  }

  lanSyncPairDevice(deviceId: string): Promise<LanSyncPairedDeviceDto> {
    return this.call<LanSyncPairedDeviceDto>('lan_sync_pair_device', { device_id: deviceId });
  }

  lanSyncConfirmPairing(requestId: string, accept: boolean): Promise<void> {
    return this.call<void>('lan_sync_confirm_pairing', { request_id: requestId, accept: accept });
  }

  lanSyncListDevices(): Promise<LanSyncPairedDeviceDto[]> {
    return this.call<LanSyncPairedDeviceDto[]>('lan_sync_list_devices', undefined);
  }

  lanSyncRemoveDevice(deviceId: string): Promise<void> {
    return this.call<void>('lan_sync_remove_device', { device_id: deviceId });
  }

  lanSyncSyncFromDevice(deviceId: string, options: SyncOperationOptions): Promise<ESObject> {
    return this.call<ESObject>('lan_sync_sync_from_device',
      { device_id: deviceId, options: options });
  }

  lanSyncPushToDevice(deviceId: string, options: SyncOperationOptions): Promise<ESObject> {
    return this.call<ESObject>('lan_sync_push_to_device',
      { device_id: deviceId, options: options });
  }

  lanSyncSetSyncMode(mode: SyncMode, persist: boolean): Promise<void> {
    return this.call<void>('lan_sync_set_sync_mode', { mode: mode, persist: persist });
  }

  lanSyncClearSyncModeOverride(): Promise<void> {
    return this.call<void>('lan_sync_clear_sync_mode_override', undefined);
  }

  lanSyncSetOverwritePolicy(overwritePolicy: OverwritePolicy): Promise<void> {
    return this.call<void>('lan_sync_set_overwrite_policy', { overwrite_policy: overwritePolicy });
  }

  // ---- P6.2: tt_sync（5）----

  ttSyncPair(pairUri: string): Promise<TtSyncPairedServerDto> {
    return this.call<TtSyncPairedServerDto>('tt_sync_pair', { pair_uri: pairUri });
  }

  ttSyncListServers(): Promise<TtSyncPairedServerDto[]> {
    return this.call<TtSyncPairedServerDto[]>('tt_sync_list_servers', undefined);
  }

  ttSyncRemoveServer(serverDeviceId: string): Promise<void> {
    return this.call<void>('tt_sync_remove_server', { server_device_id: serverDeviceId });
  }

  ttSyncPull(serverDeviceId: string, mode: SyncMode, options: SyncOperationOptions): Promise<ESObject> {
    return this.call<ESObject>('tt_sync_pull',
      { server_device_id: serverDeviceId, mode: mode, options: options });
  }

  ttSyncPush(serverDeviceId: string, mode: SyncMode, options: SyncOperationOptions): Promise<ESObject> {
    return this.call<ESObject>('tt_sync_push',
      { server_device_id: serverDeviceId, mode: mode, options: options });
  }

  // ---- P6.2: sync（1）----

  syncGetDatasetCatalog(): Promise<SyncDatasetCatalogDto> {
    return this.call<SyncDatasetCatalogDto>('sync_get_dataset_catalog', undefined);
  }

  // ---- P6.2: sync_automation（3）----

  syncAutomationGetConfig(): Promise<ESObject> {
    return this.call<ESObject>('sync_automation_get_config', undefined);
  }

  syncAutomationUpdateConfig(config: ESObject): Promise<ESObject> {
    return this.call<ESObject>('sync_automation_update_config', { config: config });
  }

  syncAutomationGetStatus(): Promise<ESObject> {
    return this.call<ESObject>('sync_automation_get_status', undefined);
  }
}

/**
 * `initialize` 的入参类型。
 * 注意：字段名必须与 Rust 侧 `OhosAppPaths` 的 camelCase 序列化一致
 * （Rust 侧同时接受 snake_case，但 ArkTS 只发 camelCase）。
 */
export interface OhosPathsPayloadLike {
  filesDir: string;
  databaseDir: string;
  cacheDir: string;
  bundleName: string;
  versionName: string;
  /** P4：rawfile 媒体抽取目录（BundledMedia.ensureExtracted() 返回的 root）。 */
  bundledMediaDir?: string;
}

interface CreateUserPayload {
  dto: CreateUserInput;
}

interface DeleteUserPayload {
  id: string;
}

interface HandlePayload {
  handle: string;
}


// ---- P4 命名参数 DTO（字段名与 Rust 命令的 Args 键一致） ----

interface FileNamePayload {
  fileName: string;
}

interface UploadFilePayload {
  name: string;
  dataBase64: string;
}

interface PathPayload {
  path: string;
}

interface UrlsPayload {
  urls: string[];
}

interface UploadImagePayload {
  imageBase64: string;
  format: string;
  filename?: string;
  chName?: string;
}

interface ListImagesPayload {
  folder: string;
  sortField?: string;
  sortOrder?: string;
  mediaType?: number;
}

interface ImportCharacterPayload {
  dto: ImportCharacterDto;
}

interface ReplaceCharacterPayload {
  dto: ReplaceCharacterDto;
}

/** import_world_info 的入参（字段名跟 Rust 的 args 对齐：camelCase）。 */
interface ImportWorldInfoPayload {
  filePath: string;
  originalFilename: string;
  convertedData?: string;
}

interface ExportCharacterPayload {
  dto: ExportCharacterDto;
}

interface UrlPayload {
  url: string;
}

interface ImportCharacterDto {
  file_path: string;
  preserve_file_name?: string;
}

interface ReplaceCharacterDto {
  name: string;
  file_path: string;
}

interface ExportCharacterDto {
  name: string;
  format: string;
}

// ---- P5 命名参数 DTO ----

interface ChatLocatorPayload {
  characterName: string;
  fileName: string;
}

interface CharacterNamePayload {
  characterName: string;
}

interface AddMessagePayload {
  dto: AddMessageDto;
}

/** search_chats 入参（query 必填，characterFilter 可选）。 */
interface SearchChatsPayload {
  query: string;
  characterFilter?: string;
}

/** get_all_characters 入参（可选 shallow，缺省 deep）。 */
interface ShallowPayload {
  shallow: boolean;
}

/** create_chat 入参（Rust CreateChatDto 平铺 snake_case，包在 dto 里）。 */
interface CreateChatPayload {
  dto: CreateChatDtoWire;
}

interface CreateChatDtoWire {
  character_name: string;
  user_name: string;
  first_message: string | null;
}

interface AddMessageDto {
  character_name: string;
  file_name: string;
  is_user: boolean;
  content: string;
}

interface StartStreamPayload {
  streamId: string;
  dto: GenerateRequestDto;
}

interface GenerateCompletionPayload {
  requestId: string;
  dto: GenerateRequestDto;
}

interface ReadStreamPayload {
  streamId: string;
  afterSeq: number;
  format?: string;
}

interface StreamIdPayload {
  streamId: string;
}

interface RequestIdPayload {
  requestId: string;
}

interface EndpointPayload {
  endpoint: string;
}

export interface SettingsSnapshotDto {
  date: number;
  name: string;
  size: number;
}


interface ChatSearchQueryShape {
  query: string;
  limit: number;
}

interface IdShape {
  id: string;
}

interface RenameGroupChatShape {
  old_file_name: string;
  new_file_name: string;
}

interface WorldInfoSaveShape {
  name: string;
  data: ESObject;
}

interface TokenCountItemShape {
  messages: ESObject[];
}

interface TokenCountRequestShape {
  model: string;
  requests: TokenCountItemShape[];
}

export interface CommitBeginDto {
  // 注意：CommitBegin 在 Rust 侧是 #[serde(rename_all = "camelCase")]，所以是 sessionId
  sessionId: string;
  maxFrameBytes: number;
}

export interface UserSettingsRevisionShape {
  hash_algorithm: string;
  settings_hash: string;
}

export interface UserSettingsSaveResultDto {
  result: string;
  tauritavern_settings_revision: UserSettingsRevisionShape;
  persona_errors?: Record<string, string>;
}

interface SettingsChunkPayload {
  sessionId: string;
  offset: number;
  chunkBase64: string;
}

interface SettingsFinishPayload {
  sessionId: string;
  expectedSize: number;
}

interface SettingsSessionPayload {
  sessionId: string;
}

interface UpdateAvatarDtoShape {
  name: string;
  avatar_path: string;
}

interface ImportChatDtoShape {
  character_name: string;
  file_path: string;
  format: string;
}

interface ImportCharacterChatsDtoShape {
  character_name: string;
  file_path: string;
  file_type: string;
}

interface SecretKeyIdDto {
  key: string;
  id?: string;
}

interface SecretKeyIdOnlyDto {
  key: string;
  id: string;
}

interface SecretKeyIdLabelDto {
  key: string;
  id: string;
  label: string;
}

interface SecretPayload {
  dto: SecretWriteDto;
}

interface ProviderStatusPayload {
  dto: ProviderRequestDto;
}

interface SecretWriteDto {
  key: string;
  value: string;
  label?: string;
}
/** 全局单例：整个 ArkTS 侧只用一个后端门面。 */
export const Backend: BackendFacade = new BackendFacade();
