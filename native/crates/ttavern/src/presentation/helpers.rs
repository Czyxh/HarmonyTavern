//! Command helpers, ported from upstream `presentation/commands/helpers.rs`.
//!
//! The iOS-policy guard stays in shape but is inert: our `StartupProfile` always resolves
//! `IosPolicyScope::Ignored`, so `ensure_ios_policy_allows` never rejects. Keeping the call
//! sites makes the future policy work a no-op change instead of a refactor.

use std::fmt::Display;

use tt_domain::ios_policy::{IosPolicyActivationReport, IosPolicyScope};

use super::errors::CommandError;

pub fn ensure_ios_policy_allows(
    ios_policy: &IosPolicyActivationReport,
    allowed: bool,
    capability: &'static str,
) -> Result<(), CommandError> {
    if ios_policy.scope == IosPolicyScope::Ios && !allowed {
        return Err(CommandError::Unauthorized(format!(
            "iOS policy disabled capability: {capability}"
        )));
    }

    Ok(())
}

pub fn log_command(command: impl AsRef<str>) {
    tracing::debug!(
        target: crate::observability::COMMAND,
        command = %command.as_ref(),
        "Command invoked",
    );
}

fn should_log_as_warning(error: &CommandError) -> bool {
    matches!(
        error,
        CommandError::TooManyRequests(_) | CommandError::Cancelled(_) | CommandError::Conflict(_)
    )
}

pub fn map_command_error<E>(context: impl AsRef<str>) -> impl FnOnce(E) -> CommandError
where
    E: Display + Into<CommandError>,
{
    let context = context.as_ref().to_string();

    move |error| {
        let error_text = error.to_string();
        let command_error: CommandError = error.into();
        let message = format!("{}: {}", context, error_text);

        if should_log_as_warning(&command_error) {
            tracing::warn!(
                target: crate::observability::COMMAND,
                context = %context,
                error = %error_text,
                "Command returned expected failure",
            );
        } else {
            log_user_visible_error(&message);
        }

        command_error
    }
}

pub fn log_user_visible_error(message: impl AsRef<str>) {
    tracing::error!(
        target: crate::observability::USER_VISIBLE_ERROR,
        "{}",
        message.as_ref(),
    );
}
