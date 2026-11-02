#[path = "../examples/support/web_host_defaults.rs"]
mod defaults;

// Upstream keeps this test at `tests/web_host_defaults.rs` and reads the snapshot
// from `../../../../src/tauri/web-host/default-state.json`, i.e. the Tauri web-host
// tree. This port deliberately keeps no Tauri code, so that path does not exist and
// the whole `-p tt-application` test build failed with os error 3.
//
// The snapshot itself is plain data (1,723 B of default profile/settings JSON), not
// code, so it is kept here as a fixture. The assertion is unchanged and still earns
// its place: it pins `native_defaults()` so a refactor of the application layer
// cannot silently change the defaults users get on first launch.
#[test]
fn native_defaults_match_the_published_snapshot() {
    let published: serde_json::Value =
        serde_json::from_str(include_str!("fixtures/web-host-default-state.json")).unwrap();
    let native = defaults::native_defaults().unwrap();
    assert_eq!(
        published, native,
        "Native defaults changed. If the change is intended, regenerate the snapshot:\n  \
         cargo run --quiet -p tt-application --example web_host_defaults",
    );
}
