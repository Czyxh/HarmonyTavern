# 赞助开发者

沿用 HarmonyTavern 现有纸色、苔绿与运行时主题，使用杯子标记、支付方式切换、白底二维码与感谢文案。页面外层随浅色、深色和自定义主题变化，二维码区域始终保留白底。赞助自愿，不设金额档位。

原图只提取二维码及至少四个模块宽的静区，保留原有中心头像，不重绘、不重新编码二维码。两个独立的收款卡片带有应用标记、支付方式和感谢文案，可在页面中通过系统文件保存选择器导出。

- `alipay-card.png` / `wechat-card.png`：可分享的感谢收款卡片。
- 对应 `.svg`：卡片设计源文件。
- `qr-validation.json`：裁剪坐标、静区和原二维码内容的 SHA-256 摘要，不写入收款链接明文。
- 应用二维码：`entry/src/main/resources/base/media/sponsor_{alipay,wechat}_qr.png`。
- 应用保存用卡片：`entry/src/main/resources/rawfile/sponsor/{alipay,wechat}_card.png`。

重新生成：

```powershell
npm install --prefix build/sponsor-tools --no-save --package-lock=false sharp jsqr
node scripts/prepare-sponsor-assets.cjs <支付宝原图路径> <微信原图路径>
```

SVG 渲染依赖与图标设计共用 `build/icon-render/node_modules/@resvg/resvg-js`。脚本逐一解码原图、裁剪图、完整卡片、360px 卡片和 240px 二维码，确认所有结果内容一致后才完成导出；不访问支付链接，不发起付款。
