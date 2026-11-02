# 创造模式布局与纯磨砂 UI（2026-11-01）

本轮覆盖 WORLD-STATE-MODE、PANEL-GLASS 等历史文档的界面描述；世界状态原生协议和已有存档不迁移、不改名。

## 界面调整

- 用户可见“世界状态模式”改为“创造模式”，内部 `mode: world`、命令名和状态元数据保持兼容。
- 聊天输入栏上方：左侧人物与血量/主指标；右侧独立“背包”“状态”按钮，状态效果横排滚动。优先显示已有 health 指标，没有时按世界定义的指标显示，不虚构血量。
- 背包打开独立“背包物品栏”面板，只显示物品部分；状态入口保留指标、状态效果、位置和说明。未确认的数值、位置和物品数量继续明确标注。
- PageSurface 默认关闭正文边缘渐变模糊和顶部渐变覆盖，聊天列表以布局间距避开顶栏，不再靠正文渐变遮罩处理重叠。顶栏按钮、导航与主题入口保留。
- OriginPanel 使用普通背景磨砂和主题边框；保留来源展开/反向关闭几何动画，但不再使用折射材质、液态镜片或独立变形描边。模糊关闭时仍使用可读主题底色。
- 普通玻璃与展开磨砂的 saturation/brightness 都为 1，磨砂保持 ALWAYS_ACTIVE。SystemGlass 共用入口显式关闭原生折射材质，导航和加号走统一普通磨砂路径。
- 柔雾绿、暖米色、静雾蓝、月白的前景、玻璃、按钮等二级色从对应主题派生，不再沿用默认粉色。纸张、玫瑰、自定义入口保留。
- 主题派生使用与 base/dark 资源一致的明确色值，避免冷启动 UI 资源上下文尚未就绪时将背景解析为黑色，进而生成错误的浅字/黑玻璃。客户端回归直接与资源文件校验文字对比度（至少 7:1）。
- 导航离散模式与材质切换放在零时长事务，320ms 过渡仅动画 chatReveal；导航宽度由 reveal 插值，避免新控件默认底色参与模式隐式动画。
- 工具页“恢复这份”改用 OriginPanel + ChatPanel 应用内确认面板，显示快照名称、备份说明、确认/取消。忙碌期间禁止关闭和重复确认；失败留在面板显示错误，成功后关闭。原生恢复语义不变。

## 验证

- ArkTS 双架构、arm64-only 签名构建通过：`creator-frost-arkts-build.log`、`creator-frost-phone-package.log`。
- 客户端共 19 组通过：本轮 5 组，世界状态 7 组，上下文/列表 4 组，用量 3 组。日志 `creator-final-*-tests.log`。
- 模拟器 UI：柔雾绿下消息菜单、三次主页/聊天切换采样、应用内快照确认与取消、创造模式名称、左血量/右状态、独立背包入口及关闭返回均通过。见 `creator-frost-ui-tests.log`、`creator-inventory-ui-tests.log`。
- 测试恢复了原纸张主题；布局演示未保存，没有创建/删除聊天、没有点击模型生成。保留测试中创建的设置安全快照，没有实际恢复设置。
- 最终会话采样日志 `build/creator-final-runtime.log` 未发现 TypeError/ReferenceError/JsCrash/FATAL。较早调试日志含中间版本确认框的 DSL 回调错误；已拆为独立 @Builder 并通过真实打开/关闭验证，不能将早期日志当成最终包日志。
- 本轮未更改 Rust、未重新运行原生全套，沿用前轮已验证原生库；前轮群聊整套路径用例失败的限制仍然适用。
- 切换截图不是逐帧视频证明；真机、API22、深色模式端到端、极端字体和键盘场景仍需后续验收。未调用在线模型，不声称验证了实时状态生成质量。

## 截图

- `build/creator-sage-message-menu.jpeg`：柔雾绿消息菜单。
- `build/creator-themed-snapshot-confirm.jpeg`：应用内快照确认。
- `build/creator-horizontal-hud-preview.jpeg`：明确标记的离线布局示例，非真实人物数据。
- `build/creator-independent-inventory.jpeg`：实际聊天独立背包面板，未知状态保持未知。

截图和独立背包检查均来自最终安装的双架构包；检查后冷启动返回主页，未保存布局演示草稿。

## 安装包与回退

- 手机：`dist/HarmonyTavern-creator-frost-arm64-20261101-signed.hap`，39,914,693 字节。
- 模拟器：`dist/HarmonyTavern-creator-frost-simulator-20261101-signed.hap`，69,363,470 字节，含 arm64-v8a/x86_64。
- 同名 `.sha256` 校验通过；打手机包临时移出的 `entry/libs/x86_64` 已恢复。
- 之前的世界状态原型、生成设置安装包及 `backups/HarmonyTavern-before-world-state-20261101-202950.zip` 保留。该归档不含设备沙箱聊天数据。
