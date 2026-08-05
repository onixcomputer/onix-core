use crate::{TaskId, TaskState};

/// Upper bound for one dashboard input line. Keeps the argv for
/// `pueue send` bounded and the draft state small.
pub const MAX_SEND_INPUT_CHARS: usize = 256;
/// `pueue send` delivers the exact string it receives. Most stdin prompts
/// are line based, so the dashboard terminates confirmed input with a
/// newline, matching the upstream wiki example `pueue send "y\n"`.
pub const SEND_LINE_TERMINATOR: char = '\n';

const NO_CONTROLS: &[ControlOperation] = &[];
const STASHED_CONTROLS: &[ControlOperation] = &[ControlOperation::Enqueue];
const RUNNING_CONTROLS: &[ControlOperation] = &[ControlOperation::Pause, ControlOperation::Kill];
const PAUSED_CONTROLS: &[ControlOperation] = &[ControlOperation::Resume, ControlOperation::Kill];
const COMPLETED_CONTROLS: &[ControlOperation] =
    &[ControlOperation::Restart, ControlOperation::Remove];

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ControlOperation {
    Enqueue,
    Resume,
    Pause,
    Kill,
    Restart,
    Remove,
}

impl ControlOperation {
    pub const fn label(self) -> &'static str {
        match self {
            Self::Enqueue => "enqueue",
            Self::Resume => "resume",
            Self::Pause => "pause",
            Self::Kill => "kill",
            Self::Restart => "restart",
            Self::Remove => "remove",
        }
    }

    pub const fn requires_confirmation(self) -> bool {
        matches!(self, Self::Kill | Self::Restart | Self::Remove)
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct PueueRequest {
    pub operation: ControlOperation,
    pub task_id: TaskId,
}

impl PueueRequest {
    pub const fn new(operation: ControlOperation, task_id: TaskId) -> Self {
        Self { operation, task_id }
    }

    pub fn argv(self) -> Vec<String> {
        // r[impl herdr.pueue_plugin.security.argv]
        let task_id = self.task_id.to_string();
        match self.operation {
            ControlOperation::Enqueue => vec!["enqueue".to_string(), task_id],
            ControlOperation::Resume => vec!["start".to_string(), task_id],
            ControlOperation::Pause => vec!["pause".to_string(), task_id],
            ControlOperation::Kill => vec!["kill".to_string(), task_id],
            ControlOperation::Restart => {
                vec!["restart".to_string(), "--in-place".to_string(), task_id]
            }
            ControlOperation::Remove => vec!["remove".to_string(), task_id],
        }
    }
}

/// A task accepts stdin input only while a live process exists for it.
pub const fn accepts_input(state: TaskState) -> bool {
    matches!(state, TaskState::Running | TaskState::Paused)
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SendRequest {
    pub task_id: TaskId,
    pub input: String,
}

impl SendRequest {
    pub fn new(task_id: TaskId, input: String) -> Self {
        Self { task_id, input }
    }

    pub fn argv(&self) -> Vec<String> {
        // r[impl herdr.pueue_plugin.security.argv]
        vec![
            "send".to_string(),
            self.task_id.to_string(),
            self.input.clone(),
        ]
    }
}

pub const fn allowed_controls(state: TaskState) -> &'static [ControlOperation] {
    // r[impl herdr.pueue_plugin.controls]
    match state {
        TaskState::Stashed => STASHED_CONTROLS,
        TaskState::Running => RUNNING_CONTROLS,
        TaskState::Paused => PAUSED_CONTROLS,
        TaskState::Completed(_) => COMPLETED_CONTROLS,
        TaskState::Locked | TaskState::Queued => NO_CONTROLS,
    }
}

#[cfg(test)]
mod tests {
    use crate::Completion;

    use super::*;

    const TASK_ID_VALUE: u64 = 42;
    const TASK_ID_TEXT: &str = "42";

    #[test]
    fn admits_controls_by_state() {
        // r[verify herdr.pueue_plugin.controls.approved]
        assert_eq!(allowed_controls(TaskState::Stashed), STASHED_CONTROLS);
        assert_eq!(allowed_controls(TaskState::Running), RUNNING_CONTROLS);
        assert_eq!(allowed_controls(TaskState::Paused), PAUSED_CONTROLS);
        assert_eq!(
            allowed_controls(TaskState::Completed(Completion::Success)),
            COMPLETED_CONTROLS
        );
    }

    #[test]
    fn rejects_force_start_for_queued_tasks() {
        // r[verify herdr.pueue_plugin.controls.policy]
        assert!(allowed_controls(TaskState::Queued).is_empty());
        assert!(allowed_controls(TaskState::Locked).is_empty());
    }

    #[test]
    fn constructs_separate_argv_values() {
        let task_id = TaskId::new(TASK_ID_VALUE);
        assert_eq!(
            PueueRequest::new(ControlOperation::Enqueue, task_id).argv(),
            ["enqueue", TASK_ID_TEXT]
        );
        assert_eq!(
            PueueRequest::new(ControlOperation::Restart, task_id).argv(),
            ["restart", "--in-place", TASK_ID_TEXT]
        );
    }

    #[test]
    fn builds_send_argv_without_a_shell() {
        // r[verify herdr.pueue_plugin.security.argv]
        let request = SendRequest::new(TaskId::new(TASK_ID_VALUE), "y\n".to_string());
        assert_eq!(request.argv(), ["send", TASK_ID_TEXT, "y\n"]);
    }

    #[test]
    fn admits_input_only_for_live_tasks() {
        assert!(accepts_input(TaskState::Running));
        assert!(accepts_input(TaskState::Paused));
        assert!(!accepts_input(TaskState::Queued));
        assert!(!accepts_input(TaskState::Stashed));
        assert!(!accepts_input(TaskState::Locked));
        assert!(!accepts_input(TaskState::Completed(Completion::Success)));
    }

    #[test]
    fn identifies_destructive_controls() {
        assert!(!ControlOperation::Enqueue.requires_confirmation());
        assert!(!ControlOperation::Resume.requires_confirmation());
        assert!(ControlOperation::Kill.requires_confirmation());
        assert!(ControlOperation::Restart.requires_confirmation());
        assert!(ControlOperation::Remove.requires_confirmation());
    }
}
