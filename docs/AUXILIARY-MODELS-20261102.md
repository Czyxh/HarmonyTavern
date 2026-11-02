# 辅助模型与整栏光效（2026-11-02）

最新修订：见 `SETTINGS-HELP-20261102.md`。辅助模型现改为复用服务商管理中已配置的模型，独立新建连接表单已移除；本文自定义配置创建说明仅记录上一版实现，不代表当前界面。

## 用户确认的入口与用途

- 设置首页「模型与连接」中新增「辅助模型设置」，与服务商管理同级。用户已纠正最初放在服务商分组内的方案，不恢复该方案。
- 默认内置云端 Qwen/Qwen3.5-4B，地址为硅基流动中国站。设备内已保存的内置助手凭据继续使用。
- 可添加多套自定义辅助模型，支持填写名称、基础地址、模型 ID、五种现有兼容协议及密钥；可切换、编辑，编辑时留空密钥保留原凭据。
- 辅助模型独立处理「让 AI 帮我配置」、新建普通对话的故事草稿、创造模式手动生成状态栏。
- 普通聊天回复与随回复附带的状态更新仍沿用已有主模型流程；本轮未拆分自动回复请求。

## 数据与请求

- EntryAbility 在 UI 挂载前持久化 auxiliaryModels 与 auxiliaryModelId。仅存模型连接信息和 secretId。
- 凭据继续存放后端私有密钥库。新增辅助密钥后恢复原有 custom 活跃凭据，辅助请求显式携带自己的 secret_id，不调用 ProviderPreferences.activate。
- AuxiliaryModels.route 从任务消息、采样参数、Token 预算组装独立路由，不继承主聊天的地址、密钥、服务商区域或自定义请求体。
- 内置模型关闭思考。配置整理与故事草稿额外要求 JSON 对象；世界状态请求保留原有 XML 包裹 JSON 协议。
- 配置助手仍只发送本机提取后的地址、模型、协议；原始示例和待配置服务的密钥不发给辅助模型。
- 故事草稿发送需求、当前故事字段、所选角色的有限文本。预览后明确点击「填入故事设置」，再由用户编辑和创建；不会自动建立聊天或改动角色卡、世界书与聊天模式。
- 故事生成有进度、顶部取消、离页取消及晚到结果防护。字段直接绑定 story 状态，确保填入后文本框同步。
- 创造模式独立生成保留 NativeWorld.prepare/commit 的指纹、身份、取消、端点授权与过期保护；不改写聊天原文。

## 栏底光效

- JellyTabBar 的光效移至整条栏的完整容器，原生材质路径、兼容路径和 bare 路径均覆盖。
- GlassLightField 的 fullCoverage 使用中心固定、半径加宽的光场；按压增强覆盖整个栏底。
- 移除滑块内部随拖动移动的局部强调色光斑，保留镜片边缘、形变、系统材质和独立交互层。
- 不修改其他圆球、输入栏等 GlassLightField 使用者的默认配方。

## 验证与边界

- 双架构模拟器包与 arm64 手机包构建、签名通过；打包脚本在 finally 中恢复 x86_64 源库。
- auxiliary-client-tests、provider-setup-client-tests、world-state-client-tests 通过：路由与密钥隔离、多配置、编辑、原任务消息和预算、JSON 格式、草稿人工应用、取消及离页晚到、聊天切换保护。
- generation-client-tests、usage-nav-client-tests、panel-sizing-client-tests 通过。
- API26 模拟器：独立设置入口、保留内置凭据、添加表单、内置 Qwen 联网生成故事草稿及人工填入已验证；生成草稿后离页，首页仍为原有两段聊天。
- 最终包复测确认背景、风格、规则、开场白均在填入后出现在对应的可编辑 TextArea 中，顶部取消入口在生成期间可见。
- 自定义模型的实际远端连通性与创造模式完整线上生成未在本轮逐一验证；相关路由与状态保护使用 mock 回归。真机与深色/大字号拖动未验证。
- creator-ui-client-tests 存在本轮未触及的材质期望失败（effect.saturation 为 NaN，旧用例期望 1），不把该套件报告为通过。
- 截图：build/auxiliary-fullrail-rest.jpeg、build/auxiliary-fullrail-drag.jpeg。采样未见原先局部色块边界，但不能据此承诺所有真机与主题。

## 产物

- dist/HarmonyTavern-auxiliary-models-arm64-20261102-signed.hap
- dist/HarmonyTavern-auxiliary-models-simulator-20261102-signed.hap
- 各产物附 .sha256；脚本 build/package-auxiliary-models.ps1。
- 修改前源码与相关测试备份于 backups/auxiliary-models-20261102。
