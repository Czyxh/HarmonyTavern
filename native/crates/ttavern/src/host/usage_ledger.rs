//! Local provider-reported request ledger. Never stores prompts, endpoints or credentials.
use std::{fs::{self, OpenOptions}, io::{BufRead, BufReader, Write}, path::{Path, PathBuf}, sync::{Arc, Mutex}};
use tt_application::services::chat_completion_service::usage_observer::{UsageObservation, UsageObserver};
static LEDGER_LOCK: Mutex<()> = Mutex::new(());
pub fn ledger_path(data_root: &Path) -> PathBuf { data_root.join("default-user/harmony-usage/requests.jsonl") }
pub fn observer(data_root: PathBuf) -> UsageObserver {
    Arc::new(move |event| {
        if let Err(error) = append(&ledger_path(&data_root), &event) { tracing::warn!("Usage ledger write failed: {error}"); }
    })
}
pub fn append(path: &Path, event: &UsageObservation) -> std::io::Result<()> {
    let _guard = LEDGER_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    if let Some(parent) = path.parent() { fs::create_dir_all(parent)?; }
    let mut bytes = serde_json::to_vec(event)?; bytes.push(b'\n');
    let mut file = OpenOptions::new().create(true).append(true).open(path)?;
    file.write_all(&bytes)?; file.sync_data()
}
pub fn read(path: &Path) -> std::io::Result<(Vec<UsageObservation>, usize)> {
    let _guard = LEDGER_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let file = match fs::File::open(path) { Ok(file) => file, Err(e) if e.kind() == std::io::ErrorKind::NotFound => return Ok((vec![], 0)), Err(e) => return Err(e) };
    let mut events = Vec::new(); let mut invalid = 0;
    for line in BufReader::new(file).lines() {
        let line = line?;
        if line.trim().is_empty() { continue; }
        match serde_json::from_str(&line) { Ok(event) => events.push(event), Err(_) => invalid += 1 }
    }
    Ok((events, invalid))
}
