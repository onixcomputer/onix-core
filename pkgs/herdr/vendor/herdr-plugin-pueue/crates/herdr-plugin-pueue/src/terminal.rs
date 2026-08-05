use std::{collections::VecDeque, io, time::Duration, time::Instant};

use crossterm::{
    cursor::Show,
    event::{
        self, DisableMouseCapture, EnableMouseCapture, Event, KeyCode, KeyEvent, KeyEventKind,
        KeyModifiers, MouseButton, MouseEvent, MouseEventKind,
    },
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use pueue_plugin_core::{
    reduce, ControlOperation, DashboardEvent, DashboardState, Diagnostic, Direction, Effect,
    FailureClass, Operation, QueueOverview,
};
use ratatui::{backend::CrosstermBackend, Terminal};

use crate::{
    process::{
        open_dashboard_from_environment, open_split_dashboard_from_environment, PueueClient,
        WorkspaceOverviewReporter, SIDEBAR_METADATA_TTL_MS,
    },
    ui::{render_dashboard, RenderState},
};

const REFRESH_INTERVAL_MS: u64 = 2_000;
const MINIMUM_METADATA_TTL_REFRESH_INTERVALS: u64 = 4;
const REFRESH_INTERVAL: Duration = Duration::from_millis(REFRESH_INTERVAL_MS);
const INPUT_POLL_INTERVAL: Duration = Duration::from_millis(100);
const MAX_EFFECT_CHAIN: usize = 4;

const _: () = assert!(
    SIDEBAR_METADATA_TTL_MS >= REFRESH_INTERVAL_MS * MINIMUM_METADATA_TTL_REFRESH_INTERVALS
);

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
struct EffectOutcome {
    did_exit: bool,
    did_refresh: bool,
}

pub fn run_open_dashboard() -> Result<(), Diagnostic> {
    open_dashboard_from_environment()
}

pub fn run_open_split_dashboard() -> Result<(), Diagnostic> {
    open_split_dashboard_from_environment()
}

pub fn run_dashboard() -> Result<(), Diagnostic> {
    let backend = CrosstermBackend::new(io::stdout());
    let mut terminal = Terminal::new(backend).map_err(|_| terminal_diagnostic())?;
    enable_raw_mode().map_err(|_| terminal_diagnostic())?;
    if execute!(
        terminal.backend_mut(),
        EnterAlternateScreen,
        EnableMouseCapture
    )
    .is_err()
    {
        let _restore_raw_mode = disable_raw_mode();
        return Err(terminal_diagnostic());
    }
    let overview_reporter = WorkspaceOverviewReporter::from_environment();
    let run_result = run_dashboard_loop(
        &mut terminal,
        &PueueClient::installed(),
        overview_reporter.as_ref(),
    );
    let restore_result = restore_terminal(&mut terminal);
    match (run_result, restore_result) {
        (Err(diagnostic), _) => Err(diagnostic),
        (Ok(()), Err(diagnostic)) => Err(diagnostic),
        (Ok(()), Ok(())) => Ok(()),
    }
}

fn run_dashboard_loop(
    terminal: &mut Terminal<CrosstermBackend<io::Stdout>>,
    client: &PueueClient,
    overview_reporter: Option<&WorkspaceOverviewReporter>,
) -> Result<(), Diagnostic> {
    // r[impl herdr.pueue_plugin.dashboard.refresh]
    let mut state = DashboardState::default();
    let initial = apply_event(
        &mut state,
        DashboardEvent::RefreshRequested,
        client,
        overview_reporter,
    )?;
    if initial.did_exit {
        return Ok(());
    }
    let mut refresh_deadline = next_refresh_deadline();
    let mut is_running = true;
    while is_running {
        let mut render_state = RenderState::default();
        terminal
            .draw(|frame| render_state = render_dashboard(frame, &state))
            .map_err(|_| terminal_diagnostic())?;
        if Instant::now() >= refresh_deadline {
            let outcome = apply_event(
                &mut state,
                DashboardEvent::RefreshRequested,
                client,
                overview_reporter,
            )?;
            is_running = !outcome.did_exit;
            refresh_deadline = next_refresh_deadline();
            continue;
        }
        if !event::poll(INPUT_POLL_INTERVAL).map_err(|_| terminal_diagnostic())? {
            continue;
        }
        let terminal_event = event::read().map_err(|_| terminal_diagnostic())?;
        let Some(dashboard_event) = map_terminal_event(&state, &render_state, terminal_event)
        else {
            continue;
        };
        let outcome = apply_event(&mut state, dashboard_event, client, overview_reporter)?;
        is_running = !outcome.did_exit;
        if outcome.did_refresh {
            refresh_deadline = next_refresh_deadline();
        }
    }
    Ok(())
}

fn apply_event(
    state: &mut DashboardState,
    event: DashboardEvent,
    client: &PueueClient,
    overview_reporter: Option<&WorkspaceOverviewReporter>,
) -> Result<EffectOutcome, Diagnostic> {
    let transition = reduce(std::mem::take(state), event);
    *state = transition.state;
    let mut pending_effects = VecDeque::from(transition.effects);
    let mut outcome = EffectOutcome::default();
    for _step in 0..MAX_EFFECT_CHAIN {
        let Some(effect) = pending_effects.pop_front() else {
            return Ok(outcome);
        };
        match effect {
            Effect::Refresh => {
                outcome.did_refresh = true;
                let event = read_refresh_event(client, overview_reporter);
                append_transition(state, event, &mut pending_effects);
            }
            Effect::RunControl(request) => {
                let event = DashboardEvent::ControlFinished(client.control(request));
                append_transition(state, event, &mut pending_effects);
            }
            Effect::RunSend(request) => {
                let event = DashboardEvent::SendFinished(client.send_input(&request));
                append_transition(state, event, &mut pending_effects);
            }
            Effect::Exit => outcome.did_exit = true,
        }
    }
    if pending_effects.is_empty() {
        Ok(outcome)
    } else {
        Err(Diagnostic::new(
            Operation::Terminal,
            FailureClass::InvalidData,
        ))
    }
}

fn read_refresh_event(
    client: &PueueClient,
    overview_reporter: Option<&WorkspaceOverviewReporter>,
) -> DashboardEvent {
    match client.read_queue() {
        Ok(queue) => {
            let overview = QueueOverview::from_queue(&queue);
            if let Some(reporter) = overview_reporter {
                reporter.report_best_effort(&overview);
            }
            DashboardEvent::RefreshSucceeded(queue)
        }
        Err(diagnostic) => {
            if let Some(reporter) = overview_reporter {
                reporter.report_best_effort(&QueueOverview::unavailable());
            }
            DashboardEvent::RefreshFailed(diagnostic)
        }
    }
}

fn append_transition(
    state: &mut DashboardState,
    event: DashboardEvent,
    pending_effects: &mut VecDeque<Effect>,
) {
    let transition = reduce(std::mem::take(state), event);
    *state = transition.state;
    pending_effects.extend(transition.effects);
}

fn map_terminal_event(
    state: &DashboardState,
    render_state: &RenderState,
    terminal_event: Event,
) -> Option<DashboardEvent> {
    match terminal_event {
        Event::Key(key) => map_key_event(state, key),
        Event::Mouse(mouse) => map_mouse_event(render_state, mouse),
        Event::FocusGained | Event::FocusLost | Event::Paste(_) | Event::Resize(_, _) => None,
    }
}

fn map_key_event(state: &DashboardState, key: KeyEvent) -> Option<DashboardEvent> {
    if key.kind == KeyEventKind::Release {
        return None;
    }
    if state.pending_confirmation().is_some() {
        return match key.code {
            KeyCode::Enter | KeyCode::Char('y') => Some(DashboardEvent::ConfirmControl),
            KeyCode::Esc | KeyCode::Char('n') => Some(DashboardEvent::CancelControl),
            _ => None,
        };
    }
    if state.input_draft().is_some() {
        return match key.code {
            KeyCode::Enter => Some(DashboardEvent::SendConfirmed),
            KeyCode::Esc => Some(DashboardEvent::SendCancelled),
            KeyCode::Backspace => Some(DashboardEvent::InputBackspaced),
            KeyCode::Char(character)
                if !key.modifiers.contains(KeyModifiers::CONTROL)
                    && !key.modifiers.contains(KeyModifiers::SUPER) =>
            {
                Some(DashboardEvent::InputAppended(character))
            }
            _ => None,
        };
    }
    match key.code {
        KeyCode::Esc | KeyCode::Char('q') => Some(DashboardEvent::Quit),
        KeyCode::Up => Some(DashboardEvent::MoveSelection(Direction::Previous)),
        KeyCode::Down => Some(DashboardEvent::MoveSelection(Direction::Next)),
        KeyCode::Char('R') => Some(DashboardEvent::RefreshRequested),
        KeyCode::Char('i') => Some(DashboardEvent::SendRequested),
        KeyCode::Char('e') => control_event(ControlOperation::Enqueue),
        KeyCode::Char('s') => control_event(ControlOperation::Resume),
        KeyCode::Char('p') => control_event(ControlOperation::Pause),
        KeyCode::Char('k') => control_event(ControlOperation::Kill),
        KeyCode::Char('r') => control_event(ControlOperation::Restart),
        KeyCode::Char('d') => control_event(ControlOperation::Remove),
        _ => None,
    }
}

fn control_event(operation: ControlOperation) -> Option<DashboardEvent> {
    Some(DashboardEvent::ControlRequested(operation))
}

fn map_mouse_event(render_state: &RenderState, mouse: MouseEvent) -> Option<DashboardEvent> {
    match mouse.kind {
        MouseEventKind::Down(MouseButton::Left) => render_state
            .task_at(mouse.column, mouse.row)
            .map(DashboardEvent::SelectTask),
        MouseEventKind::ScrollUp => Some(DashboardEvent::MoveSelection(Direction::Previous)),
        MouseEventKind::ScrollDown => Some(DashboardEvent::MoveSelection(Direction::Next)),
        _ => None,
    }
}

fn next_refresh_deadline() -> Instant {
    let now = Instant::now();
    now.checked_add(REFRESH_INTERVAL).unwrap_or(now)
}

fn restore_terminal(
    terminal: &mut Terminal<CrosstermBackend<io::Stdout>>,
) -> Result<(), Diagnostic> {
    let screen_result = execute!(
        terminal.backend_mut(),
        DisableMouseCapture,
        LeaveAlternateScreen,
        Show
    );
    let raw_mode_result = disable_raw_mode();
    if screen_result.is_err() || raw_mode_result.is_err() {
        return Err(terminal_diagnostic());
    }
    Ok(())
}

const fn terminal_diagnostic() -> Diagnostic {
    Diagnostic::new(Operation::Terminal, FailureClass::TerminalUnavailable)
}

#[cfg(test)]
mod tests {
    use crossterm::event::KeyModifiers;
    use pueue_plugin_core::parse_status;

    use super::*;

    fn key(code: KeyCode) -> KeyEvent {
        KeyEvent::new(code, KeyModifiers::NONE)
    }

    #[test]
    fn maps_positive_keyboard_controls() {
        let state = DashboardState::default();
        assert_eq!(
            map_key_event(&state, key(KeyCode::Char('R'))),
            Some(DashboardEvent::RefreshRequested)
        );
        assert_eq!(
            map_key_event(&state, key(KeyCode::Char('p'))),
            Some(DashboardEvent::ControlRequested(ControlOperation::Pause))
        );
        assert_eq!(
            map_key_event(&state, key(KeyCode::Esc)),
            Some(DashboardEvent::Quit)
        );
    }

    #[test]
    fn ignores_unassigned_and_release_keys() {
        let state = DashboardState::default();
        assert_eq!(map_key_event(&state, key(KeyCode::Char('x'))), None);
        let mut release = key(KeyCode::Char('q'));
        release.kind = KeyEventKind::Release;
        assert_eq!(map_key_event(&state, release), None);
    }

    fn draft_state() -> DashboardState {
        let status_json = r#"{
            "tasks": {
                "7": {
                    "id": 7,
                    "created_at": "2026-08-05T12:00:00-04:00",
                    "original_command": "apt install",
                    "command": "apt install",
                    "path": "/tmp",
                    "envs": {},
                    "group": "default",
                    "dependencies": [],
                    "priority": 0,
                    "label": null,
                    "status": {
                        "Running": {
                            "enqueued_at": "2026-08-05T12:00:01-04:00",
                            "start": "2026-08-05T12:00:02-04:00"
                        }
                    }
                }
            },
            "groups": {
                "default": {
                    "status": "Running",
                    "parallel_tasks": 1
                }
            }
        }"#;
        let Ok(queue) = parse_status(status_json) else {
            // The draft assertions then fail and surface the parse problem.
            return DashboardState::default();
        };
        let accepted = reduce(
            DashboardState::default(),
            DashboardEvent::RefreshSucceeded(queue),
        )
        .state;
        reduce(accepted, DashboardEvent::SendRequested).state
    }

    #[test]
    fn opens_input_mode_from_normal_keys() {
        let state = DashboardState::default();
        assert_eq!(
            map_key_event(&state, key(KeyCode::Char('i'))),
            Some(DashboardEvent::SendRequested)
        );
    }

    #[test]
    fn maps_input_keys_while_a_draft_is_open() {
        // r[verify herdr.pueue_plugin.send]
        let state = draft_state();
        assert!(state.input_draft().is_some());
        assert_eq!(
            map_key_event(&state, key(KeyCode::Char('y'))),
            Some(DashboardEvent::InputAppended('y'))
        );
        assert_eq!(
            map_key_event(&state, key(KeyCode::Enter)),
            Some(DashboardEvent::SendConfirmed)
        );
        assert_eq!(
            map_key_event(&state, key(KeyCode::Backspace)),
            Some(DashboardEvent::InputBackspaced)
        );
        assert_eq!(
            map_key_event(&state, key(KeyCode::Esc)),
            Some(DashboardEvent::SendCancelled)
        );
    }

    #[test]
    fn ignores_control_modified_characters_while_typing() {
        let state = draft_state();
        let controlled = KeyEvent::new(KeyCode::Char('c'), KeyModifiers::CONTROL);
        assert_eq!(map_key_event(&state, controlled), None);
    }
}
