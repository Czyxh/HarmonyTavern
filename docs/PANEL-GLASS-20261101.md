# 展开面板与来源圆球的玻璃统一（2026-11-01）

## 需求澄清

用户要求：展开页面与触发它的小圆球保持相同透明程度，保留早期版本的毛玻璃感觉，而不是为了可读性将展开页面变为近乎实色块。不是更改顶栏背景，也不是继续调整圆球本身。

## 原因与最小修改

此前 `OriginPanel.material()` 虽然保留模糊，但将背景强制改为 `bgSurface` 的 0.88 alpha，同时把饱和度、亮度重置为 1。来源圆球已使用 SystemGlass.navigation，展开面板仍走单独的浓底色路径，两者因此断层。

本轮只修改两个组件：

- `entry/src/main/ets/components/OriginPanel.ets`：去掉 88% 实色覆盖、饱和度和亮度覆盖。在系统材质可用且模糊开启时，复用来源圆球同一个 NativeGlassBackdrop / SystemGlass.navigation，外层效果保持透明，不二次叠加模糊、底色和轮廓。兼容路径直接使用来源圆球 GLASS_ORB 的共享玻璃配方及相同的细边。
- `entry/src/main/ets/components/NativeGlassBackdrop.ets`：增加可选 fillParent，供展开面板随父级尺寸铺满，现有圆球默认仍保持原来的固定尺寸。展开的轮廓和连颈继续由原 LiquidSurface / @AnimatableExtend 路径负责，不更改展开、收回或减少动效的逻辑。

保留面板的外部关闭遮罩、前景文字、列表项目与交互布局。不修改 PageSurface 顶部渐变模糊、聊天记录、角色与世界书选择。关闭模糊仍明确回退实色，尊重用户设置。

系统材质放在支持的自定义 TabBar 子树中，仍受 API 能力检测保护；此处仅说明共享系统玻璃与轮廓裁剪，不宣称实现任意路径的光学折射。

## 验证

- ArkTS 编译及签名通过：`panel-glass-build.log`。
- API26 模拟器：主页加号菜单、聊天记录大面板、底部工具菜单均打开并截图，展开后可见背后的模糊轮廓。
- 验证深色下的聊天记录大面板，保留原主题文字和前景卡片，没有额外增浓整块面板。
- 聊天菜单连续开合三次可正常关闭，再打开其他面板也正常。未做真机帧率或高速反向打断验收。
- 经设置界面关闭模糊，兼容实色菜单正常打开；随后恢复原有护眼纸张 / 跟随系统 / 模糊强度 60。没有修改或删除聊天内容，没有请求在线生成。
- 截图：`build/panel-glass-home-menu.jpeg`、`build/panel-glass-conversations.jpeg`、`build/panel-glass-tools.jpeg`、`build/panel-glass-dark.jpeg`、`build/panel-glass-off.jpeg`。
- 未验证物理手机和 API22 设备的最终效果。编译与模拟器通过不代表真机体验验收。

## 安装包

- 手机：`dist/HarmonyTavern-panel-glass-arm64-20261101-signed.hap`。
- 模拟器：`dist/HarmonyTavern-panel-glass-simulator-20261101-signed.hap`，对应版本已安装。
- 两包附同名 `.sha256`，均校验通过；手机打包后 x86_64 源库已恢复。
- 手机包日志：`panel-glass-arm64-package.log`。

这是 `HISTORY-GLASS-20261101.md` 的材质增补；保留前一版本的聊天记录选择与其它功能。
