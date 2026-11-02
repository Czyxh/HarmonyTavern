# HarmonyTavern · 故事入杯

以项目已有的角色对话、故事共创、世界书功能为设计依据。采用手工编写的 SVG 路径，不使用 AI 生图、外部素材或字体图标。

杯柄与麦金杯沿表达酒馆；杯身左下的气泡尾角表达聊天；杯中负形书页表达故事与世界设定。沿用项目纸色主题的苔绿 `#465C37`、纸白 `#F5EDDC`，增加麦金 `#D9B879` 作为杯沿点缀。图标本体不带文字。

- `icon.svg`：1024 × 1024 可编辑矢量母版，背景满铺，无预制圆角。
- `icon-1024.png`：完整方形 PNG；另有 512、256、128、96、64、48、32 像素导出。
- `icon-rounded.png`：透明外角的圆角展示图，不用于替代系统图标蒙版。
- `foreground.svg` / `foreground.png`：透明前景，书页为透明负形。
- `background.svg` / `background.png`：纯色背景，可供后续分层图标适配。
- `monochrome.svg`：单色标志。
- `preview.png` / `preview.svg`：设计说明、圆角/圆形/深色预览和实际小尺寸对照。

本次仅交付图标设计文件，未替换应用现有资源。圆形与圆角为设计预览，分层资源接入设备前仍需检查系统缩放和裁切。

重新导出：在项目根目录安装渲染依赖并运行：

```powershell
npm install --prefix build/icon-render --no-save --package-lock=false @resvg/resvg-js
node opendesign/mockups/app-icon/render.cjs
```
