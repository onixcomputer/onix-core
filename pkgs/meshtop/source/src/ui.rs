use std::{
    borrow::Cow,
    fmt::Write as _,
    io,
    time::{Duration, Instant},
};

use anyhow::Result;
use crossterm::{
    event::{self, Event, KeyCode, KeyEventKind},
    execute,
    terminal::{EnterAlternateScreen, LeaveAlternateScreen, disable_raw_mode, enable_raw_mode},
};
use ratatui::{
    Frame, Terminal,
    backend::CrosstermBackend,
    layout::{Constraint, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, BorderType, Borders, Paragraph, Sparkline, Wrap},
};
use tokio::sync::mpsc::{self, Receiver};

use crate::model::{DiskUsage, GpuUsage, ProcessUsage, Snapshot};

const STALE_AFTER: Duration = Duration::from_secs(10);
const HISTORY_LEN: usize = 48;
const TOP_PROCESSES: usize = 8;
const MIN_CARD_WIDTH: u16 = 38;
const MIN_CARD_HEIGHT: u16 = 14;
const CARD_GAP: u16 = 1;
const BACKGROUND: Color = Color::Rgb(13, 18, 29);
const PANEL: Color = Color::Rgb(24, 32, 47);
const BORDER: Color = Color::Rgb(68, 84, 109);
const TEXT: Color = Color::Rgb(229, 237, 249);
const MUTED: Color = Color::Rgb(148, 164, 190);
const CYAN: Color = Color::Rgb(102, 218, 242);
const PURPLE: Color = Color::Rgb(196, 155, 246);
const GREEN: Color = Color::Rgb(132, 225, 163);
const YELLOW: Color = Color::Rgb(249, 199, 111);
const RED: Color = Color::Rgb(255, 114, 130);
const FILLED: &str = "████████████████████████";
const EMPTY: &str = "░░░░░░░░░░░░░░░░░░░░░░░░";

pub struct Update {
    pub host_index: usize,
    pub result: Result<Snapshot, String>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Status {
    Waiting,
    Online,
    Stale,
    Offline,
}

struct Host {
    label: String,
    snapshot: Option<Snapshot>,
    last_update: Option<Instant>,
    error: Option<String>,
    history: Vec<u64>,
    top_processes: [Option<usize>; TOP_PROCESSES],
}

impl Host {
    fn status(&self, now: Instant) -> Status {
        if self.error.is_some() {
            Status::Offline
        } else if let Some(last) = self.last_update {
            if now.duration_since(last) > STALE_AFTER {
                Status::Stale
            } else {
                Status::Online
            }
        } else {
            Status::Waiting
        }
    }

    fn age(&self, now: Instant) -> String {
        self.last_update
            .map(|last| format!("{}s ago", now.duration_since(last).as_secs()))
            .unwrap_or_else(|| "never".to_owned())
    }
}

struct Dashboard {
    hosts: Vec<Host>,
    scroll_row: usize,
}

impl Dashboard {
    fn new(labels: Vec<String>) -> Self {
        Self {
            hosts: labels
                .into_iter()
                .map(|label| Host {
                    label,
                    snapshot: None,
                    last_update: None,
                    error: None,
                    history: Vec::with_capacity(HISTORY_LEN),
                    top_processes: [None; TOP_PROCESSES],
                })
                .collect(),
            scroll_row: 0,
        }
    }

    fn update(&mut self, update: Update, now: Instant) {
        let Some(host) = self.hosts.get_mut(update.host_index) else {
            return;
        };
        match update.result {
            Ok(snapshot) => {
                if host.history.len() == HISTORY_LEN {
                    host.history.rotate_left(1);
                    host.history.pop();
                }
                host.history.push(if snapshot.cpu_percent.is_finite() {
                    snapshot.cpu_percent.clamp(0.0, 100.0) as u64
                } else {
                    0
                });
                host.top_processes = top_process_indices(&snapshot);
                host.snapshot = Some(snapshot);
                host.last_update = Some(now);
                host.error = None;
            }
            Err(error) => host.error = Some(error),
        }
    }

    fn scroll(&mut self, delta: isize, area: Rect) {
        let (columns, visible_rows) = grid_size(area, self.hosts.len());
        let max_row = self
            .hosts
            .len()
            .div_ceil(columns)
            .saturating_sub(visible_rows);
        self.scroll_row = self
            .scroll_row
            .min(max_row)
            .saturating_add_signed(delta)
            .min(max_row);
    }
}

/// Restores the user's screen and input mode even when drawing or event handling unwinds.
struct ScreenGuard;

impl ScreenGuard {
    fn enter() -> io::Result<Self> {
        enable_raw_mode()?;
        if let Err(error) = execute!(io::stdout(), EnterAlternateScreen) {
            let _ = disable_raw_mode();
            return Err(error);
        }
        Ok(Self)
    }
}

impl Drop for ScreenGuard {
    fn drop(&mut self) {
        let _ = execute!(io::stdout(), LeaveAlternateScreen);
        let _ = disable_raw_mode();
    }
}

pub fn run(hosts: Vec<String>, mut updates: Receiver<Update>) -> Result<()> {
    let _screen = ScreenGuard::enter()?;
    let mut terminal = Terminal::new(CrosstermBackend::new(io::stdout()))?;
    let mut state = Dashboard::new(hosts);
    let mut closed = false;
    let mut dirty = true;
    let mut last_draw = Instant::now();
    loop {
        // A busy producer must not starve keyboard events or screen refreshes.
        for _ in 0..256 {
            match updates.try_recv() {
                Ok(update) => {
                    state.update(update, Instant::now());
                    dirty = true;
                }
                Err(mpsc::error::TryRecvError::Empty) => break,
                Err(mpsc::error::TryRecvError::Disconnected) => {
                    if !closed {
                        for host in &mut state.hosts {
                            host.error
                                .get_or_insert_with(|| "update channel closed".to_owned());
                        }
                        closed = true;
                        dirty = true;
                    }
                    break;
                }
            }
        }
        let now = Instant::now();
        if dirty || now.duration_since(last_draw) >= Duration::from_secs(1) {
            terminal.draw(|frame| draw(frame, &state, now))?;
            last_draw = now;
            dirty = false;
        }
        if event::poll(Duration::from_millis(200))?
            && let Event::Key(key) = event::read()?
        {
            if key.kind != KeyEventKind::Press && key.kind != KeyEventKind::Repeat {
                continue;
            }
            let (direction, page) = match key.code {
                KeyCode::Char('q') | KeyCode::Esc => break,
                KeyCode::Char('j') | KeyCode::Down => (1, false),
                KeyCode::Char('k') | KeyCode::Up => (-1, false),
                KeyCode::Tab | KeyCode::PageDown => (1, true),
                KeyCode::BackTab | KeyCode::PageUp => (-1, true),
                _ => continue,
            };
            let size = terminal.size()?;
            let body = Rect::new(0, 0, size.width, size.height.saturating_sub(2));
            let (_, visible_rows) = grid_size(body, state.hosts.len());
            state.scroll(
                if page {
                    direction * visible_rows as isize
                } else {
                    direction
                },
                body,
            );
            dirty = true;
        }
    }
    Ok(())
}

fn draw(frame: &mut Frame<'_>, state: &Dashboard, now: Instant) {
    let area = frame.area();
    if area.width == 0 || area.height == 0 {
        return;
    }
    if area.height < 3 {
        frame.render_widget(Paragraph::new("meshtop  q: quit"), area);
        return;
    }
    frame.render_widget(
        Block::default().style(Style::default().bg(BACKGROUND)),
        area,
    );
    let rows = Layout::vertical([
        Constraint::Length(1),
        Constraint::Min(1),
        Constraint::Length(1),
    ])
    .split(area);
    let body = rows[1];
    let (columns, visible_rows) = grid_size(body, state.hosts.len());
    let total_rows = state.hosts.len().div_ceil(columns);
    let first_row = state
        .scroll_row
        .min(total_rows.saturating_sub(visible_rows));
    let start = first_row * columns;
    let end = ((first_row + visible_rows) * columns).min(state.hosts.len());
    let online = state
        .hosts
        .iter()
        .filter(|host| host.status(now) == Status::Online)
        .count();
    let page = if total_rows > visible_rows {
        format!("   {}–{} / {}", start + 1, end, state.hosts.len())
    } else {
        String::new()
    };
    frame.render_widget(
        Paragraph::new(Line::from(vec![
            Span::styled(
                " ◢ MESHTOP ",
                Style::default().fg(CYAN).add_modifier(Modifier::BOLD),
            ),
            Span::styled("  SYSTEM MONITOR  ", Style::default().fg(MUTED)),
            Span::styled(
                format!("● {online}/{} live", state.hosts.len()),
                Style::default().fg(if online == state.hosts.len() {
                    GREEN
                } else {
                    YELLOW
                }),
            ),
            Span::styled(page, Style::default().fg(MUTED)),
        ])),
        rows[0],
    );
    frame.render_widget(
        Paragraph::new(Line::from(vec![
            Span::styled(" q", Style::default().fg(CYAN).add_modifier(Modifier::BOLD)),
            Span::styled(" quit   ", Style::default().fg(MUTED)),
            Span::styled("j/k", Style::default().fg(CYAN)),
            Span::styled(" rows   ", Style::default().fg(MUTED)),
            Span::styled("Tab/PgDn", Style::default().fg(CYAN)),
            Span::styled(" next   ", Style::default().fg(MUTED)),
            Span::styled("PgUp", Style::default().fg(CYAN)),
            Span::styled(" previous", Style::default().fg(MUTED)),
        ])),
        rows[2],
    );
    if state.hosts.is_empty() {
        frame.render_widget(Paragraph::new("No hosts configured"), body);
        return;
    }
    let card_width = (body.width - (columns as u16 - 1) * CARD_GAP) / columns as u16;
    let card_height = (body.height - (visible_rows as u16 - 1) * CARD_GAP) / visible_rows as u16;
    for (index, host) in state.hosts[start..end].iter().enumerate() {
        let row = index / columns;
        let column = index % columns;
        let x = body.x + column as u16 * card_width + column as u16 * CARD_GAP;
        let y = body.y + row as u16 * card_height + row as u16 * CARD_GAP;
        let width = if column + 1 == columns {
            body.width - column as u16 * card_width - column as u16 * CARD_GAP
        } else {
            card_width
        };
        let height = if row + 1 == visible_rows {
            body.height - row as u16 * card_height - row as u16 * CARD_GAP
        } else {
            card_height
        };
        draw_detail(frame, Rect::new(x, y, width, height), host, now);
    }
}

fn grid_size(area: Rect, host_count: usize) -> (usize, usize) {
    let columns = ((usize::from(area.width) + usize::from(CARD_GAP))
        / usize::from(MIN_CARD_WIDTH + CARD_GAP))
    .max(1)
    .min(host_count.max(1));
    let visible_rows = ((usize::from(area.height) + usize::from(CARD_GAP))
        / usize::from(MIN_CARD_HEIGHT + CARD_GAP))
    .max(1)
    .min(host_count.div_ceil(columns).max(1));
    (columns, visible_rows)
}

fn status_label(status: Status) -> (&'static str, Color) {
    match status {
        Status::Waiting => ("WAIT", MUTED),
        Status::Online => ("ON", GREEN),
        Status::Stale => ("STALE", YELLOW),
        Status::Offline => ("OFF", RED),
    }
}

fn draw_detail(frame: &mut Frame<'_>, area: Rect, host: &Host, now: Instant) {
    let status_kind = host.status(now);
    let (status, color) = status_label(status_kind);
    let title = Line::from(vec![
        Span::styled(
            format!(" {} ", host.label),
            Style::default().fg(TEXT).add_modifier(Modifier::BOLD),
        ),
        Span::styled(
            format!(" {status} "),
            Style::default().fg(color).add_modifier(Modifier::BOLD),
        ),
        Span::styled(format!("  {} ", host.age(now)), Style::default().fg(MUTED)),
    ]);
    let block = Block::default()
        .title(title)
        .title_style(Style::default().fg(TEXT))
        .border_type(BorderType::Rounded)
        .borders(Borders::ALL)
        .border_style(Style::default().fg(if status_kind == Status::Online {
            BORDER
        } else {
            color
        }))
        .style(Style::default().bg(PANEL).fg(TEXT));
    let inner = block.inner(area);
    frame.render_widget(block, area);
    if inner.width == 0 || inner.height == 0 {
        return;
    }
    let Some(snapshot) = &host.snapshot else {
        frame.render_widget(
            Paragraph::new(host.error.as_deref().unwrap_or("Waiting for first sample"))
                .style(Style::default().fg(if host.error.is_some() { RED } else { MUTED }))
                .wrap(Wrap { trim: true }),
            inner,
        );
        return;
    };
    if inner.width < 50 || inner.height < if host.error.is_some() { 23 } else { 21 } {
        draw_compact(frame, inner, host, snapshot);
    } else {
        draw_full(frame, inner, host, snapshot);
    }
}

fn draw_compact(frame: &mut Frame<'_>, area: Rect, host: &Host, snapshot: &Snapshot) {
    let gpu_rows = if snapshot.gpus.as_ref().is_some_and(|gpus| !gpus.is_empty()) {
        2
    } else {
        1
    };
    let headings = area.height >= 17 + gpu_rows + u16::from(host.error.is_some());
    let mut lines = Vec::with_capacity(20);
    if let Some(error) = &host.error {
        lines.push(Line::styled(
            format!("Last poll failed: {error}"),
            Style::default().fg(RED).add_modifier(Modifier::BOLD),
        ));
    }
    if headings {
        lines.push(hardware_heading(
            " ── CPU: ",
            snapshot.cpu_model.as_deref().unwrap_or("model unavailable"),
            area.width,
            CYAN,
        ));
    }
    lines.push(cpu_line(
        snapshot,
        8,
        false,
        (!headings).then_some(area.width),
    ));
    lines.push(Line::styled(
        core_line(snapshot, area.width),
        Style::default().fg(MUTED),
    ));
    if area.height >= 14 {
        lines.push(Line::from(vec![
            Span::styled("LOAD ", Style::default().fg(MUTED)),
            Span::styled(
                format!(
                    "{:.2}  {:.2}  {:.2}",
                    snapshot.load_average[0], snapshot.load_average[1], snapshot.load_average[2]
                ),
                Style::default().fg(TEXT),
            ),
        ]));
    }
    if headings {
        lines.push(Line::styled(" ── MEMORY", Style::default().fg(PURPLE)));
    }
    lines.push(usage_line(
        "RAM",
        snapshot.memory_used,
        snapshot.memory_total,
        6,
    ));
    lines.push(usage_line(
        "SWAP",
        snapshot.swap_used,
        snapshot.swap_total,
        6,
    ));
    if headings {
        if let Some(gpu) = snapshot.gpus.as_ref().and_then(|gpus| gpus.first()) {
            lines.push(hardware_heading(
                " ── GPU: ",
                &gpu.label,
                area.width,
                PURPLE,
            ));
        } else {
            lines.push(Line::styled(" ── GRAPHICS", Style::default().fg(PURPLE)));
        }
    }
    if let Some(gpu) = snapshot.gpus.as_ref().and_then(|gpus| gpus.first()) {
        lines.extend(gpu_lines(
            gpu,
            true,
            !headings,
            (!headings).then_some(area.width),
        ));
    } else {
        lines.push(gpu_unavailable(snapshot));
    }
    if headings {
        lines.push(Line::styled(" ── NETWORK", Style::default().fg(CYAN)));
    }
    lines.push(network_line(snapshot));
    lines.push(Line::styled(
        format!("UP   {}", uptime(snapshot.uptime_seconds)),
        Style::default().fg(MUTED),
    ));
    if headings && !snapshot.disks.is_empty() {
        lines.push(Line::styled(" ── FILESYSTEMS", Style::default().fg(PURPLE)));
    }
    for disk in snapshot.disks.iter().take(2) {
        lines.push(disk_line(disk, true));
    }
    if headings && !snapshot.processes.is_empty() {
        lines.push(Line::styled(" ── PROCESSES", Style::default().fg(CYAN)));
    }
    for process in host
        .top_processes
        .iter()
        .flatten()
        .take(if area.height < 14 + u16::from(host.error.is_some()) {
            1
        } else {
            2
        })
        .map(|index| &snapshot.processes[*index])
    {
        lines.push(process_line(process, true));
    }
    frame.render_widget(Paragraph::new(lines), area);
}

fn core_line(snapshot: &Snapshot, width: u16) -> String {
    let mut cores = String::from("Cores");
    for (index, percent) in snapshot.cores_percent.iter().enumerate() {
        let previous_len = cores.len();
        write!(cores, "  {index}:{percent:.0}%").expect("writing to String");
        if cores.len() > usize::from(width) {
            cores.truncate(previous_len);
            break;
        }
    }
    cores
}
fn cpu_color(percent: f64) -> Color {
    if percent >= 90.0 {
        RED
    } else if percent >= 70.0 {
        YELLOW
    } else {
        CYAN
    }
}

fn usage_color(percent: f64) -> Color {
    if percent >= 90.0 {
        RED
    } else if percent >= 75.0 {
        YELLOW
    } else {
        GREEN
    }
}

fn meter(percent: f64, width: usize, color: Color) -> [Span<'static>; 2] {
    let bounded = if percent.is_finite() {
        percent.clamp(0.0, 100.0)
    } else {
        0.0
    };
    let filled = ((bounded * width as f64 / 100.0).round() as usize).min(width);
    [
        Span::styled(&FILLED[..filled * 3], Style::default().fg(color)),
        Span::styled(&EMPTY[..(width - filled) * 3], Style::default().fg(BORDER)),
    ]
}

fn cpu_line(
    snapshot: &Snapshot,
    width: usize,
    with_load: bool,
    compact_width: Option<u16>,
) -> Line<'static> {
    let [filled, empty] = meter(
        f64::from(snapshot.cpu_percent),
        width,
        cpu_color(f64::from(snapshot.cpu_percent)),
    );
    let percentage = format!("{:>5.1}% ", snapshot.cpu_percent);
    let label = if let Some(area_width) = compact_width {
        let model = snapshot.cpu_model.as_deref().unwrap_or("model unavailable");
        let available =
            usize::from(area_width).saturating_sub("CPU ".len() + percentage.len() + width + 1);
        Span::styled(
            format!("CPU {} ", clipped_model(model, available)),
            Style::default().fg(MUTED),
        )
    } else {
        Span::styled("CPU ", Style::default().fg(MUTED))
    };
    let mut spans = vec![
        label,
        Span::styled(
            percentage,
            Style::default()
                .fg(cpu_color(f64::from(snapshot.cpu_percent)))
                .add_modifier(Modifier::BOLD),
        ),
        filled,
        empty,
    ];
    if with_load {
        spans.push(Span::styled(
            format!(
                "   LOAD {:.1} / {:.1} / {:.1}",
                snapshot.load_average[0], snapshot.load_average[1], snapshot.load_average[2]
            ),
            Style::default().fg(MUTED),
        ));
    }
    Line::from(spans)
}

fn usage_line(label: &'static str, used: u64, total: u64, width: usize) -> Line<'static> {
    let percent = ratio(used, total);
    let [filled, empty] = meter(percent, width, usage_color(percent));
    let values = if width <= 6 {
        format!(" {} / {}", bytes(used), bytes(total))
    } else {
        format!(" {} / {}  {:.0}%", bytes(used), bytes(total), percent)
    };
    Line::from(vec![
        Span::styled(format!("{label:<5}"), Style::default().fg(MUTED)),
        filled,
        empty,
        Span::styled(values, Style::default().fg(TEXT)),
    ])
}

fn network_line(snapshot: &Snapshot) -> Line<'static> {
    Line::from(vec![
        Span::styled(
            format!("↓ {}/s", bytes(snapshot.rx_bytes_per_second)),
            Style::default().fg(CYAN),
        ),
        Span::styled("    ", Style::default().fg(MUTED)),
        Span::styled(
            format!("↑ {}/s", bytes(snapshot.tx_bytes_per_second)),
            Style::default().fg(PURPLE),
        ),
    ])
}

fn clipped(value: &str, chars: usize) -> &str {
    value
        .char_indices()
        .nth(chars)
        .map_or(value, |(end, _)| &value[..end])
}

fn clipped_model(model: &str, available: usize) -> Cow<'_, str> {
    let short = clipped(model, available);
    if short.len() < model.len() && available > 0 {
        Cow::Owned(format!("{}…", clipped(model, available - 1)))
    } else {
        Cow::Borrowed(short)
    }
}

fn hardware_heading(prefix: &str, model: &str, width: u16, color: Color) -> Line<'static> {
    let available = usize::from(width).saturating_sub(prefix.len());
    Line::styled(
        format!("{prefix}{}", clipped_model(model, available)),
        Style::default().fg(color),
    )
}

fn disk_line(disk: &DiskUsage, compact: bool) -> Line<'static> {
    let percent = ratio(disk.used, disk.total);
    let mount = if compact {
        let short = clipped(&disk.mount, 7);
        format!(
            "{}{} ",
            short,
            if short.len() < disk.mount.len() {
                "…"
            } else {
                ""
            }
        )
    } else {
        format!("{:<9} ", clipped(&disk.mount, 9))
    };
    let mut spans = vec![Span::styled(mount, Style::default().fg(TEXT))];
    if !compact {
        let [filled, empty] = meter(percent, 6, usage_color(percent));
        spans.push(filled);
        spans.push(empty);
    }
    let values = if compact {
        format!(
            "{:>3.0}%  {}/{}",
            percent,
            bytes(disk.used),
            bytes(disk.total)
        )
    } else {
        format!(
            " {:>3.0}%  {} / {}",
            percent,
            bytes(disk.used),
            bytes(disk.total)
        )
    };
    spans.push(Span::styled(
        values,
        Style::default().fg(usage_color(percent)),
    ));
    Line::from(spans)
}

fn process_line(process: &ProcessUsage, compact: bool) -> Line<'static> {
    let name_width = if compact { 10 } else { 18 };
    Line::from(vec![
        Span::styled(format!("{:>6} ", process.pid), Style::default().fg(MUTED)),
        Span::styled(
            format!("{:<name_width$} ", clipped(&process.name, name_width)),
            Style::default().fg(TEXT),
        ),
        Span::styled(
            format!("{:>5.1}% ", process.cpu_percent),
            Style::default().fg(cpu_color(f64::from(process.cpu_percent))),
        ),
        Span::styled(bytes(process.memory_bytes), Style::default().fg(PURPLE)),
    ])
}

fn gpu_unavailable(snapshot: &Snapshot) -> Line<'static> {
    Line::styled(
        if snapshot.gpus.is_some() {
            "GPU counters unavailable"
        } else {
            "GPU telemetry not reported"
        },
        Style::default().fg(MUTED),
    )
}

fn gpu_lines<'a>(
    gpu: &'a GpuUsage,
    compact: bool,
    show_label: bool,
    compact_width: Option<u16>,
) -> [Line<'a>; 2] {
    let percent_label = gpu
        .utilization_percent
        .map(|percent| format!("{percent:.0}% "));
    let busy_width = percent_label.as_ref().map_or(" busy n/a".len(), |label| {
        label.len() + if compact { 4 } else { 8 }
    });
    let model = match (show_label, compact_width) {
        (true, Some(area_width)) => clipped_model(
            &gpu.label,
            usize::from(area_width).saturating_sub(1 + busy_width),
        ),
        (true, None) => Cow::Borrowed(gpu.label.as_str()),
        (false, _) => Cow::Borrowed("GPU"),
    };
    let mut activity = vec![
        Span::styled(
            model,
            Style::default().fg(PURPLE).add_modifier(Modifier::BOLD),
        ),
        Span::raw(" "),
    ];
    if let (Some(percent), Some(label)) = (gpu.utilization_percent, percent_label) {
        activity.push(Span::styled(
            label,
            Style::default().fg(cpu_color(f64::from(percent))),
        ));
        let [filled, empty] = meter(f64::from(percent), if compact { 4 } else { 8 }, PURPLE);
        activity.push(filled);
        activity.push(empty);
    } else {
        activity.push(Span::styled(" busy n/a", Style::default().fg(MUTED)));
    }
    if let Some(temp) = gpu.temperature_celsius {
        activity.push(Span::styled(
            format!("  {temp:.0}°C"),
            Style::default().fg(YELLOW),
        ));
    }
    if let Some(clock) = gpu.clock_mhz {
        activity.push(Span::styled(
            format!("  {clock}MHz"),
            Style::default().fg(MUTED),
        ));
    }
    let vram = if let (Some(used), Some(total)) = (gpu.memory_used, gpu.memory_total) {
        usage_line("VRAM", used, total, if compact { 6 } else { 10 })
    } else {
        Line::styled("VRAM unavailable", Style::default().fg(MUTED))
    };
    [Line::from(activity), vram]
}

fn section(title: &'static str) -> Block<'static> {
    Block::default()
        .title(title)
        .title_style(Style::default().fg(CYAN).add_modifier(Modifier::BOLD))
        .borders(Borders::TOP)
        .border_style(Style::default().fg(BORDER))
}

fn draw_full(frame: &mut Frame<'_>, area: Rect, host: &Host, snapshot: &Snapshot) {
    let gpu_height = if snapshot.gpus.as_ref().is_some_and(|gpus| !gpus.is_empty()) {
        4
    } else {
        2
    };
    let sections = Layout::vertical([
        Constraint::Length(if host.error.is_some() { 2 } else { 0 }),
        Constraint::Length(6),
        Constraint::Length(3),
        Constraint::Length(gpu_height),
        Constraint::Length(3),
        Constraint::Length(4),
        Constraint::Min(1),
    ])
    .split(area);
    if let Some(error) = &host.error {
        frame.render_widget(
            Paragraph::new(format!("LAST POLL FAILED  {error}"))
                .style(Style::default().fg(RED))
                .wrap(Wrap { trim: true }),
            sections[0],
        );
    }
    let cpu = Layout::vertical([Constraint::Length(3), Constraint::Length(3)]).split(sections[1]);
    frame.render_widget(
        Paragraph::new(vec![
            Line::styled(
                format!(
                    "CPU  {}",
                    snapshot.cpu_model.as_deref().unwrap_or("model unavailable")
                ),
                Style::default().fg(CYAN).add_modifier(Modifier::BOLD),
            ),
            cpu_line(snapshot, 10, true, None),
            Line::styled(
                core_line(snapshot, cpu[0].width),
                Style::default().fg(MUTED),
            ),
        ]),
        cpu[0],
    );
    frame.render_widget(
        Sparkline::default()
            .block(section(" CPU HISTORY "))
            .data(&host.history)
            .max(100)
            .style(Style::default().fg(CYAN)),
        cpu[1],
    );
    frame.render_widget(
        Paragraph::new(vec![
            usage_line("RAM", snapshot.memory_used, snapshot.memory_total, 10),
            usage_line("SWAP", snapshot.swap_used, snapshot.swap_total, 10),
        ])
        .block(section(" MEMORY / SWAP ")),
        sections[2],
    );
    let graphics = if let Some(gpu) = snapshot.gpus.as_ref().and_then(|gpus| gpus.first()) {
        let [activity, vram] = gpu_lines(gpu, false, false, None);
        vec![
            Line::styled(gpu.label.as_str(), Style::default().fg(PURPLE)),
            activity,
            vram,
        ]
    } else {
        vec![gpu_unavailable(snapshot)]
    };
    frame.render_widget(
        Paragraph::new(graphics).block(section(" GRAPHICS ")),
        sections[3],
    );
    frame.render_widget(
        Paragraph::new(vec![
            network_line(snapshot),
            Line::styled(
                format!("UPTIME  {}", uptime(snapshot.uptime_seconds)),
                Style::default().fg(MUTED),
            ),
        ])
        .block(section(" NETWORK ")),
        sections[4],
    );
    let disks: Vec<_> = snapshot
        .disks
        .iter()
        .take(sections[5].height.saturating_sub(1) as usize)
        .map(|disk| disk_line(disk, false))
        .collect();
    frame.render_widget(
        Paragraph::new(disks).block(section(" FILESYSTEMS ")),
        sections[5],
    );
    let processes: Vec<_> = host
        .top_processes
        .iter()
        .flatten()
        .take(sections[6].height.saturating_sub(1) as usize)
        .map(|index| process_line(&snapshot.processes[*index], false))
        .collect();
    frame.render_widget(
        Paragraph::new(processes).block(section(" PROCESSES    PID / NAME / CPU / RAM ")),
        sections[6],
    );
}

fn top_process_indices(snapshot: &Snapshot) -> [Option<usize>; TOP_PROCESSES] {
    let mut top = [None; TOP_PROCESSES];
    for (process_index, process) in snapshot.processes.iter().enumerate() {
        let mut index = 0;
        while index < TOP_PROCESSES
            && top[index].is_some_and(|prior_index: usize| {
                let prior = &snapshot.processes[prior_index];
                prior.cpu_percent.total_cmp(&process.cpu_percent).is_gt()
                    || (prior.cpu_percent == process.cpu_percent && prior.pid < process.pid)
            })
        {
            index += 1;
        }
        if index < TOP_PROCESSES {
            top.copy_within(index..TOP_PROCESSES - 1, index + 1);
            top[index] = Some(process_index);
        }
    }
    top
}

fn ratio(used: u64, total: u64) -> f64 {
    if total == 0 {
        0.0
    } else {
        used as f64 / total as f64 * 100.0
    }
}

fn bytes(value: u64) -> String {
    const UNITS: [&str; 5] = ["B", "KiB", "MiB", "GiB", "TiB"];
    let mut n = value as f64;
    let mut unit = 0;
    while n >= 1024.0 && unit < UNITS.len() - 1 {
        n /= 1024.0;
        unit += 1;
    }
    if unit == 0 {
        format!("{value} B")
    } else {
        format!("{n:.1} {}", UNITS[unit])
    }
}

fn uptime(seconds: u64) -> String {
    format!(
        "{}d {:02}h {:02}m",
        seconds / 86_400,
        seconds / 3_600 % 24,
        seconds / 60 % 60
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::{DiskUsage, GpuUsage, ProcessUsage};
    use ratatui::backend::TestBackend;

    fn screen(state: &Dashboard, now: Instant, width: u16, height: u16) -> String {
        let mut terminal = Terminal::new(TestBackend::new(width, height)).unwrap();
        terminal.draw(|frame| draw(frame, state, now)).unwrap();
        terminal
            .backend()
            .buffer()
            .content()
            .chunks(width as usize)
            .map(|line| line.iter().map(|cell| cell.symbol()).collect::<String>())
            .collect::<Vec<_>>()
            .join("\n")
    }

    fn snapshot() -> Snapshot {
        Snapshot {
            host: "untrusted-reported-name".to_owned(),
            cpu_model: Some("AMD Ryzen 9 9950X".into()),
            uptime_seconds: 60,
            cpu_percent: 42.0,
            cores_percent: vec![42.0],
            load_average: [0.1, 0.2, 0.3],
            memory_used: 1,
            memory_total: 2,
            swap_used: 0,
            swap_total: 0,
            rx_bytes_per_second: 3,
            tx_bytes_per_second: 4,
            disks: Vec::new(),
            gpus: Some(vec![GpuUsage {
                label: "AMD Granite Ridge [Radeon Graphics]".into(),
                utilization_percent: Some(50.0),
                memory_used: Some(1),
                memory_total: Some(2),
                temperature_celsius: Some(65.0),
                clock_mhz: Some(2200),
            }]),
            processes: Vec::new(),
        }
    }

    #[test]
    fn success_error_recovery_and_age() {
        let start = Instant::now();
        let mut state = Dashboard::new(vec!["pinned-name".into()]);
        assert_eq!(state.hosts[0].status(start), Status::Waiting);
        state.update(
            Update {
                host_index: 0,
                result: Ok(snapshot()),
            },
            start,
        );
        assert_eq!(state.hosts[0].status(start), Status::Online);
        assert_eq!(
            state.hosts[0].status(start + STALE_AFTER + Duration::from_secs(1)),
            Status::Stale
        );
        state.update(
            Update {
                host_index: 0,
                result: Err("unreachable".into()),
            },
            start + STALE_AFTER,
        );
        assert_eq!(state.hosts[0].status(start + STALE_AFTER), Status::Offline);
        assert_eq!(state.hosts[0].age(start + STALE_AFTER), "10s ago");
        assert_eq!(
            state.hosts[0].snapshot.as_ref().unwrap().host,
            "untrusted-reported-name"
        );
        assert_eq!(state.hosts[0].label, "pinned-name");
        state.update(
            Update {
                host_index: 0,
                result: Ok(snapshot()),
            },
            start + STALE_AFTER,
        );
        assert_eq!(state.hosts[0].status(start + STALE_AFTER), Status::Online);
        assert!(state.hosts[0].error.is_none());
    }
    #[test]
    fn both_hosts_show_live_metrics_and_independent_failure_on_one_screen() {
        let now = Instant::now();
        let mut state = Dashboard::new(vec!["aspen3".into(), "britton-desktop".into()]);
        let mut desktop = snapshot();
        desktop.cpu_percent = 84.0;
        desktop.cpu_model = Some("AMD Ryzen AI Max+ 395".into());
        if let Some(gpu) = desktop.gpus.as_mut().and_then(|gpus| gpus.first_mut()) {
            gpu.label =
                "AMD Strix Halo [Radeon Graphics / Radeon 8050S Graphics / Radeon 8060S Graphics]"
                    .into();
            gpu.utilization_percent = Some(87.0);
        }
        desktop.disks.push(DiskUsage {
            mount: "/home".into(),
            used: 1024,
            total: 2048,
        });
        desktop.disks.push(DiskUsage {
            mount: "/very-long-mount-path".into(),
            used: 536_870_912,
            total: 1_073_741_824,
        });
        desktop.processes.push(ProcessUsage {
            pid: 1234,
            name: "desktop-task".into(),
            cpu_percent: 12.0,
            memory_bytes: 4096,
        });
        state.update(
            Update {
                host_index: 0,
                result: Ok(snapshot()),
            },
            now,
        );
        state.update(
            Update {
                host_index: 1,
                result: Ok(desktop),
            },
            now,
        );

        for (width, height) in [(120, 30), (80, 24)] {
            let view = screen(&state, now, width, height);
            let titles = view.lines().nth(1).unwrap();
            assert!(
                titles.contains("aspen3") && titles.contains("britton-desktop"),
                "{view}"
            );
            assert_eq!(titles.matches(" ON ").count(), 2, "{view}");
            assert!(view.contains("42.0%") && view.contains("84.0%"), "{view}");
            assert!(view.contains("AMD Ryzen 9 9950X"), "{view}");
            assert!(view.contains("AMD Ryzen AI Max+ 395"), "{view}");
            assert!(view.contains("AMD Granite Ridge"), "{view}");
            assert!(view.contains("AMD Strix Halo"), "{view}");
            assert!(view.contains("50%") && view.contains("87%"), "{view}");
            assert!(view.contains("VRAM") && view.contains("/home"), "{view}");
            if width == 80 {
                assert!(view.contains("512.0 MiB/1.0 GiB"), "{view}");
                assert!(view.contains("/very-") && view.contains("…"), "{view}");
            }
            assert!(view.contains("1234") && view.contains("desktop-"), "{view}");
            assert!(!view.contains("untrusted-reported-name"), "{view}");
        }

        state.update(
            Update {
                host_index: 1,
                result: Err("unreachable".into()),
            },
            now,
        );
        let view = screen(&state, now, 80, 24);
        let titles = view.lines().nth(1).unwrap();
        assert!(
            titles.contains("aspen3") && titles.contains("britton-desktop"),
            "{view}"
        );
        assert!(
            titles.contains(" ON ") && titles.contains(" OFF "),
            "{view}"
        );
        assert!(view.contains("Last poll failed: unreachable"), "{view}");
        assert!(
            view.contains("84.0%") && view.contains("AMD Strix Halo"),
            "{view}"
        );
    }

    #[test]
    fn short_cards_keep_hardware_models_and_utilization_visible() {
        let now = Instant::now();
        let mut state = Dashboard::new(vec!["aspen3".into(), "britton-desktop".into()]);
        for index in 0..2 {
            let mut sample = snapshot();
            if index == 0 {
                let gpu = sample.gpus.as_mut().unwrap().first_mut().unwrap();
                gpu.label =
                    "AMD Strix Halo [Radeon Graphics / Radeon 8050S Graphics / Radeon 8060S Graphics]"
                        .into();
                gpu.utilization_percent = Some(0.0);
            } else {
                sample.cpu_model = Some("AMD Ryzen AI 9 HX 370 w/ Radeon 890M".into());
                sample.cpu_percent = 84.0;
            }
            state.update(
                Update {
                    host_index: index,
                    result: Ok(sample),
                },
                now,
            );
        }
        let view = screen(&state, now, 74, 38);
        assert!(
            view.lines()
                .any(|line| line.contains("AMD Ryzen 9 9950X") && line.contains("42.0%")),
            "{view}"
        );
        assert!(
            view.lines()
                .any(|line| line.contains("AMD Ryzen AI 9 HX 370 w/ Radeon 890M")
                    && line.contains("84.0%")),
            "{view}"
        );
        assert!(
            view.lines().any(|line| line.contains("AMD Strix Halo")
                && line.contains("0% ")
                && line.contains("░░░░")),
            "{view}"
        );
        assert!(view.contains("AMD Granite Ridge"), "{view}");
    }

    #[test]
    fn older_agent_without_cpu_model_has_an_explicit_unknown_label() {
        let mut old_wire_sample = serde_json::to_value(snapshot()).unwrap();
        old_wire_sample.as_object_mut().unwrap().remove("cpu_model");
        let legacy: Snapshot = serde_json::from_value(old_wire_sample).unwrap();
        let now = Instant::now();
        let mut state = Dashboard::new(vec!["older-agent".into()]);
        state.update(
            Update {
                host_index: 0,
                result: Ok(legacy),
            },
            now,
        );
        let view = screen(&state, now, 40, 24);
        assert!(view.contains("CPU: model unavailable"), "{view}");
    }

    #[test]
    fn extra_hosts_scroll_by_rows_when_the_terminal_cannot_fit_them() {
        let now = Instant::now();
        let mut state = Dashboard::new(vec!["first".into(), "second".into(), "third".into()]);
        for index in 0..3 {
            let mut sample = snapshot();
            sample.cpu_percent = 10.0 * (index + 1) as f32;
            state.update(
                Update {
                    host_index: index,
                    result: Ok(sample),
                },
                now,
            );
        }
        let viewport = Rect::new(0, 0, 80, 22);
        let first = screen(&state, now, 80, 24);
        assert!(
            first.contains("first") && first.contains("second"),
            "{first}"
        );
        assert!(!first.contains("third"), "{first}");

        state.scroll(1, viewport);
        let next = screen(&state, now, 80, 24);
        assert!(next.contains("third") && next.contains("30.0%"), "{next}");
        assert!(!next.contains("first"), "{next}");

        state.scroll(-1, viewport);
        assert!(screen(&state, now, 80, 24).contains("first"));
        let narrow = Rect::new(0, 0, 40, 22);
        state.scroll(1, narrow);
        let next = screen(&state, now, 40, 24);
        assert!(next.contains("second"), "{next}");
        assert!(!next.contains("first"), "{next}");
    }
    #[test]
    fn missing_gpu_telemetry_is_distinct_from_a_reported_zero() {
        let now = Instant::now();
        let mut old = serde_json::to_value(snapshot()).unwrap();
        old.as_object_mut().unwrap().remove("gpus");
        let old: Snapshot = serde_json::from_value(old).unwrap();
        assert!(old.gpus.is_none());
        let mut state = Dashboard::new(vec!["old-agent".into()]);
        state.update(
            Update {
                host_index: 0,
                result: Ok(old),
            },
            now,
        );
        let view = screen(&state, now, 80, 24);
        assert!(view.contains("GPU telemetry not reported"), "{view}");

        let mut no_gpu = snapshot();
        no_gpu.gpus = Some(Vec::new());
        state.update(
            Update {
                host_index: 0,
                result: Ok(no_gpu),
            },
            now,
        );
        let view = screen(&state, now, 80, 24);
        assert!(view.contains("GPU counters unavailable"), "{view}");

        let mut idle = snapshot();
        idle.gpus.as_mut().unwrap()[0].utilization_percent = Some(0.0);
        state.update(
            Update {
                host_index: 0,
                result: Ok(idle),
            },
            now,
        );
        let view = screen(&state, now, 80, 24);
        assert!(
            view.contains("AMD Granite Ridge") && view.contains("GPU 0%"),
            "{view}"
        );
        assert!(
            !view.contains("unavailable") && !view.contains("not reported"),
            "{view}"
        );
    }
}
