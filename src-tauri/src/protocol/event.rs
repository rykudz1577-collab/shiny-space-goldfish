//! Re-export event contract từ antares-core để src-tauri và TS dùng chung —
//! không copy schema thứ hai (single source of truth).
pub use antares_core::events::{EventEnvelope, EventQos, EventTopic, CURRENT_SCHEMA};

/// Channel Tauri mà event bridge emit envelope lên. Đồng bộ với
/// apps/desktop/src/types/protocol.ts EVENT_CHANNEL.
pub const EVENT_CHANNEL: &str = "antares://event";
