//! Statistics from retained chat JSONL and the durable provider request ledger.
use std::{collections::{BTreeMap, BTreeSet}, fs, io::{BufRead, BufReader}, path::{Path, PathBuf}};
use chrono::{DateTime, Duration, FixedOffset, NaiveDate, Utc, Months};
use serde::Serialize;
use serde_json::{Value, json};
use crate::{host::{Ctx, usage_ledger}, presentation::{dispatch::Args, errors::CommandError, token_usage::TokenUsage}};

#[derive(Default)]
struct Counters { input: Option<u64>, output: Option<u64>, total: Option<u64>, cached: Option<u64>, cache_input: u64, known: u64, missing: u64, partial: u64, reply_total: u64, reply_count: u64 }
fn add(target: &mut Option<u64>, value: Option<u64>) { if let Some(v) = value { *target = Some(target.unwrap_or(0).saturating_add(v)); } }
impl Counters {
    fn apply(&mut self, usage: &TokenUsage, reply: bool, complete: bool) {
        if usage.is_empty() { self.missing += 1; return; }
        self.known += 1; if !complete { self.partial += 1; }
        add(&mut self.input, usage.prompt_tokens); add(&mut self.output, usage.completion_tokens); add(&mut self.total, usage.total_tokens);
        if let (Some(cache), Some(input)) = (usage.cached_tokens, usage.prompt_tokens) {
            if cache <= input { add(&mut self.cached, Some(cache)); self.cache_input = self.cache_input.saturating_add(input); }
        }
        if reply { if let Some(total) = usage.total_tokens { self.reply_total = self.reply_total.saturating_add(total); self.reply_count += 1; } }
    }
}
#[derive(Serialize)]
struct Rank { name: String, value: u64 }
fn ranks(map: BTreeMap<String, u64>) -> Vec<Rank> {
    let mut rows: Vec<_> = map.into_iter().map(|(name,value)| Rank{name,value}).collect();
    rows.sort_by(|a,b| b.value.cmp(&a.value).then(a.name.cmp(&b.name))); rows.truncate(10); rows
}
fn inc(map: &mut BTreeMap<String,u64>, key: String, value: u64) { let entry = map.entry(key).or_default(); *entry = entry.saturating_add(value); }
fn parse_date(value: &Value, offset: FixedOffset) -> Option<NaiveDate> {
    let millis = tt_domain::models::chat::parse_message_timestamp_value(Some(value));
    if millis != 0 { return DateTime::<Utc>::from_timestamp_millis(millis).map(|d| d.with_timezone(&offset).date_naive()); }
    value.as_str().and_then(|s| NaiveDate::parse_from_str(s, "%Y-%m-%d").ok())
}
fn chat_paths(directory: &Path, depth: usize, result: &mut Vec<PathBuf>) -> std::io::Result<()> {
    if !directory.exists() { return Ok(()); }
    for entry in fs::read_dir(directory)? {
        let entry = entry?; let kind = entry.file_type()?; let path = entry.path();
        if kind.is_dir() && depth > 0 { chat_paths(&path, depth-1, result)?; }
        else if kind.is_file() && path.extension().is_some_and(|s| s == "jsonl") { result.push(path); }
    } Ok(())
}
pub async fn get(_ctx: &Ctx<'_>, args: &Args) -> Result<Value, CommandError> {
    let range: String = args.optional("range")?.unwrap_or_else(|| "12m".into());
    if !["all","30d","12m"].contains(&range.as_str()) { return Err(CommandError::BadRequest("Invalid statistics range".into())); }
    let minutes: i32 = args.optional("offsetMinutes")?.unwrap_or(0);
    let offset = FixedOffset::east_opt(minutes.checked_mul(60).unwrap_or(i32::MAX))
        .filter(|_| (-840..=840).contains(&minutes)).ok_or_else(|| CommandError::BadRequest("Invalid timezone offset".into()))?;
    let root = crate::host::runtime::runtime().ok_or_else(|| CommandError::InternalServerError("Runtime unavailable".into()))?.context.paths.data_root.clone();
    tokio::task::spawn_blocking(move || report(&root, &range, offset, Utc::now().with_timezone(&offset).date_naive()))
        .await.map_err(|e| CommandError::InternalServerError(e.to_string()))?
        .map_err(|e| CommandError::InternalServerError(format!("Read usage statistics: {e}")))
}
fn report(root: &Path, range: &str, offset: FixedOffset, today: NaiveDate) -> std::io::Result<Value> {
    let start = match range { "30d" => Some(today - Duration::days(29)), "12m" => today.checked_sub_months(Months::new(12)).map(|d| d + Duration::days(1)), _ => None };
    let in_range = |day: Option<NaiveDate>| day.is_some_and(|d| d <= today && start.is_none_or(|s| d >= s)) || (range == "all" && day.is_none());
    let (events, invalid_ledger) = usage_ledger::read(&usage_ledger::ledger_path(root))?;
    let request_keys: BTreeSet<_> = events.iter().filter(|event| !event.request_key.is_empty()).map(|event| event.request_key.clone()).collect();
    let mut paths = vec![]; let user = root.join("default-user");
    chat_paths(&user.join("chats"), 1, &mut paths)?; chat_paths(&user.join("group chats"), 0, &mut paths)?;
    let mut conversations = 0_u64; let mut messages = 0_u64; let mut unknown_dates = 0_u64; let mut unknown_models = 0_u64;
    let mut days = BTreeMap::new(); let mut models = BTreeMap::new(); let mut token_models = BTreeMap::new(); let mut sources = BTreeMap::new();
    let mut counters = Counters::default(); let mut invalid_rows = 0; let mut known_model_names = BTreeSet::new();
    for path in paths {
        let mut active = false;
        for line in BufReader::new(fs::File::open(path)?).lines() {
            let line = line?; if line.trim().is_empty() { continue; }
            let msg: Value = match serde_json::from_str(&line) { Ok(v) => v, Err(_) => { invalid_rows+=1; continue; } };
            if !msg["is_user"].is_boolean() || msg["is_system"] == true || msg["mes"].as_str().is_none_or(|s| s.trim().is_empty()) { continue; }
            let day = parse_date(&msg["send_date"], offset);
            if !in_range(day) { if day.is_none() { unknown_dates+=1; } continue; }
            active = true; messages+=1;
            if let Some(day) = day { inc(&mut days, day.to_string(), 1); } else { unknown_dates+=1; }
            if msg["is_user"] == true { continue; }
            let model = msg.pointer("/extra/model").and_then(Value::as_str).filter(|s| !s.trim().is_empty());
            if let Some(model) = model { known_model_names.insert(model.to_string()); inc(&mut models, model.to_string(),1); }
            else { unknown_models+=1; }
            // New requests are counted by the request ledger, even if the message is later edited/deleted.
            if msg.pointer("/extra/harmony_usage_request").and_then(Value::as_str).is_some_and(|key| request_keys.contains(key)) { continue; }
            if let Some(raw) = msg.pointer("/extra/harmony_token_usage") {
                let usage: TokenUsage = serde_json::from_value(raw.clone()).unwrap_or_default();
                counters.apply(&usage, true, msg.pointer("/extra/harmony_usage_complete") != Some(&Value::Bool(false)));
                if let Some(total) = usage.total_tokens { inc(&mut sources, "historical".into(), total); inc(&mut token_models, model.unwrap_or("未知模型（历史）").into(),total); }
            } else { counters.missing += 1; }
        }
        if active { conversations+=1; }
    }
    let mut seen = BTreeSet::new(); let mut requests = 0_u64;
    for event in events {
        if !seen.insert(event.id.clone()) { continue; }
        let day = parse_date(&json!(event.started_at), offset); if !in_range(day) { continue; }
        requests+=1;
        let is_chat = event.kind == "chat" || event.kind == "group";
        counters.apply(&event.usage, is_chat, event.complete);
        if let Some(total) = event.usage.total_tokens {
            inc(&mut sources,event.kind,total); inc(&mut token_models,event.model,total);
        }
    }
    let active_days = days.len(); let mut longest=0_u64; let mut current=0_u64; let mut previous: Option<NaiveDate>=None;
    for day in days.keys().filter_map(|s| NaiveDate::parse_from_str(s,"%Y-%m-%d").ok()) {
        current = if previous == Some(day-Duration::days(1)) {current+1} else {1}; longest=longest.max(current); previous=Some(day);
    }
    let heat_start = start.unwrap_or(today.checked_sub_months(Months::new(12)).unwrap_or(today-Duration::days(364)) + Duration::days(1)); let mut heat = vec![]; let mut day=heat_start;
    while day<=today { let date=day.to_string(); heat.push(json!({"date":date,"count":days.get(&date).copied().unwrap_or(0)})); day+=Duration::days(1); }
    let heat_active = heat.iter().filter(|d| d["count"].as_u64().unwrap_or(0)>0).count();
    let mut heat_longest=0;let mut streak=0;
    for day in &heat { if day["count"].as_u64().unwrap_or(0)>0 {streak+=1;heat_longest=heat_longest.max(streak);} else {streak=0;} }
    Ok(json!({"heat_active_days":heat_active,"heat_longest_streak":heat_longest,"range":range,"from":start.map(|s|s.to_string()),"to":today.to_string(),"heat":heat,
        "conversations":conversations,"messages":messages,"models":known_model_names.len(),"active_days":active_days,"longest_streak":longest,
        "model_rank":ranks(models),"token_rank":ranks(token_models),"sources":ranks(sources),"requests":requests,
        "input":counters.input,"output":counters.output,"total":counters.total,"cached":counters.cached,
        "cache_rate":if counters.cache_input>0 {counters.cached.map(|v|v as f64/counters.cache_input as f64)} else {None},
        "average":if counters.reply_count>0 {Some(counters.reply_total as f64/counters.reply_count as f64)} else {None},
        "known_usage":counters.known,"missing_usage":counters.missing,"partial_usage":counters.partial,"average_samples":counters.reply_count,
        "unknown_dates":unknown_dates,"unknown_models":unknown_models,"invalid_rows":invalid_rows+invalid_ledger,
        "updated_at":Utc::now().to_rfc3339()}))
}

#[cfg(test)]
mod tests {
    use super::*;
    use tt_application::services::chat_completion_service::usage_observer::UsageObservation;
    #[test]
    fn native_usage_ranges_legacy_dedup_cache_and_streak() {
        let root=std::env::temp_dir().join(format!("usage-stats-{}",uuid::Uuid::new_v4()));
        let dir=root.join("default-user/chats/A");fs::create_dir_all(&dir).unwrap();
        let rows=vec![json!({"chat_metadata":{}}),json!({"is_user":true,"mes":"a","send_date":"2026-10-31T16:30:00Z"}),
          json!({"is_user":false,"mes":"b","send_date":"2026-11-02T00:00:00Z","extra":{"model":"m","harmony_usage_recorded":true,"harmony_usage_request":"request-1","harmony_token_usage":{"total_tokens":999}}}),
          json!({"is_user":false,"mes":"old","send_date":"2026-01-01","extra":{"model":"old","harmony_token_usage":{"prompt_tokens":10,"completion_tokens":2,"total_tokens":12}}})];
        fs::write(dir.join("a.jsonl"),rows.iter().map(|v|format!("{v}\n")).collect::<String>()).unwrap();
        let event=UsageObservation{id:"once".into(),request_key:"request-1".into(),started_at:"2026-11-02T00:00:00Z".into(),model:"m".into(),provider:"custom".into(),kind:"chat".into(),usage:TokenUsage{prompt_tokens:Some(100),completion_tokens:Some(20),total_tokens:Some(120),cached_tokens:Some(50)},complete:true};
        let path=usage_ledger::ledger_path(&root);usage_ledger::append(&path,&event).unwrap();usage_ledger::append(&path,&event).unwrap();
        let today=NaiveDate::from_ymd_opt(2026,11,2).unwrap();let offset=FixedOffset::east_opt(8*3600).unwrap();
        let a=report(&root,"30d",offset,today).unwrap();assert_eq!(a["messages"],2);assert_eq!(a["total"],120);assert_eq!(a["longest_streak"],2);assert_eq!(a["active_days"],2);assert_eq!(a["cached"],50);assert_eq!(a["cache_rate"],0.5);assert_eq!(a["requests"],1);assert_eq!(a["heat"].as_array().unwrap().len(),30);
        let all=report(&root,"all",offset,today).unwrap();assert_eq!(all["total"],132);assert_eq!(all["messages"],3);
        fs::rename(&path,path.with_extension("saved")).unwrap();
        let imported=report(&root,"30d",offset,today).unwrap();assert_eq!(imported["total"],999);
        let empty=report(&root.join("empty"),"30d",offset,today).unwrap();assert!(empty["total"].is_null());assert!(empty["cached"].is_null());assert_eq!(empty["messages"],0);
    }
    #[tokio::test]
    async fn native_usage_records_real_service_nonstream_stream_and_missing_usage() {
        use tokio::io::{AsyncReadExt, AsyncWriteExt};
        let root=std::env::temp_dir().join(format!("usage-service-{}",uuid::Uuid::new_v4()));
        crate::host::runtime::initialize(&json!({"filesDir":root.join("files"),"databaseDir":root.join("db"),"cacheDir":root.join("cache"),"bundleName":"com.example.harmonytavern","versionName":"1"}).to_string()).await.unwrap();
        let listener=tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let endpoint=format!("http://127.0.0.1:{}/",listener.local_addr().unwrap().port());
        let server=tokio::spawn(async move {
            for index in 0..3 {
                let (mut socket,_)=listener.accept().await.unwrap();let mut request=vec![];let mut buf=[0_u8;4096];
                loop { let n=socket.read(&mut buf).await.unwrap();if n==0 {break;} request.extend_from_slice(&buf[..n]);
                    let text=String::from_utf8_lossy(&request);
                    if let Some((head,body))=text.split_once("\r\n\r\n") { let len=head.lines().find_map(|l|l.to_ascii_lowercase().strip_prefix("content-length:").and_then(|v|v.trim().parse::<usize>().ok())).unwrap_or(0);if body.len()>=len {break;} }
                }
                assert!(!String::from_utf8_lossy(&request).contains("_harmony_usage_"));
                let (content_type,body)=if index==1 {("text/event-stream",format!("data: {}\n\ndata: {}\n\ndata: [DONE]\n\n",json!({"choices":[{"delta":{"content":"ok"}}],"usage":{"prompt_tokens":100,"completion_tokens":20,"total_tokens":120,"prompt_tokens_details":{"cached_tokens":40}}}),json!({"choices":[],"usage":{"prompt_tokens":100,"completion_tokens":20,"total_tokens":120,"prompt_tokens_details":{"cached_tokens":40}}})))}
                    else { let mut body=json!({"choices":[{"message":{"content":"ok","role":"assistant"},"finish_reason":"stop"}]});if index==0 {body["usage"]=json!({"prompt_tokens":10,"completion_tokens":5,"total_tokens":15,"prompt_tokens_details":{"cached_tokens":6}});} ("application/json",body.to_string()) };
                let response=format!("HTTP/1.1 200 OK\r\nContent-Type: {content_type}\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",body.len());socket.write_all(response.as_bytes()).await.unwrap();
            }
        });
        async fn invoke(command:&str,args:Value)->Value {serde_json::from_str(&crate::presentation::dispatch::invoke(command,Some(&args.to_string())).await).unwrap()}
        let grant=invoke("grant_user_endpoint_access",json!({"endpoint":endpoint})).await;assert_eq!(grant["ok"],true,"{grant}");
        let prefix=format!("usage_{}",uuid::Uuid::new_v4().simple());
        let dto=json!({"model":"test-model","chat_completion_source":"custom","custom_url":endpoint,"custom_api_format":"openai_compat","max_tokens":16,"messages":[{"role":"user","content":"private-test"}]});
        let response=invoke("generate_chat_completion",json!({"requestId":format!("{prefix}_normal"),"dto":dto})).await;assert_eq!(response["ok"],true,"{response}");
        let id=format!("{prefix}_stream");let response=invoke("start_chat_completion_stream",json!({"streamId":id,"dto":dto})).await;assert_eq!(response["ok"],true,"{response}");
        for _ in 0..100 {let read=invoke("read_chat_completion_stream",json!({"streamId":id,"afterSeq":0})).await;if read["data"]["status"]=="done" {break;}tokio::time::sleep(std::time::Duration::from_millis(10)).await;}
        invoke("close_chat_completion_stream",json!({"streamId":id})).await;
        let response=invoke("generate_chat_completion",json!({"requestId":format!("{prefix}_missing"),"dto":dto})).await;assert_eq!(response["ok"],true,"{response}");server.await.unwrap();
        let root=&crate::host::runtime::runtime().unwrap().context.paths.data_root;
        let (events,_)=usage_ledger::read(&usage_ledger::ledger_path(root)).unwrap();let events:Vec<_>=events.iter().filter(|e|e.request_key.starts_with(&prefix)).collect();
        assert_eq!(events.len(),3);assert_eq!(events[0].usage.total_tokens,Some(15));assert_eq!(events[1].usage.total_tokens,Some(120));assert_eq!(events[1].usage.cached_tokens,Some(40));assert!(events[2].usage.is_empty());assert!(events.iter().all(|e|e.complete));
        assert!(!serde_json::to_string(&events).unwrap().contains("private-test"));
    }

}
