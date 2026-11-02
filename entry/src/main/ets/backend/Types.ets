/**
 * ArkTS 侧的 DTO 视图（partial view）。
 *
 * 后端返回的 JSON 与上游 TauriTavern 的 DTO 同构、字段更多；这里只声明 UI 实际读取的字段。
 * `as` 断言不做运行时校验，多余字段会被忽略，因此新增后端字段不需要同步改这里。
 */

/** 命令失败信封（invoke 永不 reject，失败以此结构返回）。 */
export interface CommandErrorPayload {
  code: string;
  message: string;
}

/** invoke 的返回信封。 */
export interface CommandEnvelope {
  ok: boolean;
  data?: ESObject;
  error?: CommandErrorPayload;
}

/** 后端事件信封：{"event":"<name>","payload":<json>}。 */
export interface BackendEventEnvelope {
  event: string;
  payload: ESObject;
}

/** getBackendStatus() 的返回结构。 */
export interface BackendStatus {
  ready: boolean;
  version: string;
  platform: string;
  dataRoot?: string;
  logRoot?: string;
  bundledResources?: number;
  /** P4: rawfile media root handed to the backend via undledMediaDir. */
  bundledMediaRoot?: string | null;
  /** P4: number of media files visible under that root. */
  bundledMediaFiles?: number;
  services?: number;
  initializedAt?: string;
  reason?: string;
}

/** get_runtime_paths。 */
export interface RuntimePathsDto {
  mode: string;
  data_root: string;
  configured_data_root?: string;
  migration_pending: boolean;
  migration_error?: string;
}

/** UserDto（UI 需要的字段）。 */
export interface UserDto {
  id: string;
  username: string;
  name: string;
  created: number;
  avatar?: string;
}

/** 创建用户入参。 */
export interface CreateUserInput {
  username: string;
  name: string;
  password?: string;
}

/** UserDirectoryDto（UI 需要的字段）。 */
export interface UserDirectoryDto {
  handle: string;
  name: string;
}

/** 角色（bootstrap 快照里 UI 需要的字段）。 */
export interface CharacterSummary {
  id: string;
  name: string;
  avatar?: string;
  description?: string;
}

/** get_bootstrap_metadata 的返回结构（partial）。 */
export interface BootstrapMetadata {
  characters: CharacterSummary[];
  groups: CharacterSummary[];
  avatars: string[];
  secret_state?: ESObject;
  ios_policy?: ESObject;
}

/** 后端初始化入参（与 host::paths::OhosAppPaths 的 camelCase 契约一致）。 */
export interface OhosPathsPayload {
  filesDir: string;
  databaseDir: string;
  cacheDir: string;
  bundleName: string;
  versionName: string;
}

// ---- P4 批次 DTO 视图（只声明 UI 会读的字段；后端加字段无需同步） ----

/** get_client_version（沿用上游字段名，扩展会按这些名字做兼容判断）。 */
export interface ClientVersion {
  agent: string;
  pkgVersion: string;
  tauriVersion: string;
  gitRevision?: string | null;
  gitBranch?: string | null;
  defaultUpdateChannel: string;
}

/** upload_user_file：SillyTavern 风格路径 /user/files/<name>。 */
export interface UserFileUploadResult {
  path: string;
}

/** upload_user_image / list_user_images 的结果路径（/user/images/...）。 */
export interface UserImageUploadResult {
  path: string;
}

/** upload_user_image 入参。 */
export interface UploadImageInput {
  imageBase64: string;
  format: string;
  filename?: string;
  chName?: string;
}

/** list_user_images 入参。 */
export interface ListImagesInput {
  folder: string;
  sortField?: string;
  sortOrder?: string;
  mediaType?: number;
}

/** import_character / replace_character 结果。 */
export interface ImportCharacterResult {
  character: CharacterSummary;
  lorebook?: ESObject;
}

/** export_character_content：JSON 通道下的 base64 载体。 */
export interface ExportedCharacterContent {
  dataBase64: string;
  byteLength: number;
}

/** download_external_import_url：base64 + 元数据。 */
export interface ExternalImportDownload {
  fileName: string;
  mimeType: string;
  dataBase64: string;
  byteLength: number;
}
// ---- P5：聊天与生成 ----

// 字段名契约（2026-10-26 23:55 修正）：tt-application 的 DTO **没有**
// #[serde(rename_all="camelCase")]，线上 JSON 是 snake_case —— 之前误按
// camelCase 建模，真机全部取到 undefined。Args 键（顶层参数）才是 camelCase。
// 对应 Rust 源：tt-application/src/dto/chat_dto.rs。

/** 服务商返回的本次请求用量；未提供的计数保持缺省，不伪造为 0。 */
export interface TokenUsage {
  prompt_tokens?: number;
  completion_tokens?: number;
  total_tokens?: number;
}

/** 聊天消息（对应 Rust ChatMessageDto：name/is_user/is_system/send_date/mes）。 */
export interface ChatMessageDto {
  name: string;
  is_user: boolean;
  is_system: boolean;
  send_date: string;
  mes: string;
  extra?: Record<string, ESObject>;
  /** 额外字段透传（上游 flattened additional；ArkTS 不允许索引签名，需要时用 Record 取值）。 */
  additional?: Record<string, ESObject>;
}

/**
 * 新增聊天消息的入参（ArkTS 侧便利类型）。Rust 的 AddMessageDto 是平铺
 * snake_case：{character_name, file_name, is_user, content, extra?} ——
 * Backend.addMessage 内部会做这个 reshape，sendDate/isSystem 由服务端落库时设置。
 */
export interface ChatMessageInput {
  name: string;
  isUser: boolean;
  isSystem: boolean;
  sendDate: string;
  mes: string;
  extra?: Record<string, ESObject>;
}

/** 生成请求体（对应 Rust ChatCompletionGenerateRequestDto 的扁平 payload）。 */
export interface ProviderRequestDto {
  chat_completion_source?: string;
  custom_api_format?: string;
  custom_url?: string;
  secret_id?: string;
  opencode_endpoint?: string;
  opencode_api_format?: string;
  moonshot_endpoint?: string;
  siliconflow_endpoint?: string;
  minimax_endpoint?: string;
  workers_ai_account_id?: string;
  aws_bedrock_region?: string;
  vertexai_region?: string;
}

export interface GenerateRequestDto extends ProviderRequestDto {
  custom_include_body?: string;
  model?: string;
  stream?: boolean;
  temperature?: number;
    top_p?: number;
  include_reasoning?: boolean;
  reasoning_effort?: string;
  max_tokens?: number;
  messages: ESObject[];
}

/**
 * 角色（对应 Rust CharacterDto，仅声明 UI 用到的字段；其余字段 JSON 透传时被忽略）。
 * P7 步骤 7 修复：真机 0 聊天时无法发送消息——需要角色列表 + create_chat 入口。
 */
export interface CharacterDto {
  name: string;
  first_mes: string;
  avatar?: string;
  description?: string;
  personality?: string;
  scenario?: string;
  mes_example?: string;
  creator?: string;
  creator_notes?: string;
  character_version?: string;
  tags?: string[];
  alternate_greetings?: string[];
  system_prompt?: string;
  post_history_instructions?: string;
}

/** 聊天（对应 Rust ChatDto：character_name/user_name/file_name/create_date/...）。 */
export interface ChatDto {
  character_name: string;
  user_name: string;
  file_name: string;
  create_date: string;
  chat_metadata: ESObject;
  messages: ChatMessageDto[];
  message_count: number;
  chat_id: number;
}

/** 聊天摘要（对应 Rust ChatSearchResultDto，list 类命令返回它）。 */
export interface ChatSearchResultDto {
  character_name: string;
  file_name: string;
  file_size: number;
  message_count: number;
  preview: string;
  date: number;
  chat_id?: string;
  chat_metadata?: ESObject;
}

/** 解码后的流片段：三通道（文本/推理/工具）+ 停止 + 原文兜底。 */
export interface TextPart { kind: 'text'; text: string; }
export interface ReasoningPart { kind: 'reasoning'; text: string; }
export interface ToolCallPart { kind: 'tool_call'; index: number; name: string; arguments_fragment: string; }
export interface StopPart { kind: 'stop'; reason: string; }
export interface RawPart { kind: 'raw'; data: string; }
export interface UsagePart { kind: 'usage'; usage: TokenUsage; }
export type DecodedPart = TextPart | ReasoningPart | ToolCallPart | StopPart | RawPart | UsagePart;

/** 解码后的流事件（对应 Rust DecodedStreamEventDto）。 */
export interface ChunkEvent { type: 'chunk'; seq: number; parts: DecodedPart[]; }
export interface DoneEvent { type: 'done'; seq: number; }
export interface ErrorEvent { type: 'error'; seq: number; message: string; }
export type DecodedStreamEvent = ChunkEvent | DoneEvent | ErrorEvent;

/** 解码后的流读取结果（对应 Rust ChatCompletionStreamReadResultDecodedDto）。 */
export interface ChatCompletionStreamReadResultDecodedDto {
  events: DecodedStreamEvent[];
  status: 'running' | 'done' | 'error' | 'cancelled';
}

// ---- P6.1：预设 / MCP / Skills / provider 元数据 / LLM 连接 / SearXNG / vector / database / data archive / extension store ----
// 字段名以各 Rust DTO 的 serde 为准：请求 DTO 绝大多数 camelCase；skill 的
// SkillImportInput 字段是 snake（skill_root / file_name / content_base64 / sha256）。

// 预设（tt-application/src/dto/preset_dto.rs + host 私有响应）
export interface SavePresetDto {
  name: string;
  apiId: string;
  /** 完整预设 JSON 对象（按 apiId 对应的格式，Rust 侧直接落盘）。 */
  preset: ESObject;
}

export interface DeletePresetDto {
  name: string;
  apiId: string;
}

export interface RestorePresetDto {
  name: string;
  apiId: string;
}

export interface DeleteOpenAIPresetDto {
  name: string;
}

export interface SavePresetResponseDto {
  name: string;
}

export interface RestorePresetResponseDto {
  isDefault: boolean;
  preset: ESObject;
}

export interface DeleteOpenAIPresetResponseDto {
  ok?: boolean;
  error?: string;
}

// ---- MCP（tt-application/src/dto/mcp_dto.rs；请求 DTO 全部 deny_unknown_fields，
// 只发下列精确字段，多一个键都会被 Rust 拒绝）----

export interface CreateMcpServerDto {
  displayName: string;
  endpoint: string;
  headers: Record<string, string>;
  protocolVersion: string;
}

export interface UpdateMcpServerDto {
  registrationId: string;
  displayName: string;
  endpoint: string;
  headers: Record<string, string>;
  protocolVersion: string;
}

export interface SetMcpServerStateDto {
  registrationId: string;
  /** 'active' | 'paused'（Rust McpServerState snake_case）。 */
  state: string;
}

export interface SetMcpToolPermissionDto {
  registrationId: string;
  nativeName: string;
  /** 'off' | 'ask' | 'allow'（Rust McpToolPermission snake_case）。 */
  permission: string;
}

export interface SetMcpToolDescriptionOverrideDto {
  registrationId: string;
  nativeName: string;
  /** Rust 字段 override_ 序列化为 "override"，Option，省略即清除。 */
  override?: ToolDescriptionOverride;
}

export interface ToolDescriptionOverride {
  description?: string;
  properties: Record<string, string>;
}

export interface TestMcpToolCallDto {
  callId: string;
  registrationId: string;
  nativeName: string;
  /** JSON 字符串（工具参数）。 */
  argumentsJson: string;
}

export interface McpTestCallIdDto {
  callId: string;
}

export interface McpExecutionCallIdDto {
  executionCallId: string;
}

export interface CallLegacyMcpToolDto {
  executionCallId: string;
  /** ToolId newtype，JSON 上是普通字符串。 */
  toolId: string;
  argumentsJson: string;
}

export interface McpRegistrationIdDto {
  registrationId: string;
}

// MCP 响应 DTO
export interface McpServerDto {
  id: string;
  displayName: string;
  endpoint: string;
  headers: Record<string, string>;
  protocolVersion: string;
  state: string;
  toolPermissions: Record<string, string>;
  toolDescriptionOverrides: Record<string, ESObject>;
}

export interface McpStorageIssueDto {
  fileName: string;
  message: string;
}

export interface ListMcpServersResultDto {
  servers: McpServerDto[];
  storageIssues: McpStorageIssueDto[];
}

export interface McpToolDto {
  id: string;
  nativeName: string;
  title?: string;
  description?: string;
  inputSchema: ESObject;
  outputSchema?: ESObject;
  annotations: ESObject;
  permission: string;
}

export interface McpToolDiagnosticDto {
  code: string;
  nativeName?: string;
  message: string;
}

export interface McpStaleToolDto {
  nativeName: string;
  permission: string;
}

export interface McpDiscoveryResultDto {
  registrationId: string;
  protocolVersion: string;
  serverName?: string;
  serverVersion?: string;
  tools: McpToolDto[];
  diagnostics: McpToolDiagnosticDto[];
  staleTools: McpStaleToolDto[];
}

export interface LegacyMcpToolDto {
  toolId: string;
  nativeName: string;
  serverDisplayName: string;
  title?: string;
  description?: string;
  inputSchema: ESObject;
}

export interface McpModelToolDiagnosticDto {
  toolId?: string;
  code: string;
  message: string;
}

export interface ListLegacyMcpToolsResultDto {
  tools: LegacyMcpToolDto[];
  diagnostics: McpModelToolDiagnosticDto[];
}

export interface McpTextContentDto {
  index: number;
  text: string;
}

export interface McpCallDiagnosticDto {
  code: string;
  message: string;
  contentIndex?: number;
}

/** McpKnownResponseDto：tag=kind 的枚举（toolResult / serverError / unsupportedResponse），
 *   rename_all_fields camelCase，用可选字段收拢。 */
export interface McpKnownResponseDto {
  kind: string;
  isError?: boolean;
  textBlocks?: McpTextContentDto[];
  structuredJson?: string;
  diagnostics?: McpCallDiagnosticDto[];
  code?: number;
  message?: string;
  dataJson?: string;
  responseType?: string;
}

/** McpCallOutcomeDto：tag=outcome（knownResponse / notSent / outcomeUnknown）。 */
export interface McpCallOutcomeDto {
  outcome: string;
  response?: McpKnownResponseDto;
  code?: string;
  message?: string;
}

// ---- Agent Skills（tt-domain/src/models/skill.rs）----

/** SkillScope：tag=kind（builtin / global / preset / profile / character），
 *   rename_all_fields camelCase。 */
export interface SkillScope {
  kind: string;
  apiId?: string;
  name?: string;
  profileId?: string;
  characterId?: string;
}

/** SkillScopeFilter：与 SkillScope 同形（builtin / all / global / preset / profile / character）。 */
export interface SkillScopeFilter {
  kind: string;
  apiId?: string;
  name?: string;
  profileId?: string;
  characterId?: string;
}

export interface SkillInlineFile {
  path: string;
  encoding?: string;
  content: string;
  mediaType?: string;
  sizeBytes?: number;
  sha256?: string;
}

/** SkillImportInput：tag=kind（inlineFiles / directory / archiveFile / archiveBase64）。
 *   注意：字段名是 snake_case（skill_root / file_name / content_base64 / sha256）。 */
export interface SkillImportInput {
  kind: string;
  files?: SkillInlineFile[];
  source?: string;
  path?: string;
  skill_root?: string;
  file_name?: string;
  content_base64?: string;
  sha256?: string;
}

export interface SkillInstallRequest {
  input: SkillImportInput;
  targetScope: SkillScope;
  /** 'replace' | 'keep'（Rust SkillInstallConflictStrategy snake_case）。 */
  conflictStrategy?: string;
}

export interface SkillMoveRequest {
  name: string;
  fromScope: SkillScope;
  toScope: SkillScope;
  conflictStrategy?: string;
}

export interface SkillScopeRetargetRequest {
  fromScope: SkillScope;
  toScope: SkillScope;
}

export interface SkillScopeRetargetResult {
  moved: number;
  merged: number;
  sourceRefsUpdated: number;
}

export interface SkillFileRef {
  path: string;
  kind: string;
  mediaType: string;
  sizeBytes: number;
  sha256: string;
}

export interface SkillSourceRef {
  kind: string;
  id: string;
  label: string;
  installedHash: string;
}

export interface SkillIndexEntry {
  scope: SkillScope;
  name: string;
  description: string;
  displayName?: string;
  sourceKind?: string;
  license?: string;
  author?: string;
  version?: string;
  tags: string[];
  installedHash: string;
  fileCount: number;
  totalBytes: number;
  hasScripts: boolean;
  hasBinary: boolean;
  installedAt: string;
  sourceRefs?: SkillSourceRef[];
}

export interface SkillImportConflict {
  kind: string;
  installedHash?: string;
}

export interface SkillImportPreview {
  skill: SkillIndexEntry;
  files: SkillFileRef[];
  conflict: SkillImportConflict;
  warnings: string[];
  source: ESObject;
}

export interface SkillInstallResult {
  scope: SkillScope;
  name: string;
  action: string;
  skill?: SkillIndexEntry;
}

export interface SkillReadResult {
  scope: SkillScope;
  name: string;
  path: string;
  content: string;
  chars: number;
  words: number;
  totalChars: number;
  totalWords: number;
  totalLines: number;
  startLine: number;
  endLine: number;
  nextStartLine?: number;
  lineTruncated: boolean;
  bytes: number;
  sha256: string;
  truncated: boolean;
  resourceRef: string;
}

/** export_skill：host 私有响应（Rust SkillExportPayload），base64 走 JSON 通道。 */
export interface SkillExportPayload {
  fileName: string;
  contentBase64: string;
  sha256: string;
}

// ---- provider 元数据（tt-application/src/dto/provider_metadata_dto.rs）----
// 注意这三个请求 DTO 是 snake_case 字段（与大多数 camelCase DTO 不同）。

export interface ProviderModelProvidersRequestDto {
  model: string;
}

export interface SiliconFlowEmbeddingModelsRequestDto {
  siliconflow_endpoint: string;
}

export interface WorkersAiModelsRequestDto {
  workers_ai_account_id: string;
}

// 响应（OpenRouterCredits / NanoGptCredits / NanoGptModelProviders 等）结构动态，用 ESObject。

// ---- LLM 连接（tt-application/src/dto/llm_connection_dto.rs）----

export interface LlmConnectionIdDto {
  connectionId: string;
}

export interface LlmConnectionSummary {
  id: string;
  displayName: string;
  description?: string;
  chatCompletionSource: string;
  customApiFormat?: string;
}

export interface ListLlmConnectionsResultDto {
  connections: LlmConnectionSummary[];
}

export interface LoadLlmConnectionResultDto {
  connection?: ESObject;
}

/** SaveLlmConnectionDto 的入参视图：{connection: LlmConnectionDefinition}，
 *   LlmConnectionDefinition 结构很大且随 provider 变化，用 ESObject 承载。 */
export interface SaveLlmConnectionDto {
  connection: ESObject;
}

// ---- SearXNG（tt-application/src/dto/searxng_search_dto.rs）----

export interface SearxngSearchRequestDto {
  baseUrl: string;
  query: string;
  /** 偏好/分类是字符串（不是数组），可省略。 */
  preferences?: string;
  categories?: string;
}

// ---- vector（tt-application/src/dto/vector_dto.rs）----

export interface VectorItemDto {
  hash: number;
  text: string;
  index: number;
}

/** VectorRouteRequestDto：字段很多且大多有默认值，只声明 UI 会设置的。 */
export interface VectorRouteRequestDto {
  collectionId?: string;
  collectionIds?: string[];
  source?: string;
  items?: VectorItemDto[];
  hashes?: number[];
  searchText?: string;
  topK?: number;
  threshold?: number;
  model?: string;
  apiUrl?: string;
  keep?: boolean;
  isQuery?: boolean;
  texts?: string[];
}

export interface VectorRouteResponseDto {
  status: number;
  kind: string;
  body: ESObject;
}

// ---- database（tt-contracts/src/database.rs）----

export interface DatabaseOpenOptions {
  dim?: number;
  storageMode?: string;
  syncMode?: string;
  loadTextIndex?: boolean;
  autoBuildQuiver?: boolean;
  memoryLimitMb?: number;
}

/** DatabaseRequest：tag=type（open / close / listNamespaces / execute / flushAll / closeAll）。 */
export interface DatabaseRequest {
  type: string;
  namespace?: string;
  options?: DatabaseOpenOptions;
  /** DatabaseOperation（execute 用），结构随操作类型变化，用 ESObject。 */
  operation?: ESObject;
}

// ---- data archive（tt-application/src/dto/data_archive_dto.rs + host 私有响应）----
// DataArchiveJobStatus 没有 serde 属性，线上字段是 snake_case。

export interface DataArchiveLocalMutationSummaryDto {
  files_written: number;
  bytes_written: number;
  target_changed?: boolean;
}

export interface DataArchiveJobStatus {
  job_id: string;
  kind: string;
  state: string;
  stage: string;
  progress_percent: number;
  message: string;
  result?: ESObject;
  error?: string;
  local_applied?: DataArchiveLocalMutationSummaryDto;
  reconcile_error?: string;
  started_at: string;
  finished_at?: string;
}

/** import_data_archive_from_picker：host 私有响应（cancelled 恒为 false）。 */
export interface ImportArchiveResult {
  cancelled: boolean;
  job_id?: string;
  file_name?: string;
}

/** save_export_data_archive / export_user_backup_archive：host 私有响应
 *   （比上游多 path/fileName —— OHOS 由 ArkTS 读沙箱文件交给保存选择器）。 */
export interface DeliveryResult {
  delivered: boolean;
  path?: string;
  fileName?: string;
}

// ---- extension store（tt-contracts/src/extension_store.rs）----

export type EntryKind = 'json' | 'blob';


// ============================================================================
// P6.2 类型（agent / extension / sync 域）
// ============================================================================
// 命名与字段与 Rust 侧 serde 输出一一对应：agent 域 camelCase、extension 结构体 snake、
// sync snake、枚举串值（SyncMode 小写、OverwritePolicy kebab、ExtensionType PascalCase）。

// ---- agent：请求 DTO（ArkTS 构造，camelCase）----

/** AgentChatRef（tt-domain models::agent）：Character {characterId, fileName} | Group {chatId} */
export interface AgentChatRefDto {
  characterId?: string;
  fileName?: string;
  chatId?: string;
}

export interface AgentSkillScopeRefsDto {
  characterId?: string;
}

export interface AgentStartRunOptionsDto {
  hostPresentation: boolean;
  startWithEmptyPersist: boolean;
  stream?: boolean;
  presentation?: ESObject;
}

export interface AgentStartRunDto {
  chatRef: ESObject;
  stableChatId?: string;
  generationType?: string;
  profileId?: string;
  persistBaseStateId?: string;
  promptSnapshot?: ESObject;
  frozenRunInputSnapshot?: ESObject;
  generationIntent?: ESObject;
  skillScopeRefs?: AgentSkillScopeRefsDto;
  options?: AgentStartRunOptionsDto;
}

export interface AgentResumeRunDto {
  runId: string;
  expectedTerminalSeq: number;
  chatRef: ESObject;
  stableChatId: string;
  hostPresentation?: boolean;
  revision?: AgentOutputRevisionDto;
}

export interface AgentOutputRevisionDto {
  guidance: string;
  previousOutput: string;
}

export interface AgentReadRunCheckpointDto {
  runId: string;
}

export interface AgentFinishRunPresentationDto {
  runId: string;
  terminalSeq: number;
  presentation?: ESObject;
}

export interface AgentSubscribeRunLiveProjectionDto {
  runId: string;
}

export interface AgentPreparePromptAssemblyDto {
  profileId?: string;
  generationType?: string;
  frozenRunInputSnapshot: ESObject;
  jsonSchema?: ESObject;
}

export interface AgentBuildCurrentModelConnectionSnapshotDto {
  settings: ESObject;
  model: string;
  secretId?: string;
}

export interface AgentApplyCurrentModelConnectionSnapshotDto {
  settings: ESObject;
  currentModelConnection: ESObject;
}

export interface AgentListToolsDto {
  context?: string;
}

export interface AgentResolveSystemPromptDto {
  profileId?: string;
}

export interface AgentProfileIdDto {
  profileId: string;
}

export interface AgentSaveProfileDto {
  profile: ESObject;
}

export interface AgentRepairProfileFileDto {
  profileId: string;
  action: string;
}

/** AgentPresetRef {apiId, name} */
export interface AgentPresetRefDto {
  apiId: string;
  name: string;
}

export interface AgentRetargetPresetRefsDto {
  from: AgentPresetRefDto;
  to: AgentPresetRefDto;
}

export interface AgentCancelRunDto {
  runId: string;
}

export interface AgentSubmitGuidanceDto {
  runId: string;
  text: string;
  clientGuidanceId?: string;
}

export interface AgentListRunsCursorDto {
  createdAt: string;
  runId: string;
}

export interface AgentListRunsDto {
  chatRef?: ESObject;
  stableId?: string;
  statuses?: string[];
  before?: AgentListRunsCursorDto;
  limit?: number;
}


export interface AgentReadEventsDto {
  runId: string;
  afterSeq?: number;
  beforeSeq?: number;
  limit?: number;
  invocationId?: string;
  includeTimelineProjection: boolean;
}

export interface AgentReadWorkspaceFileDto {
  runId: string;
  path: string;
}

export interface AgentReadTaskDetailDto {
  runId: string;
  taskId: string;
  includeResult: boolean;
}

export interface AgentReadModelTurnDto {
  runId: string;
  invocationId?: string;
  round: number;
  maxChars?: number;
}

export interface AgentReadPromptAssemblyRequestDto {
  runId: string;
  assemblyId: string;
}

export interface AgentResolveChatCommitDto {
  runId: string;
  commitId: string;
  messageId?: string;
  error?: string;
}

export interface AgentResolvePersistentStateMetadataUpdateDto {
  runId: string;
  updateId: string;
  error?: string;
}

export interface AgentResolvePromptAssemblyDto {
  runId: string;
  assemblyId: string;
  promptSnapshot?: ESObject;
  frozenRunInputSnapshot?: ESObject;
  generationIntent?: ESObject;
  assembly?: ESObject;
  error?: string;
}

export interface AgentPruneChatPersistentStatesDto {
  chatRef: ESObject;
  stableId?: string;
  candidateStateIds?: string[];
}

export interface AgentCopyChatPersistentStatesDto {
  sourceChatRef: ESObject;
  sourceStableChatId: string;
  targetChatRef: ESObject;
  targetStableChatId: string;
}

// ---- agent session：请求 DTO（camelCase）----

export interface AgentPrepareSessionRunDto {
  sessionId: string;
  input: ESObject;
  profile: ESObject;
}

export interface AgentStartSessionRunDto {
  sessionId: string;
  input: ESObject;
  profile: ESObject;
  expectedHistorySeq: number;
  promptSnapshot: ESObject;
  promptAssemblyRequest: ESObject;
  generationIntent: ESObject;
  stream?: boolean;
}

export interface AgentRenameSessionDto {
  sessionId: string;
  title: string;
}

export interface AgentDeleteSessionDto {
  sessionId: string;
}

export interface AgentReadSessionDto {
  sessionId: string;
  beforeSeq?: number;
  limit?: number;
}

// ---- agent：简单返回 DTO（camelCase；深结构用 ESObject 直返）----

export interface AgentRunHandleDto {
  runId: string;
  workspaceId: string;
  stableChatId: string;
  generationType: string;
  status: string;
  afterSeq?: number;
}

export interface AgentSessionRunHandleDto {
  sessionId: string;
  runId: string;
  status: string;
  createdAt: string;
}

export interface AgentActiveRunDto {
  runId: string;
  afterSeq: number;
}

export interface AgentWorkspaceFileDto {
  path: string;
  text: string;
  chars: number;
  words: number;
  sha256: string;
}

export interface AgentResolveSystemPromptResultDto {
  agentSystemPrompt: string;
}

export interface AgentBuildCurrentModelConnectionSnapshotResultDto {
  currentModelConnection: ESObject;
}

export interface AgentApplyCurrentModelConnectionSnapshotResultDto {
  settings: ESObject;
}

export interface AgentSubmitGuidanceResultDto {
  runId: string;
  guidanceId: string;
  clientGuidanceId?: string;
  status: string;
  preview: string;
  chars: number;
  words: number;
  pendingCount: number;
}

export interface AgentRetargetPresetRefsResultDto {
  updated: number;
  profileIds: string[];
  sessionProfileUpdated: boolean;
}

export interface AgentPruneChatPersistentStatesResultDto {
  workspaceId: string;
  removedStateIds: string[];
}

export interface AgentReadRunCheckpointResultDto {
  run: AgentRunHandleDto;
  terminalSeq: number;
  presentation?: ESObject;
  nextStep: string;
  blockedReason?: string;
}

export interface AgentReadEventsResultDto {
  events: ESObject[];
  timelineProjection?: ESObject;
}

export interface AgentSessionProfileResultDto {
  profile?: ESObject;
}

export interface AgentSessionResultDto {
  session: ESObject;
}

// ---- extension（tt-domain models::extension：结构体 snake、枚举 PascalCase）----

export type ExtensionType = 'System' | 'Local' | 'Global';

export interface Extension {
  name: string;
  extension_type: ExtensionType;
}

export interface ExtensionVersion {
  current_branch_name: string;
  current_commit_hash: string;
  is_up_to_date: boolean;
  remote_url: string;
}

export interface ExtensionBranch {
  name: string;
  commit: string;
  current: boolean;
  label: string;
}

export interface ExtensionInstallResult {
  version: string;
  author: string;
  display_name: string;
  extension_path: string;
  folder_name: string;
}

export interface ExtensionUpdateResult {
  short_commit_hash: string;
  extension_path: string;
  is_up_to_date: boolean;
  remote_url: string;
}

// ---- sync 域（snake 键）----

/** SyncMode 串值（ttsync-contract）：normal / full / off */
export type SyncMode = 'normal' | 'full' | 'off';
/** OverwritePolicy（ttsync-contract）：exact / prefer-newer */
export type OverwritePolicy = 'exact' | 'prefer-newer';

export interface SyncOperationOptions {
  selection: ESObject;
  overwrite_policy?: OverwritePolicy;
  require_bundle_zstd?: boolean;
}

export interface LanSyncPairedDeviceDto {
  device_id: string;
  device_name: string;
  last_known_address?: string;
  paired_at_ms: number;
  last_sync_ms?: number;
}

export interface LanSyncPairingInfoDto {
  address: string;
  pair_uri: string;
  qr_svg: string;
}

export interface TtSyncPermissionsDto {
  read: boolean;
  write: boolean;
  mirror_delete: boolean;
}

export interface TtSyncPairedServerDto {
  server_device_id: string;
  server_device_name: string;
  base_url: string;
  spki_sha256: string;
  permissions: TtSyncPermissionsDto;
  paired_at_ms: number;
  last_sync_ms?: number;
}

export interface SyncDatasetCatalogDto {
  policy_version: number;
  supported_dataset_ids: string[];
  supported_profile_ids: string[];
  default_dataset_ids: string[];
}


/** list_agent_runs 的响应：runs + 分页游标。 */
export interface AgentRunSummaryDto {
  runId: string;
  workspaceId: string;
  stableChatId: string;
  chatRef: AgentChatRefDto;
  generationType: string;
  profileId?: string;
  status: string;
  createdAt: string;
  updatedAt: string;
  commitCount: number;
}

export interface AgentListRunsResultDto {
  runs: AgentRunSummaryDto[];
  nextCursor?: ESObject;
}

/** read_agent_run_events 里的事件（payload 是任意 JSON）。 */
export interface AgentRunEventDto {
  seq: number;
  id: string;
  runId: string;
  timestamp: string;
  level: string;
  type: string;
  payload?: ESObject;
}

/** list_agent_profiles 的响应。 */
export interface AgentProfileSummaryDto {
  id: string;
  displayName: string;
  description?: string;
  directRunnable: boolean;
}

export interface AgentListProfilesResultDto {
  profiles: AgentProfileSummaryDto[];
  issues?: ESObject[];
}

export interface AgentRunPruneRetentionDto {
  keepRecentTerminalRuns: number;
  keepFullRecentRuns: number;
}

export interface AgentPlanRunPruneDto {
  retention?: AgentRunPruneRetentionDto;
  detailLimit?: number;
}

export interface AgentApplyRunPruneDto {
  retention?: AgentRunPruneRetentionDto;
  detailLimit?: number;
}

export interface AgentRunPrunePlanDto {
  retention: AgentRunPruneRetentionDto;
  detailLimit: number;
  terminalRunCount: number;
  nonTerminalRunCount: number;
  blockedRunCount: number;
  fullRetainedRunCount: number;
  coreRetainedRunCount: number;
  slimCandidateCount: number;
  deleteCandidateCount: number;
  totalSlimFileCount: number;
  totalDeleteFileCount: number;
  totalSlimBytes: number;
  totalDeleteBytes: number;
}

export interface AgentRunPruneApplyResultDto {
  slimmedRuns: number;
  deletedRuns: number;
  freedBytes: number;
}
