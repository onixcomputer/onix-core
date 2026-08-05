use std::{
    ffi::{OsStr, OsString},
    io::{self, Read},
    path::Path,
    process::{Child, Command, ExitStatus, Stdio},
    thread::JoinHandle,
    time::{Duration, Instant},
};

use pueue_plugin_core::{
    parse_status, parse_version, workspace_metadata_arguments, CoreError, Diagnostic, FailureClass,
    Operation, PueueRequest, QueueOverview, QueueState, SendRequest, MAX_STATUS_JSON_BYTES,
};
pub const PROCESS_TIMEOUT: Duration = Duration::from_secs(3);
pub const HERDR_OPEN_TIMEOUT: Duration = Duration::from_secs(10);
pub const HERDR_METADATA_TIMEOUT: Duration = Duration::from_secs(1);
pub const MAX_PROCESS_STDOUT_BYTES: usize = MAX_STATUS_JSON_BYTES;
pub const MAX_PROCESS_STDERR_BYTES: usize = 64 * 1024;
pub const SIDEBAR_METADATA_TTL_MS: u64 = 8_000;

const KIBIBYTE_BYTES: usize = 1024;
const MAX_HERDR_METADATA_OUTPUT_KIBIBYTES: usize = 8;
const MAX_HERDR_METADATA_OUTPUT_BYTES: usize = MAX_HERDR_METADATA_OUTPUT_KIBIBYTES * KIBIBYTE_BYTES;
const PROCESS_WAIT_POLL_INTERVAL: Duration = Duration::from_millis(10);
const MAX_PROCESS_WAIT_POLLS: u32 = 2_000;
const HERDR_PANE_OPEN_ARGUMENT_COUNT: usize = 7;
const PUEUE_PROGRAM: &str = "pueue";
const HERDR_BIN_PATH_ENVIRONMENT: &str = "HERDR_BIN_PATH";
const HERDR_WORKSPACE_ID_ENVIRONMENT: &str = "HERDR_WORKSPACE_ID";
const PLUGIN_ID: &str = "dev.herdr.pueue";
const POPUP_DASHBOARD_ENTRYPOINT: &str = "dashboard";
const SPLIT_DASHBOARD_ENTRYPOINT: &str = "dashboard-split";
const DAEMON_ERROR_MARKERS: &[&str] = &[
    "daemon",
    "connect",
    "configuration file",
    "named pipe",
    "socket",
];

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ProcessLimits {
    pub timeout: Duration,
    pub stdout_max_bytes: usize,
    pub stderr_max_bytes: usize,
}

impl ProcessLimits {
    pub const fn pueue() -> Self {
        Self {
            timeout: PROCESS_TIMEOUT,
            stdout_max_bytes: MAX_PROCESS_STDOUT_BYTES,
            stderr_max_bytes: MAX_PROCESS_STDERR_BYTES,
        }
    }

    pub const fn herdr() -> Self {
        Self {
            timeout: HERDR_OPEN_TIMEOUT,
            stdout_max_bytes: MAX_PROCESS_STDOUT_BYTES,
            stderr_max_bytes: MAX_PROCESS_STDERR_BYTES,
        }
    }

    pub const fn herdr_metadata() -> Self {
        Self {
            timeout: HERDR_METADATA_TIMEOUT,
            stdout_max_bytes: MAX_HERDR_METADATA_OUTPUT_BYTES,
            stderr_max_bytes: MAX_HERDR_METADATA_OUTPUT_BYTES,
        }
    }
}

type OutputReader = JoinHandle<io::Result<Vec<u8>>>;

struct OutputReaders {
    stdout: OutputReader,
    stderr: OutputReader,
}

#[derive(Clone, Debug)]
pub struct PueueClient {
    program: OsString,
    environment: Vec<(OsString, OsString)>,
    limits: ProcessLimits,
}

impl Default for PueueClient {
    fn default() -> Self {
        Self::installed()
    }
}

#[derive(Clone, Debug)]
pub struct WorkspaceOverviewReporter {
    herdr_path: OsString,
    workspace_id: String,
    limits: ProcessLimits,
}

impl WorkspaceOverviewReporter {
    pub fn from_environment() -> Option<Self> {
        let herdr_path = std::env::var_os(HERDR_BIN_PATH_ENVIRONMENT)?;
        let workspace_id = std::env::var(HERDR_WORKSPACE_ID_ENVIRONMENT).ok()?;
        let workspace_id = workspace_id.trim();
        if workspace_id.is_empty() {
            return None;
        }
        Some(Self {
            herdr_path,
            workspace_id: workspace_id.to_string(),
            limits: ProcessLimits::herdr_metadata(),
        })
    }

    pub fn report_best_effort(&self, overview: &QueueOverview) {
        // Sidebar presentation must not remove accepted queue state or mutation authority.
        match report_workspace_overview_at(
            Path::new(&self.herdr_path),
            &self.workspace_id,
            overview,
            self.limits,
        ) {
            Ok(()) => {}
            Err(_diagnostic) => {}
        }
    }
}

impl PueueClient {
    pub fn installed() -> Self {
        Self {
            program: OsString::from(PUEUE_PROGRAM),
            environment: Vec::new(),
            limits: ProcessLimits::pueue(),
        }
    }

    pub fn with_program(program: impl Into<OsString>, limits: ProcessLimits) -> Self {
        Self {
            program: program.into(),
            environment: Vec::new(),
            limits,
        }
    }

    pub fn with_program_and_environment(
        program: impl Into<OsString>,
        environment: Vec<(OsString, OsString)>,
        limits: ProcessLimits,
    ) -> Self {
        Self {
            program: program.into(),
            environment,
            limits,
        }
    }

    pub fn read_queue(&self) -> Result<QueueState, Diagnostic> {
        // r[impl herdr.pueue_plugin.adapter.status]
        let version_output = run_process(
            &self.program,
            &["--version".to_string()],
            Operation::PueueVersion,
            &self.environment,
            self.limits,
        )?;
        parse_version(&version_output)
            .map_err(|error| core_diagnostic(Operation::PueueVersion, error))?;

        let status_output = run_process(
            &self.program,
            &["status".to_string(), "--json".to_string()],
            Operation::PueueStatus,
            &self.environment,
            self.limits,
        )?;
        parse_status(&status_output).map_err(|error| core_diagnostic(Operation::PueueStatus, error))
    }

    pub fn control(&self, request: PueueRequest) -> Result<(), Diagnostic> {
        // r[impl herdr.pueue_plugin.security.argv]
        let operation = Operation::PueueControl(request.operation);
        run_process(
            &self.program,
            &request.argv(),
            operation,
            &self.environment,
            self.limits,
        )
        .map(|_| ())
    }

    pub fn send_input(&self, request: &SendRequest) -> Result<(), Diagnostic> {
        // r[impl herdr.pueue_plugin.security.argv]
        run_process(
            &self.program,
            &request.argv(),
            Operation::PueueSendInput,
            &self.environment,
            self.limits,
        )
        .map(|_| ())
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum DashboardPlacement {
    Popup,
    Split,
}

impl DashboardPlacement {
    const fn entrypoint(self) -> &'static str {
        match self {
            Self::Popup => POPUP_DASHBOARD_ENTRYPOINT,
            Self::Split => SPLIT_DASHBOARD_ENTRYPOINT,
        }
    }

    const fn operation(self) -> Operation {
        match self {
            Self::Popup => Operation::HerdrPopup,
            Self::Split => Operation::HerdrSplit,
        }
    }
}

pub fn report_workspace_overview_at(
    path: &Path,
    workspace_id: &str,
    overview: &QueueOverview,
    limits: ProcessLimits,
) -> Result<(), Diagnostic> {
    // r[impl herdr.pueue_plugin.sidebar_overview]
    let operation = Operation::HerdrMetadata;
    if path.as_os_str().is_empty() || !path.is_file() {
        return Err(Diagnostic::new(operation, FailureClass::InvalidHerdrPath));
    }
    if workspace_id.trim().is_empty() {
        return Err(Diagnostic::new(
            operation,
            FailureClass::InvalidHerdrContext,
        ));
    }
    let arguments = workspace_metadata_arguments(workspace_id, overview, SIDEBAR_METADATA_TTL_MS);
    run_process(path.as_os_str(), &arguments, operation, &[], limits).map(|_| ())
}

pub fn open_dashboard_from_environment() -> Result<(), Diagnostic> {
    open_dashboard_from_environment_at(DashboardPlacement::Popup)
}

pub fn open_split_dashboard_from_environment() -> Result<(), Diagnostic> {
    open_dashboard_from_environment_at(DashboardPlacement::Split)
}

fn open_dashboard_from_environment_at(placement: DashboardPlacement) -> Result<(), Diagnostic> {
    let operation = placement.operation();
    let herdr_path = std::env::var_os(HERDR_BIN_PATH_ENVIRONMENT)
        .ok_or_else(|| Diagnostic::new(operation, FailureClass::InvalidHerdrPath))?;
    open_dashboard_placement_at(Path::new(&herdr_path), ProcessLimits::herdr(), placement)
}

pub fn open_dashboard_at(path: &Path, limits: ProcessLimits) -> Result<(), Diagnostic> {
    open_dashboard_placement_at(path, limits, DashboardPlacement::Popup)
}

pub fn open_split_dashboard_at(path: &Path, limits: ProcessLimits) -> Result<(), Diagnostic> {
    open_dashboard_placement_at(path, limits, DashboardPlacement::Split)
}

fn open_dashboard_placement_at(
    path: &Path,
    limits: ProcessLimits,
    placement: DashboardPlacement,
) -> Result<(), Diagnostic> {
    // r[impl herdr.pueue_plugin.distribution.open]
    // r[impl herdr.pueue_plugin.distribution.split]
    let operation = placement.operation();
    if path.as_os_str().is_empty() || !path.is_file() {
        return Err(Diagnostic::new(operation, FailureClass::InvalidHerdrPath));
    }
    let arguments = dashboard_open_arguments(placement);
    run_process(path.as_os_str(), &arguments, operation, &[], limits).map(|_| ())
}

fn dashboard_open_arguments(
    placement: DashboardPlacement,
) -> [String; HERDR_PANE_OPEN_ARGUMENT_COUNT] {
    [
        "plugin".to_string(),
        "pane".to_string(),
        "open".to_string(),
        "--plugin".to_string(),
        PLUGIN_ID.to_string(),
        "--entrypoint".to_string(),
        placement.entrypoint().to_string(),
    ]
}

fn run_process(
    program: &OsStr,
    arguments: &[String],
    operation: Operation,
    environment: &[(OsString, OsString)],
    limits: ProcessLimits,
) -> Result<String, Diagnostic> {
    // r[impl herdr.pueue_plugin.adapter] r[impl herdr.pueue_plugin.security]
    debug_assert!(limits.timeout > Duration::ZERO);
    debug_assert!(limits.stdout_max_bytes > 0);
    debug_assert!(limits.stderr_max_bytes > 0);

    let mut child = Command::new(program)
        .args(arguments)
        .envs(environment.iter().cloned())
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|error| spawn_diagnostic(operation, &error))?;
    let readers = match spawn_output_readers(&mut child, limits, operation) {
        Ok(readers) => readers,
        Err(diagnostic) => {
            terminate_child(&mut child);
            return Err(diagnostic);
        }
    };
    let wait_result = wait_for_child(&mut child, limits.timeout, operation);
    let stdout = join_output_reader(readers.stdout, operation)?;
    let stderr = join_output_reader(readers.stderr, operation)?;
    let status = wait_result?;
    validate_output_bounds(&stdout, &stderr, limits, operation)?;
    if !status.success() {
        return Err(exit_diagnostic(operation, &stderr));
    }
    String::from_utf8(stdout).map_err(|_| Diagnostic::new(operation, FailureClass::InvalidUtf8))
}

fn spawn_output_readers(
    child: &mut Child,
    limits: ProcessLimits,
    operation: Operation,
) -> Result<OutputReaders, Diagnostic> {
    let stdout = child
        .stdout
        .take()
        .ok_or_else(|| Diagnostic::new(operation, FailureClass::ProcessPipeUnavailable))?;
    let stderr = child
        .stderr
        .take()
        .ok_or_else(|| Diagnostic::new(operation, FailureClass::ProcessPipeUnavailable))?;
    let stdout_max_bytes = limits.stdout_max_bytes;
    let stderr_max_bytes = limits.stderr_max_bytes;
    let stdout_reader = std::thread::spawn(move || read_bounded(stdout, stdout_max_bytes));
    let stderr_reader = std::thread::spawn(move || read_bounded(stderr, stderr_max_bytes));
    Ok(OutputReaders {
        stdout: stdout_reader,
        stderr: stderr_reader,
    })
}

fn read_bounded(reader: impl Read, max_bytes: usize) -> io::Result<Vec<u8>> {
    let admitted_bytes = max_bytes.saturating_add(1);
    let read_limit = u64::try_from(admitted_bytes)
        .map_err(|_| io::Error::other("process output limit does not fit in u64"))?;
    let mut bytes = Vec::with_capacity(admitted_bytes);
    reader.take(read_limit).read_to_end(&mut bytes)?;
    Ok(bytes)
}

fn wait_for_child(
    child: &mut Child,
    timeout: Duration,
    operation: Operation,
) -> Result<ExitStatus, Diagnostic> {
    let maximum_wait = PROCESS_WAIT_POLL_INTERVAL.saturating_mul(MAX_PROCESS_WAIT_POLLS);
    debug_assert!(timeout <= maximum_wait);
    let started_at = Instant::now();
    for _poll in 0..MAX_PROCESS_WAIT_POLLS {
        match child.try_wait() {
            Ok(Some(status)) => return Ok(status),
            Ok(None) => {}
            Err(_) => {
                terminate_child(child);
                return Err(Diagnostic::new(operation, FailureClass::ProcessWaitFailed));
            }
        }
        let elapsed = started_at.elapsed();
        if elapsed >= timeout {
            terminate_child(child);
            return Err(Diagnostic::new(operation, FailureClass::Timeout));
        }
        let remaining = timeout.saturating_sub(elapsed);
        std::thread::sleep(PROCESS_WAIT_POLL_INTERVAL.min(remaining));
    }
    terminate_child(child);
    Err(Diagnostic::new(operation, FailureClass::Timeout))
}

fn terminate_child(child: &mut Child) {
    let _kill_result = child.kill();
    let _wait_result = child.wait();
}

fn join_output_reader(
    reader: JoinHandle<io::Result<Vec<u8>>>,
    operation: Operation,
) -> Result<Vec<u8>, Diagnostic> {
    reader
        .join()
        .map_err(|_| Diagnostic::new(operation, FailureClass::ProcessOutputThreadFailed))?
        .map_err(|_| Diagnostic::new(operation, FailureClass::ProcessOutputReadFailed))
}

fn validate_output_bounds(
    stdout: &[u8],
    stderr: &[u8],
    limits: ProcessLimits,
    operation: Operation,
) -> Result<(), Diagnostic> {
    if stdout.len() > limits.stdout_max_bytes {
        return Err(Diagnostic::new(operation, FailureClass::StdoutLimit));
    }
    if stderr.len() > limits.stderr_max_bytes {
        return Err(Diagnostic::new(operation, FailureClass::StderrLimit));
    }
    Ok(())
}

fn spawn_diagnostic(operation: Operation, error: &io::Error) -> Diagnostic {
    let class = match error.kind() {
        io::ErrorKind::NotFound => FailureClass::MissingExecutable,
        io::ErrorKind::PermissionDenied => FailureClass::PermissionDenied,
        _ => FailureClass::SpawnFailed,
    };
    Diagnostic::new(operation, class)
}

fn exit_diagnostic(operation: Operation, stderr: &[u8]) -> Diagnostic {
    let class = if operation == Operation::PueueStatus && stderr_indicates_daemon_error(stderr) {
        FailureClass::DaemonUnavailable
    } else {
        FailureClass::NonzeroExit
    };
    Diagnostic::new(operation, class)
}

fn stderr_indicates_daemon_error(stderr: &[u8]) -> bool {
    let stderr = String::from_utf8_lossy(stderr).to_ascii_lowercase();
    DAEMON_ERROR_MARKERS
        .iter()
        .any(|marker| stderr.contains(marker))
}

fn core_diagnostic(operation: Operation, error: CoreError) -> Diagnostic {
    let class = match error {
        CoreError::UnsupportedMajorVersion => FailureClass::UnsupportedVersion,
        CoreError::StatusOutputTooLarge => FailureClass::StdoutLimit,
        _ => FailureClass::InvalidData,
    };
    Diagnostic::new(operation, class)
}
