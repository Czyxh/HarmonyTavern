# 创建对话的资料选择展开动效（2026-11-01）

## 用户要求

“创建对话里面的展开也要有动画。”在上一轮展开面板玻璃统一基础上，补齐创建页内联的角色卡、聊天记录、世界书列表展开/收起效果。

## 修改

仅修改 `entry/src/main/ets/pages/StoryPage.ets`：

- 三个列表各增加一个自然高度的 Column 转场容器，不设置固定列表高度，不改变原选项布局和玻璃样式。
- 统一通过 `UIContext.animateTo` 更新展开状态，项目参数为 240ms / EaseInOut；内容以 opacity 和 -8vp 的轻位移出入。使用系统 TransitionEffect，不使用延时删除或动画结束回调承载业务状态。
- 手动收起与选中角色/聊天记录后自动收起均调用同一方法。聊天记录仍先读取成功再收起，失败时不假装已选中。
- `MOTION_REDUCE_KEY` 开启时采用 0ms 与 TransitionEffect.IDENTITY，不播放位移/淡入动画。
- 不锁定动画期间的按钮，连续点击可以反转展开目标；世界书收起后再打开保留选择。
- 不改后端数据协议、顶栏效果或上一轮面板/圆球共享玻璃。

这些时长与位移属于项目风格参数，不是官方强制值。

## 验证

- `create-picker-motion-build.log`：ArkTS 编译及签名通过。
- API26 模拟器：三个选择器展开/收起，选中角色自动关闭，真实聊天记录读取后关闭、切回空白关闭，世界书选中后收起/重开保留状态。
- 测试脚本 `build/create-picker-motion-qa.cjs`：以上状态检查及世界书开关快速反向点击 8 次，最终状态正确。
- 通过设置页开启“减少动态效果”后检查选择器开合，完成后恢复原来的关闭状态。
- 选择均为未保存草稿，退出后未创建、修改、删除用户聊天数据。
- 截图：`build/create-picker-motion-expanded.jpeg`。静态截图只作最终布局证据，不代表动画帧率验收。
- 未做真机、API22 运行、慢放录屏与性能验收。

## 最新安装包

- 手机：`dist/HarmonyTavern-create-motion-arm64-20261101-signed.hap`。
- 模拟器：`dist/HarmonyTavern-create-motion-simulator-20261101-signed.hap`，对应版本已安装。
- 两包附同名 `.sha256`，均校验通过；手机打包后恢复 x86_64 源库。
- 手机日志：`create-picker-motion-arm64-package.log`。

保留 `PANEL-GLASS-20261101.md` 的面板玻璃统一和此前已有聊天记录选择功能。
