//! TauriTavern → HarmonyOS 原生宿主（NAPI 桥接层）
//!
//! P1：ArkTS 调 hello()/add()；P2：initialize(pathsJson) + get_backend_status；
//! P3：invoke(command, payload) 单一通用分发 + 首批命令 + 服务装配 + 事件通道。
//!
//! NAPI 表面共 5 个符号（其余全部收敛到 invoke）：hello / add / initialize /
//! getBackendStatus / invoke / setEventListener。

mod host;
mod observability;
mod presentation;

// 端到端命令契约测试（57 条路由逐个打一遍，不需要鸿蒙设备）。
#[cfg(test)]
mod dispatch_contract_tests;
#[cfg(test)]
mod wire_contract_tests;
// P6.1 接缝级聚焦测试（空参数点名 / 无参命令 ok / camel-snake-tag 反序列化形状）。
#[cfg(test)]
mod p61_focused_contract_tests;
// P6.1 功能往返测试（真实载荷走通 preset/mcp/skill/data_archive 等域的服务层）。
#[cfg(test)]
mod p61_functional_tests;
#[cfg(test)]
mod p62_functional_tests;

use napi_ohos::bindgen_prelude::*;
use napi_ohos::threadsafe_function::ThreadsafeFunction;
use napi_derive_ohos::napi;

/// P1 demo：ArkTS 调用的第一个 Rust 函数。
#[napi]
pub fn hello() -> String {
    "Hello from Rust! (TauriTavern NAPI demo)".to_string()
}

/// P1 demo：验证参数传递（同步、标量）。
#[napi]
pub fn add(a: i32, b: i32) -> i32 {
    a + b
}

/// 生命周期：ArkTS 启动时调用，注入沙箱路径并初始化宿主。
/// 入参 JSON：{ filesDir, databaseDir, cacheDir, bundleName, versionName }
/// 返回 JSON：{ ready, version, platform, dataRoot, ... }
#[napi]
pub async fn initialize(paths_json: String) -> Result<String> {
    host::runtime::initialize(&paths_json).await.map_err(|reason| {
        tracing::error!(%reason, "initialize failed");
        Error::from_reason(reason)
    })
}

/// 就绪状态/版本（P2 验收：ArkTS 可轮询直到 ready=true）。
/// 返回 JSON：{ ready, version, platform, dataRoot, logRoot, bundledResources, initializedAt }
/// 声明为 async 以匹配 ArkTS 侧的 Promise<string> 契约（后续阶段可能需 await 内部状态）。
#[napi]
pub async fn get_backend_status() -> String {
    host::runtime::get_backend_status()
}

/// 事件订阅（替代 Tauri `AppHandle::emit`）。
///
/// ArkTS 侧注册一个回调，Rust 侧收到的每个事件都以 JSON 信封投递：
/// `{"event":"<name>","payload":<json>}`，ArkTS 按 `event` 分发。
/// 回调在 JS 线程执行（ThreadsafeFunction），因此断言/异常不会影响 Rust 侧。
#[napi]
pub fn set_event_listener(listener: ThreadsafeFunction<String>) -> Result<()> {
    host::events::set_listener(listener);
    Ok(())
}

/// 通用命令入口（替代 Tauri 的 362 个 `#[tauri::command]`）。
///
/// 入参：`command`（ArkTS 侧命令名，与上游同名）、`payloadJson`（命名参数对象 JSON，
/// 形态与 Tauri invoke 完全一致，例如 `{"id":"abc"}` / `{"dto":{...}}`）。
///
/// 返回值永远是 JSON 信封，不会 reject，ArkTS 只有一条解析路径：
/// - 成功：`{"ok":true,"data":<结果>}`
/// - 失败：`{"ok":false,"error":{"code":"not_found","message":"Not found: ..."}}`
#[napi]
pub async fn invoke(command: String, payload_json: Option<String>) -> String {
    presentation::dispatch::invoke(&command, payload_json.as_deref()).await
}
