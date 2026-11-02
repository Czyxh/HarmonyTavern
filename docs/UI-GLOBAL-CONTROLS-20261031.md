# 全局控件样式统一（2026-10-31）

针对工具页的设置快照、立即创建快照，以及旧文字按钮、表单和菜单内样式不一致的问题。仅修改 ArkUI 前端，保留现有回调、可用条件和业务逻辑。

## 实现

- 新增 theme/ControlStyles.ets，统一普通、主要、危险、选中和警告操作的配色、44vp 高度、16vp 圆角、描边及按下/焦点/禁用态。菜单项使用 48vp 高度；关闭圆球复用工具栏玻璃材质。
- 31 个页面/组件接入共用表单样式，共 180 处按钮声明、38 处单行输入、18 处多行输入；公共菜单组件的接入同时覆盖其使用位置。
- 工具页的“设置快照 / 聊天搜索 / Token 计数”改用 SegmentedPicker，复用现有 JellyTabBar；内容较多时横向滚动。
- 公共 LiquidMenuItem 和 ChatPanel 关闭按钮同步统一；主要/普通/危险操作仍有语义区别。
- 设备检查发现 AttributeModifier 中 border 设置会重置独立圆角属性，因此在 BorderOptions 中直接指定 radius，修复按钮方角。

## 验证

- 完整构建通过：ui-global-controls-build.log，21.760 秒；沿用既有 ArkTS 警告。
- 模拟器覆盖安装、重启后检查工具页：分段切换正常，立即创建快照按钮圆角正确、文字完整；Token 页单行/多行输入和统计按钮一致。
- 检查聊天选项菜单：条目排列、文字、玻璃容器正常。当前应用日志缓冲区未发现 TypeError、ReferenceError、JsCrash 或 FATAL。
- 截图：build/unified-tools-final.jpeg、build/unified-fields.jpeg、build/unified-menu.jpeg。
- 未创建/恢复快照、保存连接配置或发送聊天请求。本次抽查不等同于所有菜单状态、横屏、大字体和主题组合的完整设备验收。
- HDC 当前只有模拟器 127.0.0.1:5555，手机仍待连接。

## 产物

- dist/HarmonyTavern-global-ui-simulator-20261031-signed.hap：包含 x86_64 和 arm64 库的模拟器验证包。
- dist/HarmonyTavern-global-ui-arm64-20261031-signed.hap：39,472,851 字节，仅 arm64，附 SHA-256。
- arm64 打包通过，包内库哈希与 SDK strip 后库一致；源库与中间库一致，x86_64 源库已恢复。未重新构建或修改 Rust。
