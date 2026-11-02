# P6.2 契约对表（77 命令：agent 43 + extension 8 + sync 26）

来源：`native/p62-sigs.txt`（77 条机械提取，与审计计数逐一吻合）+ 逐定义 serde 核对（2026-10-27 14:00）。

## 铁律（与 P6.1 同）

- 顶层 Args 键：**仅 agent 域 = camelCase 单键 `dto`**（`args.typed("dto")`）；**extension / lan_sync / tt_sync / sync_automation 的顶层标量键 = 字面参数名（snake）**（`pair_uri`、`device_id`、`extension_name`、`overwrite_policy`、`server_device_id`、`request_id`、`source`、`destination`…）。⚠ 契约铁律「顶层键=camelCase」不可推广到 P6.2 全域。
- DTO 体字段名**逐 DTO 以 serde 属性为准**，不可推广任何结论：
  - agent 域 74 个类型**几乎全 camelCase**（agent_dto.rs `rename_all="camelCase"`），仅 2 例外；
  - extension / sync 域基本 **snake**，另有 2 个非常规：`SyncMode` **lowercase**、`OverwritePolicy` **kebab-case**。

## 参数类别（按命令文件，2026-10-27 15:45 审计修正无参计数）

| 文件 | 条数 | 参数形态 |
| --- | --- | --- |
| agent_commands.rs | 34 | 31 条 `dto:` 必填 + 2 条无参（list_agent_profiles / list_active_agent_runs）+ 1 条 `dto: Option<AgentListToolsDto>`（list_agent_tools） |
| agent_session_commands.rs | 9 | 3 条无参（load_agent_session_profile / create_agent_session / list_agent_sessions）+ 6 条 `dto:` |
| extension_commands.rs | 8 | 1 条无参（get_extensions）+ 7 条命名键标量（url, global / extension_name, global / extension_name, branch, global / extension_name, source, destination） |
| lan_sync_commands.rs | 17 | 7 条无参（get_status / start_server / stop_server / get_pairing_info / discover_devices / list_devices / clear_sync_mode_override）+ 10 条命名键标量（pair_uri / address / name / device_id / request_id+accept / options / mode+persist / overwrite_policy） |
| tt_sync_commands.rs | 5 | 1 条无参（list_servers）+ 4 条命名键（pair_uri / server_device_id / server_device_id+mode+options） |
| sync_commands.rs | 1 | 无参（sync_get_dataset_catalog，无 Result 包装，invoke 数据直通） |
| sync_automation_commands.rs | 3 | 2 条无参（get_config / get_status）+ 1 条整结构 `config: SyncAutomationConfig` |

⚠ **bool 必填参数**（install/update/delete/get_version/get_branches 的 `global`、lan_sync_confirm_pairing 的 `accept`、lan_sync_set_sync_mode 的 `persist`）：host Args 现无 `require_bool`，实现时用 `require_typed::<bool>`（或按需新增 helper）。

## DTO serde 对表

### agent（camelCase 主旋律，agent_dto.rs / tt-domain agent）

- **34 个请求 DTO + 28 个响应 DTO 全部 `rename_all="camelCase"`**（AgentStartRunDto … AgentSessionRunHandleDto 等，见 p62-sigs.txt）。
- **例外 1**：`AgentRunLiveUpdateDto`（enum）`tag="type"` + 双 camelCase → 线上 `{type:"...", ...}` 事件形状（live projection 用）。
- **例外 2**：`AgentCancelRunResultDto` **untagged**（原始值透传）。
- `AgentProfileHealth`（tt-domain profile_diagnostic.rs）camelCase。
- **宿主特殊接线**：
  - `read_agent_workspace_bytes` 返回 `tauri::ipc::Response`（二进制）→ 宿主改造成 base64 字符串通道；
  - `subscribe_agent_run_live_projection` 参数含 `Channel<AgentRunLiveUpdateDto>` → 按决策 A 复用 `setEventListener` 事件桥，不引入 Channel；
  - `read_agent_prompt_assembly_request` 返回 `Option<...>`，ArkTS 侧判空。

### extension（snake，tt-domain/src/models/extension.rs）

- `Extension` / `ExtensionInstallResult` / `ExtensionUpdateResult` / `ExtensionVersion` / `ExtensionBranch`：无 struct 级 serde → **字段 snake_case**。

### sync（snake + 2 个非常规）

- `SyncOperationOptions`（tt-contracts sync.rs）snake。
- **`SyncMode`（tt-contracts database.rs）`rename_all="lowercase"`** → 线上 `"normal" / "full" / "off"`。
- **`OverwritePolicy`（ttsync-contract 2.6.0，registry 依赖）`rename_all="kebab-case"`** → 线上 `"exact" / "prefer-newer"`。
- `LanSyncStatus`（tt-domain lan_sync.rs）snake；`LanDiscoveredDevice`（tt-contracts lan_discovery.rs）snake；`SyncJobReport`（tt-contracts sync.rs）snake；`SyncAutomationConfig` / `SyncAutomationStatus`（tt-contracts sync_automation.rs）snake。

### 宿主重建 5 个（上游 presentation/commands 自有，照抄字段，无 serde → snake）

| 类型 | 线上形状 |
| --- | --- |
| LanSyncPairingInfoDto | `{address, pair_uri, qr_svg}` |
| LanSyncPairedDeviceDto | `{device_id, device_name, last_known_address?, paired_at_ms, last_sync_ms?}` |
| TtSyncPairedServerDto | `{server_device_id, server_device_name, base_url, spki_sha256, permissions, paired_at_ms, last_sync_ms?}` |
| TtSyncPermissionsDto | `{read, write, mirror_delete}` |
| SyncDatasetCatalogDto | `{policy_version, supported_dataset_ids, supported_profile_ids, default_dataset_ids}` |

## 与审计的对应

- 计数：agent 43（34+9）+ extension 8 + lan_sync 17 + tt_sync 5 + sync 1 + sync_automation 3 = **77** ✓
- 两项 P6 决策在此落地：① extension 管理-only 先行；② live projection 复用事件桥（对应上面的宿主特殊接线）。

## 空载荷 dispatch 分类审计（2026-10-27 15:45，子代理逐条对照上游签名，77/77 一致）

规则：剔除 Tauri 注入（State/AppHandle/Channel/ipc::Response 返回）后，存在任一非 Option 参数 → `bad_request`；全部 Option/注入 → `ok`。**统计：ok=18 / bad_request=59**。

| 命令名 | 必填顶层键 | 分类 | 备注 |
| --- | --- | --- | --- |
| agent::start_agent_run | dto | bad_request | DTO camelCase |
| agent::read_agent_run_checkpoint | dto | bad_request | |
| agent::resume_agent_run | dto | bad_request | |
| agent::finish_agent_run_presentation | dto | bad_request | |
| agent::subscribe_agent_run_live_projection | dto | bad_request | channel=Channel 注入忽略；复用事件桥；dto 含 run_id |
| agent::prepare_agent_prompt_assembly | dto | bad_request | |
| agent::build_agent_current_model_connection_snapshot | dto | bad_request | |
| agent::apply_agent_current_model_connection_snapshot | dto | bad_request | |
| agent::list_agent_profiles | — | ok | |
| agent::list_agent_tools | — | ok | `dto: Option<AgentListToolsDto>` 缺失=None，上游 unwrap_or_default() |
| agent::resolve_agent_system_prompt | dto | bad_request | |
| agent::load_agent_profile | dto | bad_request | |
| agent::diagnose_agent_profile | dto | bad_request | |
| agent::save_agent_profile | dto | bad_request | |
| agent::delete_agent_profile | dto | bad_request | |
| agent::repair_agent_profile_file | dto | bad_request | |
| agent::retarget_agent_profile_preset_refs | dto | bad_request | |
| agent::cancel_agent_run | dto | bad_request | 结果 AgentCancelRunResultDto untagged |
| agent::submit_agent_run_guidance | dto | bad_request | |
| agent::list_active_agent_runs | — | ok | |
| agent::list_agent_runs | dto | bad_request | |
| agent::plan_agent_run_prune | dto | bad_request | |
| agent::apply_agent_run_prune | dto | bad_request | |
| agent::read_agent_run_events | dto | bad_request | |
| agent::read_agent_workspace_bytes | dto | bad_request | 返回 ipc::Response→宿主 base64 通道 |
| agent::read_agent_workspace_file | dto | bad_request | |
| agent::read_agent_task_detail | dto | bad_request | |
| agent::read_agent_model_turn | dto | bad_request | |
| agent::read_agent_prompt_assembly_request | dto | bad_request | 返回 Option<...>→ArkTS 判空 |
| agent::resolve_agent_chat_commit | dto | bad_request | |
| agent::resolve_agent_prompt_assembly | dto | bad_request | |
| agent::resolve_agent_persistent_state_metadata_update | dto | bad_request | |
| agent::prune_agent_chat_persistent_states | dto | bad_request | |
| agent::copy_agent_chat_persistent_states | dto | bad_request | |
| agent_session::load_agent_session_profile | — | ok | |
| agent_session::save_agent_session_profile | dto | bad_request | 复用 AgentSaveProfileDto |
| agent_session::create_agent_session | — | ok | |
| agent_session::list_agent_sessions | — | ok | |
| agent_session::rename_agent_session | dto | bad_request | |
| agent_session::delete_agent_session | dto | bad_request | |
| agent_session::read_agent_session | dto | bad_request | |
| agent_session::prepare_agent_session_run | dto | bad_request | |
| agent_session::start_agent_session_run | dto | bad_request | |
| extension::get_extensions | — | ok | |
| extension::install_extension | url, global | bad_request | branch: Option 可选 |
| extension::update_extension | extension_name, global | bad_request | 键 snake |
| extension::delete_extension | extension_name, global | bad_request | |
| extension::get_extension_version | extension_name, global | bad_request | |
| extension::get_extension_branches | extension_name, global | bad_request | |
| extension::switch_extension_branch | extension_name, branch, global | bad_request | |
| extension::move_extension | extension_name, source, destination | bad_request | |
| lan_sync::lan_sync_get_status | — | ok | |
| lan_sync::lan_sync_start_server | — | ok | |
| lan_sync::lan_sync_stop_server | — | ok | |
| lan_sync::lan_sync_get_pairing_info | — | ok | |
| lan_sync::lan_sync_request_pairing | pair_uri | bad_request | snake |
| lan_sync::lan_sync_discover_devices | — | ok | |
| lan_sync::lan_sync_connect_address | address | bad_request | |
| lan_sync::lan_sync_set_device_name | name | bad_request | |
| lan_sync::lan_sync_pair_device | device_id | bad_request | |
| lan_sync::lan_sync_confirm_pairing | request_id, accept | bad_request | accept 必填 bool |
| lan_sync::lan_sync_list_devices | — | ok | |
| lan_sync::lan_sync_remove_device | device_id | bad_request | |
| lan_sync::lan_sync_sync_from_device | device_id, options | bad_request | options=SyncOperationOptions snake |
| lan_sync::lan_sync_push_to_device | device_id, options | bad_request | |
| lan_sync::lan_sync_set_sync_mode | mode, persist | bad_request | mode=SyncMode lowercase→"normal"/"full"/"off"；persist bool |
| lan_sync::lan_sync_clear_sync_mode_override | — | ok | 上游吞 Result 恒 Ok |
| lan_sync::lan_sync_set_overwrite_policy | overwrite_policy | bad_request | OverwritePolicy kebab→"exact"/"prefer-newer" |
| tt_sync::tt_sync_pair | pair_uri | bad_request | |
| tt_sync::tt_sync_list_servers | — | ok | |
| tt_sync::tt_sync_remove_server | server_device_id | bad_request | |
| tt_sync::tt_sync_pull | server_device_id, mode, options | bad_request | mode=SyncMode lowercase |
| tt_sync::tt_sync_push | server_device_id, mode, options | bad_request | mode=SyncMode lowercase |
| sync::sync_get_dataset_catalog | — | ok | 纯函数无 Result，invoke 数据直通 |
| sync_automation::sync_automation_get_config | — | ok | |
| sync_automation::sync_automation_update_config | config | bad_request | config=SyncAutomationConfig snake |
| sync_automation::sync_automation_get_status | — | ok | |

ok 18 = agent 3 + agent_session 3 + extension 1 + lan_sync 7 + tt_sync 1 + sync 1 + sync_automation 2。实现提醒：bool 必填参数（global/accept/persist）用 `require_typed::<bool>`（host 暂无 require_bool helper）。

**审计实测化（2026-10-27 21:35，p62_functional_tests::payload_shape_sweep）**：`{}` 载荷扫描 74/77 —— 59 条 bad_request 全部回 `code=="bad_request"`、15 条 ok（lan_sync 剔除 start_server/get_pairing_info/discover_devices 3 条变异/网络命令避免跨测试竞态与端口绑定）全部回 ok；3 条跳过项由签名审计覆盖（无必填键）并留真机点验。ttavern lib 43/43（42 + sweep）。

**键形状审计（2026-10-27 21:45，Backend.ets 26 条 snake 字面参数命令逐条比对，零漂移）**：extension 8（install `{url,global}+branch?`、update/delete/get_version/get_branches `{extension_name,global}`、switch `{extension_name,branch,global}`、move `{extension_name,source,destination}`）、lan_sync 17（request_pairing `{pair_uri}`、connect_address `{address}`、set_device_name `{name}`、pair_device/remove_device `{device_id}`、confirm_pairing `{request_id,accept}`、sync_from/push_to `{device_id,options}`、set_sync_mode `{mode,persist}`、set_overwrite_policy `{overwrite_policy}`、9 条无参 undefined）、tt_sync 5（pair `{pair_uri}`、remove_server `{server_device_id}`、pull/push `{server_device_id,mode,options}`、list_servers undefined）、sync 1（get_dataset_catalog undefined）、sync_automation 3（update_config `{config}`、get/get_status undefined）——与上表 59 条必填键集合完全一致。

**agent 域 camelCase 钉死（2026-10-27 21:31，wire_contract_tests::agent_request_dtos_are_camel_case）**：agent 请求 DTO（AgentProfileIdDto `{profileId}`、AgentSubscribeRunLiveProjectionDto `{runId}`）camelCase 反序列化必须成功、snake 形态必须失败——与 P5 chat 域 snake 钉死（add_message/chat_dto）互为反向闭合，防止 agent DTO 被改回 snake 静默打断 ArkTS Types.ets 的 camelCase 模型。ttavern lib 44/44。

## extension 域接线映射（2026-10-27 19:55，对照上游 extension_commands.rs 8/8）

`ExtensionService` 已在 native `tt-application/src/services/extension_service.rs`（8 方法全有，直接复用）。host 命令 = 参数点名 + `ensure_ios_policy_allows(extensions.third_party_management)`（host helpers.rs 已有；ios_policy=Ignored 恒放行）+ 服务调用 + `map_command_error`。`Extension` 等 6 个类型**全部无 struct 级 serde → 字段 snake_case**；`ExtensionType` 枚举无 serde → 线上 **"System"/"Local"/"Global"**（PascalCase，ArkTS 侧类型照此）。

| 命令 | 顶层键（snake 字面参数名） | 服务方法 | 返回 |
| --- | --- | --- | --- |
| get_extensions | 无参 | `get_extensions()` | `Vec<Extension>{name, extension_type}` |
| install_extension | `url`(String) + `global`(bool, require_typed) + `branch`?(Option<String>) | `install_extension(&url, global, branch)` | `ExtensionInstallResult{version, author, display_name, extension_path, folder_name}` |
| update_extension | `extension_name` + `global` | `update_extension(&name, global)` | `ExtensionUpdateResult{short_commit_hash, extension_path, is_up_to_date, remote_url}` |
| delete_extension | `extension_name` + `global` | `delete_extension(&name, global)` | `()` |
| get_extension_version | `extension_name` + `global` | `get_extension_version(&name, global)` | `ExtensionVersion{current_branch_name, current_commit_hash, is_up_to_date, remote_url}` |
| get_extension_branches | `extension_name` + `global` | `get_extension_branches(&name, global)` | `Vec<ExtensionBranch>{name, commit, current, label}` |
| switch_extension_branch | `extension_name` + `branch` + `global` | `switch_extension_branch(&name, &branch, global)` | `()` |
| move_extension | `extension_name` + `source` + `destination` | `move_extension(&name, &source, &destination)` | `()` |

⚠ 上游 `install_extension` 还有 iOS 过滤逻辑只出现在 `get_extensions`（scope==Ios 时）；host scope=Ignored，**不做过滤、不留死代码**。⚠ install 的 `branch` 是 `Option<String>`，ArkTS 顶层可省略（`args.optional("branch")`）。

## agent live projection 事件桥可行性（2026-10-27 20:05，零代码核查）

`host/events.rs` 的 `emit(event, payload)` 是**通用 JSON 信封**（`{"event":"<name>","payload":<json>}`，ArkTS 单监听按事件名分发）——直接承载 `AgentRunLiveUpdateDto`（tag="type" 双 camelCase，`{type:"...",...}`）。设计落地只需宿主一个**转发 shim**：agent 运行时更新流（tokio 通道）→ `events::emit("agent:run-live-update", <dto json>)`；无需新机制、无需 Tauri Channel。订阅命令 `subscribe_agent_run_live_projection` 的 `Channel<AgentRunLiveUpdateDto>` 参数在上游只用于把服务端推送接到 emit —— 宿主侧用 tokio::sync::broadcast 订阅运行时更新即可。**结论：事件桥方案成立，步骤 3 无阻塞点。**

## sync 26 条接线映射（2026-10-27 20:50，对照上游 lan_sync_commands.rs 17 + tt_sync_commands.rs 5 + sync_commands.rs 1 + sync_automation_commands.rs 3，已实现）

顶层键一律 snake 字面参数名（铁律）：`pair_uri` / `address` / `name` / `device_id` / `request_id` / `accept` / `options` / `mode` / `persist` / `overwrite_policy` / `server_device_id` / `config`。bool 用 `require_typed::<bool>`（无 require_bool）；枚举走 `typed`（SyncMode lowercase / OverwritePolicy kebab / SyncOperationOptions snake）。iOS 策略检查跳过（scope=Ignored）。

### 宿主重建 5 个 sync DTO（presentation/commands/{lan_sync,tt_sync,sync}.rs，照抄上游字段，Serialize only）

| DTO | 字段 |
| --- | --- |
| LanSyncPairingInfoDto | `address: String`, `pair_uri: String`, `qr_svg: String` |
| LanSyncPairedDeviceDto | `device_id: String`, `device_name: String`, `last_known_address: Option<String>`, `paired_at_ms: u64`, `last_sync_ms: Option<u64>`（From<LanSyncPairedDeviceSummary>） |
| TtSyncPairedServerDto | `server_device_id: String`, `server_device_name: String`, `base_url: String`, `spki_sha256: String`, `permissions: TtSyncPermissionsDto`, `paired_at_ms: u64`, `last_sync_ms: Option<u64>` |
| TtSyncPermissionsDto | `read: bool`, `write: bool`, `mirror_delete: bool` |
| SyncDatasetCatalogDto | `policy_version: u32`, `supported_dataset_ids: Vec<String>`, `supported_profile_ids: Vec<String>`, `default_dataset_ids: Vec<String>` |

### lan_sync 17 条（lan_sync.rs，generate_qr_svg = qrcode 0.14 svg，min_dimensions(200,200)）

| 命令 | 顶层键 | 服务方法 | 返回 |
| --- | --- | --- | --- |
| lan_sync_get_status | 无参 | `get_status()` | `LanSyncStatus`（domain 结构，snake） |
| lan_sync_start_server | 无参 | `start_server()` | `LanSyncStatus` |
| lan_sync_stop_server | 无参 | `stop_server()` | `()` |
| lan_sync_get_pairing_info | 无参 | `get_pairing_info()` + 宿主生成 qr_svg | `LanSyncPairingInfoDto` |
| lan_sync_request_pairing | `pair_uri` | `request_pairing(&pair_uri)` | `LanSyncPairedDeviceDto` |
| lan_sync_discover_devices | 无参 | `discover_devices()` | `Vec<LanDiscoveredDevice>{device_id, device_name, platform?, base_urls, spki_sha256}` |
| lan_sync_connect_address | `address` | `connect_address(&address)` | `()` |
| lan_sync_set_device_name | `name` | `set_device_name(&name)` | `()` |
| lan_sync_pair_device | `device_id` | `pair_device(&device_id)` | `LanSyncPairedDeviceDto` |
| lan_sync_confirm_pairing | `request_id` + `accept`(bool) | `confirm_pairing(&request_id, accept)` | `()` |
| lan_sync_list_devices | 无参 | `list_paired_devices()` | `Vec<LanSyncPairedDeviceDto>` |
| lan_sync_remove_device | `device_id` | `remove_paired_device(&device_id)` | `()` |
| lan_sync_sync_from_device | `device_id` + `options`(SyncOperationOptions) | `sync_from_device(&device_id, options)` | `SyncJobReport` |
| lan_sync_push_to_device | `device_id` + `options` | `push_to_device(&device_id, options)` | `SyncJobReport` |
| lan_sync_set_sync_mode | `mode`(SyncMode) + `persist`(bool) | `set_sync_mode(mode, persist)` | `()` |
| lan_sync_clear_sync_mode_override | 无参 | `clear_sync_mode_override()` | `()` |
| lan_sync_set_overwrite_policy | `overwrite_policy`(OverwritePolicy) | `set_overwrite_policy(policy)` | `()` |

### tt_sync 5 条（tt_sync.rs）

| 命令 | 顶层键 | 服务方法 | 返回 |
| --- | --- | --- | --- |
| tt_sync_pair | `pair_uri` | `pair(&pair_uri)` | `TtSyncPairedServerDto` |
| tt_sync_list_servers | 无参 | `list_servers()` | `Vec<TtSyncPairedServerDto>` |
| tt_sync_remove_server | `server_device_id` | `remove_server(&server_device_id)` | `()` |
| tt_sync_pull | `server_device_id` + `mode`(SyncMode) + `options` | `pull(&id, mode, options)` | `SyncJobReport` |
| tt_sync_push | `server_device_id` + `mode` + `options` | `push(&id, mode, options)` | `SyncJobReport` |

### sync 1 条（sync.rs）—— 裸 DTO 返回，无 Result 包装

`sync_get_dataset_catalog` 无参 → `SyncDatasetCatalogDto`。dispatch 臂为 `to_value(cmd(ctx).await)?`（首个无 `?` 的 await 臂；`policy_version = ttsync_contract::dataset::DATASET_POLICY_VERSION`，dataset ids 来自 `ttsync_core::dataset::{supported_dataset_ids, supported_profile_ids, tauri_tavern_default_selection}`）。

### sync_automation 3 条（sync_automation.rs）

| 命令 | 顶层键 | 服务方法 | 返回 |
| --- | --- | --- | --- |
| sync_automation_get_config | 无参 | `get_config()` | `SyncAutomationConfig{lan_server_auto_start, auto_sync_enabled, interval_minutes, target?, sync_mode, selection}` |
| sync_automation_update_config | `config`(SyncAutomationConfig) | `update_config(config)` | `SyncAutomationConfig` |
| sync_automation_get_status | 无参 | `get_status()` | `SyncAutomationStatus{running, next_run_at_ms?}` |

## read_agent_workspace_bytes base64 通道（2026-10-27 20:50）

上游返回 `ipc::Response`（二进制）；OHOS 无该类型 → 宿主 `read_agent_workspace_bytes` **返回 base64 String**（`base64::STANDARD.encode(bytes)`，需 `use base64::Engine;`）。ArkTS 侧 `readAgentWorkspaceBytes(): Promise<string>`，字节还原用 `util.Base64Helper` 解码（P7 消费时接）。

## subscribe_agent_run_live_projection 事件桥（2026-10-27 20:50，已实现）

订阅命令 `dto = {run_id}`（camelCase）；Rust 侧：快照（`AgentRunLiveUpdateDto::Snapshot`）即发 `agent:run-live-update` → 后台 `background_handle().spawn` 循环等 `changed()` → `presenter.updates()` → 增量（Append/Replace/Remove/Response*）逐条 emit。事件形状 `AgentRunLiveUpdateDto` = tag="type" 双 camelCase（`{type:"responseAppend", invocationId, text, reasoning, toolIds}` 等 7 变体，字段见 tt-application dto/agent_dto.rs L539-571）。ArkTS `Backend.on('agent:run-live-update', handler)` 订阅（P7 UI 接）。**未知 run → not_found**（p62_functional_tests 实测 2026-10-27：服务层先查 run 文件，错误先于订阅到达；空 Snapshot 分支仅在订阅成功路径可达）。
