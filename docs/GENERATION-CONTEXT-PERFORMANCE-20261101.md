# 聊天生成设置、上下文精简与渲染优化（2026-11-01）

## 最新用户需求

- 改善聊天展开面板的可读性，保留毛玻璃而不是背景文字重影。
- 优化应用主要使用路径的流畅度与正常聊天上下文开销。
- 底部加号菜单的“切换或新建会话”改为“精简上下文”，接通真实后端。
- 将旧聊天设置统一为“聊天生成设置”，加入模型返回的思考过程、推理强度、回复长度、独立的上下文长度。

## 交付内容

### 统一聊天生成设置

右上角“加一” → 聊天生成设置；更多菜单也可以进入。面板保留逐次回复 Token 显示，并增加：

- 显示模型返回的思考过程（跨重启记住显示偏好，默认关闭）。只显示 API 返回的 reasoning / 思考摘要，不获取隐藏思维链，不伪造未提供的数据。
- 回复长度上限：1–131072 个输出 Token，仍受模型/服务商自身限制；部分模型包含思考 Token。
- 上下文长度预算：1024–1048576 个输入 Token，默认 32768，是最终组装的消息的本地 tokenizer 估算值，不冒充服务商实际计费。
- 推理强度：模型默认 / 低 / 中 / 高。使用现有适配器将 reasoning_effort 转为各协议能力；不支持的模型可能拒绝或忽略，面板明确提示，不强行伪装所有模型都支持。
- 温度、Top-P、自动跟随最新、删除消息确认、首尾空白处理。

生成参数复用已有 `NativePreferences`、乐观版本校验与原有全局设置存储，不另建一套独立参数。生成参数需按“保存生成设置”提交；Token/思考显示开关即时保存。所有聊天共用此配置，面板已说明。

显示开关不强制打开推理；非默认推理强度会要求可用接口返回 reasoning。原始思考文本独立流通道接收，和助手正文一次提交到消息 extra.reasoning，保存重试不会丢失。完成后默认折叠，历史可展开。流中只显示最近一段，最多保留 60000 UTF-16 单元并避免截断代理对；超长内容明确标记。思考不再通过日志输出，也不被拼入下一次上下文。

模型只有思考而没有正文时给出检查回复长度/推理强度的提示，不把它作为正常正文回复保存。

### 精简上下文

- 底部加号 → 精简上下文；右上角仍保留原会话选择入口。
- 不是删消息，也不是只把历史藏起来。生成前从后端读取真实历史，用事实摘要替代已经覆盖的较早部分，仍提交近期原文、角色、用户身份、故事设置及所选世界书。
- 每次保留至少最近 8 条原文，尽量不在用户发言后直接切断一轮。更长历史分段精简；源输入每段上限 48 KiB，摘要输出上限 1200 Token，超长单条消息明确报错而不偷偷截断。
- 只有点下“调用当前模型精简（额外消耗 Token）”才调用在线模型。摘要调用复用当前服务商、端点授权、模型与密钥路径，不写进聊天消息，不混进正文 Token 账单。
- 先 prepare 得到绑定当前聊天和摘要版本的指纹，再生成，最后 commit 重新核验。失败、取消、过时结果、非正常结束、空摘要、过长摘要或没有缩短实际历史都不会覆盖原摘要。
- 摘要存于当前聊天 extension store；恢复完整上下文会清除该摘要状态，聊天原文始终完整保留。
- 摘要校验覆盖前缀的正文、角色、发言者和时间。修改/删除已覆盖的历史会令旧摘要自动失效，下一次生成改用完整历史，避免使用过时摘要。
- 旧聊天无 integrity 元数据时可以正常读取完整上下文；第一次实际保存摘要才创建必要标识。模拟器发现此兼容问题后补齐后端及回归用例，不把旧记录读取错误当成“暂无可摘要”。

### 上下文预算与正常 Token 开销

- 最终消息组装（包括角色、系统提示、身份、世界书、故事要求与当前待发送文字）后做预算检查。
- 超过输入预算明确要求先精简或增加预算，不静默丢掉历史。检查发生在新增用户消息落库之前；失败保留输入，不会因重试重复增加用户消息。
- 精简后的上下文在正文和独立剧情选项请求中生效，不每轮重复发送已摘要的较早消息。
- ArkTS 不再为每次生成把完整历史重复序列化穿过桥接层，后端使用当前聊天的真实持久化记录；已返回的思考文本不被回传。
- 不承诺所有模型固定节省比例。实际消耗依服务商 tokenizer、缓存、思考、输出长度、背景资料及摘要费用而异；独立选项/摘要费用不混入正文显示。

### 流畅度与面板可读性

- 聊天列表改用 `List + LazyForEach`，只构建可视区域附近的消息；数据源带替换版本号，同长度编辑或 metadata 改变也会刷新可见项。
- 首页、聊天会话选择和创建页的记录选择统一读取 `list_chat_summaries`，不再为了列表预览加载全部会话的完整正文。
- 流式读取一批事件后才更新一次正文/思考，避免一批最多 64 事件逐条触发渲染；滚动刷新每帧合并，保留手动向上阅读时不追底。
- 思考内容流中显示尾段，完整已保存内容默认折叠，减少长文本反复布局。
- 大展开面板采用专用系统 reading 材质：共享圆球的主题 tint，使用 THIN（轻柔模式为 REGULAR）扩散背景文字；小菜单、圆球和顶栏不改。API22 兼容路径对大面板增加背景虚化，不恢复 88% 实色覆盖；关闭模糊仍尊重实色回退。
- 已比较浅色/深色截图，避免大段聊天文字穿透到设置文字中。没有宣称达到固定帧率或完成整应用所有页面的真机性能验收。

## 主要代码

- `entry/src/main/ets/pages/ChatPage.ets`
- `entry/src/main/ets/components/ChatMessageSource.ets`（新增）
- `entry/src/main/ets/components/ChatDock.ets`
- `entry/src/main/ets/backend/NativeContext.ets`（新增）
- `entry/src/main/ets/backend/NativePreferences.ets`、`NativeStory.ets`、`Types.ets`
- `entry/src/main/ets/theme/PersonalizationStore.ets`
- `entry/src/main/ets/pages/Index.ets`、`StoryPage.ets`
- `entry/src/main/ets/components/OriginPanel.ets`、`NativeGlassBackdrop.ets`
- `entry/src/main/ets/theme/SystemGlass.ets`、`SystemGlassNative.ets`
- `native/crates/ttavern/src/presentation/commands/native_context.rs`（新增）
- `native/crates/ttavern/src/presentation/commands/native_preferences.rs`、`native_story.rs`
- `native/crates/ttavern/src/presentation/commands/mod.rs`、`presentation/dispatch.rs`

## 已完成验证

- `generation-native-tests.log`：native_ 回归 12/12，覆盖真实文件中的摘要落盘、恢复、旧记录迁移、过时结果拒绝、截断摘要拒绝、历史不删除、上下文预算超限且消息不落库、回复/推理参数持久化、思考内容随回复落盘。
- `generation-decoder-tests.log`：流解码 10/10。
- `generation-usage-tests.log`：Token 用量 6/6。
- `generation-provider-tests.log`：已有适配器 reasoning 相关测试 22/22。
- `generation-full-tests.log`：完整 ttavern --lib 串行 58/59；原有 group session 集成用例在整套测试中仍报 os error 3，与此前版本同一问题。本轮未改 group；`generation-group-isolated.log` 独立运行 1/1 通过。
- `generation-flow-tests.log` / `build/generation-client-tests.cjs`：实际 ArkTS 方法转译执行，验证取消精简后晚到结果不提交、成功只提交一次、超预算不新增用户消息、10000 项惰性数据源与同长度更新失效。
- `generation-client-tests.log` / `build/chat-usage-client-tests.cjs`：末批事件排空、分批用量合并、思考通道、不完整流、缺省/零用量显示。
- `generation-arkts-build.log`：ArkTS 编译与签名成功。
- 模拟器实际保存回复上限 256 / 输入预算 4096 / 推理高，冷启动核验后恢复原来的 8192 / 32768 / 模型默认：`generation-settings-ui-tests.log`，脚本 `build/generation-settings-ui-qa.cjs`。未向在线模型发请求。
- 浅深色阅读材质截图：`build/reading-glass-light-thin.jpeg`、`build/reading-glass-dark-settings.jpeg`。整合设置截图：`build/generation-settings-top.jpeg`、`build/generation-parameters-draft.jpeg`、`build/generation-settings-bottom.jpeg`。

## 安装包

- 手机：`dist/HarmonyTavern-generation-context-arm64-20261101-signed.hap`，39,736,044 字节，仅 arm64。
- 模拟器：`dist/HarmonyTavern-generation-context-simulator-20261101-signed.hap`，69,131,571 字节，arm64 + x86_64；对应最终版本已安装。
- 两包附同名 `.sha256`，校验通过；架构检查通过，x86_64 源库已恢复。
- 原生成功日志：`generation-legacy-arm64.log` / `generation-legacy-arm64-error.log`、`generation-verified-x86.log`。更早的后台构建曾因等待或中止不完整，未作为最终产物。
- 最终打包日志：`generation-final-package.log`、`generation-arm64-package.log`。Hvigor 会剥离源 .so 的符号，故归档与源库文件整体 SHA 不同；已经逐一比较 ELF `.text` / `.rodata` / `.data.rel.ro`，手机包和模拟器包对应的代码与数据节均与最终构建源库完全相同。
- 最终 x86_64 版本安装后，复查旧聊天可以读取“尚未精简”状态、无 integrity 错误；历史只有一条时，在调用模型前提示至少保留 8 条原文。检查思考显示开关及开场白“接口未提供”，恢复原先关闭状态。
- 在最终模拟器包再次执行生成参数保存/冷启动/恢复脚本，通过，推理强度显示中文标签。未调用在线模型或修改聊天消息。
- `build/generation-runtime.log` 未发现 TypeError / ReferenceError / JsCrash / FATAL。
- 最终截图增加 `build/generation-compact-final.jpeg`、`build/generation-compact-short-history.jpeg`、更新后的 `build/generation-settings-top.jpeg`、`build/generation-parameters-draft.jpeg` 和 `build/generation-settings-bottom.jpeg`。

## 尚未验收

真实在线模型的摘要质量、思考返回、推理强度适配以及实际 Token/扣费差异；真机、API22 运行、极长记录设备内存/帧率、横屏大字号与所有输入法组合。测试样本与本地估算不代表真实在线消耗。
