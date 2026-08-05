use std::collections::{BTreeMap, BTreeSet};

use semver::Version;
use serde::Deserialize;

use crate::text::sanitize_command_description;
use crate::{
    sanitize_terminal_text, Completion, Group, GroupState, PueueVersion, QueueState, Task, TaskId,
    TaskState, MAX_COMMAND_TEXT_COLUMNS, MAX_GROUPS, MAX_GROUP_TEXT_COLUMNS,
    MAX_LABEL_TEXT_COLUMNS, MAX_PATH_TEXT_COLUMNS, MAX_STATUS_JSON_BYTES, MAX_TASKS,
    SUPPORTED_PUEUE_MAJOR,
};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum CoreError {
    InvalidVersionText,
    UnsupportedMajorVersion,
    StatusOutputTooLarge,
    InvalidStatusData,
    TooManyGroups,
    TooManyTasks,
    InvalidTaskIdentity,
    DuplicateTaskIdentity,
    UnknownTaskGroup,
    InvalidGroupName,
    AmbiguousGroupDisplay,
}

impl std::fmt::Display for CoreError {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let message = match self {
            Self::InvalidVersionText => "pueue returned invalid version text",
            Self::UnsupportedMajorVersion => "pueue returned an unsupported major version",
            Self::StatusOutputTooLarge => "pueue status output exceeded its byte limit",
            Self::InvalidStatusData => "pueue returned unsupported or malformed status data",
            Self::TooManyGroups => "pueue status exceeded the group limit",
            Self::TooManyTasks => "pueue status exceeded the task limit",
            Self::InvalidTaskIdentity => "pueue status contained an invalid task identity",
            Self::DuplicateTaskIdentity => "pueue status contained a duplicate task identity",
            Self::UnknownTaskGroup => "pueue status referenced an unknown task group",
            Self::InvalidGroupName => "pueue status contained an invalid group name",
            Self::AmbiguousGroupDisplay => "pueue group names became ambiguous after sanitation",
        };
        formatter.write_str(message)
    }
}

impl std::error::Error for CoreError {}

#[derive(Deserialize)]
struct WireState {
    tasks: BTreeMap<String, WireTask>,
    groups: BTreeMap<String, WireGroup>,
}

#[derive(Deserialize)]
struct WireGroup {
    status: WireGroupState,
}

#[derive(Deserialize)]
enum WireGroupState {
    Running,
    Paused,
    Reset,
}

#[derive(Deserialize)]
struct WireTask {
    id: u64,
    command: String,
    path: String,
    group: String,
    label: Option<String>,
    status: WireTaskState,
}

#[derive(Deserialize)]
enum WireTaskState {
    Locked {
        #[serde(rename = "previous_status")]
        _previous_status: Box<WireTaskState>,
    },
    Stashed {
        #[serde(rename = "enqueue_at")]
        _enqueue_at: Option<String>,
    },
    Queued {
        #[serde(rename = "enqueued_at")]
        _enqueued_at: String,
    },
    Running {
        #[serde(rename = "enqueued_at")]
        _enqueued_at: String,
        #[serde(rename = "start")]
        _start: String,
    },
    Paused {
        #[serde(rename = "enqueued_at")]
        _enqueued_at: String,
        #[serde(rename = "start")]
        _start: String,
    },
    Done {
        #[serde(rename = "enqueued_at")]
        _enqueued_at: String,
        #[serde(rename = "start")]
        _start: String,
        #[serde(rename = "end")]
        _end: String,
        result: WireTaskResult,
    },
}

#[derive(Deserialize)]
enum WireTaskResult {
    Success,
    Failed(i32),
    FailedToSpawn(serde::de::IgnoredAny),
    Killed,
    Errored,
    DependencyFailed,
}

pub fn parse_version(version_text: &str) -> Result<PueueVersion, CoreError> {
    // r[impl herdr.pueue_plugin.adapter]
    let version = version_text
        .trim()
        .strip_prefix("pueue ")
        .ok_or(CoreError::InvalidVersionText)
        .and_then(|value| Version::parse(value).map_err(|_| CoreError::InvalidVersionText))?;
    if version.major != SUPPORTED_PUEUE_MAJOR {
        return Err(CoreError::UnsupportedMajorVersion);
    }
    Ok(PueueVersion {
        major: version.major,
        minor: version.minor,
        patch: version.patch,
    })
}

pub fn parse_status(status_text: &str) -> Result<QueueState, CoreError> {
    // r[impl herdr.pueue_plugin.adapter] r[impl herdr.pueue_plugin.security]
    if status_text.len() > MAX_STATUS_JSON_BYTES {
        return Err(CoreError::StatusOutputTooLarge);
    }
    let wire: WireState =
        serde_json::from_str(status_text).map_err(|_| CoreError::InvalidStatusData)?;
    validate_collection_bounds(&wire)?;
    let (groups, group_display_names) = project_groups(wire.groups)?;
    let tasks = project_tasks(wire.tasks, &group_display_names)?;
    Ok(QueueState::new(groups, tasks))
}

fn validate_collection_bounds(wire: &WireState) -> Result<(), CoreError> {
    if wire.groups.len() > MAX_GROUPS {
        return Err(CoreError::TooManyGroups);
    }
    if wire.tasks.len() > MAX_TASKS {
        return Err(CoreError::TooManyTasks);
    }
    Ok(())
}

fn project_groups(
    wire_groups: BTreeMap<String, WireGroup>,
) -> Result<(Vec<Group>, BTreeMap<String, String>), CoreError> {
    let mut groups = Vec::with_capacity(wire_groups.len());
    let mut display_names = BTreeMap::new();
    let mut unique_display_names = BTreeSet::new();
    for (raw_name, wire_group) in wire_groups {
        if raw_name.is_empty() {
            return Err(CoreError::InvalidGroupName);
        }
        let display_name = sanitize_terminal_text(&raw_name, MAX_GROUP_TEXT_COLUMNS);
        if display_name.is_empty() {
            return Err(CoreError::InvalidGroupName);
        }
        if !unique_display_names.insert(display_name.clone()) {
            return Err(CoreError::AmbiguousGroupDisplay);
        }
        display_names.insert(raw_name, display_name.clone());
        groups.push(Group {
            name: display_name,
            state: project_group_state(wire_group.status),
        });
    }
    groups.sort_by(|left, right| left.name.cmp(&right.name));
    Ok((groups, display_names))
}

fn project_group_state(state: WireGroupState) -> GroupState {
    match state {
        WireGroupState::Running => GroupState::Running,
        WireGroupState::Paused => GroupState::Paused,
        WireGroupState::Reset => GroupState::Reset,
    }
}

fn project_tasks(
    wire_tasks: BTreeMap<String, WireTask>,
    group_display_names: &BTreeMap<String, String>,
) -> Result<Vec<Task>, CoreError> {
    let mut tasks = Vec::with_capacity(wire_tasks.len());
    let mut task_ids = BTreeSet::new();
    for (task_key, wire_task) in wire_tasks {
        validate_task_identity(&task_key, wire_task.id, &mut task_ids)?;
        let display_group = group_display_names
            .get(&wire_task.group)
            .ok_or(CoreError::UnknownTaskGroup)?;
        tasks.push(Task {
            id: TaskId::new(wire_task.id),
            group: display_group.clone(),
            state: project_task_state(wire_task.status),
            label: project_optional_text(wire_task.label, MAX_LABEL_TEXT_COLUMNS),
            command: project_required_text(
                &sanitize_command_description(&wire_task.command, MAX_COMMAND_TEXT_COLUMNS),
                MAX_COMMAND_TEXT_COLUMNS,
            ),
            path: project_required_text(&wire_task.path, MAX_PATH_TEXT_COLUMNS),
        });
    }
    tasks.sort_by(|left, right| {
        left.group
            .cmp(&right.group)
            .then_with(|| left.id.cmp(&right.id))
    });
    Ok(tasks)
}

fn validate_task_identity(
    task_key: &str,
    task_id: u64,
    task_ids: &mut BTreeSet<u64>,
) -> Result<(), CoreError> {
    if task_key != task_id.to_string() {
        return Err(CoreError::InvalidTaskIdentity);
    }
    if !task_ids.insert(task_id) {
        return Err(CoreError::DuplicateTaskIdentity);
    }
    Ok(())
}

fn project_task_state(state: WireTaskState) -> TaskState {
    match state {
        WireTaskState::Locked { .. } => TaskState::Locked,
        WireTaskState::Stashed { .. } => TaskState::Stashed,
        WireTaskState::Queued { .. } => TaskState::Queued,
        WireTaskState::Running { .. } => TaskState::Running,
        WireTaskState::Paused { .. } => TaskState::Paused,
        WireTaskState::Done { result, .. } => TaskState::Completed(project_completion(result)),
    }
}

fn project_completion(result: WireTaskResult) -> Completion {
    match result {
        WireTaskResult::Success => Completion::Success,
        WireTaskResult::Failed(_exit_code) => Completion::Failed,
        WireTaskResult::FailedToSpawn(_message) => Completion::FailedToSpawn,
        WireTaskResult::Killed => Completion::Killed,
        WireTaskResult::Errored => Completion::Errored,
        WireTaskResult::DependencyFailed => Completion::DependencyFailed,
    }
}

fn project_optional_text(value: Option<String>, max_columns: u32) -> String {
    value
        .map(|text| project_required_text(&text, max_columns))
        .filter(|text| !text.is_empty())
        .unwrap_or_else(|| "—".to_string())
}

fn project_required_text(value: &str, max_columns: u32) -> String {
    let text = sanitize_terminal_text(value, max_columns);
    if text.is_empty() {
        "—".to_string()
    } else {
        text
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const FIXTURE_SECRET: &str = "fixture-secret-do-not-display";
    const FAILED_EXIT_CODE: i32 = 17;
    const FIXTURE_GROUP_COUNT: usize = 2;
    const FIXTURE_TASK_COUNT: usize = 3;
    const TEST_KIBIBYTE_BYTES: usize = 1024;
    const TEST_MEBIBYTE_KIBIBYTES: usize = 1024;
    const REALISTIC_STATUS_PADDING_MEBIBYTES: usize = 8;
    const REALISTIC_STATUS_PADDING_BYTES: usize =
        REALISTIC_STATUS_PADDING_MEBIBYTES * TEST_MEBIBYTE_KIBIBYTES * TEST_KIBIBYTE_BYTES;
    const RUNNING_TASK_ID: TaskId = TaskId::new(2);

    #[test]
    fn parses_supported_version() -> Result<(), CoreError> {
        // r[verify herdr.pueue_plugin.adapter.status]
        let version = parse_version(include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/../../fixtures/pueue-4.0.4/version.txt"
        )))?;
        assert_eq!(version.major, SUPPORTED_PUEUE_MAJOR);
        assert_eq!(version.minor, 0);
        assert_eq!(version.patch, SUPPORTED_PUEUE_MAJOR);
        Ok(())
    }

    #[test]
    fn rejects_unsupported_and_malformed_versions() {
        assert_eq!(
            parse_version("pueue 5.0.0"),
            Err(CoreError::UnsupportedMajorVersion)
        );
        assert_eq!(
            parse_version("not-pueue"),
            Err(CoreError::InvalidVersionText)
        );
    }

    #[test]
    fn parses_groups_tasks_and_discards_environments() -> Result<(), CoreError> {
        // r[verify herdr.pueue_plugin.dashboard.grouped]
        // r[verify herdr.pueue_plugin.security.envs]
        let queue = parse_status(include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/../../fixtures/pueue-4.0.4/status.json"
        )))?;
        assert_eq!(queue.groups().len(), FIXTURE_GROUP_COUNT);
        assert_eq!(queue.tasks().len(), FIXTURE_TASK_COUNT);
        assert_eq!(queue.tasks()[0].group, "build");
        assert_eq!(queue.tasks()[1].id, RUNNING_TASK_ID);
        assert!(!format!("{queue:?}").contains(FIXTURE_SECRET));
        Ok(())
    }

    #[test]
    fn parses_every_known_task_status_and_result() -> Result<(), CoreError> {
        let timestamp = "2026-07-29T12:00:00-04:00";
        let cases = [
            (
                serde_json::json!({"Locked": {"previous_status": {"Queued": {"enqueued_at": timestamp}}}}),
                TaskState::Locked,
            ),
            (
                serde_json::json!({"Stashed": {"enqueue_at": null}}),
                TaskState::Stashed,
            ),
            (
                serde_json::json!({"Queued": {"enqueued_at": timestamp}}),
                TaskState::Queued,
            ),
            (
                serde_json::json!({"Running": {"enqueued_at": timestamp, "start": timestamp}}),
                TaskState::Running,
            ),
            (
                serde_json::json!({"Paused": {"enqueued_at": timestamp, "start": timestamp}}),
                TaskState::Paused,
            ),
            (
                serde_json::json!({"Done": {"enqueued_at": timestamp, "start": timestamp, "end": timestamp, "result": "Success"}}),
                TaskState::Completed(Completion::Success),
            ),
            (
                serde_json::json!({"Done": {"enqueued_at": timestamp, "start": timestamp, "end": timestamp, "result": {"Failed": FAILED_EXIT_CODE}}}),
                TaskState::Completed(Completion::Failed),
            ),
            (
                serde_json::json!({"Done": {"enqueued_at": timestamp, "start": timestamp, "end": timestamp, "result": {"FailedToSpawn": FIXTURE_SECRET}}}),
                TaskState::Completed(Completion::FailedToSpawn),
            ),
            (
                serde_json::json!({"Done": {"enqueued_at": timestamp, "start": timestamp, "end": timestamp, "result": "Killed"}}),
                TaskState::Completed(Completion::Killed),
            ),
            (
                serde_json::json!({"Done": {"enqueued_at": timestamp, "start": timestamp, "end": timestamp, "result": "Errored"}}),
                TaskState::Completed(Completion::Errored),
            ),
            (
                serde_json::json!({"Done": {"enqueued_at": timestamp, "start": timestamp, "end": timestamp, "result": "DependencyFailed"}}),
                TaskState::Completed(Completion::DependencyFailed),
            ),
        ];
        for (status, expected) in cases {
            let value = serde_json::json!({
                "tasks": {"1": {
                    "id": 1,
                    "command": "command",
                    "path": "/tmp",
                    "group": "default",
                    "label": null,
                    "envs": {"TOKEN": FIXTURE_SECRET},
                    "status": status
                }},
                "groups": {"default": {"status": "Running", "parallel_tasks": 1}}
            });
            let queue = parse_status(&value.to_string())?;
            assert_eq!(queue.tasks().first().map(|task| task.state), Some(expected));
            assert!(!format!("{queue:?}").contains(FIXTURE_SECRET));
        }
        Ok(())
    }

    #[test]
    fn projects_hostile_task_fields_without_terminal_controls() -> Result<(), CoreError> {
        // r[verify herdr.pueue_plugin.security.terminal]
        let hostile_group = "g\u{001b}]0;fixture-secret-do-not-display\u{0007}roup";
        let value = serde_json::json!({
            "tasks": {"1": {
                "id": 1,
                "command": "echo\nnext",
                "path": "/tmp/\u{0007}safe",
                "group": hostile_group,
                "label": "\u{001b}[31mred\u{001b}[0m",
                "status": {"Stashed": {"enqueue_at": null}}
            }},
            "groups": {"g\u{001b}]0;fixture-secret-do-not-display\u{0007}roup": {"status": "Running", "parallel_tasks": 1}}
        });
        let queue = parse_status(&value.to_string())?;
        let task = queue.tasks().first().ok_or(CoreError::InvalidStatusData)?;
        assert_eq!(task.group, "group");
        assert_eq!(task.label, "red");
        assert_eq!(task.command, "echo next");
        assert_eq!(task.path, "/tmp/safe");
        assert!(!format!("{queue:?}").contains(FIXTURE_SECRET));
        Ok(())
    }

    #[test]
    fn command_projection_discards_environment_assignments() -> Result<(), CoreError> {
        // r[verify herdr.pueue_plugin.sidebar_overview.privacy]
        let value = serde_json::json!({
            "tasks": {"1": {
                "id": 1,
                "command": format!(
                    "env API_TOKEN={FIXTURE_SECRET} LONG_VALUE={} /usr/bin/herdr server",
                    "x".repeat(MAX_COMMAND_TEXT_COLUMNS as usize)
                ),
                "path": "/tmp",
                "group": "default",
                "label": null,
                "status": {"Running": {
                    "enqueued_at": "2026-07-29T12:01:01-04:00",
                    "start": "2026-07-29T12:01:02-04:00"
                }}
            }},
            "groups": {"default": {"status": "Running", "parallel_tasks": 1}}
        });

        let queue = parse_status(&value.to_string())?;
        let task = queue.tasks().first().ok_or(CoreError::InvalidStatusData)?;
        assert_eq!(task.command, "herdr");
        assert!(!format!("{queue:?}").contains(FIXTURE_SECRET));
        assert!(!task.command.contains("LONG_VALUE"));
        Ok(())
    }

    #[test]
    fn accepts_bounded_multi_mebibyte_status_output() -> Result<(), CoreError> {
        let value = serde_json::json!({
            "tasks": {},
            "groups": {},
            "future_padding": "x".repeat(REALISTIC_STATUS_PADDING_BYTES)
        });
        let status = value.to_string();
        assert!(status.len() < MAX_STATUS_JSON_BYTES);
        let queue = parse_status(&status)?;
        assert!(queue.tasks().is_empty());
        assert!(queue.groups().is_empty());
        Ok(())
    }

    #[test]
    fn ignores_unknown_fields_but_rejects_unknown_statuses() -> Result<(), CoreError> {
        let accepted = r#"{
          "tasks": {},
          "groups": {"default": {"status": "Running", "parallel_tasks": 1, "future": true}},
          "future": {"field": true}
        }"#;
        assert_eq!(parse_status(accepted)?.groups().len(), 1);

        let rejected = r#"{
          "tasks": {"1": {"id": 1, "command": "x", "path": ".", "group": "default", "label": null, "status": "FutureState"}},
          "groups": {"default": {"status": "Running", "parallel_tasks": 1}}
        }"#;
        assert_eq!(parse_status(rejected), Err(CoreError::InvalidStatusData));
        Ok(())
    }

    #[test]
    fn rejects_malformed_identity_and_unknown_group() {
        let invalid_identity = r#"{
          "tasks": {"01": {"id": 1, "command": "x", "path": ".", "group": "default", "label": null, "status": {"Stashed": {"enqueue_at": null}}}},
          "groups": {"default": {"status": "Running", "parallel_tasks": 1}}
        }"#;
        assert_eq!(
            parse_status(invalid_identity),
            Err(CoreError::InvalidTaskIdentity)
        );

        let unknown_group = r#"{
          "tasks": {"1": {"id": 1, "command": "x", "path": ".", "group": "missing", "label": null, "status": {"Stashed": {"enqueue_at": null}}}},
          "groups": {"default": {"status": "Running", "parallel_tasks": 1}}
        }"#;
        assert_eq!(
            parse_status(unknown_group),
            Err(CoreError::UnknownTaskGroup)
        );
    }

    #[test]
    fn rejects_oversized_status_before_parsing() {
        let oversized = "x".repeat(MAX_STATUS_JSON_BYTES.saturating_add(1));
        assert_eq!(
            parse_status(&oversized),
            Err(CoreError::StatusOutputTooLarge)
        );
    }
}
