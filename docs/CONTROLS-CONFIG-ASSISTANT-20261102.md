# 控件稳定、紧凑分段与连接配置助手（2026-11-02）

## 改动

- 使用统计：范围读取不再驱动HeaderAction的pending，避免刷新图标与加载圈短暂互换；左右日期按钮不再随busy切换禁用样式，读取中的点击由事件处理器忽略。内容淡化只作用于热力图，按钮保持原节点与不透明度。
- 热力图周项key由跨范围重复的序号改为实际日期与计数序列，避免复用旧年度格子；标题说明改为直接响应式Text，防止@Builder按值参数保留旧窗口说明。指标和排行的key包含数值，防止同名项复用旧值。
- JellyTabBar：清除原生TabBar默认材质/背景底层，文字分段高度56→48vp并裁剪轮廓，兼容路径移除文字分段投影；保留44vp独立点击区域，主底部导航高度和动效保持原值。SegmentedPicker相应48vp。
- 服务商管理：列表间距20→12vp、卡片内边距20→14vp、列表头像48→40vp、标题18→16sp、自定义入口60→48vp，顶部内容起点104→84vp。
- 顶部说明卡改为可操作的“让 AI 帮我配置”二级页，支持在本机识别URL/JSON/curl，生成地址、模型、协议草稿，核对后填入自定义服务商，继续既有保存/获取模型/连接测试流程。没有自动保存或联网测试。
- AI整理接到当前已保存聊天服务商的真实generateChatCompletion，复用端点授权流程，用量归为既有后台请求。只允许发送提取后的地址、模型、协议；不发送原始示例和提取的密钥。模型回复解析支持OpenAI/Responses/Claude/Gemini，并拒绝AI改写服务地址或模型。未连接模型仍能本机识别。

## 验证

- controls-assistant-build.log与controls-assistant-arm64-build.log构建成功；复用上一轮Rust库，本轮无Rust修改。
- build/provider-setup-client-tests.cjs：curl/JSON、密钥不进AI输入、URL/协议校验、四类响应、真实调用组装、拒绝虚构地址与只读保护通过（mock，不消耗用户额度）。
- build/usage-nav-client-tests.cjs：异步乱序/保留数据/失败/减少动态、日历key差异和导航回归通过。
- API26模拟器验证服务商管理、个性化、通用偏好、配置助手、本机识别与返回；未保存或改写真实连接与聊天。截图build/controls-provider.jpeg、controls-assistant.jpeg、controls-appearance.jpeg、controls-preferences.jpeg。
- 独立OpenDesign图片复查通过分段底层、居中、密度、助手可读性，指出旧标题说明后已改为响应式Text并重新构建检查。
- build/controls-usage-ui-check.cjs连续切换7次，核对窗口说明、内容及刷新不透明度、按钮启用状态。刷新与两个日期按钮的实际节点hash在不同范围保持不变。截图build/controls-usage-month-final.jpeg。尚未作真机逐帧性能验收。

## AI接入边界

配置助手AI整理使用用户已有服务商。本地生成模型与小艺还未接入，已向用户提出方案选择，不能把本机规则识别描述为本地小模型。官方SDK @hms.ai.AgentFramework.d.ets的AgentController.isAgentSupport与FunctionComponent都要求实际创建的agentId，且有华为账号/协议/网络条件；FunctionComponent提供官方智能体界面，并非任意无配置本地文本生成API。SDK中NaturalLanguageKit仅提供分词/实体抽取，不等于生成模型。参考官方能力概览 https://developer.huawei.com/consumer/cn/harmonyos-ai 和SDK内创建智能体链接 https://developer.huawei.com/consumer/cn/doc/service/quick-start-0000002469548009 。未编造Agent ID，未下载大型模型权重。

## 包

- 手机 dist/HarmonyTavern-controls-assistant-arm64-20261102-signed.hap，40221655字节，仅arm64。
- 模拟器 dist/HarmonyTavern-controls-assistant-simulator-20261102-signed.hap，98080284字节，arm64+x86_64，已安装。
- 附SHA256。ABI临时移动后已恢复x86_64源库。
