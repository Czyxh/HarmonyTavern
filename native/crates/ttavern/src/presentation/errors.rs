//! Command boundary error (ported from upstream `presentation/errors.rs`, minus `tauri::Error`).
//!
//! Wire shape: `invoke` never rejects; failures come back as
//! `{"ok":false,"error":{"code":"not_found","message":"Not found: ..."}}` so ArkTS can switch
//! on `code` instead of parsing English prose.

use serde::Serialize;
use thiserror::Error;

use tt_application::errors::ApplicationError;
use tt_domain::errors::DomainError;
use tt_domain::models::upstream_failure::UpstreamFailure;

#[derive(Error, Debug, Serialize)]
pub enum CommandError {
    #[error("Bad request: {0}")]
    BadRequest(String),

    #[error("Conflict: {0}")]
    Conflict(String),

    #[error("Not found: {0}")]
    NotFound(String),

    #[error("Unauthorized: {0}")]
    Unauthorized(String),

    #[error("{0}")]
    Cancelled(String),

    #[error("{0}")]
    TooManyRequests(String),

    #[error("{0}")]
    UpstreamFailure(UpstreamFailure),

    #[error("Internal server error: {0}")]
    InternalServerError(String),
}

impl CommandError {
    /// Stable machine-readable code for the ArkTS side.
    pub fn code(&self) -> &'static str {
        match self {
            CommandError::BadRequest(_) => "bad_request",
            CommandError::Conflict(_) => "conflict",
            CommandError::NotFound(_) => "not_found",
            CommandError::Unauthorized(_) => "unauthorized",
            CommandError::Cancelled(_) => "cancelled",
            CommandError::TooManyRequests(_) => "too_many_requests",
            CommandError::UpstreamFailure(_) => "upstream_failure",
            CommandError::InternalServerError(_) => "internal",
        }
    }
}

impl From<ApplicationError> for CommandError {
    fn from(error: ApplicationError) -> Self {
        match error {
            ApplicationError::ValidationError(msg) => CommandError::BadRequest(msg),
            ApplicationError::Conflict(msg) => CommandError::Conflict(msg),
            ApplicationError::NotFound(msg) => CommandError::NotFound(msg),
            ApplicationError::Unauthorized(msg) => CommandError::Unauthorized(msg),
            ApplicationError::PermissionDenied(msg) => CommandError::Unauthorized(msg),
            ApplicationError::RateLimited(msg) => CommandError::TooManyRequests(msg),
            ApplicationError::Transient(msg) => CommandError::InternalServerError(msg),
            ApplicationError::UpstreamFailure(failure) => CommandError::UpstreamFailure(failure),
            ApplicationError::Cancelled(msg) => CommandError::Cancelled(msg),
            ApplicationError::InternalError(msg) => CommandError::InternalServerError(msg),
        }
    }
}

impl From<DomainError> for CommandError {
    fn from(error: DomainError) -> Self {
        match error {
            DomainError::NotFound(msg) => CommandError::NotFound(msg),
            DomainError::InvalidData(msg) => CommandError::BadRequest(msg),
            DomainError::Conflict(msg) => CommandError::Conflict(msg),
            DomainError::AuthenticationError(msg) => CommandError::Unauthorized(msg),
            error @ DomainError::WorkspaceAccessDenied { .. } => {
                CommandError::Unauthorized(error.to_string())
            }
            DomainError::Cancelled(msg) => CommandError::Cancelled(msg),
            error @ DomainError::FileIo { .. } => CommandError::InternalServerError(error.to_string()),
            DomainError::InternalError(msg) => CommandError::InternalServerError(msg),
            DomainError::RateLimited { message } => CommandError::TooManyRequests(message),
            DomainError::Transient(msg) => CommandError::InternalServerError(msg),
            DomainError::UpstreamFailure(failure) => CommandError::UpstreamFailure(failure),
            DomainError::WorkspacePathIsDirectory { path } => {
                CommandError::BadRequest(format!("Workspace path is a directory: {path}"))
            }
            DomainError::WorkspaceFileNotText { path } => {
                CommandError::BadRequest(format!("Workspace file is not UTF-8 text: {path}"))
            }
            DomainError::WorkspaceWriteConflict { kind, .. } => {
                CommandError::BadRequest(format!("Workspace write conflict: {kind}"))
            }
        }
    }
}

impl From<serde_json::Error> for CommandError {
    fn from(error: serde_json::Error) -> Self {
        CommandError::BadRequest(format!("Malformed command payload: {error}"))
    }
}
