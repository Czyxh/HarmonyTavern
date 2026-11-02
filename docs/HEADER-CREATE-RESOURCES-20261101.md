# 恢复原顶栏与创建对话资料选择（2026-11-01）

## 用户纠正

用户要求保留此前顶栏效果，指出新版顶栏下面有明显白条；“创建对话”应在页面内选择已有的角色卡、世界书等资料。本轮以该要求为准，不继续把顶栏换成新的玻璃样式。

## 实施

### 顶栏

- `PageSurface` 恢复原渐变模糊、原主题淡出色和背景采样；撤销上一轮新增的实色遮罩方案。
- `HeaderAction` 恢复原来的玻璃背景、细描边、渐变高光；顶栏按钮不再使用新加的原生 TabBar 圆球背板。
- `Glass` 恢复页头圆球的原模糊半径与 headerButtonTint，不改变底部导航、输入栏和其他圆球的现有方案。
- 保留目前的 systemTopInset/systemBottomInset、页面水平与底部留白属性，并显式将 Scroll 内容对齐顶部；未恢复为早期会遮挡内容的安全区实现。
- 资料库 embedded 页面透明背景、底部导航去叠光和剧情选项修复继续保留。

### 创建对话

- 首页“创建对话”直接进入配置页，不再先展开一个只选择角色的小菜单。
- 创建页列出当前资料库中的角色卡；必须选一个角色。支持重新选择，角色多时可搜索；选择角色后使用其原开场白，不覆盖用户手动修改过的开场文本。
- 世界书读取 `list_world_infos` 的实际资料，支持不选或多选，最多 8 本；不新建或修改原角色卡/世界书。空列表、读取失败、已删除的引用均有对应处理。
- 当前对话的故事设置页可查看固定角色、调整所选世界书，不借编辑操作替换角色。
- `StorySettings.world_books` 是向后兼容字段，旧记录默认空数组。新建和保存前验证世界书存在，失败不创建聊天或覆盖现有配置。
- 真实发送与补选项会读取所选世界书，按条目 order 排序，忽略 disable=true / enabled=false 的条目，把启用内容加入当前对话背景，并替换 `{{char}}` / `{{user}}`。明确采用“选中书的启用条目作为背景”，不是伪称实现了 SillyTavern 的关键词/递归激活引擎。
- 世界书内容以引用方式在每次准备请求时重读，不复制到角色卡；总启用内容超过 128 KiB 时明确报错，不静默截断。

## 安装包

- 原生 arm64、x86_64 release 编译通过，日志 `header-create-native-arm64.log`、`header-create-native-x86.log`。
- 手机包 `dist/HarmonyTavern-header-resources-arm64-20261101-signed.hap`：39,568,864 字节，仅含 arm64 原生库。
- 模拟器包 `dist/HarmonyTavern-header-resources-simulator-20261101-signed.hap`：68,943,913 字节，含两种架构，已安装 API26 模拟器。
- 两包附同名 `.sha256`，校验通过；手机打包时暂存的 x86_64 源库已恢复。打包日志 `header-create-final-package.log`、`header-create-arm64-package.log`。

## 验证

- `header-create-native-tests.log`：聚焦原生测试 11/11；新增验证所选世界书进入提示词、禁用条目不进入提示词、不存在的书禁止保存、失败后原选择保持。
- `header-create-arkts.log`：ArkTS 构建通过，保留现有兼容性/弃用警告。
- API26 模拟器实测：首页顶栏恢复原描边圆球和渐变效果，顶栏下未再见上一轮白色横条；内容恢复顶部对齐。
- 首页“创建对话”直接进入资源选择页；实际选择现有 `Seraphina` 角色卡和 `Eldoria` 世界书，世界书节点 selected=true；退出时未保存，未新增、修改或删除用户对话。
- 截图：`build/header-restored.jpeg`、`build/header-restored-dark-home.jpeg`、`build/create-resources.jpeg`、`build/create-resources-selected.jpeg`。深浅模式检查后恢复纸张/跟随系统；运行日志 `build/header-create-runtime.log` 未检出 TypeError、ReferenceError、JsCrash、FATAL。
- 真实在线模型效果及物理手机仍未验收；世界书上下文的实际构造由原生集成测试验证，不以选择 UI 代替后端验证。
