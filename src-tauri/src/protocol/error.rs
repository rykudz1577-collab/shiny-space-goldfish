use serde::{Deserialize, Serialize};

/// §117 — Error taxonomy. Mỗi code thuộc một domain prefix.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ErrorDomain {
    App,
    Config,
    Storage,
    Network,
    Process,
    Ipc,
    Mc,
    Loader,
    Mod,
    Resource,
    Java,
    Auth,
    Disk,
    Ui,
    Plugin,
    Security,
}

/// §117 — Mỗi error có: code, severity, retryable, user_action, safe_message.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AntaresError {
    pub code: String,
    pub message: String,
    pub retryable: bool,
    pub action: Option<String>,
}

impl AntaresError {
    pub fn new(code: &str, message: impl Into<String>, retryable: bool) -> Self {
        Self {
            code: code.to_string(),
            message: message.into(),
            retryable,
            action: None,
        }
    }

    pub fn with_action(mut self, action: &str) -> Self {
        self.action = Some(action.to_string());
        self
    }

    pub fn domain(&self) -> Option<&str> {
        self.code.split('_').next()
    }
}

impl std::fmt::Display for AntaresError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}: {}", self.code, self.message)
    }
}

impl std::error::Error for AntaresError {}

/// Constructor cho các code phổ biến — giữ catalog tập trung một chỗ.
pub mod codes {
    pub const APP_INTERNAL: &str = "APP_INTERNAL";
    pub const APP_NOT_READY: &str = "APP_NOT_READY";
    pub const CONFIG_INVALID: &str = "CONFIG_INVALID";
    pub const STORAGE_WRITE_FAILED: &str = "STORAGE_WRITE_FAILED";
    pub const NETWORK_UNAVAILABLE: &str = "NETWORK_UNAVAILABLE";
    pub const IPC_SESSION_STALE: &str = "IPC_SESSION_STALE";
    pub const INSTANCE_LOCKED: &str = "INSTANCE_LOCKED";
    pub const JAVA_NOT_FOUND: &str = "JAVA_NOT_FOUND";
    pub const MC_VERSION_UNKNOWN: &str = "MC_VERSION_UNKNOWN";
}

pub fn internal(message: impl Into<String>) -> AntaresError {
    AntaresError::new(codes::APP_INTERNAL, message, false)
}

pub fn retryable(code: &str, message: impl Into<String>) -> AntaresError {
    AntaresError::new(code, message, true)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn domain_is_prefix_before_underscore() {
        let err = AntaresError::new(codes::INSTANCE_LOCKED, "locked", false);
        assert_eq!(err.domain(), Some("INSTANCE"));
    }

    #[test]
    fn retryable_flag_roundtrip() {
        let err = retryable(codes::NETWORK_UNAVAILABLE, "offline");
        assert!(err.retryable);
    }
}
