use pueue_plugin_core::{DashboardState, GroupState, Task, TaskId};
use ratatui::{
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::Line,
    widgets::{Block, Borders, Cell, Paragraph, Row, Table, Wrap},
    Frame,
};

const HEADER_AREA_INDEX: usize = 0;
const TASK_AREA_INDEX: usize = 1;
const MESSAGE_AREA_INDEX: usize = 2;
const FOOTER_AREA_INDEX: usize = 3;
const HEADER_HEIGHT_ROWS: u16 = 3;
const MESSAGE_HEIGHT_ROWS: u16 = 5;
const FOOTER_HEIGHT_ROWS: u16 = 3;
const TABLE_HEADER_ROWS: u16 = 1;
const TASK_ROW_HEIGHT_ROWS: u16 = 1;
const WINDOW_CENTER_DIVISOR: usize = 2;
const ID_COLUMN_WIDTH: u16 = 6;
const GROUP_COLUMN_WIDTH: u16 = 20;
const STATE_COLUMN_WIDTH: u16 = 18;
const LABEL_COLUMN_WIDTH: u16 = 20;
const PATH_COLUMN_WIDTH: u16 = 28;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
struct TaskHit {
    area: Rect,
    task_id: TaskId,
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub(crate) struct RenderState {
    task_hits: Vec<TaskHit>,
}

impl RenderState {
    pub(crate) fn task_at(&self, column: u16, row: u16) -> Option<TaskId> {
        self.task_hits
            .iter()
            .find(|hit| rect_contains(hit.area, column, row))
            .map(|hit| hit.task_id)
    }
}

pub(crate) fn render_dashboard(frame: &mut Frame<'_>, state: &DashboardState) -> RenderState {
    // r[impl herdr.pueue_plugin.dashboard]
    let areas = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(HEADER_HEIGHT_ROWS),
            Constraint::Min(1),
            Constraint::Length(MESSAGE_HEIGHT_ROWS),
            Constraint::Length(FOOTER_HEIGHT_ROWS),
        ])
        .split(frame.area());
    render_header(frame, areas[HEADER_AREA_INDEX], state);
    let render_state = render_tasks(frame, areas[TASK_AREA_INDEX], state);
    render_message(frame, areas[MESSAGE_AREA_INDEX], state);
    render_footer(frame, areas[FOOTER_AREA_INDEX]);
    render_state
}

fn render_header(frame: &mut Frame<'_>, area: Rect, state: &DashboardState) {
    let (group_count, task_count) = state.queue().map_or((0usize, 0usize), |queue| {
        (queue.groups().len(), queue.tasks().len())
    });
    let control_state = if state.mutations_enabled() {
        "enabled"
    } else {
        "disabled"
    };
    let text = format!(
        "Pueue dashboard  |  groups: {group_count}  tasks: {task_count}  controls: {control_state}"
    );
    let paragraph = Paragraph::new(text)
        .style(
            Style::default()
                .fg(Color::Cyan)
                .add_modifier(Modifier::BOLD),
        )
        .block(Block::default().borders(Borders::ALL));
    frame.render_widget(paragraph, area);
}

fn render_tasks(frame: &mut Frame<'_>, area: Rect, state: &DashboardState) -> RenderState {
    let block = Block::default().title(" Tasks ").borders(Borders::ALL);
    let inner = block.inner(area);
    frame.render_widget(block, area);
    let Some(queue) = state.queue() else {
        frame.render_widget(Paragraph::new("No accepted Pueue state."), inner);
        return RenderState::default();
    };
    let available_rows = usize::from(inner.height.saturating_sub(TABLE_HEADER_ROWS));
    let (start, end) = visible_task_range(queue.tasks(), state.selected_task_id(), available_rows);
    let visible_tasks = &queue.tasks()[start..end];
    let rows = visible_tasks.iter().map(|task| {
        let is_selected = state.selected_task_id() == Some(task.id);
        task_row(task, group_state_label(state, &task.group), is_selected)
    });
    let header = Row::new(["ID", "Group", "State", "Label", "Command", "Path"]).style(
        Style::default()
            .fg(Color::Yellow)
            .add_modifier(Modifier::BOLD),
    );
    let table = Table::new(
        rows,
        [
            Constraint::Length(ID_COLUMN_WIDTH),
            Constraint::Length(GROUP_COLUMN_WIDTH),
            Constraint::Length(STATE_COLUMN_WIDTH),
            Constraint::Length(LABEL_COLUMN_WIDTH),
            Constraint::Min(1),
            Constraint::Length(PATH_COLUMN_WIDTH),
        ],
    )
    .header(header)
    .column_spacing(1);
    frame.render_widget(table, inner);
    RenderState {
        task_hits: task_hits(inner, visible_tasks),
    }
}

fn task_row(task: &Task, group_state: &'static str, is_selected: bool) -> Row<'static> {
    let group = format!("{} ({group_state})", task.group);
    let style = if is_selected {
        Style::default()
            .bg(Color::Blue)
            .fg(Color::White)
            .add_modifier(Modifier::BOLD)
    } else {
        Style::default()
    };
    Row::new([
        Cell::from(task.id.to_string()),
        Cell::from(group),
        Cell::from(task.state.label().to_string()),
        Cell::from(task.label.clone()),
        Cell::from(task.command.clone()),
        Cell::from(task.path.clone()),
    ])
    .height(TASK_ROW_HEIGHT_ROWS)
    .style(style)
}

fn group_state_label(state: &DashboardState, group_name: &str) -> &'static str {
    state
        .queue()
        .and_then(|queue| queue.groups().iter().find(|group| group.name == group_name))
        .map_or("unknown", |group| match group.state {
            GroupState::Running => "running",
            GroupState::Paused => "paused",
            GroupState::Reset => "reset",
        })
}

fn render_message(frame: &mut Frame<'_>, area: Rect, state: &DashboardState) {
    let (title, message, color) = if let Some(request) = state.pending_confirmation() {
        (
            " Confirm ",
            format!(
                "Confirm {} for task {}? Enter/y confirms. Escape/n cancels.",
                request.operation.label(),
                request.task_id
            ),
            Color::Yellow,
        )
    } else if let Some(draft) = state.input_draft() {
        (
            " Send input ",
            format!(
                "Input for task {} (Enter sends the line, Escape cancels): {}",
                draft.task_id(),
                draft.buffer()
            ),
            Color::Cyan,
        )
    } else if let Some(diagnostic) = state.diagnostic() {
        (" Error ", diagnostic.message(), Color::Red)
    } else {
        (" Status ", "Ready.".to_string(), Color::DarkGray)
    };
    let paragraph = Paragraph::new(message)
        .style(Style::default().fg(color))
        .block(Block::default().title(title).borders(Borders::ALL))
        .wrap(Wrap { trim: true });
    frame.render_widget(paragraph, area);
}

fn render_footer(frame: &mut Frame<'_>, area: Rect) {
    let controls = Line::from(
        "↑/↓ select  click select  R refresh  i send input  e enqueue  s resume  p pause  k kill  r restart  d remove  q/Esc close",
    );
    let paragraph = Paragraph::new(controls)
        .block(Block::default().title(" Keys ").borders(Borders::ALL))
        .wrap(Wrap { trim: true });
    frame.render_widget(paragraph, area);
}

fn visible_task_range(
    tasks: &[Task],
    selected_task_id: Option<TaskId>,
    available_rows: usize,
) -> (usize, usize) {
    if tasks.is_empty() || available_rows == 0 {
        return (0, 0);
    }
    if tasks.len() <= available_rows {
        return (0, tasks.len());
    }
    let selected_position = selected_task_id
        .and_then(|selected| tasks.iter().position(|task| task.id == selected))
        .unwrap_or(0);
    let centered_start = selected_position.saturating_sub(available_rows / WINDOW_CENTER_DIVISOR);
    let max_start = tasks.len().saturating_sub(available_rows);
    let start = centered_start.min(max_start);
    (start, start.saturating_add(available_rows))
}

fn task_hits(inner: Rect, tasks: &[Task]) -> Vec<TaskHit> {
    tasks
        .iter()
        .enumerate()
        .filter_map(|(index, task)| {
            let row_offset = u16::try_from(index).ok()?;
            let row = inner
                .y
                .saturating_add(TABLE_HEADER_ROWS)
                .saturating_add(row_offset);
            Some(TaskHit {
                area: Rect::new(inner.x, row, inner.width, TASK_ROW_HEIGHT_ROWS),
                task_id: task.id,
            })
        })
        .collect()
}

fn rect_contains(area: Rect, column: u16, row: u16) -> bool {
    let right = area.x.saturating_add(area.width);
    let bottom = area.y.saturating_add(area.height);
    column >= area.x && column < right && row >= area.y && row < bottom
}

#[cfg(test)]
mod tests {
    use pueue_plugin_core::{Completion, TaskState};

    use super::*;

    const FIRST_TASK_ID: TaskId = TaskId::new(10);
    const SECOND_TASK_ID: TaskId = TaskId::new(11);
    const THIRD_TASK_ID: TaskId = TaskId::new(12);
    const TWO_VISIBLE_ROWS: usize = 2;
    const TEST_INNER_X: u16 = 4;
    const TEST_INNER_Y: u16 = 5;
    const TEST_INNER_WIDTH: u16 = 80;
    const TEST_INNER_HEIGHT: u16 = 10;

    fn task(id: TaskId) -> Task {
        Task {
            id,
            group: "default".to_string(),
            state: TaskState::Completed(Completion::Success),
            label: "task".to_string(),
            command: "echo task".to_string(),
            path: "/tmp".to_string(),
        }
    }

    #[test]
    fn selected_task_stays_inside_the_visible_window() {
        let tasks = [
            task(FIRST_TASK_ID),
            task(SECOND_TASK_ID),
            task(THIRD_TASK_ID),
        ];
        let final_window_start = tasks.len().saturating_sub(TWO_VISIBLE_ROWS);
        assert_eq!(
            visible_task_range(&tasks, Some(THIRD_TASK_ID), TWO_VISIBLE_ROWS),
            (final_window_start, tasks.len())
        );
        assert_eq!(
            visible_task_range(&tasks, None, TWO_VISIBLE_ROWS),
            (0, TWO_VISIBLE_ROWS)
        );
    }

    #[test]
    fn mouse_hit_returns_the_same_task_identity() {
        // r[verify herdr.pueue_plugin.dashboard.grouped]
        let inner = Rect::new(
            TEST_INNER_X,
            TEST_INNER_Y,
            TEST_INNER_WIDTH,
            TEST_INNER_HEIGHT,
        );
        let tasks = [task(FIRST_TASK_ID), task(SECOND_TASK_ID)];
        let render_state = RenderState {
            task_hits: task_hits(inner, &tasks),
        };
        let first_task_row = TEST_INNER_Y.saturating_add(TABLE_HEADER_ROWS);
        let second_task_row = first_task_row.saturating_add(TASK_ROW_HEIGHT_ROWS);
        let outside_column = TEST_INNER_X.saturating_sub(1);
        assert_eq!(
            render_state.task_at(TEST_INNER_X, first_task_row),
            Some(FIRST_TASK_ID)
        );
        assert_eq!(
            render_state.task_at(TEST_INNER_X, second_task_row),
            Some(SECOND_TASK_ID)
        );
        assert_eq!(render_state.task_at(outside_column, first_task_row), None);
        assert_eq!(render_state.task_at(TEST_INNER_X, TEST_INNER_Y), None);
    }
}
