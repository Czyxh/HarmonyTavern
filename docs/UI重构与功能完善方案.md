# HarmonyTavern UI 重构与功能完善方案（P8）

> 依据 `harmonyos-design` skill（设计模式）。来源等级：H1=华为官方 / H2=OpenHarmony 官方 / H3=系统应用观察 / H4=项目建议（House Style）。
> 目标：把当前"验证用调试页"重构为可交付的角色扮演客户端，并把已移植的 263 条命令逐一接到界面上。

---

## 1. 上下文卡

```yaml
目标设备: 手机（主）、平板/折叠屏（未验证）
窗口形态: 全屏竖屏；未适配分屏/自由窗口
主要输入: 触摸；无键盘/鼠标/手写笔路径
API_Level: 22（HarmonyOS NEXT，模拟器与真机同）
主题与字号: 当前仅深色硬编码；无跟随系统、无大字号适配
无障碍状态: 无 accessibilityText；无焦点顺序；颜色为主要信号（部分有文字双信号）
任务入口: 首页（Index）→ 聊天 / 设置 / 扩展
任务模式: 单会话深入（读消息→输入→生成→复制/重试）
平台版本档案: ArkUI Navigation/List/LazyForEach/SymbolGlyph（API 12+ 稳定）
项目人格: 沉浸、暗色、信息密度中等、长会话可读优先
可用证据: 源码 4 页（Index/ChatPage/SettingsPage/ExtensionPage）+ 模拟器实机行为
假设: 不做 PC/车机；平板仅要求不破版（拉伸/分栏转换可后置）
```

---

## 2. 原则分层

### Evergreen Foundation（不随视觉趋势变）

| 原则 | 本项目落点 |
| --- | --- |
| 反馈即时 | 按压态、发送按钮即时禁用、生成中状态可见 |
| 状态真实 | 不在流未成功时显示"完成"；错误必须上屏（本轮已修的三处同源缺陷） |
| 因果连续 | 新建会话 → 直接进入该会话；返回保留列表位置 |
| 层级清晰 | 会话/角色/设置三类任务互不混排 |
| 可读性 | 消息正文 14vp、行高 1.5、长文本可滚动不截断 |
| 无障碍 | 图标按钮有语义；颜色不作唯一信号 |

### Versioned Platform Layer（当前 HarmonyOS/ArkUI）

- 导航：`Navigation` + `NavPathStack` + `NavDestination`（已用，保留）
- 列表：`List` + `LazyForEach`（消息区改此，替代 `Scroll{Column{ForEach}}`）
- 图标：`SymbolGlyph`（系统符号，H3 观察系统应用）
- 动效：`animateTo` + `curves`（不自定义物理曲线除非手势跟手）
- 主题：`@StorageProp('themeMode')` + 系统 `ColorMode`（跟随系统）

### Project Overlay（House Style，非官方）

- 暗色优先、低饱和背景、消息气泡右对齐用户/左对齐角色
- 密度：列表行高 56vp、卡片间距 12vp

---

## 3. 目标信息架构

```
首页（Navigation 根）
├── 底部 Tab：聊天 / 角色 / 更多
│
├── 聊天  ── 会话列表（get_all_chats）→ 会话页
├── 角色  ── 角色网格（get_all_characters）→ 角色详情/编辑
└── 更多  ── 设置（密钥/模型/预设/提示词/连接）
            扩展（ExtensionPage 重构）
            Agent（34 条命令）
            MCP（16 条）
            Skills（13 条）
            备份（data archive 6 条）
            同步（lan_sync 17 + tt_sync 5 + sync_automation 3）
            诊断（P6.2 probe / hilog 导出）
```

**导航规则**（H2）：同层 Tab 切换不压栈；进入详情 `pushPathByName`；返回 `pop`；离开会话页前关闭流式会话。

---

## 4. 设计 Token（`ets/theme/Tokens.ets`）

```text
颜色（Light / Dark 两套）
  bg.base / bg.surface / bg.surfaceHigh / bg.overlay
  border.subtle / border.strong
  text.primary / text.secondary / text.tertiary / text.inverse
  accent.base / accent.pressed / accent.container
  danger.base / danger.container / success.base / warning.base

字号
  display 28 / title 20 / subtitle 16 / body 14 / caption 12 / micro 10

间距 4 / 8 / 12 / 16 / 24 / 32
圆角 4 / 8 / 12 / 16 / 999（胶囊）
行高 1.5（正文）
触摸目标 ≥ 40vp（H2 参考）

动效
  duration.instant 100 / short 150 / local 200 / full 300
  curve.standard（LinearOutSlowIn）/ decelerate / accelerate
  仅手势跟手用弹簧曲线
```

---

## 5. 组件库（`ets/components/`）

| 组件 | 职责 | 状态覆盖 |
| --- | --- | --- |
| `PageShell` | 标题栏 + 返回 + 内容区 + 安全区 | 有/无返回、标题左对齐 |
| `SectionCard` | 分组卡片（标题 + 内容） | 正常 |
| `ListRow` | 列表行（主文本 + 次文本 + 右槽） | 正常/按压/禁用 |
| `PrimaryButton` | 主操作 | 正常/按压/禁用/加载中 |
| `DangerButton` | 破坏性操作 | 正常/按压/禁用 |
| `ErrorBanner` | 错误上屏（带图标 + 文本，颜色以外的第二信号） | 显示/隐藏（transition） |
| `EmptyState` | 空列表引导（图标 + 说明 + 主操作） | — |
| `Chip` | 角色/标签选择 | 正常/选中/禁用 |
| `MessageBubble` | 消息（角色名 + 正文 + 时间） | 用户/角色/系统 |

---

## 6. 页面清单与分期

| 阶段 | 内容 | 验收 |
| --- | --- | --- |
| **P8-1（本轮）** | Design Token + 组件库 + 首页重构（Tab + 概览 + 诊断折叠） | 构建通过 + 模拟器三 Tab 可切换 + 返回正确 |
| P8-2 | 会话页重构：`List`+`LazyForEach` 虚拟化、消息气泡、输入栏、流式状态、自动滚动、重试/停止/摘要/图片 | 1000 条消息滚动无长帧；流式追加 60fps |
| P8-3 | 角色页：网格 + 新建/编辑/删除/重命名 + 导入（`create_character`~`import_character`） | 命令全链路 |
| P8-4 | 设置页重构：分组（密钥/模型/预设/提示词/连接）+ 跟随系统主题 | 深浅色切换正常 |
| P8-5 | 扩展页重构 + Agent 页 + MCP 页 + Skills 页 | 各域命令可操作 |
| P8-6 | 备份页 + 同步页 + 通知 + 诊断页 | — |
| P8-7 | 无障碍（语义/焦点顺序）+ 大字号 + 深色验证 | 无障碍扫描通过 |

---

## 7. 功能矩阵（263 命令 → 页面归属）

| 命令域 | 条数 | 目标页面 | 现状 |
| --- | --- | --- | --- |
| chat（会话/消息/摘要/图片） | 53 | 聊天 Tab + 会话页 | 部分（列表/发送/停止/摘要/图片/重试） |
| character（增删改查/导入/导出） | 27 | 角色 Tab + 角色编辑 | 仅列表/新建会话 |
| agent + agent session | 43 | 更多→Agent | 无 |
| lan_sync | 17 | 更多→同步 | 仅配对弹窗 |
| MCP | 16 | 更多→MCP | 无 |
| Skills | 13 | 更多→Skills | 无 |
| presets | 9 | 设置→预设 | 部分（新增/删除/恢复） |
| secrets | 8 | 设置→密钥 | 已接 |
| extension | 8 | 扩展页 | 本轮已建页 |
| provider metadata + connections | 11 | 设置→模型/连接 | 部分（模型目录/测试连接） |
| data archive | 7 | 更多→备份 | 无 |
| chat completion | 6 | 会话页 | 已接 |
| extension store（5 可移植） | 5 | 扩展页 | 未接 |
| tt_sync + sync + sync_automation | 9 | 更多→同步 | 无 |
| 明确不移植（Webview 绑定） | 23 | — | 文档已记录 |

---

## 8. 验收矩阵（P8-1）

| 项 | 方法 | 结果 |
| --- | --- | --- |
| 构建 | `hvigorw assembleApp` | 待填 |
| 目标设备 | 模拟器 API 22 | 待填 |
| 主题 | 深色（当前唯一） | 待填 |
| 大字体 | 系统字号放大 1.3× | P8-7 |
| 快速连续 | Tab 连点、返回连点 | 待填 |
| 无障碍 | 图标按钮语义 | P8-7 |

---

## 9. 未解决风险

1. 平板/折叠屏未适配（`断点` 未接）。
2. 浅色主题 token 已定义但未在真机验证。
3. Agent/MCP/Skills 页面信息架构需结合原项目页面进一步确认（原项目为 Web 界面，鸿蒙侧需重新组织）。
4. 扩展安装的 git 401 问题（真机待复测）。

---

## 10. P8-1 实施记录（2026-10-28 21:14）

**新增文件**

| 文件 | 作用 |
| --- | --- |
| `entry/src/main/ets/theme/Tokens.ets` | 颜色（浅/深两套）、字号、间距、圆角、触摸目标、动效时长 Token，全部标注来源等级 |
| `entry/src/main/ets/components/Builders.ets` | 全局 @Builder：SectionTitle / ErrorBanner / EmptyHint / KeyValueLine / SubtleDivider |
| `entry/src/main/ets/nav/RootNav.ets`（改） | 新增 `ChatIntent` 一次性意图（新建会话 → 直接打开） |
| `entry/src/main/ets/pages/Index.ets`（重写） | 三 Tab 首页：聊天 / 角色 / 更多；旧的 P4/P6.2/通知验收全部折叠进「更多 → 诊断」 |

**关键行为变化**

1. **自动初始化**：页面出现即跑 媒体抽取 → initialize → wait → 播撒默认内容，失败可点「重新初始化」重试（旧版必须手点 P6.2 按钮才有可用后端）。
2. **导航可解释**：底部三 Tab（系统 Tabs + 默认 tabBar，未自定义样式）；进入详情 `pushPathByName`；详情页「返回」`pop`。
3. **角色 → 新建会话 → 直接进入该会话**：`ChatIntent.request(characterName, fileName)` 由 ChatPage `aboutToAppear` 消费后立即清空。
4. **诊断能力零丢失**：P4 全链路、P6.2 十二点、通知测试、桥接/媒体/后端/内容/路径/图片渲染信息全部保留在折叠区。

**模拟器实证**（API 22）

- 冷启 → 自动初始化 → 更多页标题显示 `就绪 · v0.1.0`
- 三 Tab 均可切换：聊天（空态「还没有会话 / 到「角色」页选一个角色开始」）、角色（`1 个` + `Seraphina` + 新建会话）、更多（设置入口 / 扩展管理 / 刷新数据 / 重新初始化 / 诊断）
- 角色 → 新建会话 → 自动跳到聊天页并列出 `Seraphina / default_Seraphina - <时间>`
- 扩展管理入口 → 扩展页（`共 20 个扩展`）→ 返回首页

**踩坑记录（重要）**

1. **`hdc install -r` 同 versionCode 时可能不真正替换**：装完启动仍是旧 UI，`hdc uninstall` 后再装才生效。已把「卸载 → 安装 → 启动」固化为 `scripts\verify-device.ps1 -Mode install`，交付给别人装机时优先用它。
2. **App 版本号已升到 1.1.0 / versionCode 1000001**，便于区分 P8-1 前后。
3. ArkUI `Tabs` 默认 tabBar 的文字在 uitest dump 里可读；但**页面上有多个 TextInput 时**（如 provider 自定义模型名），按「第一个 TextInput」定位会点错框——自动化脚本必须按 placeholder 或相邻文本定位。

**未完成（进入 P8-2）**：会话页仍是 `Scroll{Column{ForEach}}`（未虚拟化）、消息未分气泡、输入栏未做 IME 避让、详情页取参仍是一次性意图而非 `NavDestination` 参数。

**验证矩阵填表**

| 项 | 方法 | 结果 |
| --- | --- | --- |
| 构建 | `hvigorw assembleApp` | ✅ 通过 |
| 目标设备 | 模拟器 API 22 | ✅ |
| 主题 | 深色（唯一） | ✅ 深色正常 |
| 大字体 | 系统放大 | 未验证（P8-7） |
| 快速连续 | Tab 连点 | ✅ 无异常 |
| 无障碍 | 图片有 accessibilityText，按钮为文本按钮 | 部分（P8-7 补齐） |
| 真机 | 待用户装 1.1.0 | 待验证 |
---

## 11. 液态玻璃材质与动效层（P8-1b，2026-10-28 21:31）

**用户要求**：UI 符合鸿蒙规范 + 好动效 + 多用液态玻璃。

### 11.1 来源与边界（必须写清楚）

| 项 | 归类 | 说明 |
| --- | --- | --- |
| `backgroundBlurStyle(BlurStyle.COMPONENT_*)` | **H2 平台 API** | ArkUI 官方材质接口，SDK 里 `BlurStyle` 枚举 NONE=0 … COMPONENT_ULTRA_THICK=12 |
| 液态玻璃作为全局视觉风格 | **H4 House Style** | 用户明确要求的品牌层；**不是**华为官方规范，skill 也提醒"禁止把所有产品统一成模糊玻璃" |
| 0.97 按下缩放 | **H4** | House Style，非官方数值 |
| 动效时长 100/150/200/300ms | **H2 公开参考** | OpenHarmony 公开动效参考值 |

### 11.2 使用约束（写进 `theme/Glass.ets` 注释，评审可核对）

1. 玻璃只用在**导航层与浮层**：底部 Tab 栏、页头、悬浮输入条、浮层卡片。
2. **不用在正文与长列表**：消息正文、会话列表行保持实色 —— 保对比度、保滚动性能。
3. 玻璃必须有 **tint**（半透明深底），避免纯模糊让文字对比度随背景漂移。
4. 每处玻璃都有 **1px hairline 描边**提供边界，层级不单靠阴影。
5. 单个界面 ≤3 处玻璃；滚动区内不放玻璃。

### 11.3 已落地的玻璃面

| 位置 | 材质 | 效果 |
| --- | --- | --- |
| 底部 Tab 栏（自绘） | `COMPONENT_THICK` + 62% tint + hairline + 轻投影 | 悬浮胶囊，内容从底部穿过时可见模糊 |
| 聊天页页头 | `COMPONENT_THIN` + 55% tint | 标题栏玻璃 |
| 聊天输入条 | `COMPONENT_THICK` + 70% tint + 24vp 胶囊 | 悬浮输入条 |
| 设置页 / 扩展页卡片 | `COMPONENT_REGULAR` + 52% tint + hairline | 浮层卡片 |

### 11.4 动效清单（每条都能回答"它反馈了什么"）

| 动效 | 作用 | 实现 | 曲线/时长 |
| --- | --- | --- | --- |
| Tab 选中胶囊 | 反馈"当前在哪一层" | 背景色 + 选中 1.0 / 未选中 0.94 缩放 | `curves.springMotion()`，300ms（可打断） |
| 卡片按下 | 立即反馈"系统听到了" | `stateStyles` 0.97 缩放 + 0.92 透明度 | 即时（按下态） |
| 列表项入场 | 说明"新内容出现" | `TransitionEffect.OPACITY + translate(y:8)` | 200ms `FastOutSlowIn` |
| 生成中脉冲点 | 反馈"任务仍在进行"（不是假成功） | 透明度 1↔0.25 循环 | 900ms `EaseInOut` Alternate |
| 诊断面板展开 | 说明层级展开 | `TransitionEffect.OPACITY` | 200ms |
| 页面进入/返回 | 说明父子层级 | Navigation 默认转场（未自定义） | 系统默认 |

**状态真实性**：脉冲点仅在 `streaming === true` 时显示，与后端流状态严格同源；停止/失败立即消失。没有任何"动画计时器伪装后端完成"。

### 11.5 验证情况（**重要：本次无法做视觉验收**）

- ✅ 构建：`BUILD SUCCESSFUL`（debug + release 双构建）
- ✅ 结构：模拟器 uitest dump 确认自绘 Tab 栏三胶囊项（◍ ☰ ⋯）存在、三 Tab 可切换、进入聊天页/设置页/扩展页、返回首页
- ✅ 功能回归：扩展页 `共 20 个扩展`；聊天页可进入并返回
- ⚠️ **视觉未验收**：当前模型无图像输入能力，`snapshot_display` 截图我无法查看。玻璃的观感（模糊强度、tint 浓度、hairline 明暗）需要**你在真机上看**再决定是否调整 `theme/Glass.ets` 里的四个档位。
- ⚠️ 性能未测：模糊是相对昂贵绘制，1 屏 ≤3 处玻璃是设计约束，仍需真机 SmartPerf 复核长帧。

### 11.6 可调参数（都集中在 `theme/Glass.ets`）

`tabBarBlur / headerBlur / cardBlur / floatingBlur`（材质档位）、`tabBarTint / headerTint / cardTint / inputTint`（着色浓度）、`edgeHairline / edgeHighlight`（描边）、`pressScale`（按压缩放）。
---

## 12. 液态玻璃（Apple 风格）落地与实测（P8-1c，2026-10-28 23:24）

**用户要求**：像苹果那种液态玻璃，很多小众鸿蒙软件也有。

### 12.1 配方（关键 API 换了）

从 `backgroundBlurStyle` 换成 `backgroundEffect`：

| 参数 | 作用 | 本工程取值 |
| --- | --- | --- |
| `radius` | 模糊半径 | Tab 栏 44 / 页头 32 / 输入条 40 / 卡片 30 |
| `saturation` | **背后颜色饱和度提升**（液态玻璃的关键，颜色才会"透出来"） | 2.0 / 1.7 / 1.8 / 1.6 |
| `brightness` | 亮度微调 | 1.04 / 1.02 / 1.03 / 1.01 |
| `color` | 着色（保证文字对比度） | 深色半透明 RGBA |

来源：`common.d.ts` `BackgroundEffectOptions { radius; saturation?; brightness?; color? }`（H2 官方 API）。

### 12.2 三个"之前缺的东西"（实测才发现的）

1. **玻璃背后必须有东西可折射**：新增 `ambientLayer()`——三团大模糊色斑（蓝/紫/青，opacity 0.20/0.16/0.11，blur 90）。纯黑背景上玻璃看不出"液态"，只会像一条黑条。
2. **Tabs 底色必须透明**：原来 `.backgroundColor(bgBase)` 不透明，把环境光层整块盖死（实测背景饱和度只有 0.238 = 纯底色）。改 `Color.Transparent` 后色斑可见。
3. **沉浸式系统栏**：原来状态栏/手势条是白色（实测亮度 208 / 171），深色界面上两条白边。`EntryAbility` 里加 `setWindowLayoutFullScreen(true)` + `setWindowSystemBarProperties`（透明底 + 白色图标）后降到 46 / 33。

### 12.3 玻璃的光：顶缘高光

Tab 栏改成 `Stack`：内容层 + 一层 `linearGradient` 高光（白 0.18 → 0.03 → 0，angle 165），`hitTestBehavior(None)` 不拦点击，整块 `clip(true)`。

### 12.4 像素实测证据（模拟器 API 22，1272×2756 截图分析）

| 指标 | 数值 | 结论 |
| --- | --- | --- |
| Tab 栏内部亮度 vs 正上方内容 | 41.9 vs 23.0（**1.83×**） | 玻璃比背景亮，浮起成立 |
| Tab 栏内部饱和度 | 0.33～0.41 | 比纯底色 0.238 高，**背后颜色确实透上来了** |
| 顶缘亮边（第 12–14 行） | 亮度 94–98、饱和度 0.16 | **1vp 高光边存在**（白亮、去饱和） |
| 状态栏区域亮度 | 208 → **46** | 沉浸式生效 |
| 手势条区域亮度 | 171 → **33** | 沉浸式生效 |
| 环境光（上部/下部带） | RGB (26,29,59) / (14,26,29) | 蓝、青两团光可见 |

> 采集方法：`hdc shell snapshot_display` 截图 → 拉回 → numpy 分区统计亮度/饱和度/逐行剖面。
> **注意**：先 `power-shell wakeup`，否则截图拿到的是壁纸而不是 App。

### 12.5 动效补充

- Tab 选中胶囊：`curves.springMotion()` 300ms，可打断。
- 卡片按下：`stateStyles` 0.97 缩放 + 0.92 透明（按下即反馈）。
- 列表项入场：opacity + translate(y:8)，200ms FastOutSlowIn。
- 生成中脉冲点：透明度 1↔0.25 呼吸，仅在 `streaming === true` 时存在。

### 12.6 仍然存在的风险（诚实记录）

1. **模糊性能未测**：单屏 3 团 blur(90) 色斑 + 3 处玻璃，模拟器流畅，真机需 SmartPerf 看长帧。
2. **无视觉主观验收**：只做了数值验证，观感（玻璃厚度、光的强弱）需要人眼判断。参数全在 `theme/Glass.ets`。
3. **浅色模式未做**：`LIGHT_COLORS` 已定义但未接线，浅色下这套玻璃配色需要重新取值。
---

## 13. 功能补齐（P8-3 / P8-4，2026-10-28 23:48）

**用户指示**：先把功能完善，UI 不是很好。→ UI 打磨暂停，转向命令覆盖面。

### 13.1 命令覆盖变化

| 项 | 之前 | 现在 |
| --- | --- | --- |
| 后端 dispatch 命令总数 | 263 | 263 |
| ArkTS 已包装 | 173 | **186** |
| 被 ArkTS 引用的命令（含页面直呼） | — | **191 / 263** |

新增包装：`create_character` / `update_character` / `delete_character` / `rename_character` /
`duplicate_character` / `get_character` / `rename_chat` / `delete_chat` / `search_chats` /
`backup_chat` / `list_chat_backups` / `delete_chat_backup` / `restore_character_chat_backup`。

### 13.2 角色管理页（新页面 `pages/CharactersPage.ets`）

- 列表：角色名 + 描述/开场白摘要，点行进入编辑。
- 新建：name / description / personality / scenario / first_mes / mes_example 六个字段。
- 编辑：保存走 `update_character`；**改名字单独走 `rename_character`**（update 的 name 语义不是重命名存储键）。
- 行操作面板：重命名 / 复制一份 / 导出 JSON / 删除（可选「同时删除会话」）。
- 入口：「角色」Tab 顶部「管理角色」按钮（常驻，不依赖是否已有角色）。

### 13.3 会话管理（首页「聊天」Tab）

| 能力 | 命令 | 状态 |
| --- | --- | --- |
| 跨会话内容搜索 | `search_chats` | 已接（搜索框 + 命中数 + 结果列表，点击直达该会话） |
| 重命名会话 | `rename_chat` | ✅ 模拟器实证：文件名改为 `default_Seraphina - 2026_r1-10-28@13h52m18s` |
| 备份会话 | `backup_chat` | 已接 |
| 删除会话 | `delete_chat`（camelCase 参数） | 已接（面板二次确认） |
| 打开指定会话 | `ChatIntent` 一次性意图 | 已接（搜索结果/列表行都能直接落到目标会话） |

### 13.4 模拟器实证（API 22）

| 步骤 | 结果 |
| --- | --- |
| 角色 Tab → 管理角色 | ✅ 页面打开，`共 1 个角色` |
| 新建 → 输入 `ProbeHero` → 保存 | ✅ `共 2 个角色` |
| 点行 → 编辑 → 输入后缀 → 保存 | ✅ 列表变为 `ProbeHeroZ` |
| 聊天 Tab 会话行 `⋯` | ✅ 面板出现「重命名 / 备份 / 删除」 |
| 重命名 → 追加 `_r1` → 确定 | ✅ 文件名实际变更 |
| 首屏搜索框 | ✅ 存在（`搜索会话内容…`） |

### 13.5 仍然缺的功能（诚实清单）

完全未被 ArkTS 引用的 72 条中，**用户可见**的还剩：

| 命令 | 缺什么 |
| --- | --- |
| `update_avatar` / `create_character_with_avatar` | 头像上传（需接图片选择 → 沙箱路径） |
| `import_chat` / `import_character_chats` / `export` 导出文件 | 文件选择与落盘（导入角色已能在诊断区验证，但没有正式入口） |
| `list_chat_backup_catalog` / `get_chat_backup_storage_stats` / `open_chat_backup_download` | 备份中心页面 |
| `search_character_chat_messages` / `find_last_character_chat_message` | 单会话内搜索（全局搜索已通） |
| `get_chat_completions_status` | 生成任务状态面板 |
| `set_data_root` | 数据目录迁移 |
| `register_agent_extension_tool` / `set_agent_extension_tool_enabled` | Agent 工具注册 UI |
| `chat_history_generation_started/finished`、`build_openai_logit_bias` | 内部/高级（token 与 bias 构造），UI 非必需 |

其余（commit 协议、secret、settings 快照、store_json、cache）属于底层或需要专门设置页，不在这轮。