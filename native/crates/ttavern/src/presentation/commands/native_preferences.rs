//! Native ArkUI preferences backed by ST settings, with optimistic concurrency.
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use tt_application::dto::settings_dto::UserSettingsRevisionDto;
use crate::host::Ctx;
use crate::presentation::{dispatch::Args, errors::CommandError};
use super::settings::get_sillytavern_settings;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct NativePreferences {
    pub user_name: String,
    #[serde(default)]
    pub user_avatar: String,
    pub persona_description: String,
    #[serde(default = "default_persona_position")]
    pub persona_position: String,
    #[serde(default = "default_persona_role")]
    pub persona_role: String,
    #[serde(default = "default_persona_depth")]
    pub persona_depth: usize,
    pub system_prompt: String,
    pub system_prompt_enabled: bool,
    pub prefer_character_prompt: bool,
    pub prefer_character_jailbreak: bool,
    pub auto_scroll_chat_to_bottom: bool,
    pub confirm_message_delete: bool,
    pub trim_spaces: bool,
    pub temperature: f64,
    pub top_p: f64,
    pub max_tokens: u64,
    #[serde(default = "default_context_tokens")]
    pub context_tokens: usize,
    #[serde(default = "default_reasoning_effort")]
    pub reasoning_effort: String,
}
fn default_context_tokens() -> usize { 32768 }
fn default_reasoning_effort() -> String { "auto".into() }
fn default_persona_position() -> String { "after_character".into() }
fn default_persona_role() -> String { "system".into() }
fn default_persona_depth() -> usize { 4 }
impl Default for NativePreferences {
    fn default() -> Self { Self {
        user_name: "User".into(), user_avatar: String::new(), persona_description: String::new(),
        persona_position: default_persona_position(), persona_role: default_persona_role(), persona_depth: 4,
        system_prompt: "Write {{char}}'s next reply in a fictional chat between {{char}} and {{user}}.".into(),
        system_prompt_enabled: true, prefer_character_prompt: true,
        prefer_character_jailbreak: true, auto_scroll_chat_to_bottom: true,
        confirm_message_delete: true, trim_spaces: true, temperature: 1.0, top_p: 1.0, max_tokens: 8192,
        context_tokens: default_context_tokens(), reasoning_effort: default_reasoning_effort(),
    } }
}
impl NativePreferences {
    fn read(s: &Value) -> Self {
        let mut p = Self::default();
        let power = &s["power_user"];
        if let Some(v) = s["name1"].as_str() { p.user_name = v.into(); }
        if let Some(v) = s["user_avatar"].as_str() { p.user_avatar = v.into(); }
        if let Some(v) = power["harmony_persona_position"].as_str() { p.persona_position = v.into(); }
        if let Some(v) = power["harmony_persona_role"].as_str() { p.persona_role = v.into(); }
        if let Some(v) = power["harmony_persona_depth"].as_u64() { p.persona_depth = v as usize; }
        if let Some(v) = power["persona_description"].as_str() { p.persona_description = v.into(); }
        if let Some(v) = power["sysprompt"]["content"].as_str() { p.system_prompt = v.into(); }
        if let Some(v) = power["sysprompt"]["enabled"].as_bool() { p.system_prompt_enabled = v; }
        macro_rules! flag { ($($f:ident),*) => { $(if let Some(v) = power[stringify!($f)].as_bool() { p.$f = v; })* }; }
        flag!(prefer_character_prompt, prefer_character_jailbreak, auto_scroll_chat_to_bottom, confirm_message_delete, trim_spaces);
        if let Some(v) = s["oai_settings"]["temp_openai"].as_f64() { p.temperature = v; }
        if let Some(v) = s["oai_settings"]["top_p_openai"].as_f64() { p.top_p = v; }
        if let Some(v) = s["oai_settings"]["openai_max_tokens"].as_u64() { p.max_tokens = v; }
        if let Some(v) = power["harmony_context_tokens"].as_u64() { p.context_tokens = v as usize; }
        if let Some(v) = power["harmony_reasoning_effort"].as_str() { p.reasoning_effort = v.into(); }
        p
    }
    fn validate(&self) -> Result<(), CommandError> {
        if self.user_name.trim().is_empty() || self.user_name.len() > 256 ||
            self.user_avatar.contains(['/', '\\']) || self.user_avatar == "." || self.user_avatar == ".." ||
            self.user_avatar.len() > 256 || self.persona_depth > 100 ||
            !["before_character", "after_character", "before_history", "in_history", "after_history"].contains(&self.persona_position.as_str()) ||
            !["system", "user", "assistant"].contains(&self.persona_role.as_str()) ||
            self.persona_description.len() > 128 * 1024 || self.system_prompt.len() > 128 * 1024 ||
            !self.temperature.is_finite() || !(0.0..=2.0).contains(&self.temperature) ||
            !self.top_p.is_finite() || !(0.0..=1.0).contains(&self.top_p) ||
            !(1..=131072).contains(&self.max_tokens) || !(1024..=1048576).contains(&self.context_tokens) ||
            !["auto", "low", "medium", "high"].contains(&self.reasoning_effort.as_str()) {
            return Err(CommandError::BadRequest("Invalid identity or generation settings".into()));
        }
        Ok(())
    }
    fn merge(&self, s: &mut Value) -> Result<(), CommandError> {
        self.validate()?;
        s["name1"] = json!(self.user_name.trim());
        s["user_avatar"] = json!(self.user_avatar);
        for key in ["power_user", "oai_settings"] {
            if s[key].is_null() { s[key] = json!({}); }
            if !s[key].is_object() { return Err(CommandError::BadRequest(format!("{key} must be an object"))); }
        }
        let p = &mut s["power_user"];
        p["persona_description"] = json!(self.persona_description);
        p["harmony_persona_position"] = json!(self.persona_position);
        p["harmony_persona_role"] = json!(self.persona_role);
        p["harmony_persona_depth"] = json!(self.persona_depth);
        if p["sysprompt"].is_null() { p["sysprompt"] = json!({}); }
        if !p["sysprompt"].is_object() { return Err(CommandError::BadRequest("sysprompt must be an object".into())); }
        p["sysprompt"]["enabled"] = json!(self.system_prompt_enabled);
        p["sysprompt"]["content"] = json!(self.system_prompt);
        macro_rules! flag { ($($f:ident),*) => { $(p[stringify!($f)] = json!(self.$f);)* }; }
        flag!(prefer_character_prompt, prefer_character_jailbreak, auto_scroll_chat_to_bottom, confirm_message_delete, trim_spaces);
        p["harmony_context_tokens"] = json!(self.context_tokens);
        p["harmony_reasoning_effort"] = json!(self.reasoning_effort);
        s["oai_settings"]["temp_openai"] = json!(self.temperature);
        s["oai_settings"]["top_p_openai"] = json!(self.top_p);
        s["oai_settings"]["openai_max_tokens"] = json!(self.max_tokens);
        Ok(())
    }
}

async fn snapshot(ctx: &Ctx<'_>) -> Result<(Value, Value), CommandError> {
    let aggregate = get_sillytavern_settings(ctx).await?;
    let mut settings: Value = serde_json::from_str(aggregate["settings"].as_str().ok_or_else(||
        CommandError::InternalServerError("Missing settings body".into()))?)
        .map_err(|e| CommandError::InternalServerError(e.to_string()))?;
    // Persona cards are independently stored and excluded from the settings CAS.
    // This form edits only the active description, never rewrites projected cards.
    tt_domain::models::persona::take_personas(&mut settings)
        .map_err(|e| CommandError::BadRequest(e.to_string()))?;
    Ok((settings, aggregate["tauritavern_settings_revision"].clone()))
}
pub async fn get(ctx: &Ctx<'_>) -> Result<Value, CommandError> {
    let (settings, revision) = snapshot(ctx).await?;
    let preferences = NativePreferences::read(&settings);
    let runtime = crate::host::runtime::runtime().ok_or_else(|| CommandError::BadRequest("Backend not ready".into()))?;
    let avatar_path = if preferences.user_avatar.is_empty() { String::new() } else {
        runtime.context.paths.data_root.join("default-user/User Avatars").join(&preferences.user_avatar).to_string_lossy().to_string()
    };
    Ok(json!({"preferences": preferences, "revision": revision, "avatar_path":avatar_path}))
}
pub async fn update(ctx: &Ctx<'_>, args: &Args) -> Result<Value, CommandError> {
    let preferences: NativePreferences = args.typed("preferences")?;
    if !preferences.user_avatar.is_empty() && !ctx.services.avatar_service.get_avatars().await?.contains(&preferences.user_avatar) {
        return Err(CommandError::BadRequest("Selected avatar no longer exists; choose another avatar".into()));
    }
    let expected: UserSettingsRevisionDto = args.typed("expectedRevision")?;
    let (mut settings, revision) = snapshot(ctx).await?;
    if serde_json::to_value(&expected).map_err(|e| CommandError::BadRequest(e.to_string()))? != revision {
        return Err(CommandError::Conflict("Settings changed; reload before saving".into()));
    }
    preferences.merge(&mut settings)?;
    let bytes = serde_json::to_vec(&settings).map_err(|e| CommandError::BadRequest(e.to_string()))?;
    let service = &ctx.services.settings_service;
    let begin = service.begin_commit(Some(expected)).await?;
    let result = async {
        for (index, chunk) in bytes.chunks(64 * 1024).enumerate() {
            service.append_commit(&begin.session_id, (index * 64 * 1024) as u64, chunk).await?;
        }
        service.finish_commit(&begin.session_id, bytes.len() as u64).await
    }.await;
    if result.is_err() { let _ = service.abort_commit(&begin.session_id).await; }
    let result = result?;
    if !result.persona_errors.is_empty() { return Err(CommandError::Conflict("Settings saved, but persona cards need repair; reload settings".into())); }
    get(ctx).await
}

pub async fn prepare_chat(ctx: &Ctx<'_>, args: &Args) -> Result<Value, CommandError> {
    let name = args.require("characterName")?;
    let mut dto: Value = args.typed("dto")?;
    if !dto.is_object() { return Err(CommandError::BadRequest("dto must be an object".into())); }
    let (settings, _) = snapshot(ctx).await?;
    let p = NativePreferences::read(&settings);
    let character = ctx.services.character_service.get_character(&name).await?;
    let c = serde_json::to_value(character).map_err(|e| CommandError::InternalServerError(e.to_string()))?;
    let mut history = if let Some(file) = args.optional::<String>("fileName")? {
        super::native_context::history(ctx, &name, &file).await?
    } else {
        dto["messages"].as_array().ok_or_else(|| CommandError::BadRequest("messages must be an array".into()))?.clone()
    };
    if let Some(pending) = args.optional::<String>("pendingMessage")? {
        if !pending.trim().is_empty() { history.push(json!({"role":"user","content":pending})); }
    }
    dto["messages"] = json!(assemble(&p, &c, &history)?);
    dto["temperature"] = json!(p.temperature);
    dto["top_p"] = json!(p.top_p);
    dto["max_tokens"] = json!(p.max_tokens);
    if p.reasoning_effort != "auto" {
        dto["reasoning_effort"] = json!(p.reasoning_effort);
        dto["include_reasoning"] = json!(true);
    }
    if let Some(file) = args.optional::<String>("fileName")? {
        let story = super::native_story::load(ctx, &name, &file).await?;
        super::native_story::apply(&mut dto, &story)?;
        let world = super::native_story::world_context(ctx, &name, &story).await?;
        if !world.is_empty() {
            let content = world.replace("{{char}}", c["name"].as_str().unwrap_or(&name)).replace("{{user}}", &p.user_name);
            dto["messages"].as_array_mut().unwrap().push(json!({"role":"system","content":content}));
        }
        if story.mode == "world" && story.world_update_mode == "inline" { super::native_world::append_previous(ctx, &name, &file, &mut dto).await?; }
    }
    check_context_budget(ctx, &dto, p.context_tokens).await?;
    Ok(dto)
}

pub async fn check_context_budget(ctx: &Ctx<'_>, dto: &Value, budget: usize) -> Result<(), CommandError> {
    use tt_application::dto::tokenization_dto::{OpenAiTokenCountBatchRequestDto, OpenAiTokenCountBatchItemDto};
    let counts = ctx.services.tokenization_service.count_openai_tokens_batch(OpenAiTokenCountBatchRequestDto {
        model: dto["model"].as_str().unwrap_or("gpt-4o").into(),
        requests: vec![OpenAiTokenCountBatchItemDto { messages: dto["messages"].as_array().cloned().unwrap_or_default() }],
    }).await?;
    let count = counts.token_counts.first().copied().unwrap_or(0);
    if count > budget {
        return Err(CommandError::BadRequest(format!("上下文估算 {count} Token，超过预算 {budget}；请先精简上下文或调高上下文长度。未删除任何消息；估算与服务商实际用量可能不同。")));
    }
    Ok(())
}

pub async fn avatars(ctx: &Ctx<'_>) -> Result<Value, CommandError> {
    let names = ctx.services.avatar_service.get_avatars().await?;
    let runtime = crate::host::runtime::runtime().ok_or_else(|| CommandError::BadRequest("Backend not ready".into()))?;
    let root = runtime.context.paths.data_root.join("default-user/User Avatars");
    Ok(json!(names.into_iter().map(|name| json!({"path":root.join(&name).to_string_lossy(),"name":name})).collect::<Vec<_>>()))
}
pub async fn upload_avatar(ctx: &Ctx<'_>, args: &Args) -> Result<Value, CommandError> {
    let runtime = crate::host::runtime::runtime().ok_or_else(|| CommandError::BadRequest("Backend not ready".into()))?;
    let raw = args.require("filePath")?;
    let path = std::fs::canonicalize(raw).map_err(|e| CommandError::BadRequest(e.to_string()))?;
    let allowed = std::fs::canonicalize(runtime.context.paths.app_root.join("imports"))
        .map_err(|e| CommandError::BadRequest(e.to_string()))?;
    if !path.starts_with(&allowed) || std::fs::metadata(&path).map_err(|e| CommandError::BadRequest(e.to_string()))?.len() > 20 * 1024 * 1024 {
        return Err(CommandError::BadRequest("Avatar must be an imported image under 20 MB".into()));
    }
    let uploaded = ctx.services.avatar_service.upload_avatar(&path, Some(format!("native-user-{}.png", uuid::Uuid::new_v4())), None).await?;
    let root = runtime.context.paths.data_root.join("default-user/User Avatars");
    Ok(json!({"name":uploaded.path,"path":root.join(&uploaded.path).to_string_lossy()}))
}
fn assemble(p: &NativePreferences, c: &Value, history: &[Value]) -> Result<Vec<Value>, CommandError> {
    p.validate()?;
    let text = |key: &str| c[key].as_str().unwrap_or("");
    let expand = |s: &str| s.replace("{{char}}", text("name")).replace("{{user}}", &p.user_name);
    let mut prompt = Vec::new();
    if p.system_prompt_enabled {
        prompt.push(if p.prefer_character_prompt && !text("system_prompt").trim().is_empty() {
            text("system_prompt").to_string()
        } else { p.system_prompt.clone() });
    }
    let persona = format!("{}: {}", p.user_name, p.persona_description);
    let has_persona = !p.persona_description.trim().is_empty();
    if has_persona && p.persona_position == "before_character" { prompt.push(persona.clone()); }
    for key in ["description", "personality", "scenario", "mes_example"] {
        if !text(key).trim().is_empty() { prompt.push(format!("{key}: {}", text(key))); }
    }
    if has_persona && p.persona_position == "after_character" { prompt.push(persona.clone()); }
    let mut messages = Vec::new();
    if !prompt.is_empty() { messages.push(json!({"role":"system", "content":expand(&prompt.join("\n\n"))})); }
    let header_length = messages.len();
    for message in history {
        if !message.is_object() { return Err(CommandError::BadRequest("Invalid message".into())); }
        let mut message = message.clone();
        if let Some(s) = message["content"].as_str() { message["content"] = json!(expand(s)); }
        messages.push(message);
    }
    if has_persona && ["before_history", "in_history", "after_history"].contains(&p.persona_position.as_str()) {
        let index = match p.persona_position.as_str() {
            "before_history" => header_length,
            "in_history" => header_length + history.len().saturating_sub(p.persona_depth),
            _ => messages.len(),
        };
        messages.insert(index, json!({"role":p.persona_role,"content":expand(&persona)}));
    }
    if p.prefer_character_jailbreak && !text("post_history_instructions").trim().is_empty() {
        messages.push(json!({"role":"system", "content":expand(text("post_history_instructions"))}));
    }
    Ok(messages)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[tokio::test]
    async fn avatar_upload_identity_roundtrip_and_import_boundary() {
        let root = std::env::temp_dir().join(format!("native-avatar-{}", uuid::Uuid::new_v4()));
        let media = std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../../entry/src/main/resources/rawfile/default");
        crate::host::runtime::initialize(&json!({"filesDir":root.join("files"),"databaseDir":root.join("db"),
            "cacheDir":root.join("cache"),"bundleName":"test.avatar","versionName":"1","bundledMediaDir":media}).to_string()).await.unwrap();
        let invoke = |command: &'static str, payload: Value| async move {
            serde_json::from_str::<Value>(&crate::presentation::dispatch::invoke(command, Some(&payload.to_string())).await).unwrap()
        };
        let runtime = crate::host::runtime::runtime().unwrap();
        let imports = runtime.context.paths.app_root.join("imports"); std::fs::create_dir_all(&imports).unwrap();
        let source = media.join("content/user-default.png"); let file = imports.join("avatar-fixture.png");
        std::fs::copy(&source, &file).unwrap();
        let rejected = invoke("upload_native_identity_avatar", json!({"filePath":source})).await;
        assert_eq!(rejected["ok"], false);
        let uploaded = invoke("upload_native_identity_avatar", json!({"filePath":file})).await;
        assert_eq!(uploaded["ok"], true, "{uploaded}");
        let before = invoke("get_native_preferences", json!({})).await;
        let mut preferences = before["data"]["preferences"].clone();
        preferences["user_name"] = json!("本地用户"); preferences["user_avatar"] = uploaded["data"]["name"].clone();
        preferences["persona_position"] = json!("in_history"); preferences["persona_role"] = json!("assistant"); preferences["persona_depth"] = json!(2);
        let saved = invoke("update_native_preferences", json!({"preferences":preferences,"expectedRevision":before["data"]["revision"]})).await;
        assert_eq!(saved["ok"], true, "{saved}");
        let read = invoke("get_native_preferences", json!({})).await;
        assert_eq!(read["data"]["preferences"]["user_name"], "本地用户");
        assert_eq!(read["data"]["preferences"]["user_avatar"], uploaded["data"]["name"]);
        assert_eq!(read["data"]["preferences"]["persona_depth"], 2);
        assert!(std::path::Path::new(read["data"]["avatar_path"].as_str().unwrap()).is_file());
    }
    #[test]
    fn persona_positions_roles_and_depth_are_applied_to_real_prompt() {
        let mut p = NativePreferences { user_name:"Alice".into(), persona_description:"PERSONA".into(), ..Default::default() };
        let c = json!({"name":"Bob","description":"CHARACTER"});
        let history = vec![json!({"role":"user","content":"old"}), json!({"role":"assistant","content":"recent"})];
        p.persona_position = "before_character".into();
        let a = assemble(&p, &c, &history).unwrap();
        let content = a[0]["content"].as_str().unwrap();
        assert!(content.find("PERSONA").unwrap() < content.find("CHARACTER").unwrap());
        p.persona_position = "after_character".into();
        let a = assemble(&p, &c, &history).unwrap();
        let content = a[0]["content"].as_str().unwrap();
        assert!(content.find("PERSONA").unwrap() > content.find("CHARACTER").unwrap());
        p.persona_position = "in_history".into(); p.persona_depth = 1; p.persona_role = "user".into();
        let a = assemble(&p, &c, &history).unwrap();
        assert_eq!(a[2]["role"], "user"); assert!(a[2]["content"].as_str().unwrap().contains("PERSONA"));
        assert_eq!(a[3], history[1]);
        p.persona_position = "before_history".into(); assert!(assemble(&p, &c, &history).unwrap()[1]["content"].as_str().unwrap().contains("PERSONA"));
        p.persona_position = "after_history".into(); assert!(assemble(&p, &c, &history).unwrap().last().unwrap()["content"].as_str().unwrap().contains("PERSONA"));
        p.persona_depth = 101; assert!(p.validate().is_err());
        p.persona_depth = 4; p.user_avatar = "../settings.json".into(); assert!(p.validate().is_err());
    }
    #[tokio::test]
    async fn native_settings_roundtrip_and_stale_write_conflict() {
        let root = std::env::temp_dir().join(format!("native-preferences-{}", uuid::Uuid::new_v4()));
        let media = std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../../../entry/src/main/resources/rawfile/default");
        crate::host::runtime::initialize(&json!({
            "filesDir":root.join("files"), "databaseDir":root.join("database"),
            "cacheDir":root.join("cache"), "bundleName":"com.example.harmonytavern",
            "versionName":"1.0.0", "bundledMediaDir":media
        }).to_string()).await.unwrap();
        let invoke = |command: &'static str, payload: Value| async move {
            let raw = crate::presentation::dispatch::invoke(command, Some(&payload.to_string())).await;
            serde_json::from_str::<Value>(&raw).unwrap()
        };
        let before = invoke("get_native_preferences", json!({})).await;
        assert_eq!(before["ok"], true, "{before}");
        let mut preferences = before["data"]["preferences"].clone();
        preferences["persona_description"] = json!("中文人设往返");
        preferences["trim_spaces"] = json!(false);
        let payload = json!({"preferences": preferences, "expectedRevision":before["data"]["revision"]});
        let saved = invoke("update_native_preferences", payload.clone()).await;
        assert_eq!(saved["ok"], true, "{saved}");
        assert_eq!(saved["data"]["preferences"]["persona_description"], "中文人设往返");
        assert_eq!(saved["data"]["preferences"]["trim_spaces"], false);
        let stale = invoke("update_native_preferences", payload).await;
        assert_eq!(stale["error"]["code"], "conflict", "{stale}");
    }
    #[test]
    fn merges_without_losing_extensions_or_other_personas() {
        let mut s = json!({"extension_settings":{"keep":true},"power_user":{"personas":{"a":"A"},"other":42}});
        let p = NativePreferences { persona_description: "身份".into(), ..Default::default() };
        p.merge(&mut s).unwrap();
        assert_eq!(s["extension_settings"]["keep"], true);
        assert_eq!(s["power_user"]["personas"]["a"], "A");
        assert_eq!(s["power_user"]["other"], 42);
        assert_eq!(NativePreferences::read(&s).persona_description, "身份");
    }
    #[test]
    fn prompt_switches_macros_and_multimodal_history() {
        let mut p = NativePreferences { user_name:"Alice".into(), persona_description:"{{user}} is a writer".into(), ..Default::default() };
        let c = json!({"name":"Bob","description":"{{char}} is kind", "system_prompt":"custom {{user}}", "post_history_instructions":"stay {{char}}"});
        let history = vec![json!({"role":"user","content":[{"type":"text","text":"hi"}]})];
        let a = assemble(&p, &c, &history).unwrap();
        assert!(a[0]["content"].as_str().unwrap().contains("custom Alice"));
        assert!(a[0]["content"].as_str().unwrap().contains("Bob is kind"));
        assert_eq!(a[1], history[0]);
        assert_eq!(a[2]["content"], "stay Bob");
        p.system_prompt_enabled = false; p.prefer_character_jailbreak = false;
        let b = assemble(&p, &c, &history).unwrap();
        assert_eq!(b.len(), 2);
        assert!(!b[0]["content"].as_str().unwrap().contains("custom"));
    }
    #[test]
    fn rejects_invalid_generation_values() {
        let mut p = NativePreferences { temperature:f64::NAN, ..Default::default() };
        assert!(p.validate().is_err());
        p.temperature = 1.0; p.max_tokens = 0;
        assert!(p.validate().is_err());
    }
}
