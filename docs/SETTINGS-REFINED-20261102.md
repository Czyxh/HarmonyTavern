# 设置首页重构（2026-11-02）

根据用户提供的分组设置长图，结合 HarmonyTavern 原有纸张、主题配色、圆角与玻璃导航重构设置首页。参考搜索、概览、分组列表的信息层级，不复制参考产品的会员、公告和未实现能力。

## 实现

- 原先每项独立大卡片改为六组紧凑列表：外观与偏好、身份与创作、模型与连接、扩展与工具、数据与同步、诊断与维护。
- 所有 19 个原路由保持且各出现一次，只重命名部分展示标题并整理说明和顺序。世界书仍在资料库，不重新引入设置。
- 新增 SettingsEntryRow：40vp 主题图标底、标题与说明、细分隔线和右箭头；每行最小 80vp，内容可随字体增高，有按下反馈及读屏说明。
- “我的酒馆”概览显示现有角色/对话数量，并进入用户设定管理。不展示虚构账号/会员状态。概览在搜索时隐藏。
- 搜索支持标题、说明和组名；无结果提示可见；提交搜索或从结果进入页面会清理焦点，避免返回时重新弹键盘。
- 刷新设为顶部玻璃圆球，复用真实 reloadHome 和忙碌反馈。重新初始化及原有诊断按钮收进可展开维护区，保留原方法与结果展示。
- 未改 Rust、存储协议、模型调用、导航材质或其他业务页面。旧版 Index 快照保存在 build/settings-redesign-before-20261102/Index.ets。

## 验证

- ArkTS 构建及手机、模拟器包签名成功，日志 settings-refined-package-build.log、settings-refined-arm64-build.log。
- 对照重构前入口，19 个路由集合一致，无丢失或重复。
- API26 模拟器验证搜索 MCP、进入真实 MCP 页面、返回保留搜索条件且键盘关闭；无结果、清空搜索、概览进入人设页、外观页跳转、深浅色显示、长列表到底、诊断展开/收起、顶栏刷新及冷启动。
- 初轮发现概览卡片贴边和圆角错误，已修复，最终截图 bounds 为 [56,738][1224,1347]，左右均 16vp。
- 检查运行日志未见 TypeError/ReferenceError/JsCrash/FATAL。主题测试后恢复跟随系统。未执行重新初始化、诊断任务、模型请求或聊天数据改写。
- 截图 build/settings-refined-final.jpeg、settings-refined-dark.jpeg、settings-refined-models.jpeg、settings-refined-footer.jpeg。真机、横屏和放大字号未实机验收，不将模拟器检查泛称为全部设备通过。

## 安装包

- dist/HarmonyTavern-settings-refined-arm64-20261102-signed.hap，仅 arm64。
- dist/HarmonyTavern-settings-refined-simulator-20261102-signed.hap，arm64+x86_64；最终包已安装模拟器并复查搜索返回。
- SHA256 校验文件齐全，手机架构检查通过，x86_64 源库已恢复。打包脚本 build/package-settings-refined.ps1。
