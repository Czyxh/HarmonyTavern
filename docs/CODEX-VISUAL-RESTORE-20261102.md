# 恢复 Codex 导航、按钮与顶部栏（2026-11-02）

用户明确选择以切换到 Percho 前、Codex 最后一版为外观基准，并澄清“上面的状态栏”指顶部标题/按钮栏，不是血条和状态行。保留 Percho 期间完成的故事、身份、生成设置、上下文精简、创造模式等功能。

## 改动

- 从 Percho 初期读取源码的历史工具输出恢复原 JellyTabBar；重叠行逐一核对后拼接，非凭截图猜参数。恢复原选中镜片、高光、光场、兼容边缘、拖动反馈和居中布局。
- SystemGlass 原生 API26 材质此前被 refractionEnabled=false 全局禁用，现重新启用，保留版本检查与不支持设备的回退。
- glassEffect 恢复原来各类控件的模糊、主题 tint、饱和度、亮度与窗口活跃策略。普通展开面板仍用独立 frostedEffect，未将可读性面板改成液态材质。
- HeaderAction 恢复原渐变与细描边，保留后来增加的 symbol 属性、真实异步忙碌状态、事件及按压反馈；PageHeader 继续复用该组件。
- PageSurface 与 ChatPage 恢复原顶部 1→0.85→0.35→0 的模糊过渡和主题淡色渐变，保留当前安全区、列表惰性渲染、菜单与功能。血条、HUD 位置、底部额外磨砂均未修改。
- 改前快照保存于 build/ui-restore-before-20261102；恢复脚本没有修改 Rust、聊天消息或世界状态数据。

## 验证

- ArkTS 签名构建成功：restore-codex-final-build.log、restore-codex-package-build.log、restore-codex-arm64-build.log。
- generation-client-tests 4 组、world-state-client-tests 7 组、chat-usage-client-tests 3 组、panel-sizing-client-tests 2 组通过。首次 world-state 抽取测试因 Windows 写文件产生 CRLF 导致匹配失败，恢复源文件 LF 后重跑通过；没有为测试修改业务逻辑。
- API26 Mate 90 Pro s 冷启动并安装新模拟器包。日志确认 API26 supported=true level=0；所查日志无 TypeError/ReferenceError/JsCrash/FATAL。
- 导航外框 [70,2503][1210,2699]，内部按钮行 [133,2524][1147,2678]，纵向中心均 2601px。与旧版已验证截图对照，恢复原玻璃和镜片形态。
- 实际检查首页加号展开、第二次点击收回、切设置与聊天、打开个性化及显示分段、深色标题/返回按钮。显示偏好测试后回到跟随系统，冷启动核对首页。
- 截图：build/codex-restored-home-final.jpeg、build/codex-restored-settings.jpeg、build/codex-restored-dark-header.jpeg、build/codex-restored-chat.jpeg。
- 未调用在线模型，未新增/删除聊天。尚未进行物理手机、API22、大字体及逐帧性能验收。主题从深色切回跟随系统后曾观察到聊天系统状态栏图标短时保持白色，冷启动恢复黑色；本轮未修改 DisplayPreferences，未将此项宣称为已修复。

## 产物

- 手机：dist/HarmonyTavern-codex-visual-restored-arm64-20261102-signed.hap，仅 arm64。
- 模拟器：dist/HarmonyTavern-codex-visual-restored-simulator-20261102-signed.hap，arm64+x86_64，已安装验收。
- 两包附 SHA256；手机包检查仅含 libs/arm64-v8a/libttavern.so，x86_64 源库已恢复。打包脚本 build/package-codex-visual-restore.ps1。
