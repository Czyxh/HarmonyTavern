# 恢复共享顶栏磨砂与贴近输入区的 HUD（2026-11-02）

## 当前最终：仅保留由上至下变清晰的顶部磨砂

用户已明确取消底部磨砂，替代下方所有血条背景磨砂方案。ChatPage.chatEdgeStops 现在只有四个停止点：顶部 1、topInset+32 为 0.65、topInset+76 为 0、底端仍为 0；短视口有归一化上限。PageSurface.fadeStops 同步采用单调递减的 1→0.65→0→0，不再有顶部恒定强度平台。底部从正文至血条后方均无额外渐变模糊，血条/输入区位置、既有控件自身玻璃样式及其他功能不动，不加实色板。

24 组客户端回归通过，增加全停止点模糊强度单调不增及底端为 0 的断言。双架构及手机构建通过，日志前缀 `top-only-`；模拟器检查原有正文经过血条后方保持清晰，截图 `build/top-only-chat.jpeg`。最终包 `dist/HarmonyTavern-top-only-arm64-20261102-signed.hap` 和同前缀 simulator 包，SHA256 校验通过，x86_64 已恢复。未调用模型或写聊天，真机未验收。以下为已被替代的历史迭代记录。


## 最终修正：血条后方必须有可见磨砂

用户反馈上一版实际仍看不出覆盖血条。根因：从血条上方 4vp 才开始过渡、到 HUD 下缘也只有 22% 半径，血条中心附近实际仅约 5% 半径，视觉上几乎无效。现保持 HUD 位置及清晰边界 inset+31 不变，但在 inset+27（血条上沿）已达到完整半径；即仅在血条上方 4vp 渐变，整个血条笔画背后均为正常磨砂。移除 world 模式 0.22 弱停止点，free 模式/共享顶栏/无底板不变。

24 组客户端回归和双架构/手机构建通过，新增断言血条上沿/中线/下沿全部落在完整磨砂区。模拟器将原有正文滚到血条后方，人工确认后方字迹明显模糊，前景血条/图标清晰；实图 `build/health-frost-underlay.jpeg` 已展示给用户，没有模型或聊天写入。日志前缀 `health-frost-`。最新手机包 `dist/HarmonyTavern-health-frost-arm64-20261102-signed.hap`、同前缀 simulator 包，SHA256 校验通过，x86_64 已恢复，真机未验收。以下弱磨砂说明为已被本修正替代的历史记录。


## 最后微调：以血条笔画为边界

用户进一步明确血条需要再贴近输入框、磨砂仅到血条上方一点。chatHudInset 改为 bottomInset-12（比本页下述初版再下移 2vp），与输入框外沿约 2vp；bottomClear 从 inset+48 改成 inset+31，按 48vp 行中垂直居中的 6vp 血条，其上边缘为 inset+27，因此磨砂上沿仅在血条上方约 4vp，较上一版减少约 19vp 的向上覆盖。0–22% 弱磨砂和输入区 16vp 过渡保留，其他页面顶栏不改。

24 组客户端回归及两架构/手机构建通过，日志前缀 `blood-edge-`。模拟器实际测得 HUD 至 TextArea 内框 8.6vp（含内部留白），血条上沿距 HUD 下沿 26.9vp，独立背包按钮点击通过；截图 `build/blood-edge-chat.jpeg`。最新包 `dist/HarmonyTavern-blood-edge-arm64-20261102-signed.hap` 及同前缀 simulator 包，SHA256 校验通过，x86_64 库已恢复。无模型/聊天写入，真机未验收。下方为共享顶栏恢复的前一轮记录。


## 最新行为

- `PageSurface.edgeFades` 此前默认 false，导致采用共享 PageSurface 的其他页面顶栏磨砂一起消失。恢复默认 true，统一使用 topInset+56 至 topInset+76 的 20vp 短渐变；仍尊重模糊强度设置。
- 移除共享顶栏单独的 palette 渐变染色叠层，仅对后方内容模糊，不加回实色板；标题和按钮保持清晰。作用于共享组件调用处，不声称所有自定义页已经逐一验收。
- ChatPage 的 HUD 下边距改为 bottomInset-10，使其向输入框靠近 10vp。按浮动输入区几何，外沿间距约 4vp；模拟器测得 HUD 到 TextArea 内框间距 10.6vp（包含输入框内部留白）。
- 底部磨砂清晰边界刚好从 48vp HUD 顶边开始，不向正文扩展：在 HUD 范围只从 0 渐至完整半径的 22%，其下方输入区再用 16vp 过渡到完整磨砂。前景血条/图标不模糊，无 HUD 底板，不增加第二行。
- 末条消息的阅读留白同步下移，聊天顶部继续维持 20vp 短渐变。free 模式保持不带 HUD 的边界。

## 验证

- `shared-glass-*-tests.log`：24 组客户端回归通过，包含共享开关/无染色板、HUD 下移、弱磨砂各停止点与阅读留白。
- `shared-glass-ui-tests.log`：原有 4 项 HUD、菜单、独立背包/状态和不保存离线演示流程通过。
- `shared-glass-header-ui-tests.log`：3 项通过；HUD 实测间距，工具与个性化页面入口、滚动和清晰顶栏。人工确认个性化页面滚动到顶栏后呈现磨砂；工具内容不够长，空白背景无纹理时不应伪造可见模糊。
- `shared-glass-layout-ui-retry.log`：2 项布局/键盘流程通过。首次复用焦点状态时未检测到 KeyHideKbd，冷重启后完整复跑通过；不归因于已证实的产品问题。
- 截图 `build/shared-glass-chat.jpeg`、`build/shared-glass-appearance.jpeg`、`build/shared-glass-tools.jpeg`；前两张已展示给用户。
- 双架构及手机签名构建通过，日志 `shared-glass-arkts-build.log`、`shared-glass-phone-package.log`。无模型调用、聊天改动或设置恢复；真机/API22/全页面逐一运行仍未验收。

## 最终包

- `dist/HarmonyTavern-shared-glass-arm64-20261102-signed.hap`
- `dist/HarmonyTavern-shared-glass-simulator-20261102-signed.hap`
- 同名 SHA256 均校验通过，x86_64 库已恢复，旧包保留。
