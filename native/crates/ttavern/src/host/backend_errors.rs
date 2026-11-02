//! Backend error hub (ported from upstream `app/backend_errors.rs`).
//!
//! Upstream held an `AppHandle` only to `emit`; here the event goes through
//! `host::events`, so the hub is a plain `Mutex<State>` and needs no handles.
//!
//! 当前宿主里错误经信封（`{ok:false,error}`）直接回 ArkTS，`emit_or_queue` 那条
//! 前置队列路径没有任何调用方，已随死代码清理移除；`backend_error_bridge_ready`
//! 命令仍然保留（ArkTS 启动序列与 dispatch 契约测试都会调），它只做
//! `mark_bridge_ready_and_drain` —— 队列恒为空，返回空 Vec。

use std::collections::VecDeque;
use std::sync::Mutex;

pub struct BackendErrorHub {
    state: Mutex<BackendErrorState>,
}

impl Default for BackendErrorHub {
    fn default() -> Self {
        Self::new()
    }
}

impl BackendErrorHub {
    pub fn new() -> Self {
        Self {
            state: Mutex::new(BackendErrorState::default()),
        }
    }

    pub fn mark_bridge_ready_and_drain(&self) -> Vec<String> {
        self.lock().mark_ready_and_drain()
    }

    fn lock(&self) -> std::sync::MutexGuard<'_, BackendErrorState> {
        match self.state.lock() {
            Ok(guard) => guard,
            Err(poisoned) => poisoned.into_inner(),
        }
    }
}

#[derive(Default)]
struct BackendErrorState {
    bridge_ready: bool,
    pending: VecDeque<String>,
}

impl BackendErrorState {
    fn mark_ready_and_drain(&mut self) -> Vec<String> {
        self.bridge_ready = true;
        self.pending.drain(..).collect()
    }
}
