# 聊天设置入口与逐次回复 Token 用量（2026-11-01）

## 用户要求

聊天页右上角“加一”（`chat-conversations-anchor`）的展开面板中加入“聊天设置”；设置里可以开启查看每次对话消耗的 Token。

## 实现与统计口径

- “选择一段故事”面板顶部新增“聊天设置”。设置面板提供“返回会话列表”及“显示每次回复的 Token 用量”开关。右上角更多菜单也提供同一设置入口。
- 开启后，在每条非系统 AI 回复下显示本次正文请求的输入、输出、合计 Token。显示设置对所有聊天生效，默认关闭，使用现有 PersonalizationStore 跨重启持久化；关闭只影响显示。
- 不用字数或 tokenizer 估算冒充实际消耗。仅记录服务商返回的 usage；没提供的字段保持缺省。旧消息、开场白或未返回用量显示“未提供”，已知零值仍显示 0。
- 输入计数包含本次请求发送的历史和背景。此功能只显示正文回复请求；单独生成剧情选项、摘要等额外请求不混入本条计数。这一口径在设置页明确说明，不把 Token 当作实际扣费账单。
- 流解码增加 usage 通道，支持 OpenAI Compatible、Responses、Claude、Gemini GenerateContent / Interactions 的常见用量格式。Claude 总输入包含缓存创建和缓存读取；Gemini 输出包含已返回的 thought 用量；服务商明确返回的 total 优先，不强制改成输入加输出。
- 用量按请求累计快照合并，不把多次报告相加；只在已知输入与输出时补合计。前端也合并分批计数，以免输入/输出在不同读取批次时丢失。
- 开始新流和切换聊天时重置计数；现有 stream_id 和 mounted 校验阻止旧流覆盖当前流。设置开关不决定是否采集，今后的 usage 即使暂时隐藏也会保存。
- `commit_native_story_reply` 增加可选 usage / usageComplete 参数，保存到对应助手消息 extra 的 `harmony_token_usage` / `harmony_usage_complete`；和正文一次 add_message 落库。保存失败重试仍保留该流的计数。停止/错误时如果有计数则标注“未完整结束”。
- 修正前端游标终态处理：一次读取最多 64 事件，服务层已结束并不意味着已经读完最后一批。继续排空到 Done / Error 事件（或终态空批）再结束，避免丢失尾部文本和最后的 usage。
- 不改已有顶栏、圆球和展开面板玻璃；保留创建页资源选择的展开动画。

## 修改文件

- `entry/src/main/ets/pages/ChatPage.ets`
- `entry/src/main/ets/backend/Types.ets`
- `entry/src/main/ets/backend/NativeStory.ets`
- `entry/src/main/ets/theme/PersonalizationStore.ets`
- `native/crates/ttavern/src/presentation/token_usage.rs`（新增）
- `native/crates/ttavern/src/presentation/mod.rs`
- `native/crates/ttavern/src/presentation/chat_stream_decoder.rs`
- `native/crates/ttavern/src/presentation/commands/chat_completion.rs`（注释同步）
- `native/crates/ttavern/src/presentation/commands/native_story.rs`

## 验证

- Token usage 测试 6/6：`chat-usage-unit-tests.log`。覆盖零值/缺省、累计快照、Claude 缓存输入、多协议、非法数字、流之间隔离。
- 完整流解码测试 10/10：`chat-usage-decoder-tests.log`。
- native_ 回归 11/11：`chat-usage-native-tests.log`。故事提交/真实文件重读验证 usage 持久化、不污染开场白、部分用量与未完整结束标记、无用量不伪造字段。
- 客户端实际 ArkTS 方法转译运行：`build/chat-usage-client-tests.cjs` / `chat-usage-client-tests.log`。验证终态下 64 条事件后继续排空，尾部文本和分批 usage 不丢失，输入 100 + 输出 12 合计 112，不重复相加；错误流不标记完整；显示区分 0、未提供和未完整结束。
- ArkTS 编译/签名：`chat-usage-arkts-build.log`、`chat-usage-final-package.log`、`chat-usage-arm64-package.log`。
- arm64 release 成功：`chat-usage-native-arm64.log`。x86_64 编译较慢，最初前台尝试超时，最终后台 release 成功：`chat-usage-native-x86-background.log` / `chat-usage-native-x86-background-error.log`。最终两包都包含本轮新原生库，不使用超时构建产物。
- 最终模拟器包安装后再执行 `build/chat-usage-ui-qa.cjs`，`chat-usage-ui-tests.log` 通过：加一面板设置入口、返回列表、开启显示、旧开场白“Token：未提供”、冷启动持久化、恢复原来关闭设置。未修改聊天数据或调用在线模型。
- 截图：`build/chat-usage-settings.jpeg`、`build/chat-usage-unavailable.jpeg`。
- 未验证真实在线服务商返回 usage 的完整运行、实际扣费、物理手机及 API22 运行；测试计数来自确定性的协议样本，不把它说成真实在线消耗。

## 最新安装包

- 手机：`dist/HarmonyTavern-chat-settings-tokens-arm64-20261101-signed.hap`，39,618,792 字节，仅 arm64。
- 模拟器：`dist/HarmonyTavern-chat-settings-tokens-simulator-20261101-signed.hap`，68,993,840 字节，arm64 + x86_64，已安装。
- 两包各附同名 `.sha256`，校验及架构检查通过。手机包打包后 x86_64 源库已恢复。
