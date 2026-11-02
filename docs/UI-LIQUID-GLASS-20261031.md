# 导航液态玻璃（2026-10-31）

本次是项目视觉风格调整，非官方设计强制值。沿用手机、API 22、已有主题和减少动态效果设置。未改后端。

- Glass.ets：导航/底部聊天栏饱和度基值从 1.35 调到 1.55，滑动选中镜片 1.45 → 1.7，小圆球 1.45 → 1.5，顶部圆球 1.35 → 1.45。保留背景模糊半径；导航 tint alpha 为原值的 0.78，让底色更透出。饱和度随沉浸档位变化，上限 1.85；模糊关闭时回到 1。
- LiquidGlassRim.ets：窄幅实时背景采样、圆弧边缘、相反方向的细小缩放偏移与斜向高光，近似折射边缘。仅作用于装饰层，文字和图标不进入变形层。取样带降低到 0.28 透明度以减轻边缘接缝。
- JellyTabBar：外沿和滑动镜片接入边缘层，按压/拖动时边缘轻微扩张，复用现有可打断弹簧回稳；减少动态效果时不做额外边缘偏移。工具页和服务商页等复用此组件的分段导航同步生效。
- Index：底部导航/聊天栏容器接入对应边缘层；固定描边圆角，避免旧 border 覆盖圆角。
- 无循环计时器、无截图轮询；窄幅取样层不接收触摸和读屏焦点。

这是现有公开 ArkUI API 下的折射视觉近似，不是自定义位移着色器对整片背景进行物理折射。没有使用 sphericalEffect：当前 SDK 和官方文档注明该效果会冻结内容，不适合实时导航。

参考：[OpenHarmony 图像效果 sphericalEffect](https://github.com/openharmony/docs/blob/master/en/application-dev/reference/apis-arkui/arkui-ts/ts-universal-attributes-image-effect.md#sphericaleffect12)，本地 SDK common.d.ts / Glass BackgroundEffectOptions。

验证：完整构建；模拟器底部导航点击切换、工具页分段切换、文字及输入框显示。截图 build/liquid-nav.jpeg、build/liquid-segment.jpeg 为材质调试过程截图；后续收窄、淡化边缘采样带。当前仅模拟器连接，真机帧率、不同主题及横屏仍待设备验收。

产物：dist/HarmonyTavern-liquid-glass-simulator-20261031-signed.hap，dist/HarmonyTavern-liquid-glass-arm64-20261031-signed.hap（仅 arm64，附 SHA-256）。
