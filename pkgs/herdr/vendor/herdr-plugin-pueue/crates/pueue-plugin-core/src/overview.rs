use crate::text::sanitize_command_description;
use crate::{sanitize_terminal_text, QueueState, Task, TaskState, MAX_COMMAND_TEXT_COLUMNS};

pub const MAX_OVERVIEW_RUNNING_TASKS: usize = 2;
pub const MAX_OVERVIEW_TASK_TEXT_COLUMNS: u32 = 72;
pub const PUEUE_METADATA_SOURCE: &str = "plugin:dev.herdr.pueue";
pub const PUEUE_STATUS_TOKEN: &str = "pueue_status";
pub const PUEUE_RUNNING_TOKENS: [&str; MAX_OVERVIEW_RUNNING_TASKS] =
    ["pueue_running_1", "pueue_running_2"];

const WORKSPACE_METADATA_ARGUMENT_COUNT: usize = 13;
const WORKSPACE_SUBCOMMAND: &str = "workspace";
const REPORT_METADATA_SUBCOMMAND: &str = "report-metadata";
const SOURCE_OPTION: &str = "--source";
const TOKEN_OPTION: &str = "--token";
const CLEAR_TOKEN_OPTION: &str = "--clear-token";
const TTL_OPTION: &str = "--ttl-ms";
const EMPTY_LABEL_MARKERS: &[&str] = &["-", "—"];

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct QueueOverview {
    status: String,
    running_tasks: Vec<String>,
}

impl QueueOverview {
    pub fn from_queue(queue: &QueueState) -> Self {
        // r[impl herdr.pueue_plugin.sidebar_overview]
        let running_count = queue
            .tasks()
            .iter()
            .filter(|task| task.state == TaskState::Running)
            .count();
        let running_tasks = queue
            .tasks()
            .iter()
            .filter(|task| task.state == TaskState::Running)
            .take(MAX_OVERVIEW_RUNNING_TASKS)
            .map(running_task_text)
            .collect::<Vec<_>>();
        let status = running_status_text(running_count);
        debug_assert!(running_tasks.len() <= MAX_OVERVIEW_RUNNING_TASKS);
        debug_assert!(running_tasks.len() <= running_count);
        Self {
            status,
            running_tasks,
        }
    }

    pub fn unavailable() -> Self {
        Self {
            status: "Pueue · unavailable".to_string(),
            running_tasks: Vec::new(),
        }
    }

    pub fn status(&self) -> &str {
        &self.status
    }

    pub fn running_tasks(&self) -> &[String] {
        &self.running_tasks
    }
}

pub fn workspace_metadata_arguments(
    workspace_id: &str,
    overview: &QueueOverview,
    ttl_ms: u64,
) -> Vec<String> {
    debug_assert!(!workspace_id.trim().is_empty());
    debug_assert!(ttl_ms > 0);
    debug_assert!(overview.running_tasks.len() <= MAX_OVERVIEW_RUNNING_TASKS);

    let mut arguments = Vec::with_capacity(WORKSPACE_METADATA_ARGUMENT_COUNT);
    arguments.extend([
        WORKSPACE_SUBCOMMAND.to_string(),
        REPORT_METADATA_SUBCOMMAND.to_string(),
        workspace_id.to_string(),
        SOURCE_OPTION.to_string(),
        PUEUE_METADATA_SOURCE.to_string(),
        TOKEN_OPTION.to_string(),
        token_assignment(PUEUE_STATUS_TOKEN, overview.status()),
    ]);
    for (index, token) in PUEUE_RUNNING_TOKENS.iter().enumerate() {
        match overview.running_tasks.get(index) {
            Some(value) => {
                arguments.extend([TOKEN_OPTION.to_string(), token_assignment(token, value)])
            }
            None => arguments.extend([CLEAR_TOKEN_OPTION.to_string(), (*token).to_string()]),
        }
    }
    arguments.extend([TTL_OPTION.to_string(), ttl_ms.to_string()]);

    debug_assert_eq!(arguments.len(), WORKSPACE_METADATA_ARGUMENT_COUNT);
    arguments
}

fn running_status_text(running_count: usize) -> String {
    if running_count == 0 {
        return "Pueue · idle".to_string();
    }
    let hidden_count = running_count.saturating_sub(MAX_OVERVIEW_RUNNING_TASKS);
    if hidden_count == 0 {
        return format!("Pueue · {running_count} running");
    }
    format!("Pueue · {running_count} running · +{hidden_count} more")
}

fn running_task_text(task: &Task) -> String {
    let label = task.label.trim();
    let description = if task_label_is_meaningful(label) {
        label.to_string()
    } else {
        sanitize_command_description(&task.command, MAX_COMMAND_TEXT_COLUMNS)
    };
    sanitize_terminal_text(
        &format!("#{} {description}", task.id),
        MAX_OVERVIEW_TASK_TEXT_COLUMNS,
    )
}

fn task_label_is_meaningful(label: &str) -> bool {
    !label.is_empty() && !EMPTY_LABEL_MARKERS.contains(&label)
}

fn token_assignment(name: &str, value: &str) -> String {
    format!("{name}={value}")
}

#[cfg(test)]
mod tests {
    use crate::{Completion, Group, GroupState, TaskId};

    use super::*;

    const FIRST_TASK_ID: TaskId = TaskId::new(1);
    const SECOND_TASK_ID: TaskId = TaskId::new(2);
    const THIRD_TASK_ID: TaskId = TaskId::new(3);
    const FOURTH_TASK_ID: TaskId = TaskId::new(4);
    const TEST_TTL_MS: u64 = 6_000;

    fn task(id: TaskId, state: TaskState, label: &str, command: &str) -> Task {
        Task {
            id,
            group: "default".to_string(),
            state,
            label: label.to_string(),
            command: command.to_string(),
            path: "/workspace".to_string(),
        }
    }

    fn queue(tasks: Vec<Task>) -> QueueState {
        QueueState::new(
            vec![Group {
                name: "default".to_string(),
                state: GroupState::Running,
            }],
            tasks,
        )
    }

    #[test]
    fn projects_two_running_tasks_and_reports_hidden_count() {
        // r[verify herdr.pueue_plugin.sidebar_overview.running]
        // r[verify herdr.pueue_plugin.sidebar_overview.overflow]
        let overview = QueueOverview::from_queue(&queue(vec![
            task(FIRST_TASK_ID, TaskState::Running, "compile", "cargo build"),
            task(
                SECOND_TASK_ID,
                TaskState::Completed(Completion::Success),
                "done",
                "cargo fmt",
            ),
            task(THIRD_TASK_ID, TaskState::Running, "", "cargo test"),
            task(FOURTH_TASK_ID, TaskState::Running, "docs", "cargo doc"),
        ]));

        assert_eq!(overview.status(), "Pueue · 3 running · +1 more");
        assert_eq!(
            overview.running_tasks(),
            ["#1 compile".to_string(), "#3 cargo test".to_string()]
        );
        assert_eq!(overview.running_tasks().len(), MAX_OVERVIEW_RUNNING_TASKS);
    }

    #[test]
    fn placeholder_labels_fall_back_to_the_running_command() {
        let overview = QueueOverview::from_queue(&queue(vec![
            task(FIRST_TASK_ID, TaskState::Running, "—", "cargo test"),
            task(SECOND_TASK_ID, TaskState::Running, "-", "nix build"),
        ]));

        assert_eq!(
            overview.running_tasks(),
            ["#1 cargo test".to_string(), "#2 nix build".to_string()]
        );
        assert!(!overview.running_tasks()[0].contains('—'));
        assert!(!overview.running_tasks()[1].ends_with('-'));
    }

    #[test]
    fn environment_wrapped_commands_hide_assignments() {
        let overview = QueueOverview::from_queue(&queue(vec![
            task(
                FIRST_TASK_ID,
                TaskState::Running,
                "—",
                "env API_TOKEN=fixture-secret /usr/bin/herdr server",
            ),
            task(
                SECOND_TASK_ID,
                TaskState::Running,
                "",
                "MODE='unsafe value' command",
            ),
        ]));

        assert_eq!(
            overview.running_tasks(),
            ["#1 herdr".to_string(), "#2 unlabeled task".to_string()]
        );
        let combined = overview.running_tasks().join(" ");
        assert!(!combined.contains("API_TOKEN"));
        assert!(!combined.contains("fixture-secret"));
        assert!(!combined.contains("unsafe value"));
        assert_eq!(
            sanitize_command_description(
                "curl https://example.invalid/?token=fixture-secret",
                MAX_COMMAND_TEXT_COLUMNS,
            ),
            "curl"
        );
        assert_eq!(
            sanitize_command_description(
                "nix run target && env API_TOKEN=fixture-secret herdr",
                MAX_COMMAND_TEXT_COLUMNS,
            ),
            "nix run target"
        );
    }

    #[test]
    fn idle_overview_excludes_every_non_running_state() {
        // r[verify herdr.pueue_plugin.sidebar_overview.stale]
        let overview = QueueOverview::from_queue(&queue(vec![
            task(FIRST_TASK_ID, TaskState::Queued, "queued", "cargo test"),
            task(
                SECOND_TASK_ID,
                TaskState::Completed(Completion::Failed),
                "failed",
                "cargo build",
            ),
        ]));

        assert_eq!(overview.status(), "Pueue · idle");
        assert!(overview.running_tasks().is_empty());
    }

    #[test]
    fn running_task_text_removes_controls_and_applies_its_bound() {
        // r[verify herdr.pueue_plugin.sidebar_overview.privacy]
        let hostile_label = format!(
            "safe\u{001b}]0;hidden-secret\u{0007} {}",
            "x".repeat(MAX_OVERVIEW_TASK_TEXT_COLUMNS as usize)
        );
        let overview = QueueOverview::from_queue(&queue(vec![task(
            FIRST_TASK_ID,
            TaskState::Running,
            &hostile_label,
            "unused",
        )]));
        let text = &overview.running_tasks()[0];

        assert!(text.starts_with("#1 safe"));
        assert!(text.ends_with('…'));
        assert!(!text.contains("hidden-secret"));
        assert!(!text.contains('\u{001b}'));
    }

    #[test]
    fn metadata_arguments_set_status_and_clear_unused_task_rows() {
        let arguments =
            workspace_metadata_arguments("wD", &QueueOverview::unavailable(), TEST_TTL_MS);

        assert_eq!(arguments.len(), WORKSPACE_METADATA_ARGUMENT_COUNT);
        assert_eq!(
            arguments,
            [
                "workspace",
                "report-metadata",
                "wD",
                "--source",
                PUEUE_METADATA_SOURCE,
                "--token",
                "pueue_status=Pueue · unavailable",
                "--clear-token",
                "pueue_running_1",
                "--clear-token",
                "pueue_running_2",
                "--ttl-ms",
                "6000",
            ]
        );
    }
}
