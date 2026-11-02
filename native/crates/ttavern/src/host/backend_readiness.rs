//! Backend readiness gate (ported verbatim from upstream `app/backend_readiness.rs`).
//!
//! ArkTS calls `wait_for_backend_ready` before its first data load so it never reads a
//! half-assembled service graph. In our flow the service graph is built inside `initialize`
//! before the runtime becomes visible, so the gate is already `Ready`; the command is kept
//! because the ArkTS startup sequence calls it. `mark_failed` 与 `Failed` 变体没有调用方
//! （initialize 失败走信封错误直接回 ArkTS），已在死代码清理中移除。

use std::fmt;

use tokio::sync::watch;

#[derive(Clone, Debug, PartialEq, Eq)]
enum BackendStatus {
    Initializing,
    Ready,
}

pub struct BackendReadiness {
    status: watch::Sender<BackendStatus>,
}

#[derive(Debug, PartialEq, Eq)]
pub enum BackendReadinessError {
    Closed,
}

impl Default for BackendReadiness {
    fn default() -> Self {
        Self::new()
    }
}

impl BackendReadiness {
    pub fn new() -> Self {
        let (status, _receiver) = watch::channel(BackendStatus::Initializing);
        Self { status }
    }

    pub fn mark_ready(&self) {
        self.status.send_replace(BackendStatus::Ready);
    }

    pub async fn wait_ready(&self) -> Result<(), BackendReadinessError> {
        let mut status = self.status.subscribe();

        loop {
            match status.borrow_and_update().clone() {
                BackendStatus::Initializing => {}
                BackendStatus::Ready => return Ok(()),
            }

            if status.changed().await.is_err() {
                return Err(BackendReadinessError::Closed);
            }
        }
    }
}

impl fmt::Display for BackendReadinessError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Closed => write!(
                formatter,
                "Backend readiness channel closed before initialization completed"
            ),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn late_waiter_returns_after_ready() {
        let readiness = BackendReadiness::new();
        readiness.mark_ready();
        assert_eq!(readiness.wait_ready().await, Ok(()));
    }
}
