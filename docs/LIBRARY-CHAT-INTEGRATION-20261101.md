# 资料库与聊天整合（2026-11-01）

## 最终行为

- 设置不再列出世界书和群聊。资料库的世界书改用共用 WorldInfoPage，统一书籍列表、新建、删除、条目添加/编辑/删除、常驻与禁用、文件/JSON 导入。导入成功回到对应书籍，保留原文件和后端格式。
- 聊天首页显示群聊入口和单人会话。顶栏左刷新、右圆形加号；另有圆形悬浮加号，复用 HoldingPose 的握姿换边与交互期间位置冻结。两处加号共用创建对话/创建群聊菜单；创建对话先选角色。刷新显示进度并提示结果。
- 浮动加号仅占自身 44vp 高度，空白区域透传，不拦截底部导航。创建菜单与原有会话菜单使用独立的模态绑定节点。
- 群聊支持创建、成员加入/移除/静音、修改群名、按成员顺序或手动指定发言成员、新建/打开记录、记录改名/删除、删除群组。修正 disabled_members 字段及记录 preview 字段；记录改名/删除同步维护所属群的 chats/chat_id。
- 新 GroupChatPage 复用服务商配置、人设/角色提示词装配、流式完成和端点授权。每位角色使用自己的提示词，正文保留发言者姓名；支持停止、保留已生成文本和继续回复。没有实现 SillyTavern 所有自然激活概率、后台定时自动发言或所有 generation_mode 行为。
- Rust native_group_session 提供创建/读取/追加，校验群归属、路径和过期消息数，原子保存 JSONL，保留额外消息字段。没有把群消息写入单人会话。
- 按用户最新要求，OriginPanel 背景撤回官方液态背板及流光层。使用导航栏的模糊半径、普通饱和度和较实的主题底色，保证文字可读；官方材质继续用于现有导航与镜片。轮廓转场、按钮按压和源圆球挤压反馈保留。
- 世界书保存、取消编辑和建群后释放输入焦点。删除群组的确认文案明确包含关联记录，修正旧提示与实际删除行为不符的问题。

## 验证

- Rust 测试 `native_group_session_roundtrip_rejects_stale_and_foreign_chat` 通过：创建、中文消息持久化/重读、附加字段保留、过期追加拒绝、跨群记录拒绝、路径穿越拒绝、空消息拒绝。日志 group-session-test.log。
- x86_64 debug 和 arm64 release 原生库构建成功；SDK 路径更新为已安装 DevEco 26，使用独立的无空格 NDK junction，未改旧 junction。
- API 26 模拟器检查：顶栏按钮位置；两个创建菜单；角色选择；第二次点击加号收回；旧会话操作菜单；底部导航点击；资料库世界书管理与导入界面。
- 用 QA_Group_20261101 验证建群、加入成员、新建群记录、返回首页显示、再次打开持久化记录；用 QA_World_20261101 验证新建书籍、添加条目、编辑保存。测试群与测试书已删除，原有 Seraphina/Eldoria 保留。
- 最终运行日志 build/library-chat-final-runtime.log 未发现 TypeError、ReferenceError、JsCrash、FATAL。截图 build/chat-create-readable.jpeg、build/world-library-merged.jpeg、build/group-chat-open-verified.jpeg。
- 未发送真实模型请求，因此真实服务下的多角色回复、端点授权、取消/网络失败和长历史性能尚未做端到端验收。未连接手机，也未验证真实握姿事件；复用了已有 HoldingPose 接入。

## 交付

- 最终构建 library-chat-release-build.log：18.196 秒；arm64 打包 library-chat-arm64-package.log：6.914 秒。
- dist/HarmonyTavern-library-chat-arm64-20261101-signed.hap：39,374,506 字节，仅 arm64。
- dist/HarmonyTavern-library-chat-simulator-20261101-signed.hap：96,938,224 字节，含 x86_64，最终版本已安装 API 26 模拟器。
- 两包附 SHA-256；源库/中间库、包内库/strip 后库哈希匹配，x86_64 源库打包后已恢复。
