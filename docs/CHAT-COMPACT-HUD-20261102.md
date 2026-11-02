# 聊天菜单清理与透明紧凑状态条（2026-11-02）

后续用户已提供明确参考图，最新上下玻璃层次实现及安装包见 [CHAT-REFERENCE-GLASS-20261102.md](CHAT-REFERENCE-GLASS-20261102.md)，替代本文此前边缘方案；菜单/HUD 等非边缘改动继续保留。


## 最新澄清：上下透明渐变磨砂玻璃

用户进一步明确：需要的不是单纯透明度淡出，而是两端透明的渐变磨砂玻璃。消息 List 现使用 `linearGradientBlur`（API12 起支持），仅取既有 GLASS_HEADER 的模糊半径，不使用其 tint/color。对称 fractionStops 让顶/底两端模糊最强，中间完全清晰；每端约 48vp，短视口最多占 20%，随实际列表高度调整。没有实色背景板、染色层、饱和度调整或折射，原紧凑 HUD/图标/菜单保留。

已移除上轮纯 alpha 的 `fadingEdge`：模拟器上将它与 List 的渐变模糊叠加会导致整个消息层不显示，现仅保留渐变模糊并人工检查正文确实可见、上下磨砂、中间清晰。24 组客户端回归、双架构/手机签名构建通过。最终截图 `build/gradient-frost-chat.jpeg` 已展示给用户；没有模型调用或聊天修改，真机/API22运行未验收。

最新手机包 `dist/HarmonyTavern-gradient-frost-arm64-20261102-signed.hap`，模拟器同前缀 simulator 包；同名 SHA256 校验通过，x86_64 库已恢复。对应日志 `gradient-frost-arkts-build.log`、`gradient-frost-phone-package.log`、`gradient-frost-*-tests.log`。下文为早一轮改动记录，“移除遮罩”不表示现在移除上下透明磨砂。


## 改动

- 右上角聊天选项菜单移除原始 statusText（会话路径/文件名/消息数等灰色字符）。宽高根据实际八项操作计算并继续使用内容测量，不再给无用状态行预留高度或让长文件名撑宽菜单。
- ChatPage 不再套 PageSurface，改为直接布局正文和透明顶栏，彻底绕开该组件的渐变/线性模糊遮罩路径。正文顶端与 72vp 顶栏之间只留 4vp 间距，世界模式正文底部额外留白由 16vp 减至 4vp。
- WorldStatusHud 压成单行 48vp，没有整块背景、边框、人物标题、血量标签或文字操作按钮。不覆盖正文；由布局为自身保留一行空间。
- 只从 health 指标读取血量，显示固定红色 `#D64545` 的血条和四舍五入百分比，不拿灵力/体力等其他资源冒充血量。未知、无有效最大值、非法数据和未就绪显示“—”；真实 0 仍显示 0%。
- 背包和状态改为透明图标按钮，视觉 22/20vp，触摸区域维持 48vp；保留明确无障碍名称及独立详情入口。
- 状态名称以小号文字横排滚动，移除多余前缀、独立色块和第二行“状态未确认”占位。
- 保留既有真实状态校验、手动生成、背包详情和展开面板内容限高，不改原生协议或聊天存档。

## 验证

- `compact-hud-arkts-build.log`、`compact-hud-phone-package.log`：双架构及 arm64 签名构建通过。
- `compact-hud-*-tests.log`：客户端共 24 组通过（新增 3、面板高度 2、此前主题/状态/上下文/用量 19）。
- `compact-hud-ui-tests.log`：4 项模拟器流程通过。
  - 实际聊天 HUD 为透明单行，未知血量显示“—”，两个按钮为图标且透明。
  - 右上角菜单恰好八项，无会话路径灰字；实测尾部仅 28px 正常内边距。
  - 背包和状态图标分别打开对应详情面板。
  - 明确标记、不保存的离线演示中 45/80 显示红条和 56%，状态、图标排列正常。
- 截图：`build/compact-hud-chat.jpeg`、`build/compact-hud-menu.jpeg`、`build/compact-hud-red-preview.jpeg`。最后一张仅为布局演示，不是当前聊天真实血量。
- 无在线模型调用、聊天写入/删除或设置恢复；结束时放弃未保存创建草稿、返回主页。
- 真机、API22、极端字体、深色端到端及键盘组合仍未验收。Rust 未改，未重跑原生全套；历史群聊用例限制不变。

## 安装包

- `dist/HarmonyTavern-compact-hud-arm64-20261102-signed.hap`：39,929,375 字节。
- `dist/HarmonyTavern-compact-hud-simulator-20261102-signed.hap`：69,382,245 字节。
- 同名 SHA256 均校验通过，`entry/libs/x86_64` 已恢复；旧安装包与备份保留。
