# 使用统计范围切换调整（2026-11-02）

- 近30天仍统计准确30天，将周列按当前内容宽度展开，避免仅占左侧一小块；年度保持紧凑方格并可横向滚动。
- 切换不再清空 report/weeks 或销毁整页内容；读取期间保留上一范围，状态行标明正在读取范围和当前数据范围，新响应就绪后以220ms EaseOut恢复不透明度。图表视口固定156vp，避免范围切换改变总览纵向位置。
- 失败保留已成功数据并恢复透明度；revision保护阻止过期响应覆盖新范围；卸载后不回写；减少动态效果使用0ms。
- 日期前后按钮在读取中禁用，热力图只有内容宽度改变才自动滚动到最新端，正常横向查看不强制归位。

验证：build/usage-nav-client-tests.cjs通过，覆盖保留数据、范围标签、读取失败、乱序、卸载、减少动态效果和30天展宽；ArkTS构建成功。API26模拟器连续切换8次后范围、内容和透明度一致，总览位置相同；build/usage-range-runtime.log未见TypeError/ReferenceError/JsCrash/FATAL。截图build/usage-range-month.jpeg、usage-range-year.jpeg供独立OpenDesign审查。未作逐帧真机性能验收，未调用在线模型或改写聊天数据。

安装包：dist/HarmonyTavern-usage-range-smooth-arm64-20261102-signed.hap（40163928字节，arm64）；dist/HarmonyTavern-usage-range-smooth-simulator-20261102-signed.hap（98022559字节，arm64+x86_64）。附SHA256校验文件。仅修改前端，复用上一轮已编译Rust库。
