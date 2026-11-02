# P6.1 契约对表（62 条，2026-10-27 00:20 程序化生成）

约定（P5 钉死的铁律，更正 3/4）：
- 顶层键 = camelCase（Tauri v2 命令参数默认 camelCase，与宿主 `args.require` 一致）
- DTO 体字段名 = 该 DTO 的 serde 属性（默认 snake_case），开工时逐条对 DTO 定义核对
- DTO 包装键 = 上游参数原名（多数为 `dto`，个别为 `request`/`input`/`handle`），宿主用 `args.typed(<包装键>)`
- `[split]` = 上游挂 WebviewWindow 对话框，鸿蒙拆到 ArkTS DocumentViewPicker 侧，Rust 只留服务调用

| 命令 | 载荷（camelCase 顶层键 + DTO 名） |
| --- | --- |
| `database_handle` | `request`: DatabaseRequest |
| `import_data_archive_from_picker` | [split] 无参（上游 window 参数 -> ArkTS DocumentViewPicker） |
| `start_export_data_archive` | 无参 |
| `get_data_archive_job_status` | `jobId`: String |
| `cancel_data_archive_job` | `jobId`: String |
| `save_export_data_archive` | [split] `jobId`: String（另收 WebviewWindow -> ArkTS 保存对话框） |
| `export_user_backup_archive` | [split] `handle`: String, `includeSecrets`: bool（另收 WebviewWindow -> ArkTS 保存对话框） |
| `rename_extension_store_key` | `namespace`: String, `key`: String, `newKey`: String, `table`: Option<String> |
| `delete_extension_store_entry` | `namespace`: String, `key`: String, `table`: Option<String>, `kind`: EntryKind |
| `list_extension_store_keys` | `namespace`: String, `table`: Option<String>, `kind`: EntryKind |
| `list_extension_store_tables` | `namespace`: String |
| `delete_extension_store_table` | `namespace`: String, `table`: String |
| `list_llm_connections` | 无参 |
| `load_llm_connection` | `dto`: LlmConnectionIdDto |
| `save_llm_connection` | `dto`: SaveLlmConnectionDto |
| `delete_llm_connection` | `dto`: LlmConnectionIdDto |
| `list_mcp_servers` | 无参 |
| `create_mcp_server` | `dto`: CreateMcpServerDto |
| `update_mcp_server` | `dto`: UpdateMcpServerDto |
| `set_mcp_server_state` | `dto`: SetMcpServerStateDto |
| `remove_mcp_server` | `dto`: McpRegistrationIdDto |
| `discover_mcp_tools` | `dto`: McpRegistrationIdDto |
| `refresh_mcp_tools` | `dto`: McpRegistrationIdDto |
| `set_mcp_tool_permission` | `dto`: SetMcpToolPermissionDto |
| `set_mcp_tool_description_override` | `dto`: SetMcpToolDescriptionOverrideDto |
| `start_mcp_test_call` | `dto`: McpTestCallIdDto |
| `test_mcp_tool_call` | `dto`: TestMcpToolCallDto |
| `cancel_mcp_test_call` | `dto`: McpTestCallIdDto |
| `list_legacy_mcp_tools` | 无参 |
| `start_legacy_mcp_tool_call` | `dto`: McpExecutionCallIdDto |
| `call_legacy_mcp_tool` | `dto`: CallLegacyMcpToolDto |
| `cancel_legacy_mcp_tool_call` | `dto`: McpExecutionCallIdDto |
| `save_preset` | `dto`: SavePresetDto |
| `delete_preset` | `dto`: DeletePresetDto |
| `restore_preset` | `dto`: RestorePresetDto |
| `save_openai_preset` | `name`: String, `dto`: SaveOpenAIPresetDto |
| `delete_openai_preset` | `dto`: DeleteOpenAIPresetDto |
| `list_presets` | `apiId`: String |
| `preset_exists` | `name`: String, `apiId`: String |
| `get_preset` | `name`: String, `apiId`: String |
| `get_openrouter_model_providers` | `dto`: ProviderModelProvidersRequestDto |
| `get_openrouter_credits` | 无参 |
| `get_nanogpt_model_providers` | `dto`: ProviderModelProvidersRequestDto |
| `get_nanogpt_credits` | 无参 |
| `get_siliconflow_embedding_models` | `dto`: SiliconFlowEmbeddingModelsRequestDto |
| `get_workers_ai_embedding_models` | `dto`: WorkersAiModelsRequestDto |
| `get_workers_ai_multimodal_models` | `dto`: WorkersAiModelsRequestDto |
| `search_searxng` | `dto`: SearxngSearchRequestDto, `locale`: String |
| `download_skill_import_url` | `url`: String |
| `list_skills` | `scope`: Option<SkillScopeFilter> |
| `list_skill_files` | `name`: String, `scope`: Option<SkillScope> |
| `discover_skill_imports` | `input`: SkillImportInput |
| `discard_skill_import_archive` | `path`: String |
| `preview_skill_import` | `input`: SkillImportInput, `targetScope`: Option<SkillScope> |
| `install_skill_import` | `request`: SkillInstallRequest |
| `read_skill_file` | `name`: String, `path`: String, `scope`: Option<SkillScope>, `startLine`: Option<usize>, `lineCount`: Option<usize> |
| `write_skill_file` | `name`: String, `path`: String, `content`: String, `scope`: Option<SkillScope>, `expectedSha256`: Option<String> |
| `export_skill` | `name`: String, `scope`: Option<SkillScope> |
| `delete_skill` | `name`: String, `scope`: Option<SkillScope> |
| `move_skill` | `request`: SkillMoveRequest |
| `retarget_skill_scope` | `request`: SkillScopeRetargetRequest |
| `vector_handle` | `path`: String, `request`: VectorRouteRequestDto |

## DTO serde 对表（27 个，2026-10-27 00:45 逐定义 + 逐字段核对）

**重要**：P6.1 的 DTO **19 个 camelCase、8 个 snake_case** —— 更正 4 的「默认 snake」只对 chat DTO 成立，不可推广。逐 DTO 以 serde 属性为准。**10 个 mcp DTO 全部 `deny_unknown_fields`**：ArkTS 侧多传一个字段、错一个键名即整个命令失败 —— 这是 P6.1 最严的契约面。

| DTO | serde | 精确线上形状 |
| --- | --- | --- |
| CreateMcpServerDto / UpdateMcpServerDto / SetMcpServerStateDto / McpRegistrationIdDto / SetMcpToolPermissionDto / TestMcpToolCallDto / McpTestCallIdDto / McpExecutionCallIdDto / CallLegacyMcpToolDto | rename_all=camelCase + **deny_unknown_fields** | 字段 camelCase，**只能传精确键** |
| SetMcpToolDescriptionOverrideDto | rename_all=camelCase + **deny_unknown_fields** | `{registrationId, nativeName, override?}`（Rust 字段 `override_` 显式 rename="override"） |
| SearxngSearchRequestDto / LlmConnectionIdDto / SaveLlmConnectionDto / VectorRouteRequestDto | rename_all=camelCase | 字段 camelCase（无 deny） |
| SavePresetDto | 无 struct serde | `{name, apiId, preset}`（`api_id` 显式 rename="apiId"；preset 为任意 JSON） |
| DeletePresetDto / RestorePresetDto | 无 struct serde | `{name, apiId}` |
| SaveOpenAIPresetDto | `#[serde(flatten)] preset: Value` | **载荷即任意 preset JSON，无信封** |
| DeleteOpenAIPresetDto | 无 struct serde | `{name}` |
| ProviderModelProvidersRequestDto | 无 serde | `{model}`（snake） |
| SiliconFlowEmbeddingModelsRequestDto | 无 serde | `{siliconflow_endpoint}`（snake，可省） |
| WorkersAiModelsRequestDto | 无 serde | `{workers_ai_account_id}`（snake，可省） |
| DatabaseRequest（enum） | tag="type" + rename_all=camelCase + rename_all_fields=camelCase | `{type:"open"\|"close"\|"listNamespaces"\|"execute"\|"flushAll"\|"closeAll", namespace, options?, operation?}` |
| SkillImportInput（enum） | tag="kind" + rename_all=camelCase（**无 rename_all_fields**） | `{kind:"inlineFiles"\|"directory"\|"archiveFile"\|"archiveBase64", ...}`；**字段保持 snake**：files/source/path/`skill_root`/`file_name`/`content_base64`/`sha256` |
| SkillInstallRequest / SkillMoveRequest / SkillScopeRetargetRequest | rename_all=camelCase | 字段 camelCase |

## 出站响应 serde 对表（24 个，2026-10-27 00:55 逐定义核对）

与入站同铁律：响应 JSON 键名以 serde 属性为准，ArkTS 接口按此建模。

| 响应类型 | serde | 线上形状 |
| --- | --- | --- |
| McpServerDto / McpDiscoveryResultDto / ListLegacyMcpToolsResultDto / ListLlmConnectionsResultDto / LoadLlmConnectionResultDto | rename_all=camelCase | 字段 camelCase |
| NanoGptModelProviders / SkillImportPreview / SkillInstallResult / SkillReadResult / SkillScopeRetargetResult / SkillFileRef / SkillIndexEntry | rename_all=camelCase | 字段 camelCase |
| SkillExportPayload（宿主重建） | rename_all=camelCase | `{fileName, contentBase64, sha256}` |
| McpCallOutcomeDto | tag="outcome" + 变体 snake + 字段 camel | `{outcome:"...", ...}` |
| DatabaseResponse（enum） | **untagged** | 原始值透传，不套标签 |
| DataArchiveJobStatus | 无 serde | `{job_id, kind, state, stage, progress_percent, message, result?, error?}`（snake） |
| NanoGptCredits | 无 serde | `{usd_balance, nano_balance, subscription?}`（snake） |
| OpenRouterCredits | 无 serde | `{remaining, total_credits, total_usage}`（snake） |
| SavePresetResponseDto | 无 serde | `{name}` |
| RestorePresetResponseDto | 无 serde + is_default rename="isDefault" | `{isDefault, preset}` |
| DeleteOpenAIPresetResponseDto | 无 serde + skip 空 Option | `{ok?, error?}` |
| VectorRouteResponseDto | 无 serde | `{status, kind, body}`（snake） |
| ImportArchiveResult / DeliveryResult（宿主重建） | 无 serde / camelCase | `{cancelled, job_id?, file_name?}` / `{delivered, path?, fileName?}` |

## P6.1 [split] 落地决策（2026-10-27，与 P4 先例一致，已实现进 host 命令）

三条窗口绑定命令的 OHOS 落地（上游全用 WebviewWindow + 系统对话框，鸿蒙只能在 ArkTS 侧弹选择器）：

1. **import_data_archive_from_picker**：新增必填顶层键 `path`（ArkTS 用 `DocumentViewPicker().select()` 选文件 → `@ohos.file.fs.copyFile` 拷到 `<cacheDir>/imports/<uuid>.archive` → 传绝对路径，P4 import_character 同款）。`fileName` 可选透传原名。Rust 侧 `start_import(&path, temporary=true)`（把文件移入任务工作区）。**分类由审计的 ok 改为 bad_request（空载荷缺 path）**。
2. **save_export_data_archive**：`claim_export_artifact` → 检查产物存在 → `finish_export_delivery` → 返回 `{delivered, path, fileName}`。ArkTS 用 `@ohos.file.fs` 读 path（沙箱内）→ `DocumentViewPicker`(SAVE) 写入用户位置。
3. **export_user_backup_archive**：同 2 的响应形状（`export_user_backup` 返回 `{file_name, archive_path}` → 转 `{delivered, path, fileName}`）。

`DeliveryResult` 比上游多 `path`/`fileName`（上游只有 `{delivered}`，因为保存对话框在 Rust 侧弹）。不采用 base64 整包通道：归档可能数十 MB，JSON 通道不适合；ArkTS 与本进程同沙箱可直接读产物路径。

## P6.1 空载荷 dispatch 分类审计（2026-10-27 15:45，子代理逐条核对上游签名，全部与 p61-sigs.txt 一致）

规则：顶层必填键缺失 → `bad_request`；仅 Tauri 注入（app_state/window）或 Option 参数 → `ok`。**统计：ok=8 / bad_request=54（合计 62）**，与开工清单预计算吻合。落地后 import_data_archive_from_picker 因新增 `path` 归入 bad_request（见上节），故**实测量纲**为：**routes=186 / ok=31 / bad=138 / not_ported=16 / other=1（view_secrets→unauthorized）**（dispatch_contract_tests 实测 2026-10-27 16:15）。ok 8 中 get_openrouter_credits / get_nanogpt_credits 空载荷下服务层报 bad_request（缺 API key），不计入 ok。

| 命令 | 必填顶层键（camelCase） | 分类 | 备注 |
| --- | --- | --- | --- |
| database_handle | request | bad_request | `request: DatabaseRequest` 必填 |
| import_data_archive_from_picker | — | ok | 仅注入；window→[split] ArkTS picker |
| start_export_data_archive | — | ok | 仅 app_state |
| get_data_archive_job_status | jobId | bad_request | `job_id: String` 必填 |
| cancel_data_archive_job | jobId | bad_request | `job_id: String` 必填 |
| save_export_data_archive | jobId | bad_request | window 注入（[split] 保存对话框）；job_id 仍必填 |
| export_user_backup_archive | handle, includeSecrets | bad_request | window 注入（[split]）；`handle` + `include_secrets: bool` 必填 |
| rename_extension_store_key | namespace, key, newKey | bad_request | `table: Option` 可省 |
| delete_extension_store_entry | namespace, key, kind | bad_request | `kind: EntryKind` 必填 |
| list_extension_store_keys | namespace, kind | bad_request | 与已核实一致 |
| list_extension_store_tables | namespace | bad_request | |
| delete_extension_store_table | namespace, table | bad_request | |
| list_llm_connections | — | ok | 仅 app_state |
| load_llm_connection | dto | bad_request | `dto: LlmConnectionIdDto` |
| save_llm_connection | dto | bad_request | `dto: SaveLlmConnectionDto` |
| delete_llm_connection | dto | bad_request | `dto: LlmConnectionIdDto` |
| list_mcp_servers | — | ok | 仅 app_state |
| create_mcp_server | dto | bad_request | mcp 各 dto 必填；deny_unknown_fields 不影响空载荷（缺失 dto 键先失败） |
| update_mcp_server | dto | bad_request | 同上 |
| set_mcp_server_state | dto | bad_request | 同上 |
| remove_mcp_server | dto | bad_request | 同上 |
| discover_mcp_tools | dto | bad_request | 同上 |
| refresh_mcp_tools | dto | bad_request | 同上 |
| set_mcp_tool_permission | dto | bad_request | 同上 |
| set_mcp_tool_description_override | dto | bad_request | 同上 |
| start_mcp_test_call | dto | bad_request | 同上 |
| test_mcp_tool_call | dto | bad_request | 同上 |
| cancel_mcp_test_call | dto | bad_request | 同上 |
| list_legacy_mcp_tools | — | ok | 仅 app_state |
| start_legacy_mcp_tool_call | dto | bad_request | `dto: McpExecutionCallIdDto` |
| call_legacy_mcp_tool | dto | bad_request | `dto: CallLegacyMcpToolDto` |
| cancel_legacy_mcp_tool_call | dto | bad_request | `dto: McpExecutionCallIdDto` |
| save_preset | dto | bad_request | `dto: SavePresetDto` |
| delete_preset | dto | bad_request | `dto: DeletePresetDto` |
| restore_preset | dto | bad_request | `dto: RestorePresetDto` |
| save_openai_preset | name, dto | bad_request | name + `dto: SaveOpenAIPresetDto`（flatten 信封）均必填 |
| delete_openai_preset | dto | bad_request | `dto: DeleteOpenAIPresetDto` |
| list_presets | apiId | bad_request | `api_id: String` 必填（顶层键 apiId） |
| preset_exists | name, apiId | bad_request | |
| get_preset | name, apiId | bad_request | |
| get_openrouter_model_providers | dto | bad_request | `dto: ProviderModelProvidersRequestDto` |
| get_openrouter_credits | — | ok | 仅 app_state |
| get_nanogpt_model_providers | dto | bad_request | |
| get_nanogpt_credits | — | ok | 仅 app_state |
| get_siliconflow_embedding_models | dto | bad_request | **歧义类**：DTO 体字段可省 ≠ 顶层 dto 键可省，空载荷仍 bad_request |
| get_workers_ai_embedding_models | dto | bad_request | 同上 |
| get_workers_ai_multimodal_models | dto | bad_request | 同上 |
| search_searxng | dto, locale | bad_request | dto + `locale: String`；app_handle 注入丢弃；**需复制三步握手** |
| download_skill_import_url | url | bad_request | `url: String` |
| list_skills | — | ok | `scope: Option<SkillScopeFilter>` 可省 |
| list_skill_files | name | bad_request | scope: Option 可省 |
| discover_skill_imports | input | bad_request | `input: SkillImportInput` |
| discard_skill_import_archive | path | bad_request | `path: String` |
| preview_skill_import | input | bad_request | target_scope: Option 可省 |
| install_skill_import | request | bad_request | `request: SkillInstallRequest` |
| read_skill_file | name, path | bad_request | scope/start_line/line_count Option 可省 |
| write_skill_file | name, path, content | bad_request | scope/expected_sha256 Option 可省 |
| export_skill | name | bad_request | scope: Option 可省 |
| delete_skill | name | bad_request | scope: Option 可省 |
| move_skill | request | bad_request | `request: SkillMoveRequest` |
| retarget_skill_scope | request | bad_request | `request: SkillScopeRetargetRequest` |
| vector_handle | path, request | bad_request | path + `request: VectorRouteRequestDto` |

