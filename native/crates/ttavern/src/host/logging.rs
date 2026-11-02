//! tracing 初始化：文件滚动日志（tracing-appender）+ 控制台 fmt。
//! 对应上游 `infrastructure/logging/tracing_runtime.rs` 的 OHOS 简化版
//! （去掉 Tauri event / devtools 通道）。

use std::path::Path;

pub fn init(log_root: &Path) -> Result<(), Box<dyn std::error::Error>> {
    std::fs::create_dir_all(log_root)?;

    let file_appender = tracing_appender::rolling::daily(log_root, "ttavern.log");
    let (non_blocking, _guard) = tracing_appender::non_blocking(file_appender);

    let subscriber = tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("ttavern=info,tracing=warn")),
        )
        .with_ansi(false)
        .with_writer(non_blocking)
        .with_target(true)
        .finish();

    // tracing::subscriber::set_global_default 只能调用一次；跨 initialize 重复调用时忽略
    if tracing::subscriber::set_global_default(subscriber).is_err() {
        tracing::warn!("tracing global default already set; keeping previous subscriber");
    }

    tracing::info!(log_root = %log_root.display(), "tracing initialized");
    Ok(())
}
