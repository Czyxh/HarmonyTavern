//! Compile-target facts shared by native composition and the ArkTS shell.
//!
//! Mirrors upstream `platform/identity.rs`, but the values are fixed instead of
//! coming from Tauri's `desktop`/`mobile` cfgs: we always build for OpenHarmony.

use tt_contracts::host::{HostIdentity, HostKind, HostPlatform};

pub const HOST_IDENTITY: HostIdentity = HostIdentity {
    platform: HostPlatform::Ohos,
    kind: HostKind::Mobile,
};

/// User agent sent by LAN/TT sync clients (upstream `product::USER_AGENT`, re-branded).
pub(crate) const USER_AGENT: &str = concat!("HarmonyTavern/", env!("CARGO_PKG_VERSION"));

/// Frame budget for chunked settings/content commits.
/// Upstream `platform/ipc.rs` gives `HostPlatform::Ohos` the desktop-sized 4 MiB frame
/// (there is no WebView IPC hop on OHOS, so the mobile limits do not apply).
pub const COMMIT_FRAME_BYTES: u64 = 4 * 1024 * 1024;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn identity_is_ohos_mobile() {
        assert_eq!(HOST_IDENTITY.platform, HostPlatform::Ohos);
        assert_eq!(HOST_IDENTITY.kind, HostKind::Mobile);
    }
}
