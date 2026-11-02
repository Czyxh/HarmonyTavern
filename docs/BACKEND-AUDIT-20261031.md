# Rust 后端与鸿蒙功能对齐审查

## 对照依据和范围

日期：2026-10-31。实际逐项命令扫描以工程内 `tauritavern-ref` 参考快照为基线（原移植方案记录为 TauriTavern 2.4.0 / `fff9af0`），不是宣称已经与当前远端 main 全量同步。

- 原版仓库与在线命令注册表：[TauriTavern](https://github.com/Darkatse/TauriTavern)、[registry.rs](https://github.com/Darkatse/TauriTavern/blob/main/src-tauri/crates/tauritavern/src/presentation/commands/registry.rs)。在线内容确认命令组织方式；本次直接下载远端文件失败，未用它替换本地参考快照。
- 原版开关依据：`tauritavern-ref/default/content/settings.json` 的 `power_user`、`oai_settings`。
- 鸿蒙依据：[ArkTS 概览](https://developer.huawei.com/consumer/cn/arkts/)、[Node-API 异步任务](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/use-napi-asynchronous-task)、[Native 子线程调用主线程](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/native_subthread-to-uimain)。保留 ArkUI UI、异步 NAPI、沙箱数据目录和 ThreadsafeFunction 事件桥。此处是按已核对规则进行工程适配，不代表已经通过华为上架或全部规范审核。

执行 `node scripts/audit-backend-parity.mjs` 可重新生成 `backend-parity-20261031.json`。扫描统计的是命令名称，不能当成功能完成率：同名路由可能明确拒绝执行；异名也可能已有鸿蒙替代。参考注册表含 362 个命令，当前有 274 个同名路由，完整差异以机器报告为准。

## 本轮修复

| 发现 | 修复 | 验证方式 |
| --- | --- | --- |
| 普通聊天仅上传消息历史，人设/角色描述/系统提示词未装配，温度与长度写死 | 新增 Rust `prepare_native_chat`，按保存设置装配用户人设、角色描述/性格/场景/示例、系统提示词和后置指令；替换 `{{char}}`、`{{user}}`；保留多模态消息结构 | Rust 参数、提示词与多模态单测；ArkTS 构建 |
| 人设只有原始 JSON 编辑入口，分散在资料库 | 归入用户设定管理，提供聊天名字和人设正文表单；高级 JSON 留在此处；其他用户档案折叠收纳 | ArkTS 构建 |
| 设置页面与实际行为缺少连接 | 增加自动滚动、删除确认、去除首尾空白、系统提示词启用、优先角色提示词、角色后置指令开关；温度/Top P/回复长度可保存并用于生成 | Rust 保存回读测试；聊天代码接线 |
| 整份设置提交可覆盖其他页面的新设置 | 新增 `get_native_preferences` / `update_native_preferences`；基于原 ST 文档只修改白名单字段，沿用分块提交与 revision 冲突检查；高级 JSON 同样传入读取时 revision | 中文人设真实命令往返及过期 revision 拒绝测试 |
| 生成准备期间能重复触发发送 | 发送与重试增加准备期重入保护 | 静态检查、ArkTS 构建 |
| 流式输出持续强制把读者拉到底部 | 自动滚动开关只控制新回复跟随；读者向上滚动后保持位置，手动“回到最新”继续有效 | 代码检查；设备体验待验 |
| 日志输出推理与原始流正文 | 改为只记录字符长度 | 代码检查 |

设置组织为：**聊天**（行为、系统提示词、生成参数）、**备份**、**连接**（代理及模型缓存）、**日志**、**高级**（Agent 保留与杂项）。用户身份与人设独立归入用户设定管理。未消费的桌面性能开关不再出现在设置主界面。

聊天页模型面板与设置页复用 `SettingsPage` / `ProviderManager`：配置、模型、生成三个标签共同维护，不再保留聊天专用的简化选择器。聊天入口直接打开当前服务商，可编辑地址/协议/密钥和区域等字段、搜索/获取/手填模型、测试连接并保存；保存选择后同步聊天当前服务商。生成过程中连接配置只读，避免更换解码协议影响正在进行的回复。内嵌模式保持透明背景与原模型面板底部弹出转场。生成参数和系统提示词是各服务商共用的聊天默认值，界面明确说明其作用范围。

新增聊天菜单“查看聊天上下文”：只调用本地装配命令，展示模型、采样参数和 messages，不展示密钥或代理认证，也不请求模型、不保存消息。可用于核对人设/角色内容确实进入上下文。

## 仍未完成的功能

| 优先级 | 范围 | 当前实际情况与下一步 |
| --- | --- | --- |
| 高 | 完整提示词引擎 | 本轮完成基础上下文装配；世界书触发/递归、预算与位置、Token 上下文裁剪、完整 instruct/context 模板、复杂宏和消息示例解析仍未实现，不宣称与 ST 装配等价 |
| 高 | 群聊 | 已有群组管理与部分搜索；群聊游标分页、备份恢复、完整扩展 KV 和群成员轮流生成仍有缺口，不能把群组 CRUD 当作完整群聊 |
| 高 | 消息保存与文件 I/O | 既有 ChatFileOps 仍有同步读写与整文件改写，应迁到 Rust 原子提交/游标方案并补竞争写测试；大文件读写可能影响主线程 |
| 高 | 角色卡编辑/合并 | 基础 CRUD 和导入已有；原版卡数据批量合并、冲突解决与角色世界书采用接口未全部暴露 |
| 中 | 多套人设和头像 | 当前支持活跃人设正文；原卡片存储保持兼容，不会清空其他人设。多套人设可视化切换、聊天绑定与头像管理仍需完善 |
| 中 | 媒体 | 资源库、表情立绘上传包、壁纸文件夹/缩略图和图像元数据整理缺少完整鸿蒙入口；已有用户图片导入不能代表整套媒体管理 |
| 中 | 翻译/语音/绘图 | 原版 translate_text、tts_handle、sd_handle/cancel_sd_request 未补齐；需要各自服务配置、取消与错误处理，不放无效开关 |
| 中 | 扩展 | 安装/管理不等于执行浏览器扩展。Tauri WebView/Channel 工具通道、资源句柄和扩展提交仍有显式不支持路由，需设计原生替代 |
| 中 | 日志 | 已有应用日志页面；原版 devlog 导出、原始 LLM 请求预览和订阅命令并未完全对齐 |
| 中 | 长任务与生命周期 | 同步/生成在切后台、恢复及取消上的真机行为仍需逐项验收；不要仅凭 async 方法认定满足后台运行规则 |

## 名称差异与平台替代

- 世界书分块提交在鸿蒙使用 `world_info_*` 命名，不能按原版 `begin_world_info_commit` 名称缺失就认定功能全缺。
- 文件选择、沙箱 URI 和通知权限由 ArkTS 系统 Kit 承担，不应照搬 Tauri picker、桌面路径或原生 WebView 资源句柄。
- 鸿蒙个性化已独立实现，原版浏览器主题 CSS、CodeMirror、窗口背板、托盘与窗口快照不适合直接搬为设置开关。
- 当前项目有 ArkTS 既有警告与 ESObject 用法；新增偏好与桥接 DTO 使用明确接口，但本轮没有将全工程所有历史代码改成零警告。

## 验证记录

- `native/test-preferences-regression.log`：Rust 命令层 45 项回归测试全部通过，包含四项偏好测试、真实设置提交、中文回读及冲突拒绝。保存前剥离独立存储的人设卡片投影，避免偏好保存重写其他卡片；偏好 DTO 要求完整字段，缺失字段不会静默重置为默认值。
- `ui-native-settings-build.log`：ArkTS 完整构建通过，保留既有警告；最终包需在 Rust 库完成后重新打包。
- x86_64 模拟器使用调试库（`build-preferences-x86-debug-final.log`），已安装并启动。核对用户设定管理入口、独立人设入口已移除、身份表单读取成功；聊天/备份/连接/日志/高级分组及行为开关显示正常；聊天模型面板共享的配置/模型/生成标签和参数读取成功。
- 本地上下文预览运行成功：已有聊天装配出 3 条消息、包含 system 角色，回复长度回读为 8192；预览不含密钥字段。未发送消息、未测试外部服务、未修改真实用户人设或连接密钥。
- 截图：`build/native-settings-user.jpeg`、`build/native-model-settings.jpeg`。已人工检查正文与控件排版；生成页顶部原服务商保存按钮会产生歧义，已在生成页隐藏，生成设置使用自身保存按钮。
- `native/scripts/build.ps1` 修复 `-Debug` 向 cargo 传空参数的问题；真机继续使用优化库，模拟器使用调试库。arm64 最终产物及手机安装状态在交付时追加。
- 依赖真实模型、双设备同步、语音和媒体供应商的成功路径未验证。手机连接不稳定，模拟器结果不代表真机性能验收。


### 最终交付记录

- arm64 优化库完成：`native/build-preferences-arm64-delivery.log`（12 分 26 秒）；x86_64 调试库完成并复核为最新：`native/build-preferences-x86-debug-final.log`。
- 最终双架构界面构建成功：`ui-native-settings-final-build.log`（21.818 秒），已覆盖安装并启动模拟器。最终复查聊天模型页“聊天生成设置”和“默认生成参数”均显示，未出现读取失败。
- 真机专用签名包：`dist/HarmonyTavern-settings-arm64-20261031-signed.hap`（39,260,215 字节），附 SHA-256 文件；仅含 `libs/arm64-v8a/libttavern.so`。SDK DoNativeStrip 会处理库，已分别验证原库与 ProcessLibs 输入哈希一致、包内库与 DoNativeStrip 输出哈希一致。
- 模拟器验证包：`dist/HarmonyTavern-settings-simulator-20261031-signed.hap`，含优化 arm64 与调试 x86_64。为生成真机包临时移出的 x86_64 库已恢复，工程两种架构源码和库均保留。
- 最终 HDC 只检测到模拟器 `127.0.0.1:5555`，手机尚未重新连接，未宣称完成手机端检查。未修改用户人设、未保存测试连接配置、未发送聊天或真实模型请求。
