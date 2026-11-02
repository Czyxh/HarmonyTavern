# API 26 与全局外观升级

> 2026-11-01：API 26 镜像已安装，聊天崩溃与导航/聊天栏偏移已修复。当前结果和水滴验收边界见 [UI-API26-FIX-20261101.md](UI-API26-FIX-20261101.md)。下文镜像下载失败及 20261031 包为历史记录。

## 构建环境

- DevEco Studio 26.0.0.865：C:/Program Files/Huawei/DevEco Studios/DevEco Studio。
- SDK 26.0.0.105，Hvigor 6.26.9。targetSdkVersion 升到 26.0.0；compatibleSdkVersion 保持 6.0.2(22)。工程 modelVersion 更新为 6.26.0。
- 使用 scripts/build-hap.ps1 构建，可用 -StudioRoot 覆盖安装位置。旧配置备份在 build/api26-before。
- module.json5 的沉浸材质开关移到 entry 模块 metadata；备份扩展的 metadata 恢复为 ohos.extension.backup。

## 官方材质接入

- SystemGlass 先检查运行时 API，再动态导入 SystemGlassNative；旧系统不会加载缺失的新原生模块。
- 设备还必须通过 uiMaterial.isImmersiveMaterialSupported() 检查。未通过时使用既有材质。
- 底部导航与共用分段导航由真正的底部 TabBar 承载自定义控件，使用 barFloatingStyle.systemMaterial 设置官方 ImmersiveMaterial；barOverlap=true、vertical=false、barPosition=End，并显式 barWidth=100%，避免单个自定义 TabBar 项默认收缩为 168vp。
- 当前自定义导航的按钮、滑动镜片、可打断切换和页面 SwingContent 回调继续使用。这个 Tabs 只承载视觉区域，不替换业务路由。
- 聊天输入栏用 SystemMaterialTray 进入受支持的底部 TabBar 材质区域；输入与发送仍由同一 ChatDockState 回调处理。
- 支持的原生弹窗、滑块、开关等由 entry enable 配置启用系统材质；自定义端点确认弹窗显式提供 systemMaterial。普通页面卡片保持主题表面，不将不支持的任意容器宣称为系统折射。
- 材质对象缓存复用，避免按压或拖动时反复构造；减少动态效果时关闭镜片光感反馈，保留既有静态状态。

官方接口依据：[Tabs 悬浮样式](https://github.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-arkui/arkui-ts/ts-container-tabs.md#barfloatingstyle)，[华为开启沉浸光感](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/arkts-immersive-light-sense-enable)，本机 API 26 公共声明文件。

## 全局外观

- 通过已有 ControlStyles 统一更新 180 处文字按钮声明、38 处单行输入、18 处多行输入的表面、细描边与高光；动作与启用条件不变。
- 新增 SurfaceStyle，为 16 个页面/组件的 34 处表面增加轻量主题渐变、细描边与柔和投影。包括设置入口、服务商卡片、工具、模型、群聊、世界书、导入等。
- 页眉返回和工具圆球固定描边圆角。浅深主题、纸张、粉色与自定义配色继续由现有 ColorTokens 决定。
- 未改 Rust 后端、存储、请求或业务权限判定。

## 验证及当前限制

- 完整构建通过：ui-api26-global-build.log，25.744 秒；arm64 打包 ui-api26-arm64-package.log，12.475 秒。
- 新建独立 HarmonyTavern_API22 模拟器，没有覆盖原 ggb 数据。最终应用可安装、启动；首页/设置卡片、导航点击、设置滚动、工具入口和 Token 分段切换通过抽查。
- 最终 API 22 应用日志未发现 TypeError、ReferenceError、JsCrash、FATAL 或 uiMaterial 模块缺失。曾发现静态导入日志，已以延迟导入修复并重新安装检查。
- 截图：build/api22-global.jpeg、build/api22-settings.jpeg、build/api22-tools.jpeg。仅为 API 22 降级效果，不是 API 26 官方折射效果验收。
- 输入法首次启动协议已取消/退出，没有代用户接受。未创建快照、保存服务商、发送模型请求。
- API 26 官方模拟器镜像下载在约 31.8% 中断，镜像未安装成功；API 26 原生材质、镜片尺寸、拖动、聊天输入/键盘、多主题和横屏仍待 API 26 设备验收。当前无手机连接。不得把编译成功表述为官方折射已验证。

## 产物

- dist/HarmonyTavern-api26-global-ui-arm64-20261031-signed.hap：39,197,333 字节，附 SHA-256，仅 arm64，源库与中间库、包内库与 strip 后库哈希均核对通过。
- dist/HarmonyTavern-api26-global-ui-simulator-20261031-signed.hap：含 x86_64 的模拟器包。最终包已安装 API 22 模拟器。
- x86_64 源库打包后已恢复。新 SDK strip 处理原有原生库，没有重新编译 Rust。
