//! `ExtensionTools` stub for OHOS (P6.2, replacing upstream's WebView-backed
//! implementation).
//!
//! Upstream implements `ExtensionTools` over the WebView's JS extension tool registry
//! (`infrastructure/extension_tools/…`): tools are exported by browser extensions running
//! inside a WebView. OHOS has no WebView tool host (the three `agent_extension_tool_*`
//! commands are deliberately not ported for exactly this reason, see `not_ported.rs`).
//!
//! Fail-fast contract (no silent degradation):
//! - `list()` returns an empty registry — truthful: there are no extension tools on OHOS.
//! - `call()` always errors with a clear message instead of pretending a tool ran.

use async_trait::async_trait;
use tokio::sync::watch;

use tt_contracts::extension_tools::{ExtensionTool, ExtensionToolCall, ExtensionToolReply};
use tt_domain::errors::DomainError;
use tt_ports::extension_tools::ExtensionTools;

#[derive(Debug, Default, Clone, Copy)]
pub struct OhosExtensionTools;

#[async_trait]
impl ExtensionTools for OhosExtensionTools {
    fn list(&self) -> Result<Vec<ExtensionTool>, DomainError> {
        Ok(Vec::new())
    }

    async fn call(
        &self,
        _call: ExtensionToolCall,
        _cancel: watch::Receiver<bool>,
    ) -> Result<ExtensionToolReply, DomainError> {
        Err(DomainError::InvalidData(
            "Extension tools are not available on HarmonyOS (WebView tool host is not ported)"
                .to_string(),
        ))
    }
}
