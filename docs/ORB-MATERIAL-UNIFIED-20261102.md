# 圆球与聊天栏材质统一（2026-11-02）

用户指出恢复 Codex 外观后顶部圆球模糊仍不一致，明确以聊天栏为基准。检查发现 HeaderAction 使用普通 backgroundEffect，聊天栏及底部加号在 API26 使用原生 ImmersiveMaterial；兼容配方还分别取不同饱和度、亮度和底色，单改模糊半径不能统一效果。

- HeaderAction（刷新、加号、返回、保存、关闭等）使用已有 NativeGlassBackdrop；与 SystemMaterialTray / ChatDockAction 同样获取 SystemGlass.navigation(level, colors) 的缓存官方材质，关闭外层重复模糊及增强高光。
- 不支持原生材质时，GLASS_HEADER_BUTTON、GLASS_ORB 和 GLASS_INPUT 统一按实际聊天栏兼容路径 GLASS_TAB_BAR 取模糊半径、饱和度、亮度、底色及活跃策略，随光感/沉浸档位一起变化。OrbButtonStyle 兼容高光强度同步。
- 保留圆球尺寸、来源挤压、即时反馈、刷新忙碌状态和回调；普通阅读面板的 frostedEffect 不变，设置重构及导航保持。
- 改前源码保存 build/orb-material-before-20261102。

ArkTS 与两种签名包构建通过（orb-material-build.log、orb-material-unified-package-build.log、orb-material-unified-arm64-build.log）。API26 模拟器实测首页创建菜单、第二次点击收回、进入旧聊天、聊天顶部菜单、底部加号菜单，原生子 TabBar 未阻断按钮触摸；检查日志未见 TypeError/ReferenceError/JsCrash/FATAL。聊天实图 build/orb-material-chat.jpeg，日志 build/orb-material-runtime.log。未调用模型或改写聊天数据；真机、API22及所有个性化档位尚未逐一验收，背景内容不同仍会影响肉眼所见透明度。

产物：dist/HarmonyTavern-orb-material-unified-arm64-20261102-signed.hap、dist/HarmonyTavern-orb-material-unified-simulator-20261102-signed.hap。均附 SHA256，手机仅 arm64，打包后 x86_64 源库已恢复。
