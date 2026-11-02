# 故事入杯 · 微立体版

沿用原版的酒杯、对话气泡与负形书页造型。增加左上方柔光、陶瓷色渐变、9px 薄侧边、接触阴影与麦金杯沿高光，保持正面视角和小尺寸辨识度。使用 SVG 路径、渐变和滤镜制作，未使用 AI 生图。

- `icon.svg` / `icon.png`：1024px 满铺方形母版。
- `icon-rounded.svg` / `icon-rounded.png`：圆角展示版。
- `foreground.svg` / `foreground.png`：含阴影的透明前景。
- `background.svg` / `background.png`：渐变背景。
- `icon-{size}.png`：512、256、128、96、64、48、32px。
- `preview.svg` / `preview.png`：前后对比和尺寸预览。

PNG 可直接放入 Photoshop 继续编辑；SVG 保留可编辑路径、渐变与滤镜。未生成 PSD 文件，未替换项目现有应用图标。

重新导出：在项目根目录运行 `node opendesign/mockups/app-icon/render-depth.cjs`，依赖与上一版共用。
