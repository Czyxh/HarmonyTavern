# UI 材质统一与逐轮剧情选项（2026-11-01）

> 后续用户要求恢复原顶栏效果并在创建页选择已有资料，最新实现与安装包见 [HEADER-CREATE-RESOURCES-20261101.md](HEADER-CREATE-RESOURCES-20261101.md)。下文关于 PageSurface 实色遮罩和页头原生材质的设计已撤回，剧情选项与其余修复继续保留。

## 范围与依据

保持现有 HarmonyTavern 的纸张、柔雾绿、暖米、静雾蓝、月白、玫瑰与自定义主题，不更换信息架构。已检查 `pages/*.ets` 全部 30 页的源码导航、背景和颜色使用；模拟器视觉抽查不等于全部设备验收。

先复用了此前 Codex 会话与 `UI-REDESIGN-20261030.md`、`API26-UI-UPGRADE-20261031.md`、`UI-API26-FIX-20261101.md`、`LIBRARY-CHAT-INTEGRATION-20261101.md` 的阅读记录和实现结论，以及 `oh-reference/` 缓存。本次另外核对 OpenHarmony 官方 Tabs、uiMaterial 文档和本机 API 26 SDK 的 MeasureUtils 声明。华为 ArkTS/ArkUI 首页抓取只返回标题，不将其算作通读全部官方文档。

- 华为沉浸光感能力边界：https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/arkts-immersive-light-sense-enable
- OpenHarmony uiMaterial：https://github.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-arkui/arkts-apis-uimaterial.md
- OpenHarmony Tabs：https://github.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-arkui/arkui-ts/ts-container-tabs.md

## 材质与页面背景

- `JellyTabBar` 删除叠在系统材质上的手绘光场、多层光圈；选中镜片走单一原生镜片材质，旧系统只保留低强度边缘与高光。清空 TabBar 默认底色/普通背景模糊，并裁剪到实际胶囊轮廓，消除分栏背后矩形阴影块。
- 底部导航、资料库切换条、工具球、共享页头按钮使用同一系统导航材质配方。新增 `NativeGlassBackdrop` 仅在真正的底部 TabBar 自定义子树承载系统材质；不是声称普通 Column 任意位置支持 systemMaterial。默认底板使用 `Material.empty`，同时清空 `barBackgroundColor` 和 `barBackgroundEffect`。输入栏原有 `SystemMaterialTray` 保留。
- API 22 / 关闭模糊仍走兼容路径。球、页头、导航、输入的普通玻璃共用输入玻璃的模糊、饱和度与亮度配方，颜色仍来自当前主题。
- `PageSurface` 只保留根底色和顶部同色遮罩；移除对正文的全区域渐变模糊与重复不透明底色。顶部透明端与当前背景使用相同 RGB，避免深色下的浅色亮带；页头区域保持可读，不让滚动消息穿过状态栏文字。
- 资料库中的角色导入、世界书和聊天导入在 embedded 模式使用透明背景，独立页面保留底色。
- 共享 HeaderAction、PageHeader、ChatPanel、服务商管理与聊天页圆球统一材质；ExtensionPage 错误文本改用主题 danger。
- `StoryPage` 的角色、显示名、文件名改为响应式状态，修复从聊天菜单进入编辑时仍显示“创建故事”和开场白字段的问题；最终包实测编辑页标题和字段隐藏均通过。
- 内置主题状态栏前景依据应用深浅状态，自定义背景仍按实际亮度选择，避免切到深色时资源尚未更新造成黑色状态文字。

## 内容驱动菜单

- `OriginPanelState.menuWidth` 依据实际菜单标签用 `UIContext.getMeasureUtils().measureText` 测量，限制 176–320vp 和当前窗口可用宽度。
- 首页创建菜单、角色选择、聊天工具、消息菜单、聊天菜单、角色菜单实测 Column 内容高度后更新目标高度，仍受视口上限约束；长内容滚动，而不是撑出屏幕。
- LiquidMenuItem 允许自然换行和自适应高度，保留至少 48vp 触摸区域。角色少时不再固定占 360vp。
- 遮罩色取主题文字色并控制透明度，不再固定黑色。

## 剧情选项协议与真实回合

模型协议由字符串改为对象：

```json
<story_options>[
  {"label":"询问道路","reply":"请问去小镇应该走哪条路？"},
  {"label":"表达感谢","reply":"谢谢你愿意帮我。"}
]</story_options>
```

- `label` 只表示选择意图，`reply` 是实际要发送的第一人称用户发言。按钮同时展示意图和带引号的发言，点击只发送冻结的 `reply`，不发送整个描述，也不把引号 UI 装饰写入消息。
- 旧字符串选项和缺字段对象不会继续作为可点击发言使用；旧叙事保留，在当前回合补生成新协议。解析接受协议内 JSON 围栏、完整结束标签后的尾注；无效/重复/过长项过滤，不足两项明确失败，不伪造选项。
- 增加 `get_native_story_choices`、`prepare_native_story_choices`、`commit_native_story_choices`。每次读取用聊天内容和故事设置的指纹校验回合；补选项只写 extension store，不新增助手叙事或用户消息。
- 开场、旧会话、模型漏返选项、模式变更、回复重试、停止后保存的部分回复，均会核对当前回合，需要时使用独立可取消流生成选项。最后一条有效消息是用户时不生成下一轮选项；末尾系统消息不再挡住助手回合判断。
- 选项失败有独立错误、重试按钮和自由输入，不把协议原文显示成剧情，不声称后端失败时已有选项。
- 发送文本在首次 await 之前冻结。会话身份、revision、streamId 在授权、异步准备、读流后检查，离开/切会话只释放自己的流，防止串写会话。
- 保存失败保留已收到回复并提供重试保存；禁止切会话、编辑、生成或返回时静默丢弃未保存内容。系统返回也使用共享 dock 的阻止标记。进程被杀仍可能丢失未落盘内容，没有承诺未保存流跨进程恢复。

## 验证记录

- ArkTS 编译与签名通过：`ui-unify-arkts-build.log`；保留原有兼容 API 提示与弃用警告，不把警告说成零。
- 聚焦原生测试 11/11：`ui-unify-story-tests-final.log`。覆盖开场补选项缓存、补生成不追加消息、label/reply 分离、协议校验、过期提交拒绝、故事修改使缓存失效、用户回合不预生成，以及偏好与人设集成。
- 全量 ttavern lib：51/52；既有群聊会话路径测试在整套中仍失败，单独执行通过（1/1），日志 `ui-unify-all-tests.log`、`ui-unify-group-isolated.log`。未为此修改无关群聊代码。
- API26 模拟器检查：首页、角色列表、资料库角色卡/世界书/聊天记录、设置、个性化主题与显示、聊天页、创建菜单和角色选择。角色为一个时面板实际高度约 112vp，不再固定 360vp。
- 视觉抽查纸张深浅色、柔雾绿深浅色、暖米与静雾蓝；测试后恢复原来的纸张/跟随系统。截图在 `build/ui-*.jpeg`，包括 `ui-glass-corrected.jpeg`、`ui-menu-fitted.jpeg`、`ui-library-paper-dark.jpeg`、`ui-dark-prefs.jpeg`、`ui-sage-dark.jpeg`、`ui-sage-light.jpeg`、`ui-sand-light.jpeg`、`ui-mist-light.jpeg`。
- `build/ui-unify-runtime.log` 未检出 TypeError、ReferenceError、JsCrash、FATAL。

## 构建与安装包

- arm64 原生 release 构建通过：`ui-unify-native-arm64.log`；x86_64 通过：`ui-unify-native-x86-final.log`。均包含本轮剧情协议命令。
- 手机安装包：`dist/HarmonyTavern-ui-story-unified-arm64-20261101-signed.hap`，39,519,908 字节，仅含 arm64 库。
- 模拟器安装包：`dist/HarmonyTavern-ui-story-unified-simulator-20261101-signed.hap`，68,886,764 字节，包含 arm64 与 x86_64，已安装 API26 模拟器并冷启动。
- 两包均附同名 `.sha256`。检查了压缩包库条目，手机/模拟器包中的 arm64 库哈希一致；用于手机打包而暂存的 x86_64 源库已恢复。
- 最终打包日志 `ui-unify-final-package.log`、`ui-unify-arm64-package.log`。手机包 6.177 秒，最终双架构包 11.822 秒。

## 尚未验收

- 真实在线模型完整多轮“选项→实际发言→下一轮选项”尚未验证；原生协议/存储测试不替代真实服务商的生成效果。
- 月白、玫瑰、自定义配色仅做源码路径检查，尚未逐页截图；物理手机、API22 新包运行、横屏、超大字号、键盘遮挡与动画性能尚未完整验收。
- 不将模糊和高光描述为任意贝塞尔水滴的真实光学折射。系统算力、系统光感配置和屏幕尺寸仍会影响实机表现。
