# RPG 聊天气泡与玻璃材质修正

## 最新用户约束

主题应接近 `opendesign/mockups/rpg-themes` 的视觉示例，但原有透明度、磨砂强度、系统玻璃和光感设置必须保留。聊天页也遵循这个要求。展开的阅读面板继续保持清晰，不增加内容模糊。

## 实现

- RPG 消息采用头像/名字、内层气泡、外层会话卡的层次。保留编辑、更多操作、思考过程和真实用量显示。普通主题沿用原有消息构建器。
- 发送按钮恢复图标，输入框清除自带底边框。删除聊天顶部的大幅主题横幅，改为小型主题标记。
- 绯樱使用圆头像和朱印；像素使用方头像、硬边框和偏移阴影；地牢使用切角头像和顶部强调边；手札使用纸色卡片。全局内容卡复用主题样式。
- 撤销先前 RPG 主题专属的不透明输入栏。所有主题均按原有设备能力、磨砂设置使用 SystemMaterialTray 或 glassEffect。加号工具按钮恢复相同的原生玻璃/兼容磨砂路径。
- 撤销聊天标题区的实色背景，恢复原有顶部渐变模糊。RPG 玻璃 tint alpha 与其他生成主题保持一致，不改动用户保存的 lightSenseBlur 和 immersiveLevel。
- 工具侧栏、展开面板和后端业务逻辑未改动。

## 验证与边界

- ArkTS 构建及签名通过，分别生成模拟器双 ABI 包和 arm64 包。
- rpg-themes-client-tests：四主题 × 深浅色、颜色对比度、素材一致性、玻璃 alpha 一致性和切换保留光感设置通过。
- creative-inventory-client-tests、world-journal-interaction-tests、panel-sizing-client-tests、chat-usage-client-tests 通过。
- 在指定模拟器安装并检查手札、绯樱聊天页面及输入栏。修正后手札截图 `build/rpg-chat-surface-glass.jpeg` 中存在 system-material-composer 节点，确认实际走系统材质输入栏。
- 模拟器全四主题交互检查未完成：自动导航中断，不应将其报告为全主题视觉验收。没有向模型发送请求，没有安装到实体手机。
- 布局参考原示例，字体保留应用可读字号和系统字体，因此不是网页的逐像素复刻。

## 交付

- `dist/HarmonyTavern-rpg-chat-glass-simulator-20261102-signed.hap`
- `dist/HarmonyTavern-rpg-chat-glass-arm64-20261102-signed.hap`
- 打包脚本 `build/package-rpg-chat-surface.ps1`；校验值在同名 `.sha256` 文件。
- 修改前主要 UI 文件在 `build/backups/rpg-chat-parity-20261102/`。
