# 聊天记录选择与圆球玻璃统一（2026-11-01）

## 用户要求

创建对话的资料选择还应包含聊天记录；刷新、加号等圆球的液态玻璃强度应与底部聊天栏一致。保留上一轮恢复的顶栏背景，不再次改动 PageSurface。

## 实现

- `StoryPage` 创建页新增“聊天记录 · 可选”，从后端读取真实已有记录，按当前选择的角色过滤，避免把其他角色的消息混进当前对话。
- 支持“从空白开始”与“选择已有记录继续”。选择已有记录时先读取其故事设置、世界书和模式；确认按钮明确显示“保存设置并继续对话”。此路径保存该对话的故事设置，再打开原聊天，不复制消息、不清空历史、不追加开场白，也不创建重名聊天。
- 从已有记录切回空白会恢复此前的新建草稿；更换角色清除旧角色的记录选择，重复选择同一角色不会误清空。选中记录的读取过程有加载状态、并发与页面存活检查；读取失败保留当前选择并显示错误。
- `HeaderAction` 刷新/加号/返回/聊天菜单等圆球复用 `NativeGlassBackdrop`，与聊天输入承载的 `SystemMaterialTray` 同样调用 `SystemGlass.navigation(immersiveLevel, uiColors)`。保留减少动效、加载、无障碍和点击逻辑。
- 原生材质路径不再叠加手绘高光、额外玻璃模糊与描边。API22 或关闭模糊时，页头圆球与导航/输入/工具球共用 GLASS_INPUT 的半径、饱和度、亮度和主题 tint。
- 本轮没有修改顶栏的渐变模糊与安全区布局，也未改 Rust 或故事/世界书协议。

## 验证

- `history-glass-build.log`：ArkTS 编译与签名通过，原有兼容性、弃用等警告仍保留。
- API26 模拟器：选择 `Seraphina` 后列出其真实聊天记录 `default_Seraphina - 2026-11-01@00h09m32s`，选择后显示记录名及世界书设置；再切回“从空白开始”成功。
- 选择、切回和退出均未提交保存，没有新增、修改或删除用户聊天记录。本轮未按下“保存设置并继续对话”来改写用户数据；继续路径复用现有 NativeStory.save / Backend.getChat。
- 截图：`build/history-glass-home.jpeg`、`build/history-picker.jpeg`、`build/history-selected.jpeg`、`build/history-glass-chat.jpeg`。主页顶部圆球、聊天页头按钮、聊天输入及工具球检查完成；未改顶栏背景，浅色下未见白色横条。
- 物理手机及低版本系统的最终视觉效果未验证，不将共享材质参数描述成不同几何组件的每个像素都相同。

## 安装包

- 手机：`dist/HarmonyTavern-history-glass-arm64-20261101-signed.hap`。
- 模拟器：`dist/HarmonyTavern-history-glass-simulator-20261101-signed.hap`，已安装 API26 模拟器。
- 两包附同名 `.sha256`，校验通过。手机包打包后恢复 x86_64 源库。
- 手机打包日志：`history-glass-arm64-package.log`。
