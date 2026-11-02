# 世界状态聊天模式：第一版原型（2026-11-01）

## 先备份，再实施

实施前已创建并逐文件 SHA256 校验：

`backups/HarmonyTavern-before-world-state-20261101-202950.zip`

- 1611 个文件，131501563 字节。
- ZIP SHA256：`65702a63eb7da95d15e5e52c0a9b5d632363257507df13aff480e1219f812692`，附同名 `.sha256`。
- 内含源码、配置、资源、原生库、文档及上一版手机 HAP 与校验文件；ZIP 内 `BACKUP-MANIFEST.json` 记录每个文件的哈希。
- 不含构建缓存、外部 SDK/NDK、参考工程、手机或模拟器沙盒中的用户数据。它是项目/安装包备份，不冒充设备聊天数据备份。既有安装包和源库没有被新名字的安装包覆盖。

## 使用方式

1. 创建对话，或现有聊天右上角“聊天选项”→“故事与聊天模式”。
2. 选择世界书，在“聊天模式”中选第三种“世界状态”。此模式至少需要一本有非空启用内容的世界书。
3. 填写“你希望怎样显示这个世界？”，例如：
   > 追踪我的人物。根据世界书显示生命、灵力、受伤与中毒，背包显示丹药数量和用途，位置精确到区域、建筑与所在房间。没有依据的数值不要编造。
4. 可先点“先看一份布局示例（不调用模型）”，查看带生命/体力条、负面效果、背包与位置的第一份示例。示例明确标注为演示数据，不读取为真实状态、不保存、不发送给模型。
5. 创建/保存后，输入栏上方出现世界状态 HUD。点击进入面板，用“根据世界书生成界面（额外消耗 Token）”独立生成第一份真实状态；也可正常聊天，在完整回复结束时更新。

独立生成只保存状态快照，不续写故事、添加消息、执行人物行为或扣除物品。实际状态生成调用当前用户配置的模型与端点，复用现有授权流程。

## 第一版能力

- 根据所选世界书的启用条目、人物/用户资料、已发生剧情和界面需求，生成结构化展示数据。
- 不固定所有世界都有 HP/MP。模型可选择生命、灵力、体力、压力等符合设定的指标和名称；无满值/当前值时不假画成满血或空血。
- 聊天栏上方显示监测人物、区域/具体地点、最多 2 个（compact）或 4 个（detailed）关键指标，以及最多 3 个负面状态名称。
- 展开面板显示完整指标、负面/正面/中性状态与效果、背包数量和说明、位置层级和细节，以及依据/未知信息。
- 已知 0 与未知区分；未知显示“未确认”，不填成 0、满值或空背包。未定义量程时只显示已知数值，不制造百分比。
- 状态随正常助手回复保存到消息 extra，并另存当前聊天的快照；重启可恢复。状态 JSON 从正文移除，流式过程中也不会把协议 JSON 展示在聊天气泡里。
- 旧自由输入、剧情选项模式不增加状态请求或提示词；新需求字段为空时不序列化入旧故事配置，旧故事可按默认值读取。既有主题、输入栏、顶部栏和 Token/思考/上下文精简功能保留。

## 数据协议与真实性边界

`native_world.rs` 验证 `<world_state>JSON</world_state>`，仅允许：

- `version/title/subject/layout`。
- `location.region/place/detail`。
- 最多 6 个 `meters`：名称、可空当前值/满值、单位、四种语义配色；有限、非负数值且不超过已知满值。
- 最多 12 个 `conditions`：名称、negative/positive/neutral、效果说明。
- 最多 32 个 `inventory`：名称、可空数量、说明。
- 有限长度的 `note`。

文本长度、数值范围、数量上限、枚举及未知字段均校验；不执行模型生成的 HTML/JS/CSS 或任意 ArkTS。第一版是**世界书驱动的数据与受控布局模板**，并不是任意代码生成器，也不是完整战斗/物理/库存计算引擎。模型选择面板标题、指标、内容、compact/detailed 布局，主题配色仍遵循应用的现有主题。

模型仍可能推断错误。界面显示的是模型上次确认的状态，不是假装真实传感器、GPS 或经过权威游戏服务器计算的数值。负面效果的持续时间是文本，暂不按设备时钟自动倒计时。

## 失败和并发处理

- 状态不合法、缺失、截断时保存有效剧情正文，状态不应用；不因一个 JSON 问题让回复丢失。
- 最新回复没有有效状态时，旧快照不再冒充当前状态，明确提示重新生成。
- 快照绑定聊天身份、覆盖的历史正文/角色/时间、故事需求和世界书实际启用内容。修改已覆盖历史或世界书/需求后，旧快照失效。
- 手动生成 prepare/commit 绑定当前完整聊天与旧快照版本。生成期间追加消息、改需求/世界书或已经应用另一份状态，过时结果都会被拒绝。
- 正常回复也携带界面配置指纹，防止生成期间世界书/需求变化后应用旧版本状态；剧情正文仍保留。
- 取消或切换聊天后晚到的前端结果不提交；取消后的端点授权错误也不能重新弹出授权框。提交中不伪装成可取消的原子事务。
- 网络或格式失败不会删除聊天、清空背包存档或用演示数据替换真实数据。

## 主要文件

- `native/crates/ttavern/src/presentation/commands/native_world.rs`（新增）
- `native/crates/ttavern/src/presentation/commands/native_story.rs`
- `native/crates/ttavern/src/presentation/commands/native_preferences.rs`
- `native/crates/ttavern/src/presentation/commands/mod.rs`、`presentation/dispatch.rs`
- `native/crates/ttavern/src/dispatch_contract_tests.rs`
- `entry/src/main/ets/backend/NativeWorld.ets`（新增）
- `entry/src/main/ets/backend/NativeStory.ets`
- `entry/src/main/ets/components/WorldStatus.ets`（新增）
- `entry/src/main/ets/pages/StoryPage.ets`、`ChatPage.ets`

新增命令：`get_native_world_state`、`prepare_native_world_state`、`commit_native_world_state`、`prepare_native_world_reply`。

## 验证

- `world-state-native-tests.log`：14/14 native_ 回归通过，包含本轮 schema 与真实文件往返测试、旧模式回归。
- `world-state-contract-tests.log`：新增命令分发契约通过。
- `world-state-client-tests.log` / `build/world-state-client-tests.cjs`：7 组实际 ArkTS 方法转译执行，覆盖取消、晚到结果、切换聊天、授权弹框、读取竞争、流式 JSON 隐藏及未知值/已知零值区分。
- `world-state-generation-regression.log`：原上下文精简、超预算发送前校验、10000 条惰性消息数据源回归通过。
- `world-state-usage-regression.log`：原末批流事件排空、Token 与思考通道回归通过。
- `world-state-full-tests.log`：全量串行 60/61；原有群聊测试仍在整套运行时报 os error 3，单独运行 `world-state-group-isolated.log` 1/1 通过，未修改群聊实现。
- `world-state-final-build.log`：ArkTS 构建与签名通过。
- `world-state-native-arm64.log` / `world-state-native-arm64-error.log`、`world-state-native-x86.log`：两个原生架构 release 编译成功。
- 模拟器：可见第三种模式、需求输入、离线示例条形图/负面状态/背包/位置；示例未保存。
- `world-state-ui-tests.log` / `build/world-state-ui-qa.cjs`：另建带唯一 QA 名称的测试会话，选择 Eldoria 和自定义需求；验证真实后端“尚未生成”状态、HUD 位于聊天输入栏上方、世界书与需求冷启动持久化。未向在线模型发请求，也没有把演示数值写入真实状态。完成后只删除此测试会话，原先的单条对话保留。
- `build/world-state-runtime.log` 未发现 TypeError / ReferenceError / JsCrash / FATAL。

截图：`build/world-state-preview.jpeg`、`build/world-state-inventory-preview.jpeg`、`build/world-mode-chat-empty.jpeg`、`build/world-mode-generation-panel.jpeg`。

## 安装包

- 手机：`dist/HarmonyTavern-world-state-prototype-arm64-20261101-signed.hap`，仅 arm64。
- 模拟器：`dist/HarmonyTavern-world-state-prototype-simulator-20261101-signed.hap`，arm64 + x86_64；已安装最终包。
- 两包附同名 SHA256 并验证。原生 ELF `.text`、`.rodata`、`.data.rel.ro` 与构建源库比对一致（归档过程会 strip 符号，不要求整个 .so 文件哈希相同）。手机打包后 x86_64 源库已恢复。
- 前一版 `HarmonyTavern-generation-context-*` 安装包保留。

## 尚未验收

真实在线模型的世界状态生成质量、不同模型对 JSON 协议和推理预算的遵守、多轮极端状态一致性、真机、API22、横屏及大字号/键盘遮挡组合尚未完整验收。当前 UI 已实际输入中文需求并处理输入法开合，但不泛称所有输入法组合通过。
