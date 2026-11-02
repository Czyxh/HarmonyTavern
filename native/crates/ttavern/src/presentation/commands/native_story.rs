use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use std::hash::{Hash, Hasher};
use tt_application::dto::chat_dto::{AddMessageDto, ChatDto, CreateChatDto, MessageExtraDto, RenameChatDto};
use crate::host::Ctx;
use crate::presentation::{dispatch::Args, errors::CommandError};

const NAMESPACE: &str = "harmony_native";
const KEY: &str = "story";
pub const OPTIONS_OPEN: &str = "<story_options>";
const OPTIONS_CLOSE: &str = "</story_options>";

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct StorySettings {
    pub title: String,
    pub scenario: String,
    pub style: String,
    pub author_note: String,
    pub opening_message: String,
    pub mode: String,
    pub choice_count: usize,
    pub choices_enabled: bool,
    pub world_books: Vec<String>,
    #[serde(skip_serializing_if = "String::is_empty")]
    pub world_ui_request: String,
    #[serde(skip_serializing_if = "String::is_empty")]
    pub world_model_id: String,
    pub world_update_mode: String,
    pub world_sidebar_side: String,
}
impl Default for StorySettings {
    fn default() -> Self { Self { title: String::new(), scenario: String::new(), style: String::new(),
        author_note: String::new(), opening_message: String::new(), mode: "free".into(), choice_count: 3, choices_enabled: false, world_books: Vec::new(), world_ui_request: String::new(),
        world_model_id: String::new(), world_update_mode: "auxiliary".into(), world_sidebar_side: "auto".into() } }
}
impl StorySettings {
    fn offers_choices(&self) -> bool { self.choices_enabled || self.mode == "choices" }

    fn validate(&self) -> Result<(), CommandError> {
        if self.title.chars().count() > 100 || self.scenario.len() > 65536 || self.style.len() > 8192 ||
            self.author_note.len() > 32768 || self.opening_message.len() > 65536 ||
            !["free", "choices", "world"].contains(&self.mode.as_str()) || !(2..=6).contains(&self.choice_count)
            || self.world_ui_request.chars().count() > 3000
            || self.world_model_id.len() > 2048 || !["auxiliary", "inline", "manual"].contains(&self.world_update_mode.as_str())
            || !["auto", "left", "right"].contains(&self.world_sidebar_side.as_str())
            || self.world_books.len() > 8 || self.world_books.iter().enumerate().any(|(index, name)|
                name.trim().is_empty() || name.chars().count() > 200 || self.world_books[..index].contains(name)) {
            return Err(CommandError::BadRequest("Invalid story settings".into()));
        } Ok(())
    }
}

pub async fn load(ctx: &Ctx<'_>, character: &str, file: &str) -> Result<StorySettings, CommandError> {
    ctx.services.chat_service.get_chat(character, file).await?;
    if ctx.services.chat_service.get_character_chat_integrity(character, file).await?.is_none() {
        return Ok(StorySettings::default());
    }
    let raw = match ctx.services.chat_service.get_character_chat_store_json(character, file, NAMESPACE, KEY).await {
        Ok(raw) => raw,
        Err(tt_application::errors::ApplicationError::NotFound(_)) => return Ok(StorySettings::default()),
        Err(error) => return Err(error.into()),
    };
    let story: StorySettings = if raw.is_null() { StorySettings::default() } else { serde_json::from_value(raw)
        .map_err(|e| CommandError::BadRequest(format!("Invalid stored story: {e}")))? };
    story.validate()?; Ok(story)
}
pub async fn get(ctx: &Ctx<'_>, args: &Args) -> Result<Value, CommandError> {
    Ok(json!(load(ctx, &args.require("characterName")?, &args.require("fileName")?).await?))
}
pub async fn save(ctx: &Ctx<'_>, args: &Args) -> Result<Value, CommandError> {
    let character = args.require("characterName")?; let file = args.require("fileName")?;
    let story: StorySettings = args.typed("story")?; story.validate()?;
    world_context(ctx, &character, &story).await?;
    // Verify the conversation before creating an extension-store entry.
    ctx.services.chat_service.ensure_character_chat_integrity(&character, &file).await?;
    ctx.services.chat_service.set_character_chat_store_json(&character, &file, NAMESPACE, KEY, json!(story)).await?;
    Ok(json!(story))
}
pub async fn create(ctx: &Ctx<'_>, args: &Args) -> Result<Value, CommandError> {
    let character = args.require("characterName")?;
    let story: StorySettings = args.typed("story")?; story.validate()?;
    world_context(ctx, &character, &story).await?;
    let preferences = super::native_preferences::get(ctx).await?;
    let name = preferences["preferences"]["user_name"].as_str().unwrap_or("User");
    let mut chat = ctx.services.chat_service.create_chat(CreateChatDto {
        character_name: character.clone(), user_name: name.into(),
        first_message: (!story.opening_message.trim().is_empty()).then(|| story.opening_message.clone())
    }).await?;
    let result: Result<(), CommandError> = async {
        if !story.title.trim().is_empty() {
            let title = tt_domain::models::filename::sanitize_filename(story.title.trim());
            let suffix = uuid::Uuid::new_v4().to_string();
            let new_name = format!("{}-{}", title, &suffix[..8]);
            let renamed = ctx.services.chat_service.rename_chat(RenameChatDto {
                character_name: character.clone(), old_file_name: chat.file_name.clone(), new_file_name: new_name
            }).await?;
            chat.file_name = renamed.clone();
            chat = ctx.services.chat_service.get_chat(&character, &renamed).await?;
        }
        ctx.services.chat_service.set_character_chat_store_json(&character, &chat.file_name, NAMESPACE, KEY, json!(story)).await?;
        Ok(())
    }.await;
    if let Err(error) = result {
        let _ = ctx.services.chat_service.delete_chat(&character, &chat.file_name).await;
        return Err(error);
    }
    Ok(json!(chat))
}

/// Enabled, non-empty entries of one book (SillyTavern object form or character-card array form), in insertion order.
fn book_text(book: &Value) -> Result<String, CommandError> {
    let entries: Vec<&Value> = match &book["entries"] {
        Value::Object(entries) => entries.values().collect(),
        Value::Array(entries) => entries.iter().collect(),
        _ => return Err(CommandError::BadRequest("World book has no valid entries".into())),
    };
    let mut enabled: Vec<&Value> = entries.into_iter().filter(|entry|
        entry["disable"] != true && entry["enabled"] != false && entry["content"].as_str().is_some_and(|text| !text.trim().is_empty())).collect();
    enabled.sort_by_key(|entry| entry["order"].as_i64().or_else(|| entry["insertion_order"].as_i64()).unwrap_or(100));
    Ok(enabled.iter().map(|entry| entry["content"].as_str().unwrap_or("")).collect::<Vec<_>>().join("\n\n"))
}

#[cfg(test)]
pub fn book_text_for_tests(book: &Value) -> Result<String, CommandError> { book_text(book) }

/// The world book embedded in the character card, if any, as prompt reference text.
async fn character_book_context(ctx: &Ctx<'_>, character: &str) -> Result<String, CommandError> {
    let card = ctx.services.character_service.get_character(character).await?;
    let card = serde_json::to_value(card).map_err(|error| CommandError::InternalServerError(error.to_string()))?;
    // CharacterDto is flat; the raw card JSON is kept in `json_data`. Prefer the parsed field, fall back to the card itself.
    let raw: Value = card["json_data"].as_str().and_then(|text| serde_json::from_str(text).ok()).unwrap_or(Value::Null);
    let book = [&card["character_book"], &raw["data"]["character_book"], &raw["character_book"]]
        .into_iter().find(|book| book.is_object()).cloned().unwrap_or(Value::Null);
    let book = &book;
    if !book.is_object() { return Ok(String::new()); }
    let content = book_text(book)?;
    if content.len() > 131072 { return Err(CommandError::BadRequest("角色卡内置世界书超过 128 KiB，请改选更精简的世界书".into())); }
    let name = book["name"].as_str().filter(|name| !name.trim().is_empty()).unwrap_or("角色卡内置世界书");
    Ok(if content.is_empty() { String::new() } else { format!("World reference — {name}:\n{content}") })
}

pub async fn world_context(ctx: &Ctx<'_>, character: &str, story: &StorySettings) -> Result<String, CommandError> {
    if story.world_books.is_empty() {
        // Creative mode may rely on the card's own book when no library book is selected.
        let embedded = if story.mode == "world" { character_book_context(ctx, character).await? } else { String::new() };
        if story.mode == "world" && embedded.trim().is_empty() {
            return Err(CommandError::BadRequest("创造模式需要世界书：请选择一本世界书，或使用带有启用条目的角色卡内置世界书。".into()));
        }
        return Ok(embedded);
    }
    let existing = ctx.services.world_info_service.list_world_infos().await?;
    let mut sections = Vec::new();
    let mut size = 0usize;
    for name in &story.world_books {
        if !existing.contains(name) { return Err(CommandError::BadRequest(format!("Selected world book no longer exists: {name}"))); }
        let document = ctx.services.world_info_service.get_world_info(name).await?;
        let book: Value = serde_json::from_slice(&document.bytes)
            .map_err(|error| CommandError::BadRequest(format!("Invalid world book {name}: {error}")))?;
        let entries: Vec<&Value> = match &book["entries"] {
            Value::Object(entries) => entries.values().collect(),
            Value::Array(entries) => entries.iter().collect(),
            _ => return Err(CommandError::BadRequest(format!("World book has no valid entries: {name}"))),
        };
        let mut enabled: Vec<&Value> = entries.into_iter().filter(|entry|
            entry["disable"] != true && entry["enabled"] != false && entry["content"].as_str().is_some_and(|text| !text.trim().is_empty())).collect();
        enabled.sort_by_key(|entry| entry["order"].as_i64().unwrap_or(100));
        let content = enabled.iter().map(|entry| entry["content"].as_str().unwrap_or("")).collect::<Vec<_>>().join("\n\n");
        size += content.len() + name.len();
        if size > 131072 { return Err(CommandError::BadRequest("Selected world reference exceeds 128 KiB; select fewer books".into())); }
        if !content.is_empty() { sections.push(format!("World reference — {name}:\n{content}")); }
    }
    let reference = sections.join("\n\n");
    if story.mode == "world" && reference.trim().is_empty() {
        return Err(CommandError::BadRequest("世界状态模式需要世界书中至少一条非空的启用内容。".into()));
    }
    Ok(reference)
}

pub fn apply(dto: &mut Value, story: &StorySettings) -> Result<(), CommandError> {
    story.validate()?;
    let messages = dto["messages"].as_array_mut().ok_or_else(|| CommandError::BadRequest("messages must be an array".into()))?;
    let mut context = Vec::new();
    for (label, value) in [("Story", &story.title), ("Setting", &story.scenario),
        ("Narration style", &story.style), ("Author instructions", &story.author_note)] {
        if !value.trim().is_empty() { context.push(format!("{label}: {value}")); }
    }
    if !context.is_empty() { messages.push(json!({"role":"system","content":context.join("\n\n")})); }
    if story.mode == "world" && story.world_update_mode == "inline" {
        messages.push(json!({"role":"system","content":super::native_world::instruction(story)}));
    }
    if story.offers_choices() {
        messages.push(json!({"role":"system","content":format!(
            "After the narrative, offer {} distinct choices for the USER in the conversation's language. End with exactly <story_options>[{{\"label\":\"brief description of the choice\",\"reply\":\"the exact words I say to the character\"}},...]</story_options>. Every reply MUST be a natural first-person user utterance, without option numbering, explanations, stage directions, or a list of choices. The label describes the intent; the reply contains ONLY what the user actually says. Keep labels under 120 characters and replies under 500 characters. Never choose or speak for the user in the narrative. No code fences.", story.choice_count)}));
    }
    Ok(())
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct StoryOption {
    label: String,
    reply: String,
}

fn clean_options(raw: Value, limit: usize) -> Vec<StoryOption> {
    let Some(values) = raw.as_array() else { return Vec::new(); };
    let mut clean: Vec<StoryOption> = Vec::new();
    for value in values {
        let Ok(option) = serde_json::from_value::<StoryOption>(value.clone()) else { continue; };
        let option = StoryOption { label: option.label.trim().into(), reply: option.reply.trim().into() };
        if option.label.is_empty() || option.label.chars().count() > 120 || option.reply.is_empty()
            || option.reply.chars().count() > 500 || option.reply.contains(OPTIONS_OPEN)
            || option.reply.contains(OPTIONS_CLOSE) || clean.iter().any(|existing| existing.reply == option.reply) {
            continue;
        }
        clean.push(option);
        if clean.len() == limit { break; }
    }
    if clean.len() < 2 { clean.clear(); }
    clean
}

fn option_json(raw: &str) -> Option<Value> {
    let trimmed = raw.trim();
    let content = if trimmed.starts_with("```") {
        trimmed.split_once('\n')?.1.trim_end().strip_suffix("```")?.trim()
    } else { trimmed };
    serde_json::from_str(content).ok()
}

pub fn parse_reply(text: &str, story: &StorySettings) -> (String, Vec<StoryOption>) {
    if !story.offers_choices() { return (text.to_string(), Vec::new()); }
    let Some(start) = text.rfind(OPTIONS_OPEN) else { return (text.to_string(), Vec::new()); };
    let body = text[..start].trim_end().to_string();
    let tail = &text[start + OPTIONS_OPEN.len()..];
    let Some(end) = tail.find(OPTIONS_CLOSE) else { return (body, Vec::new()); };
    let suffix = tail[end + OPTIONS_CLOSE.len()..].trim();
    let body = if suffix.starts_with("<world_state>") { format!("{body}\n{suffix}") } else { body };
    let Some(options) = option_json(&tail[..end]) else { return (body, Vec::new()); };
    (body, clean_options(options, story.choice_count))
}

fn choice_turn(chat: &ChatDto, story: &StorySettings) -> String {
    let mut hasher = std::collections::hash_map::DefaultHasher::new();
    chat.file_name.hash(&mut hasher);
    json!(story).to_string().hash(&mut hasher);
    for message in &chat.messages {
        message.name.hash(&mut hasher);
        message.mes.hash(&mut hasher);
        message.send_date.hash(&mut hasher);
        message.is_user.hash(&mut hasher);
        message.is_system.hash(&mut hasher);
    }
    format!("{:016x}", hasher.finish())
}

pub async fn get_choices(ctx: &Ctx<'_>, args: &Args) -> Result<Value, CommandError> {
    let character = args.require("characterName")?;
    let file = args.require("fileName")?;
    let story = load(ctx, &character, &file).await?;
    let chat = ctx.services.chat_service.get_chat(&character, &file).await?;
    let turn = choice_turn(&chat, &story);
    let last = chat.messages.iter().rev().find(|message| !message.is_system);
    let needs_options = story.offers_choices() && last.is_none_or(|message| !message.is_user);
    let mut options = Vec::new();
    if needs_options {
        if ctx.services.chat_service.get_character_chat_integrity(&character, &file).await?.is_some() {
            match ctx.services.chat_service.get_character_chat_store_json(&character, &file, NAMESPACE, "choices_turn").await {
                Ok(cached) if cached["turn"] == turn => options = clean_options(cached["options"].clone(), story.choice_count),
                Ok(_) | Err(tt_application::errors::ApplicationError::NotFound(_)) => {},
                Err(error) => return Err(error.into()),
            }
        }
    }
    Ok(json!({"turn":turn,"options":options,"needs_options":needs_options}))
}

pub async fn prepare_choices(ctx: &Ctx<'_>, args: &Args) -> Result<Value, CommandError> {
    let mut dto = super::native_preferences::prepare_chat(ctx, args).await?;
    let story = load(ctx, &args.require("characterName")?, &args.require("fileName")?).await?;
    if !story.offers_choices() { return Err(CommandError::BadRequest("Story choices are disabled".into())); }
    dto["messages"].as_array_mut().ok_or_else(|| CommandError::BadRequest("messages must be an array".into()))?
        .push(json!({"role":"system","content":format!(
            "This request ONLY generates the USER's next {} reply choices for the current scene. Do not continue the story, add character speech, or add a user message to history. Return ONLY <story_options>[{{\"label\":\"brief intent\",\"reply\":\"the exact first-person words I say\"}},...]</story_options>. The reply must be actual user speech, not an action description or option list. Respect the story and persona, use the current conversation language, and keep each label under 120 characters and reply under 500 characters.", story.choice_count)}));
    dto["_harmony_usage_kind"] = json!("choices");
    Ok(dto)
}

pub async fn commit_choices(ctx: &Ctx<'_>, args: &Args) -> Result<Value, CommandError> {
    let character = args.require("characterName")?;
    let file = args.require("fileName")?;
    let story = load(ctx, &character, &file).await?;
    let chat = ctx.services.chat_service.get_chat(&character, &file).await?;
    let turn = choice_turn(&chat, &story);
    if turn != args.require("expectedTurn")? || !story.offers_choices()
        || chat.messages.iter().rev().find(|message| !message.is_system).is_some_and(|message| message.is_user) {
        return Err(CommandError::Conflict("Conversation changed while preparing choices".into()));
    }
    let text = args.require("text")?;
    let (_, mut options) = parse_reply(&text, &story);
    if options.is_empty() {
        if let Some(raw) = option_json(&text) { options = clean_options(raw, story.choice_count); }
    }
    if options.len() < 2 { return Err(CommandError::BadRequest("Model returned no valid user reply choices; retry or type your own reply".into())); }
    ctx.services.chat_service.ensure_character_chat_integrity(&character, &file).await?;
    ctx.services.chat_service.set_character_chat_store_json(&character, &file, NAMESPACE, "choices_turn",
        json!({"turn":turn,"options":options})).await?;
    Ok(json!({"turn":turn,"options":options,"needs_options":true}))
}

pub async fn commit_reply(ctx: &Ctx<'_>, args: &Args) -> Result<Value, CommandError> {
    let character = args.require("characterName")?; let file = args.require("fileName")?;
    let text = args.require("text")?;
    let story = load(ctx, &character, &file).await?;
    let (body, choices) = parse_reply(&text, &story);
    let (body, mut world_state, mut world_issue) = if story.mode == "world" && story.world_update_mode == "inline" { super::native_world::split_reply(&body) }
        else { (body, None, String::new()) };
    if world_state.is_some() && args.optional::<String>("expectedWorldConfig")?.as_deref()
        != Some(super::native_world::config_fingerprint(ctx, &character, &story).await?.as_str()) {
        world_state = None;
        world_issue = "世界书或界面需求在生成期间发生变化，剧情已保留，旧版本状态未应用。请重新生成界面。".into();
    }
    if body.trim().is_empty() { return Err(CommandError::BadRequest("Model returned no narrative text".into())); }
    let replies: Vec<&str> = choices.iter().map(|option| option.reply.as_str()).collect();
    let usage: Option<crate::presentation::token_usage::TokenUsage> = args.optional("usage")?;
    let usage_complete: bool = args.optional("usageComplete")?.unwrap_or(true);
    let reasoning: String = args.optional("reasoning")?.unwrap_or_default();
    let reasoning_truncated: bool = args.optional("reasoningTruncated")?.unwrap_or(false);
    if reasoning.len() > 512 * 1024 { return Err(CommandError::BadRequest("Reasoning exceeds storage limit".into())); }
    let request: String = args.optional("usageRequest")?.unwrap_or_default();
    let model: String = args.optional("model")?.unwrap_or_default();
    let mut metadata = json!({"harmony_story_choices":replies,"harmony_story_options":choices,"harmony_usage_recorded":true});
    if !request.is_empty() { metadata["harmony_usage_request"] = json!(request.chars().take(128).collect::<String>()); }
    if !model.is_empty() { metadata["model"] = json!(model.chars().take(256).collect::<String>()); }
    if story.mode == "world" {
        metadata["harmony_world_state"] = json!(world_state);
        if !world_issue.is_empty() { metadata["harmony_world_state_issue"] = json!(world_issue); }
    }
    if let Some(usage) = usage.filter(|usage| !usage.is_empty()) {
        metadata["harmony_token_usage"] = serde_json::to_value(usage)
            .map_err(|e| CommandError::InternalServerError(e.to_string()))?;
        metadata["harmony_usage_complete"] = json!(usage_complete);
    }
    if !reasoning.is_empty() {
        metadata["reasoning"] = json!(reasoning);
        metadata["harmony_reasoning_truncated"] = json!(reasoning_truncated);
    }
    let extra: MessageExtraDto = serde_json::from_value(metadata)
        .map_err(|e| CommandError::InternalServerError(e.to_string()))?;
    let chat = ctx.services.chat_service.add_message(AddMessageDto { character_name: character.clone(),
        file_name: file.clone(), is_user: false, content: body, extra: Some(extra) }).await?;
    if let Some(state) = world_state {
        if let Err(error) = super::native_world::save_state(ctx, &chat, &story, state).await {
            tracing::warn!("Reply saved, but its optional world-state snapshot could not be written: {error}");
        }
    }
    if !choices.is_empty() {
        let turn = choice_turn(&chat, &story);
        if let Err(error) = ctx.services.chat_service.set_character_chat_store_json(&character, &file, NAMESPACE,
            "choices_turn", json!({"turn":turn,"options":choices})).await {
            tracing::warn!("Reply saved, but its optional story-choice cache could not be written: {error}");
        }
    }
    Ok(json!({"chat":chat,"choices":choices}))
}

#[cfg(test)]
mod tests {
    use super::*;
    async fn invoke(command: &str, payload: Value) -> Value {
        serde_json::from_str(&crate::presentation::dispatch::invoke(command, Some(&payload.to_string())).await).unwrap()
    }
    #[tokio::test]
    async fn story_create_prompt_reply_and_mode_roundtrip() {
        let root = std::env::temp_dir().join(format!("native-story-{}", uuid::Uuid::new_v4()));
        let media = std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../../entry/src/main/resources/rawfile/default");
        crate::host::runtime::initialize(&json!({"filesDir":root.join("files"),"databaseDir":root.join("db"),
            "cacheDir":root.join("cache"),"bundleName":"test.story","versionName":"1","bundledMediaDir":media}).to_string()).await.unwrap();
        let seed = invoke("initialize_default_content", json!({})).await; assert_eq!(seed["ok"], true, "{seed}");
        let characters = invoke("get_all_characters", json!({})).await;
        let avatar = characters["data"][0]["avatar"].as_str().unwrap();
        let name = avatar.rsplit_once('.').unwrap().0;
        let runtime = crate::host::runtime::runtime().unwrap();
        let directory = runtime.context.paths.data_root.join("default-user/chats").join(name);
        std::fs::create_dir_all(&directory).unwrap();
        let legacy_path = directory.join("legacy-story.jsonl");
        let header = json!({"user_name":"User","character_name":name,"create_date":"2026-11-01","chat_metadata":{}});
        std::fs::write(&legacy_path, format!("{header}\n")).unwrap();
        let legacy = invoke("get_native_story", json!({"characterName":name,"fileName":"legacy-story"})).await;
        assert_eq!(legacy["ok"], true, "{legacy}");
        assert_eq!(legacy["data"]["mode"], "free");
        let migrated = invoke("save_native_story", json!({"characterName":name,"fileName":"legacy-story","story":StorySettings::default()})).await;
        assert_eq!(migrated["ok"], true, "{migrated}");
        let legacy_chat = invoke("get_chat", json!({"characterName":name,"fileName":"legacy-story"})).await;
        assert!(legacy_chat["data"]["chat_metadata"]["integrity"].is_string());
        let plain = invoke("create_chat", json!({"dto":{"character_name":name,"user_name":"User","first_message":null}})).await;
        assert_eq!(plain["ok"], true, "{plain}");
        let default_story = invoke("get_native_story", json!({"characterName":name,"fileName":plain["data"]["file_name"]})).await;
        assert_eq!(default_story["data"]["mode"], "free", "{default_story}");
        let worlds = runtime.context.paths.data_root.join("default-user/worlds");
        std::fs::create_dir_all(&worlds).unwrap();
        std::fs::write(worlds.join("Story reference.json"), json!({"entries":{
            "0":{"content":"The selected world has two moons.","disable":false,"order":10},
            "1":{"content":"DISABLED_WORLD_SENTINEL","disable":true}
        }}).to_string()).unwrap();
        let story = StorySettings { title:"测试故事".into(), scenario:"雨夜的小镇".into(), style:"第二人称".into(),
            opening_message:"自定义开场".into(), mode:"choices".into(), world_books:vec!["Story reference".into()], ..Default::default() };
        let created = invoke("create_native_story", json!({"characterName":name,"story":story})).await;
        assert_eq!(created["ok"], true, "{created}");
        let file = created["data"]["file_name"].as_str().unwrap();
        assert_eq!(created["data"]["messages"][0]["mes"], "自定义开场");
        let stored = invoke("get_native_story", json!({"characterName":name,"fileName":file})).await;
        assert_eq!(stored["data"]["scenario"], "雨夜的小镇");
        let first_turn = invoke("get_native_story_choices", json!({"characterName":name,"fileName":file})).await;
        assert_eq!(first_turn["data"]["needs_options"], true);
        assert_eq!(first_turn["data"]["options"], json!([]));
        let candidates = "<story_options>[{\"label\":\"问候守卫\",\"reply\":\"你好，请问这里是什么地方？\"},{\"label\":\"请求帮助\",\"reply\":\"你能帮我找一处落脚的地方吗？\"}]</story_options>";
        let saved_choices = invoke("commit_native_story_choices", json!({"characterName":name,"fileName":file,
            "expectedTurn":first_turn["data"]["turn"],"text":candidates})).await;
        assert_eq!(saved_choices["ok"], true, "{saved_choices}");
        let repeated = invoke("get_native_story_choices", json!({"characterName":name,"fileName":file})).await;
        assert_eq!(repeated["data"]["options"][0]["reply"], "你好，请问这里是什么地方？");
        let unchanged = invoke("get_chat", json!({"characterName":name,"fileName":file})).await;
        assert_eq!(unchanged["data"]["messages"].as_array().unwrap().len(), 1);
        let prepared = invoke("prepare_native_chat", json!({"characterName":name,"fileName":file,
            "dto":{"messages":[{"role":"user","content":"开始"}]}})).await;
        assert_eq!(prepared["ok"], true, "{prepared}");
        assert!(prepared["data"]["messages"].to_string().contains(OPTIONS_OPEN));
        assert!(prepared["data"]["messages"].to_string().contains("two moons"));
        assert!(!prepared["data"]["messages"].to_string().contains("DISABLED_WORLD_SENTINEL"));
        let unknown = StorySettings { world_books:vec!["Missing reference".into()], ..story.clone() };
        let rejected = invoke("save_native_story", json!({"characterName":name,"fileName":file,"story":unknown})).await;
        assert_eq!(rejected["ok"], false);
        assert_eq!(invoke("get_native_story", json!({"characterName":name,"fileName":file})).await["data"]["world_books"], json!(["Story reference"]));
        let option_prompt = invoke("prepare_native_story_choices", json!({"characterName":name,"fileName":file,
            "dto":{"messages":[{"role":"assistant","content":"自定义开场"}]}})).await;
        assert_eq!(option_prompt["ok"], true, "{option_prompt}");
        assert!(option_prompt["data"]["messages"].as_array().unwrap().last().unwrap()["content"].as_str().unwrap().contains("ONLY generates"));
        let committed = invoke("commit_native_story_reply", json!({"characterName":name,"fileName":file,
            "usage":{"prompt_tokens":100,"completion_tokens":20,"total_tokens":120},"usageComplete":true,
            "reasoning":"服务商返回的思考摘要。","reasoningTruncated":false,
            "text":"走进小镇。<story_options>[{\"label\":\"推开门\",\"reply\":\"有人在吗？\"},{\"label\":\"询问守卫\",\"reply\":\"请问这里安全么？\"},{\"label\":\"在外等待\",\"reply\":\"我想先在这里等一会。\"}]</story_options>"})).await;
        assert_eq!(committed["ok"], true, "{committed}");
        assert_eq!(committed["data"]["chat"]["messages"][1]["mes"], "走进小镇。");
        let stale = invoke("commit_native_story_choices", json!({"characterName":name,"fileName":file,
            "expectedTurn":first_turn["data"]["turn"],"text":candidates})).await;
        assert_eq!(stale["ok"], false);
        let read = invoke("get_chat", json!({"characterName":name,"fileName":file})).await;
        assert_eq!(read["data"]["messages"][1]["extra"]["harmony_story_choices"][1], "请问这里安全么？");
        assert_eq!(read["data"]["messages"][1]["extra"]["harmony_story_options"][1]["label"], "询问守卫");
        assert_eq!(read["data"]["messages"][1]["extra"]["harmony_token_usage"]["total_tokens"], 120);
        assert_eq!(read["data"]["messages"][1]["extra"]["reasoning"], "服务商返回的思考摘要。");
        assert_eq!(read["data"]["messages"][1]["extra"]["harmony_usage_complete"], true);
        assert!(read["data"]["messages"][0]["extra"].get("harmony_token_usage").is_none());
        let current = invoke("get_native_story_choices", json!({"characterName":name,"fileName":file})).await;
        assert_eq!(current["data"]["options"][1]["reply"], "请问这里安全么？");
        let revised = StorySettings { scenario:"晴天的城门".into(), ..story.clone() };
        assert_eq!(invoke("save_native_story", json!({"characterName":name,"fileName":file,"story":revised})).await["ok"], true);
        let invalidated = invoke("get_native_story_choices", json!({"characterName":name,"fileName":file})).await;
        assert_eq!(invalidated["data"]["options"], json!([]));
        assert_ne!(invalidated["data"]["turn"], current["data"]["turn"]);
        let user = invoke("add_message", json!({"dto":{"character_name":name,"file_name":file,
            "is_user":true,"content":"请问这里安全么？","extra":null}})).await;
        assert_eq!(user["ok"], true, "{user}");
        let waiting = invoke("get_native_story_choices", json!({"characterName":name,"fileName":file})).await;
        assert_eq!(waiting["data"]["needs_options"], false);
        assert_eq!(waiting["data"]["options"], json!([]));
        let free = StorySettings { mode:"free".into(), ..story };
        let saved = invoke("save_native_story", json!({"characterName":name,"fileName":file,"story":free})).await;
        assert_eq!(saved["ok"], true, "{saved}");
        assert_eq!(invoke("get_native_story", json!({"characterName":name,"fileName":file})).await["data"]["mode"], "free");
        let partial = invoke("commit_native_story_reply", json!({"characterName":name,"fileName":file,
            "text":"收到的部分回复。","usage":{"completion_tokens":0},"usageComplete":false})).await;
        assert_eq!(partial["ok"], true, "{partial}");
        let partial_message = partial["data"]["chat"]["messages"].as_array().unwrap().last().unwrap();
        assert_eq!(partial_message["extra"]["harmony_token_usage"], json!({"completion_tokens":0}));
        assert_eq!(partial_message["extra"]["harmony_usage_complete"], false);
        let no_usage = invoke("commit_native_story_reply", json!({"characterName":name,"fileName":file,
            "text":"服务商未提供用量的回复。"})).await;
        assert_eq!(no_usage["ok"], true, "{no_usage}");
        assert!(no_usage["data"]["chat"]["messages"].as_array().unwrap().last().unwrap()["extra"].get("harmony_token_usage").is_none());
    }
    #[test]
    fn options_are_strict_validated_and_free_mode_preserves_original_text() {
        let story = StorySettings { mode:"choices".into(), ..Default::default() };
        let text = "故事正文\n<story_options>[{\"label\":\" 向前走 \",\"reply\":\"一起出发吧。\"},{\"label\":\"重复\",\"reply\":\"一起出发吧。\"},{\"label\":\"询问路人\",\"reply\":\"这里是哪？\"}]</story_options>";
        let (body, options) = parse_reply(text, &story);
        assert_eq!(body, "故事正文"); assert_eq!(options.iter().map(|option| option.reply.as_str()).collect::<Vec<_>>(), ["一起出发吧。", "这里是哪？"]);
        assert_eq!(parse_reply(text, &StorySettings::default()).0, text);
        for invalid in ["<story_options>not json</story_options>", "<story_options>[\"one\"]</story_options>",
            "<story_options>[\"one\",\"two\"]", "<story_options>[\"旧描述一\",\"旧描述二\"]</story_options>",
            "<story_options>[1,2]</story_options>"] {
            let (body, options) = parse_reply(&format!("正文{invalid}"), &story);
            assert_eq!(body, "正文"); assert!(options.is_empty());
        }
    }
    #[test]
    fn labels_and_actual_user_speech_remain_separate() {
        let story = StorySettings { mode:"choices".into(), ..Default::default() };
        let (body, options) = parse_reply("守卫看着你。<story_options>[{\"label\":\"询问道路\",\"reply\":\"请问去小镇应该走哪条路？\"},{\"label\":\"表达感谢\",\"reply\":\"谢谢你愿意帮我。\"}]</story_options>", &story);
        assert_eq!(body, "守卫看着你。");
        assert_eq!(options[0].label, "询问道路");
        assert_eq!(options[0].reply, "请问去小镇应该走哪条路？");
        assert_ne!(options[0].label, options[0].reply);
        let invalid = json!([{"label":"只描述动作","reply":""},{"label":"重复","reply":"你好"},{"label":"另一个重复","reply":"你好"}]);
        let fenced = "正文<story_options>```json\n[{\"label\":\"问候\",\"reply\":\"你好。\"},{\"label\":\"道别\",\"reply\":\"再见。\"}]\n```</story_options>\n模型尾注";
        assert_eq!(parse_reply(fenced, &story).1.len(), 2);
        assert!(clean_options(invalid, 3).is_empty());
    }

    #[test]
    fn mode_prompt_is_per_conversation_and_validates_bounds() {
        let mut dto = json!({"messages":[{"role":"user","content":"hello"}]});
        apply(&mut dto, &StorySettings::default()).unwrap(); assert_eq!(dto["messages"].as_array().unwrap().len(), 1);
        apply(&mut dto, &StorySettings { scenario:"雨夜".into(), mode:"choices".into(), ..Default::default() }).unwrap();
        assert!(dto["messages"].as_array().unwrap().last().unwrap()["content"].as_str().unwrap().contains(OPTIONS_OPEN));
        assert!(StorySettings { choice_count: 7, ..Default::default() }.validate().is_err());
    }

    #[test]
    fn choices_are_independent_of_normal_and_creative_modes() {
        let legacy: StorySettings = serde_json::from_value(json!({"mode":"choices"})).unwrap();
        assert!(legacy.offers_choices());
        assert!(!StorySettings::default().offers_choices());
        let options = "<story_options>[{\"label\":\"问候\",\"reply\":\"你好。\"},{\"label\":\"道别\",\"reply\":\"再见。\"}]</story_options>";
        for mode in ["free", "world"] {
            let story = StorySettings { mode: mode.into(), choices_enabled: true,
                world_books: vec!["Reference".into()], world_update_mode: "inline".into(), ..Default::default() };
            let mut dto = json!({"messages":[]});
            apply(&mut dto, &story).unwrap();
            assert!(dto["messages"].as_array().unwrap().iter().any(|message| message["content"].as_str().unwrap().contains(OPTIONS_OPEN)));
            let (body, parsed) = parse_reply(&format!("正文{options}"), &story);
            assert_eq!(body, "正文");
            assert_eq!(parsed.len(), 2);
            if mode == "world" {
                let world = "<world_state>{\"location\":\"城门\"}</world_state>";
                for text in [format!("正文{world}{options}"), format!("正文{options}{world}")] {
                    let (body, parsed) = parse_reply(&text, &story);
                    assert_eq!(parsed.len(), 2);
                    assert!(body.contains(world));
                    assert!(!body.contains(OPTIONS_OPEN));
                }
            }
        }
    }
}
