# 故事入杯 · 斜侧杯

移除原来的对话气泡尖角，将正面图形改为略微俯视的圆柱陶瓷杯。露出椭圆杯口、杯内麦金色酒液、斜侧杯柄及圆弧杯底，杯身轻微倾斜。保留苔绿底、纸白杯身和绿色书页标记，延续角色故事与世界书的产品含义。

最初的陶瓷版使用 SVG 路径、渐变和柔和阴影，不使用 AI 生图。当前应用已改用硬朗黑线版：放大斜侧杯子，以粗黑轮廓、黑色杯口和几何书页构图，去除渐变与阴影。AppScope 与 entry 的分层图标使用透明前景和 `#FFFFFF` 背景，启动图标也已同步。

- `icon.svg` / `icon.png`：1024px 满铺方形母版。
- `icon-rounded.svg` / `icon-rounded.png`：圆角展示版。
- `foreground.svg` / `foreground.png`：透明前景及阴影。
- `background.svg` / `background.png`：背景。
- `icon-{size}.png`：512、256、128、96、64、48、32px。
- `preview.svg` / `preview.png`：与上一版的对比。
- `icon-white.svg` / `icon-white.png`：应用正在使用的纯白底合成图。
- `foreground-line.svg`：当前硬朗黑线版的可编辑矢量前景，杯子放大至原设计的 1.4 倍。
- `icon-line-transparent.png`：当前黑线版透明背景导出。
- `background-white.svg` / `background-white.png`：应用使用的纯白背景。

重新导出：在项目根目录运行 `node opendesign/mockups/app-icon/render-cup.cjs`，渲染依赖与前两版共用。

更新应用资源及纯白版导出：运行 `node scripts/update-app-icon.cjs`。原始图标备份位于 `backups/app-icon-before-white-cup/`，重复运行不会覆盖备份。应用图标仍通过现有 `layered_image.json` 引用，无需改变清单配置。
