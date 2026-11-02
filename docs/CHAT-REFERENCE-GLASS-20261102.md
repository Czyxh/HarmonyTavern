# 参考图：浮动顶栏与输入区后的透明渐变磨砂（2026-11-02）

后续最新调整见 [SHARED-HEADER-HUD-20261102.md](SHARED-HEADER-HUD-20261102.md)：恢复共享顶栏磨砂；HUD 下移 10vp，磨砂最低限度覆盖 HUD 本身且只渐至 22% 半径。本文“HUD 不模糊”为前一轮要求，已由该最新调整替代，保留作迭代记录。


## 本轮目标与修正

用户提供参考图，要求聊天内容滚到顶栏/输入区后方时呈现渐变磨砂玻璃，而不是将限制在两者之间的消息视口两端模糊或淡出。此版本替代此前 compact-hud / transparent-fades / gradient-frost 的聊天边缘方案。

后续最新微调：血条/状态行背景不再模糊；底部磨砂只从状态行下缘往输入区方向开始，过渡 16vp。顶部强磨砂范围由 topInset+72 收至 topInset+56，过渡由 40vp 缩至 20vp，topInset+76 处即完全清晰；初始消息起点相应从 topInset+120 提前至 topInset+84。正文底部阅读留白恢复为 bottomInset+56（world）/bottomInset+8（free），减少空白，不新增底板。

- ChatPage 正文从 Column 的剩余高度改为全屏 Stack 内的 List；顶栏及血条/状态/输入区保持前景清晰。
- List 不再留顶栏外部 margin，也不再在底部用 padding 缩小绘制视口。使用 API11 起支持的 contentStartOffset/contentEndOffset 为开头及最后一条消息预留可读空间，滚动过程中消息仍能经过浮动控件后面。
- linearGradientBlur 仅应用于作为背景的完整消息层：顶部在浮动顶栏后方磨砂，用 20vp 平滑过渡到清晰正文；底部以实际 bottomInset 为清晰边界，不覆盖它上方 48vp HUD，仅在下方输入区以 16vp 过渡至磨砂。区域随列表实际高度变化，短视口保留中间清晰区。
- 只使用 GLASS_HEADER 的半径，保留模糊偏好。没有新加实色板、染色、饱和度/亮度修改或折射；标题、按钮、血条和图标本身不参与消息层模糊。
- 末条消息的结束位置在磨砂过渡区上方，避免静止阅读时末段文字被玻璃遮住。
- 血条/HUD 包装层 hitTestBehavior Transparent，保留自身按钮点击并让空白处滚动透传。错误提示保留，并单独预留空间。

## 验证

- 最新验证日志前缀为 `compact-glass-`：24 组客户端回归、原 4 项 UI 流程以及 2 项布局/键盘流程通过。冷启动脚本原先固定等 900ms 偶发未加载列表，已改为等待目标节点；最终复跑通过。一次组合命令 60 秒超时中断键盘检查，已单独重跑通过。下面 `reference-glass-` 为参考图初版的同类检查记录。
- `reference-glass-*-tests.log`：24 组客户端回归通过，涵盖菜单/HUD、不同高度及 free/world 模式磨砂区域、最后消息留白、既有面板/主题/状态/上下文/用量。
- `reference-glass-ui-tests.log`：原有 4 项菜单、透明 HUD、独立背包/状态和离线布局演示流程通过。
- `reference-glass-layout-ui-tests.log`：2 项新增实际模拟器流程通过，确认 List 视口跨越顶栏/底部 HUD；键盘可弹出/关闭，未输入/发送，HUD 入口保留。
- 最新截图：`build/compact-glass-rest.jpeg`、`build/compact-glass-chat.jpeg`、`build/compact-glass-keyboard.jpeg`。`compact-glass-arkts-build.log`、`compact-glass-phone-package.log` 为最新构建日志。
- 人工看图确认静止时末条消息完整清晰，滚动时正文从清晰控件后方通过并磨砂，键盘弹出后也有对应玻璃效果。截图 `build/reference-glass-rest.jpeg`、`build/reference-glass-chat.jpeg`、`build/reference-glass-keyboard.jpeg`。
- `reference-glass-arkts-build.log`、`reference-glass-phone-package.log`：双架构及 arm64 构建通过；最终模拟器包已安装。
- 没有模型调用、聊天写入/删除或设置恢复。真机、API22实际运行、深色/大字体/横屏全套仍未验收；Rust 未改。

## 实验记录

曾尝试独立 backgroundEffect + DST_IN 离屏渐变覆盖层，但模拟器下未正确采样下面的正文，出现背景文字仍清晰。已完整移除临时 ChatEdgeGlass 组件，最终直接对浮动控件背后的消息合成层渐变模糊，不使用有问题的离屏覆盖层，也不叠加会冲突的 fadingEdge。

## 最终包

- `dist/HarmonyTavern-compact-glass-arm64-20261102-signed.hap`
- `dist/HarmonyTavern-compact-glass-simulator-20261102-signed.hap`
- 同名 SHA256 校验通过；`entry/libs/x86_64` 已恢复。此前包和备份保留。
