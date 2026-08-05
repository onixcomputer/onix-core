#![forbid(unsafe_code)]

mod controls;
mod dashboard;
mod diagnostic;
mod model;
mod overview;
mod parser;
mod text;

pub use controls::{
    accepts_input, allowed_controls, ControlOperation, PueueRequest, SendRequest,
    MAX_SEND_INPUT_CHARS, SEND_LINE_TERMINATOR,
};
pub use dashboard::{
    reduce, DashboardEvent, DashboardState, Direction, Effect, InputDraft, Transition,
};
pub use diagnostic::{Diagnostic, FailureClass, Operation};
pub use model::{Completion, Group, GroupState, PueueVersion, QueueState, Task, TaskId, TaskState};
pub use overview::{
    workspace_metadata_arguments, QueueOverview, MAX_OVERVIEW_RUNNING_TASKS,
    MAX_OVERVIEW_TASK_TEXT_COLUMNS, PUEUE_METADATA_SOURCE, PUEUE_RUNNING_TOKENS,
    PUEUE_STATUS_TOKEN,
};
pub use parser::{parse_status, parse_version, CoreError};
pub use text::sanitize_terminal_text;

pub const SUPPORTED_PUEUE_MAJOR: u64 = 4;
const KIBIBYTE_BYTES: usize = 1024;
const MEBIBYTE_KIBIBYTES: usize = 1024;
const MAX_STATUS_JSON_MEBIBYTES: usize = 16;
pub const MAX_STATUS_JSON_BYTES: usize =
    MAX_STATUS_JSON_MEBIBYTES * MEBIBYTE_KIBIBYTES * KIBIBYTE_BYTES;
pub const MAX_TASKS: usize = 10_000;
pub const MAX_GROUPS: usize = 1_000;
pub const MAX_GROUP_TEXT_COLUMNS: u32 = 48;
pub const MAX_LABEL_TEXT_COLUMNS: u32 = 64;
pub const MAX_COMMAND_TEXT_COLUMNS: u32 = 120;
pub const MAX_PATH_TEXT_COLUMNS: u32 = 96;
pub const MAX_DIAGNOSTIC_TEXT_COLUMNS: u32 = 256;

const _: () = assert!(MAX_GROUPS <= MAX_TASKS);
const _: () = assert!(MAX_LABEL_TEXT_COLUMNS <= MAX_COMMAND_TEXT_COLUMNS);
const _: () = assert!(MAX_COMMAND_TEXT_COLUMNS <= MAX_DIAGNOSTIC_TEXT_COLUMNS);
