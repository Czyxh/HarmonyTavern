//! Command modules, grouped by domain like upstream `presentation/commands/`.
//!
//! P3 ports the bootstrap critical path, P4 the media/import surface, P5 chat &
//! generation. Each handler has the upstream body minus the Tauri plumbing:
//! `State<Arc<AppState>>` becomes `&Ctx`, and the return type is serialised to JSON here
//! instead of by `#[tauri::command]`.

pub mod agent;
pub mod agent_live_projection;
pub mod agent_session;
pub mod bootstrap;
pub mod character;
pub mod chat;
pub mod chat_api;
pub mod chat_completion;
pub mod content;
pub mod data_archive;
pub mod database;
pub mod extension;
pub mod extension_store;
pub mod file;
pub mod image;
pub mod lan_sync;
pub mod llm_connection;
pub mod mcp;
pub mod not_ported;
pub mod preset;
pub mod product;
pub mod provider_metadata;
pub mod group;
    pub mod runtime_paths;
pub mod searxng_search;
pub mod secret;
pub mod settings;
pub mod native_preferences;
pub mod native_context;
pub mod native_world;
pub mod native_story;
pub mod native_usage;
pub mod skill;
pub mod sync;
pub mod sync_automation;
pub mod tokenizer;
pub mod tt_sync;
pub mod user;
pub mod vector;
pub mod world_info;
