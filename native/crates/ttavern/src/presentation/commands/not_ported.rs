//! 明确不移植的命令（上游仍暴露、但结果/入参类型绑定 Tauri WebView 机制）。
//!
//! 上游这几条返回 `tauri::ResourceId` —— 一个「把字节流挂到 WebView 资源表、由前端
//! `convertFileSrc` 取走」的进程内句柄。鸿蒙没有 WebView 资源表，照搬会让 ArkTS 拿到一个
//! 无法消费的整数，比报错更糟（前端会以为成功）。所以这些命令**显式返回 NotFound + 原因**，
//! 而不是让它掉进「Unknown command」的兜底 —— 后者会让人误以为只是还没移植。
//!
//! 它们服务的功能（聊天冷启动渲染 / 滑动记录 / 大文件分段提交）在鸿蒙侧由游标分页命令
//! （`get_chat_payload_tail` / `get_chat_payload_before*`）承担，见 §11.3-D。
//!
//! P6.1 追加两族（2026-10-27）：
//! - extension_store 5 条：`open_extension_store_entry`（Webview 资源表字节流）+ 分块提交
//!   4 条（`append` 依赖 `tauri::ipc::Request` 原始体，成组不可用）。
//! - agent_extension_tool 3 条：全部绑定 `Webview` + `Channel<ExtensionToolEvent>`，
//!   是 Tauri 页面前端到宿主 Agent 工具的进程内通道，鸿蒙无对应物。
//!
//! 对应 DevEco 工程路径：native/crates/ttavern/src/presentation/commands/not_ported.rs

use crate::presentation::errors::CommandError;

pub fn webview_resource_bound(name: &'static str) -> CommandError {
    CommandError::NotFound(format!(
        "`{name}` is deliberately not ported to HarmonyOS: its return value is a Tauri \
         WebView `ResourceId` (an in-process handle for `convertFileSrc`), which has no \
         meaning on HarmonyOS. The feature it feeds is covered by the payload-paging \
         commands (`get_chat_payload_tail` / `get_chat_payload_before`) instead."
    ))
}

/// Extension-store chunked commit commands: the append step reads the raw request body
/// (`tauri::ipc::Request`), so the whole write channel is unusable outside Tauri.
pub fn extension_store_commit_bound(name: &'static str) -> CommandError {
    CommandError::NotFound(format!(
        "`{name}` is deliberately not ported to HarmonyOS: the extension-store chunked \
         write channel depends on Tauri's raw `ipc::Request` body transport, which does \
         not exist on the NAPI bridge. The store's plain key/value commands \
         (rename/delete/list) are available instead."
    ))
}

/// Agent-extension tool commands: bound to a Tauri `Webview` label + `Channel`, the
/// in-process pipe between a web page and host tools; no HarmonyOS equivalent.
pub fn agent_extension_tool_bound(name: &'static str) -> CommandError {
    CommandError::NotFound(format!(
        "`{name}` is deliberately not ported to HarmonyOS: it is bound to a Tauri \
         `Webview` + `ipc::Channel` (the in-process pipe between the web UI and host \
         agent-extension tools), which has no meaning on the NAPI bridge."
    ))
}
