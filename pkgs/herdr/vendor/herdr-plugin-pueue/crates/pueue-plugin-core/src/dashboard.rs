use crate::{
    accepts_input, allowed_controls, ControlOperation, Diagnostic, FailureClass, Operation,
    PueueRequest, QueueState, SendRequest, TaskId, MAX_SEND_INPUT_CHARS, SEND_LINE_TERMINATOR,
};

const MAX_EFFECTS_PER_EVENT: usize = 1;

/// One in-progress input line for `pueue send`. The draft binds to the task
/// it started on, so selection moves or refreshes cannot redirect it.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct InputDraft {
    task_id: TaskId,
    buffer: String,
}

impl InputDraft {
    pub const fn task_id(&self) -> TaskId {
        self.task_id
    }

    pub fn buffer(&self) -> &str {
        &self.buffer
    }
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct DashboardState {
    queue: Option<QueueState>,
    selected_task_id: Option<TaskId>,
    pending_confirmation: Option<PueueRequest>,
    input_draft: Option<InputDraft>,
    diagnostic: Option<Diagnostic>,
    mutations_enabled: bool,
}

impl DashboardState {
    pub fn queue(&self) -> Option<&QueueState> {
        self.queue.as_ref()
    }

    pub const fn selected_task_id(&self) -> Option<TaskId> {
        self.selected_task_id
    }

    pub const fn pending_confirmation(&self) -> Option<PueueRequest> {
        self.pending_confirmation
    }

    pub const fn input_draft(&self) -> Option<&InputDraft> {
        self.input_draft.as_ref()
    }

    pub const fn diagnostic(&self) -> Option<Diagnostic> {
        self.diagnostic
    }

    pub const fn mutations_enabled(&self) -> bool {
        self.mutations_enabled
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Direction {
    Previous,
    Next,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum DashboardEvent {
    RefreshRequested,
    RefreshSucceeded(QueueState),
    RefreshFailed(Diagnostic),
    MoveSelection(Direction),
    SelectTask(TaskId),
    ControlRequested(ControlOperation),
    ConfirmControl,
    CancelControl,
    ControlFinished(Result<(), Diagnostic>),
    SendRequested,
    InputAppended(char),
    InputBackspaced,
    SendConfirmed,
    SendCancelled,
    SendFinished(Result<(), Diagnostic>),
    Quit,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Effect {
    Refresh,
    RunControl(PueueRequest),
    RunSend(SendRequest),
    Exit,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Transition {
    pub state: DashboardState,
    pub effects: Vec<Effect>,
}

pub fn reduce(mut state: DashboardState, event: DashboardEvent) -> Transition {
    // r[impl herdr.pueue_plugin.dashboard] r[impl herdr.pueue_plugin.functional_boundary]
    let effects = match event {
        DashboardEvent::RefreshRequested => request_refresh(&mut state),
        DashboardEvent::RefreshSucceeded(queue) => accept_refresh(&mut state, queue),
        DashboardEvent::RefreshFailed(diagnostic) => reject_refresh(&mut state, diagnostic),
        DashboardEvent::MoveSelection(direction) => move_selection(&mut state, direction),
        DashboardEvent::SelectTask(task_id) => select_task(&mut state, task_id),
        DashboardEvent::ControlRequested(operation) => request_control(&mut state, operation),
        DashboardEvent::ConfirmControl => confirm_control(&mut state),
        DashboardEvent::CancelControl => cancel_control(&mut state),
        DashboardEvent::ControlFinished(result) => finish_control(&mut state, result),
        DashboardEvent::SendRequested => request_send(&mut state),
        DashboardEvent::InputAppended(character) => append_input(&mut state, character),
        DashboardEvent::InputBackspaced => backspace_input(&mut state),
        DashboardEvent::SendConfirmed => confirm_send(&mut state),
        DashboardEvent::SendCancelled => cancel_send(&mut state),
        DashboardEvent::SendFinished(result) => finish_send(&mut state, result),
        DashboardEvent::Quit => vec![Effect::Exit],
    };
    debug_assert!(effects.len() <= MAX_EFFECTS_PER_EVENT);
    debug_assert!(state_is_valid(&state));
    Transition { state, effects }
}

fn request_refresh(state: &mut DashboardState) -> Vec<Effect> {
    state.pending_confirmation = None;
    state.diagnostic = None;
    state.mutations_enabled = false;
    vec![Effect::Refresh]
}

fn accept_refresh(state: &mut DashboardState, queue: QueueState) -> Vec<Effect> {
    let preserved_selection = state
        .selected_task_id
        .filter(|task_id| queue.task(*task_id).is_some());
    state.selected_task_id = preserved_selection.or_else(|| queue.first_task_id());
    // A draft survives a refresh only while its task still accepts input.
    // Otherwise the user would type into a process that no longer exists.
    state.input_draft = state
        .input_draft
        .take()
        .filter(|draft| task_accepts_input(&queue, draft.task_id));
    state.queue = Some(queue);
    state.pending_confirmation = None;
    state.mutations_enabled = true;
    Vec::new()
}

fn reject_refresh(state: &mut DashboardState, diagnostic: Diagnostic) -> Vec<Effect> {
    state.queue = None;
    state.selected_task_id = None;
    state.pending_confirmation = None;
    state.input_draft = None;
    state.diagnostic = Some(diagnostic);
    state.mutations_enabled = false;
    Vec::new()
}

fn move_selection(state: &mut DashboardState, direction: Direction) -> Vec<Effect> {
    let Some(queue) = state.queue.as_ref() else {
        return Vec::new();
    };
    let Some(current) = state.selected_task_id else {
        state.selected_task_id = queue.first_task_id();
        return Vec::new();
    };
    let Some(position) = queue.task_position(current) else {
        state.selected_task_id = queue.first_task_id();
        return Vec::new();
    };
    let next_position = match direction {
        Direction::Previous => position.saturating_sub(1),
        Direction::Next => position
            .saturating_add(1)
            .min(queue.tasks().len().saturating_sub(1)),
    };
    state.selected_task_id = queue.tasks().get(next_position).map(|task| task.id);
    Vec::new()
}

fn select_task(state: &mut DashboardState, task_id: TaskId) -> Vec<Effect> {
    let is_known = state
        .queue
        .as_ref()
        .is_some_and(|queue| queue.task(task_id).is_some());
    if is_known {
        state.selected_task_id = Some(task_id);
    }
    Vec::new()
}

fn request_control(state: &mut DashboardState, operation: ControlOperation) -> Vec<Effect> {
    if state.input_draft.is_some() {
        state.diagnostic = Some(Diagnostic::new(
            Operation::PueueControl(operation),
            FailureClass::ControlRejected,
        ));
        return Vec::new();
    }
    let Some(request) = admitted_request(state, operation) else {
        state.diagnostic = Some(Diagnostic::new(
            Operation::PueueControl(operation),
            FailureClass::ControlRejected,
        ));
        return Vec::new();
    };
    state.diagnostic = None;
    if operation.requires_confirmation() {
        state.pending_confirmation = Some(request);
        return Vec::new();
    }
    state.mutations_enabled = false;
    vec![Effect::RunControl(request)]
}

fn admitted_request(state: &DashboardState, operation: ControlOperation) -> Option<PueueRequest> {
    if !state.mutations_enabled {
        return None;
    }
    let task_id = state.selected_task_id?;
    let task = state.queue.as_ref()?.task(task_id)?;
    allowed_controls(task.state)
        .contains(&operation)
        .then_some(PueueRequest::new(operation, task_id))
}

fn confirm_control(state: &mut DashboardState) -> Vec<Effect> {
    let Some(request) = state.pending_confirmation.take() else {
        return Vec::new();
    };
    let Some(admitted) = admitted_request(state, request.operation) else {
        state.diagnostic = Some(Diagnostic::new(
            Operation::PueueControl(request.operation),
            FailureClass::ControlRejected,
        ));
        return Vec::new();
    };
    if admitted != request {
        state.diagnostic = Some(Diagnostic::new(
            Operation::PueueControl(request.operation),
            FailureClass::ControlRejected,
        ));
        return Vec::new();
    }
    state.mutations_enabled = false;
    vec![Effect::RunControl(request)]
}

fn cancel_control(state: &mut DashboardState) -> Vec<Effect> {
    state.pending_confirmation = None;
    Vec::new()
}

fn finish_control(state: &mut DashboardState, result: Result<(), Diagnostic>) -> Vec<Effect> {
    state.pending_confirmation = None;
    state.diagnostic = result.err();
    state.mutations_enabled = false;
    vec![Effect::Refresh]
}

fn task_accepts_input(queue: &QueueState, task_id: TaskId) -> bool {
    queue
        .task(task_id)
        .is_some_and(|task| accepts_input(task.state))
}

/// The task a send may target: selected, live, and mutation-ready.
fn admitted_send_task(state: &DashboardState) -> Option<TaskId> {
    if !state.mutations_enabled || state.pending_confirmation.is_some() {
        return None;
    }
    let task_id = state.selected_task_id?;
    task_accepts_input(state.queue.as_ref()?, task_id).then_some(task_id)
}

fn request_send(state: &mut DashboardState) -> Vec<Effect> {
    state.diagnostic = None;
    let Some(task_id) = admitted_send_task(state) else {
        state.diagnostic = Some(Diagnostic::new(
            Operation::PueueSendInput,
            FailureClass::ControlRejected,
        ));
        return Vec::new();
    };
    state.input_draft = Some(InputDraft {
        task_id,
        buffer: String::new(),
    });
    Vec::new()
}

fn append_input(state: &mut DashboardState, character: char) -> Vec<Effect> {
    let Some(draft) = state.input_draft.as_mut() else {
        return Vec::new();
    };
    if character.is_control() {
        return Vec::new();
    }
    if draft.buffer.chars().count() >= MAX_SEND_INPUT_CHARS {
        return Vec::new();
    }
    draft.buffer.push(character);
    Vec::new()
}

fn backspace_input(state: &mut DashboardState) -> Vec<Effect> {
    if let Some(draft) = state.input_draft.as_mut() {
        draft.buffer.pop();
    }
    Vec::new()
}

fn confirm_send(state: &mut DashboardState) -> Vec<Effect> {
    let Some(draft) = state.input_draft.as_ref() else {
        return Vec::new();
    };
    // An empty line carries no intent. Keep the draft so the user can
    // continue typing instead of losing the input mode.
    if draft.buffer.trim().is_empty() {
        return Vec::new();
    }
    if admitted_send_task(state) != Some(draft.task_id) {
        state.input_draft = None;
        state.diagnostic = Some(Diagnostic::new(
            Operation::PueueSendInput,
            FailureClass::ControlRejected,
        ));
        return Vec::new();
    }
    let Some(draft) = state.input_draft.take() else {
        return Vec::new();
    };
    let mut input = draft.buffer;
    input.push(SEND_LINE_TERMINATOR);
    state.mutations_enabled = false;
    vec![Effect::RunSend(SendRequest::new(draft.task_id, input))]
}

fn cancel_send(state: &mut DashboardState) -> Vec<Effect> {
    state.input_draft = None;
    Vec::new()
}

fn finish_send(state: &mut DashboardState, result: Result<(), Diagnostic>) -> Vec<Effect> {
    state.input_draft = None;
    state.diagnostic = result.err();
    state.mutations_enabled = false;
    vec![Effect::Refresh]
}

fn state_is_valid(state: &DashboardState) -> bool {
    if state.mutations_enabled && state.queue.is_none() {
        return false;
    }
    if state.input_draft.is_some() && state.pending_confirmation.is_some() {
        return false;
    }
    if let Some(draft) = state.input_draft.as_ref() {
        let task_live = state
            .queue
            .as_ref()
            .is_some_and(|queue| task_accepts_input(queue, draft.task_id));
        if !task_live {
            return false;
        }
    }
    if let Some(request) = state.pending_confirmation {
        if !state.mutations_enabled {
            return false;
        }
        if admitted_request(state, request.operation) != Some(request) {
            return false;
        }
    }
    true
}

#[cfg(test)]
mod tests {
    use crate::{Completion, Group, GroupState, Task, TaskState};

    use super::*;

    const FIRST_TASK_ID: TaskId = TaskId::new(7);
    const SECOND_TASK_ID: TaskId = TaskId::new(9);

    fn queue(task_ids: &[TaskId]) -> QueueState {
        let tasks = task_ids
            .iter()
            .map(|task_id| Task {
                id: *task_id,
                group: "default".to_string(),
                state: if *task_id == FIRST_TASK_ID {
                    TaskState::Running
                } else {
                    TaskState::Completed(Completion::Success)
                },
                label: "task".to_string(),
                command: "echo task".to_string(),
                path: "/tmp".to_string(),
            })
            .collect();
        QueueState::new(
            vec![Group {
                name: "default".to_string(),
                state: GroupState::Running,
            }],
            tasks,
        )
    }

    fn accepted_state() -> DashboardState {
        reduce(
            DashboardState::default(),
            DashboardEvent::RefreshSucceeded(queue(&[FIRST_TASK_ID, SECOND_TASK_ID])),
        )
        .state
    }

    #[test]
    fn refresh_preserves_only_existing_selection() {
        // r[verify herdr.pueue_plugin.dashboard.refresh]
        let mut state = accepted_state();
        state.selected_task_id = Some(SECOND_TASK_ID);
        let preserved = reduce(
            state,
            DashboardEvent::RefreshSucceeded(queue(&[FIRST_TASK_ID, SECOND_TASK_ID])),
        )
        .state;
        assert_eq!(preserved.selected_task_id(), Some(SECOND_TASK_ID));

        let replaced = reduce(
            preserved,
            DashboardEvent::RefreshSucceeded(queue(&[FIRST_TASK_ID])),
        )
        .state;
        assert_eq!(replaced.selected_task_id(), Some(FIRST_TASK_ID));
    }

    #[test]
    fn destructive_control_requires_confirmation_and_cancel_has_no_effect() {
        // r[verify herdr.pueue_plugin.controls.confirm]
        let requested = reduce(
            accepted_state(),
            DashboardEvent::ControlRequested(ControlOperation::Kill),
        );
        assert!(requested.effects.is_empty());
        assert_eq!(
            requested.state.pending_confirmation(),
            Some(PueueRequest::new(ControlOperation::Kill, FIRST_TASK_ID))
        );

        let canceled = reduce(requested.state, DashboardEvent::CancelControl);
        assert!(canceled.effects.is_empty());
        assert_eq!(canceled.state.pending_confirmation(), None);
    }

    #[test]
    fn admitted_control_returns_one_typed_effect() {
        let transition = reduce(
            accepted_state(),
            DashboardEvent::ControlRequested(ControlOperation::Pause),
        );
        assert_eq!(
            transition.effects,
            [Effect::RunControl(PueueRequest::new(
                ControlOperation::Pause,
                FIRST_TASK_ID
            ))]
        );
        assert!(!transition.state.mutations_enabled());
    }

    #[test]
    fn rejected_control_has_no_process_effect() {
        let transition = reduce(
            accepted_state(),
            DashboardEvent::ControlRequested(ControlOperation::Remove),
        );
        assert!(transition.effects.is_empty());
        assert_eq!(
            transition.state.diagnostic(),
            Some(Diagnostic::new(
                Operation::PueueControl(ControlOperation::Remove),
                FailureClass::ControlRejected
            ))
        );
    }

    #[test]
    fn control_result_always_requests_a_refresh() {
        let failure = Diagnostic::new(
            Operation::PueueControl(ControlOperation::Pause),
            FailureClass::NonzeroExit,
        );
        let failed = reduce(
            accepted_state(),
            DashboardEvent::ControlFinished(Err(failure)),
        );
        assert_eq!(failed.effects, [Effect::Refresh]);
        assert_eq!(failed.state.diagnostic(), Some(failure));
        assert!(!failed.state.mutations_enabled());

        let succeeded = reduce(accepted_state(), DashboardEvent::ControlFinished(Ok(())));
        assert_eq!(succeeded.effects, [Effect::Refresh]);
        assert_eq!(succeeded.state.diagnostic(), None);
    }

    #[test]
    fn refresh_failure_clears_stale_mutation_authority() {
        // r[verify herdr.pueue_plugin.failures.unsupported]
        let failure = Diagnostic::new(Operation::PueueStatus, FailureClass::InvalidData);
        let failed = reduce(accepted_state(), DashboardEvent::RefreshFailed(failure)).state;
        assert!(failed.queue().is_none());
        assert_eq!(failed.selected_task_id(), None);
        assert!(!failed.mutations_enabled());
    }

    #[test]
    fn send_flow_types_and_submits_a_line() {
        // r[verify herdr.pueue_plugin.send]
        let requested = reduce(accepted_state(), DashboardEvent::SendRequested);
        assert!(requested.effects.is_empty());
        let draft = requested.state.input_draft().cloned();
        assert_eq!(
            draft.as_ref().map(|draft| draft.task_id()),
            Some(FIRST_TASK_ID)
        );

        let typed = reduce(requested.state, DashboardEvent::InputAppended('y'));
        assert_eq!(typed.state.input_draft().map(InputDraft::buffer), Some("y"));

        let confirmed = reduce(typed.state, DashboardEvent::SendConfirmed);
        assert_eq!(
            confirmed.effects,
            [Effect::RunSend(SendRequest::new(
                FIRST_TASK_ID,
                "y\n".to_string()
            ))]
        );
        assert!(confirmed.state.input_draft().is_none());
        assert!(!confirmed.state.mutations_enabled());

        let finished = reduce(confirmed.state, DashboardEvent::SendFinished(Ok(())));
        assert_eq!(finished.effects, [Effect::Refresh]);
        assert_eq!(finished.state.diagnostic(), None);
    }

    #[test]
    fn send_is_rejected_without_a_live_task() {
        // r[verify herdr.pueue_plugin.send.live_only]
        let selected = reduce(accepted_state(), DashboardEvent::SelectTask(SECOND_TASK_ID));
        let requested = reduce(selected.state, DashboardEvent::SendRequested);
        assert!(requested.effects.is_empty());
        assert!(requested.state.input_draft().is_none());
        assert_eq!(
            requested.state.diagnostic(),
            Some(Diagnostic::new(
                Operation::PueueSendInput,
                FailureClass::ControlRejected
            ))
        );
    }

    #[test]
    fn empty_input_is_not_sent_and_keeps_the_draft() {
        let requested = reduce(accepted_state(), DashboardEvent::SendRequested).state;
        let confirmed = reduce(requested, DashboardEvent::SendConfirmed);
        assert!(confirmed.effects.is_empty());
        assert!(confirmed.state.input_draft().is_some());
    }

    #[test]
    fn control_characters_and_overflow_never_enter_the_buffer() {
        // r[verify herdr.pueue_plugin.send.bounded]
        let mut state = reduce(accepted_state(), DashboardEvent::SendRequested).state;
        state = reduce(state, DashboardEvent::InputAppended('\n')).state;
        state = reduce(state, DashboardEvent::InputAppended('\0')).state;
        assert_eq!(state.input_draft().map(InputDraft::buffer), Some(""));
        for _ in 0..MAX_SEND_INPUT_CHARS {
            state = reduce(state, DashboardEvent::InputAppended('x')).state;
        }
        state = reduce(state, DashboardEvent::InputAppended('y')).state;
        let buffer = state.input_draft().map(InputDraft::buffer).unwrap_or("");
        assert_eq!(buffer.chars().count(), MAX_SEND_INPUT_CHARS);
        assert!(!buffer.contains('y'));

        let backspaced = reduce(state, DashboardEvent::InputBackspaced);
        assert_eq!(
            backspaced
                .state
                .input_draft()
                .map(InputDraft::buffer)
                .unwrap_or("")
                .chars()
                .count(),
            MAX_SEND_INPUT_CHARS - 1
        );
    }

    #[test]
    fn refresh_drops_a_draft_when_the_task_stops_accepting_input() {
        let mut state = reduce(accepted_state(), DashboardEvent::SendRequested).state;
        state = reduce(state, DashboardEvent::InputAppended('y')).state;
        let completed_queue = queue(&[SECOND_TASK_ID]);
        let refreshed = reduce(state, DashboardEvent::RefreshSucceeded(completed_queue));
        assert!(refreshed.state.input_draft().is_none());
    }

    #[test]
    fn refresh_keeps_a_draft_while_the_task_stays_live() {
        let mut state = reduce(accepted_state(), DashboardEvent::SendRequested).state;
        state = reduce(state, DashboardEvent::InputAppended('y')).state;
        let refreshed = reduce(
            state,
            DashboardEvent::RefreshSucceeded(queue(&[FIRST_TASK_ID, SECOND_TASK_ID])),
        );
        assert_eq!(
            refreshed.state.input_draft().map(InputDraft::buffer),
            Some("y")
        );
    }

    #[test]
    fn controls_are_rejected_while_an_input_draft_is_open() {
        let state = reduce(accepted_state(), DashboardEvent::SendRequested).state;
        let transition = reduce(
            state,
            DashboardEvent::ControlRequested(ControlOperation::Pause),
        );
        assert!(transition.effects.is_empty());
        assert_eq!(
            transition.state.diagnostic(),
            Some(Diagnostic::new(
                Operation::PueueControl(ControlOperation::Pause),
                FailureClass::ControlRejected
            ))
        );
    }

    #[test]
    fn cancel_send_clears_the_draft_without_effects() {
        let mut state = reduce(accepted_state(), DashboardEvent::SendRequested).state;
        state = reduce(state, DashboardEvent::InputAppended('y')).state;
        let canceled = reduce(state, DashboardEvent::SendCancelled);
        assert!(canceled.effects.is_empty());
        assert!(canceled.state.input_draft().is_none());
    }

    #[test]
    fn send_failure_surfaces_a_diagnostic_and_refreshes() {
        let failure = Diagnostic::new(Operation::PueueSendInput, FailureClass::NonzeroExit);
        let state = reduce(accepted_state(), DashboardEvent::SendRequested).state;
        let finished = reduce(state, DashboardEvent::SendFinished(Err(failure)));
        assert_eq!(finished.effects, [Effect::Refresh]);
        assert_eq!(finished.state.diagnostic(), Some(failure));
        assert!(finished.state.input_draft().is_none());
    }
}
