use std::{
    path::{Path, PathBuf},
    sync::{
        atomic::{AtomicU64, Ordering},
        Mutex, MutexGuard,
    },
    time::Duration,
};

use herdr_plugin_pueue::process::{
    open_dashboard_at, open_split_dashboard_at, report_workspace_overview_at, ProcessLimits,
    PueueClient, MAX_PROCESS_STDERR_BYTES, MAX_PROCESS_STDOUT_BYTES,
};
use pueue_plugin_core::{
    ControlOperation, Diagnostic, FailureClass, Operation, PueueRequest, QueueOverview,
    SendRequest, TaskId,
};

const TEST_TIMEOUT: Duration = Duration::from_millis(50);
const FIXTURE_SECRET: &str = "fixture-secret-do-not-display";
const FIXTURE_TASK_COUNT: usize = 3;
const CONTROL_TASK_ID: TaskId = TaskId::new(2);
static NEXT_FIXTURE_ID: AtomicU64 = AtomicU64::new(1);
static PROCESS_TEST_LOCK: Mutex<()> = Mutex::new(());

struct FakeProgram {
    directory: PathBuf,
    path: PathBuf,
}

impl FakeProgram {
    fn new(scenario: &str) -> Result<Self, Box<dyn std::error::Error>> {
        let fixture_id = NEXT_FIXTURE_ID.fetch_add(1, Ordering::Relaxed);
        let directory = std::env::temp_dir().join(format!(
            "herdr-plugin-pueue-{}-{fixture_id}",
            std::process::id()
        ));
        std::fs::create_dir_all(&directory)?;
        let extension = std::env::consts::EXE_EXTENSION;
        let file_name = if extension.is_empty() {
            format!("fake-pueue-{scenario}")
        } else {
            format!("fake-pueue-{scenario}.{extension}")
        };
        let path = directory.join(file_name);
        std::fs::copy(env!("CARGO_BIN_EXE_fake-pueue"), &path)?;
        Ok(Self { directory, path })
    }

    fn path(&self) -> &Path {
        &self.path
    }
}

impl Drop for FakeProgram {
    fn drop(&mut self) {
        let _cleanup_result = std::fs::remove_dir_all(&self.directory);
    }
}

fn limits() -> ProcessLimits {
    ProcessLimits {
        timeout: TEST_TIMEOUT,
        stdout_max_bytes: MAX_PROCESS_STDOUT_BYTES,
        stderr_max_bytes: MAX_PROCESS_STDERR_BYTES,
    }
}

fn client(scenario: &str) -> Result<(FakeProgram, PueueClient), Box<dyn std::error::Error>> {
    let program = FakeProgram::new(scenario)?;
    let client = PueueClient::with_program(program.path().as_os_str(), limits());
    Ok((program, client))
}

fn process_test_lock() -> Result<MutexGuard<'static, ()>, Box<dyn std::error::Error>> {
    PROCESS_TEST_LOCK
        .lock()
        .map_err(|_| std::io::Error::other("process test lock was poisoned").into())
}

#[test]
fn fake_client_reads_supported_state_without_retaining_environments(
) -> Result<(), Box<dyn std::error::Error>> {
    // r[verify herdr.pueue_plugin.verification.suites]
    let _guard = process_test_lock()?;
    let (_program, client) = client("success")?;
    let queue = client.read_queue()?;
    assert_eq!(queue.tasks().len(), FIXTURE_TASK_COUNT);
    assert!(!format!("{queue:?}").contains(FIXTURE_SECRET));
    Ok(())
}

#[test]
fn fake_client_classifies_daemon_and_schema_failures() -> Result<(), Box<dyn std::error::Error>> {
    // r[verify herdr.pueue_plugin.adapter.daemon]
    let _guard = process_test_lock()?;
    let (_program, daemon_client) = client("daemon")?;
    assert_eq!(
        daemon_client.read_queue(),
        Err(Diagnostic::new(
            Operation::PueueStatus,
            FailureClass::DaemonUnavailable
        ))
    );

    let (_program, malformed_client) = client("malformed-status")?;
    assert_eq!(
        malformed_client.read_queue(),
        Err(Diagnostic::new(
            Operation::PueueStatus,
            FailureClass::InvalidData
        ))
    );

    let (_program, unknown_client) = client("unknown-status")?;
    assert_eq!(
        unknown_client.read_queue(),
        Err(Diagnostic::new(
            Operation::PueueStatus,
            FailureClass::InvalidData
        ))
    );
    Ok(())
}

#[test]
fn child_stderr_never_enters_the_diagnostic() -> Result<(), Box<dyn std::error::Error>> {
    // r[verify herdr.pueue_plugin.security.envs]
    let _guard = process_test_lock()?;
    let (_program, client) = client("secret-stderr")?;
    let diagnostic = client.read_queue().err().ok_or("expected status failure")?;
    assert_eq!(diagnostic.class, FailureClass::NonzeroExit);
    assert!(!diagnostic.message().contains(FIXTURE_SECRET));
    Ok(())
}

#[test]
fn fake_client_rejects_unsupported_versions() -> Result<(), Box<dyn std::error::Error>> {
    let _guard = process_test_lock()?;
    let (_program, client) = client("unsupported-version")?;
    assert_eq!(
        client.read_queue(),
        Err(Diagnostic::new(
            Operation::PueueVersion,
            FailureClass::UnsupportedVersion
        ))
    );
    Ok(())
}

#[test]
fn fake_client_bounds_time_and_child_output() -> Result<(), Box<dyn std::error::Error>> {
    // r[verify herdr.pueue_plugin.security.terminal]
    let _guard = process_test_lock()?;
    let (_program, timeout_client) = client("timeout")?;
    assert_eq!(
        timeout_client.read_queue(),
        Err(Diagnostic::new(
            Operation::PueueVersion,
            FailureClass::Timeout
        ))
    );

    let (_program, stdout_client) = client("oversized-stdout")?;
    assert_eq!(
        stdout_client.read_queue(),
        Err(Diagnostic::new(
            Operation::PueueStatus,
            FailureClass::StdoutLimit
        ))
    );

    let (_program, stderr_client) = client("oversized-stderr")?;
    assert_eq!(
        stderr_client.read_queue(),
        Err(Diagnostic::new(
            Operation::PueueStatus,
            FailureClass::StderrLimit
        ))
    );
    Ok(())
}

#[test]
fn failed_control_returns_a_typed_nonzero_error() -> Result<(), Box<dyn std::error::Error>> {
    let _guard = process_test_lock()?;
    let (_program, client) = client("control-failure")?;
    let request = PueueRequest::new(ControlOperation::Pause, CONTROL_TASK_ID);
    assert_eq!(
        client.control(request),
        Err(Diagnostic::new(
            Operation::PueueControl(ControlOperation::Pause),
            FailureClass::NonzeroExit
        ))
    );
    Ok(())
}

#[test]
fn send_input_round_trips_through_the_process_adapter() -> Result<(), Box<dyn std::error::Error>> {
    // r[verify herdr.pueue_plugin.send]
    let _guard = process_test_lock()?;
    let (_program, client) = client("success")?;
    let request = SendRequest::new(CONTROL_TASK_ID, "y\n".to_string());
    assert_eq!(client.send_input(&request), Ok(()));
    Ok(())
}

#[test]
fn failed_send_returns_a_typed_nonzero_error() -> Result<(), Box<dyn std::error::Error>> {
    let _guard = process_test_lock()?;
    let (_program, client) = client("control-failure")?;
    let request = SendRequest::new(CONTROL_TASK_ID, "y\n".to_string());
    assert_eq!(
        client.send_input(&request),
        Err(Diagnostic::new(
            Operation::PueueSendInput,
            FailureClass::NonzeroExit
        ))
    );
    Ok(())
}

#[test]
fn missing_pueue_binary_is_recoverable() -> Result<(), Box<dyn std::error::Error>> {
    let _guard = process_test_lock()?;
    let missing = std::env::temp_dir().join("herdr-plugin-pueue-missing-client");
    let client = PueueClient::with_program(missing.as_os_str(), limits());
    assert_eq!(
        client.read_queue(),
        Err(Diagnostic::new(
            Operation::PueueVersion,
            FailureClass::MissingExecutable
        ))
    );
    Ok(())
}

#[test]
fn popup_launch_uses_the_exact_herdr_argv() -> Result<(), Box<dyn std::error::Error>> {
    // r[verify herdr.pueue_plugin.distribution.open]
    let _guard = process_test_lock()?;
    let program = FakeProgram::new("herdr-valid-popup")?;
    assert_eq!(open_dashboard_at(program.path(), limits()), Ok(()));
    Ok(())
}

#[test]
fn split_launch_uses_the_exact_herdr_argv() -> Result<(), Box<dyn std::error::Error>> {
    // r[verify herdr.pueue_plugin.distribution.split]
    let _guard = process_test_lock()?;
    let program = FakeProgram::new("herdr-valid-split")?;
    assert_eq!(open_split_dashboard_at(program.path(), limits()), Ok(()));
    Ok(())
}

#[test]
fn workspace_overview_report_uses_exact_bounded_herdr_argv(
) -> Result<(), Box<dyn std::error::Error>> {
    // r[verify herdr.pueue_plugin.sidebar_overview.running]
    let _guard = process_test_lock()?;
    let (_pueue_program, client) = client("success")?;
    let overview = QueueOverview::from_queue(&client.read_queue()?);
    let herdr_program = FakeProgram::new("herdr-valid-metadata")?;

    assert_eq!(
        report_workspace_overview_at(herdr_program.path(), "wD", &overview, limits()),
        Ok(())
    );
    Ok(())
}

#[test]
fn workspace_overview_report_failure_is_typed_and_contains_no_values(
) -> Result<(), Box<dyn std::error::Error>> {
    // r[verify herdr.pueue_plugin.sidebar_overview.best_effort]
    let _guard = process_test_lock()?;
    let (_pueue_program, client) = client("success")?;
    let overview = QueueOverview::from_queue(&client.read_queue()?);
    let failing_herdr = FakeProgram::new("herdr-metadata-failure")?;

    let diagnostic = report_workspace_overview_at(failing_herdr.path(), "wD", &overview, limits())
        .err()
        .ok_or("expected metadata report failure")?;
    assert_eq!(
        diagnostic,
        Diagnostic::new(Operation::HerdrMetadata, FailureClass::NonzeroExit)
    );
    assert!(!diagnostic.message().contains("tests"));
    assert!(!diagnostic.message().contains(FIXTURE_SECRET));
    Ok(())
}

#[test]
fn workspace_overview_report_rejects_invalid_path_and_context(
) -> Result<(), Box<dyn std::error::Error>> {
    let _guard = process_test_lock()?;
    let overview = QueueOverview::unavailable();
    let missing = std::env::temp_dir().join("herdr-plugin-pueue-missing-metadata-herdr");
    assert_eq!(
        report_workspace_overview_at(&missing, "wD", &overview, limits()),
        Err(Diagnostic::new(
            Operation::HerdrMetadata,
            FailureClass::InvalidHerdrPath
        ))
    );

    let herdr_program = FakeProgram::new("herdr-valid-metadata")?;
    assert_eq!(
        report_workspace_overview_at(herdr_program.path(), "", &overview, limits()),
        Err(Diagnostic::new(
            Operation::HerdrMetadata,
            FailureClass::InvalidHerdrContext
        ))
    );
    Ok(())
}

#[test]
fn pane_launch_rejects_an_invalid_herdr_path() -> Result<(), Box<dyn std::error::Error>> {
    // r[verify herdr.pueue_plugin.failures.herdr_path]
    let _guard = process_test_lock()?;
    let invalid = std::env::temp_dir().join("herdr-plugin-pueue-missing-herdr");
    assert_eq!(
        open_dashboard_at(&invalid, limits()),
        Err(Diagnostic::new(
            Operation::HerdrPopup,
            FailureClass::InvalidHerdrPath
        ))
    );
    assert_eq!(
        open_split_dashboard_at(&invalid, limits()),
        Err(Diagnostic::new(
            Operation::HerdrSplit,
            FailureClass::InvalidHerdrPath
        ))
    );
    Ok(())
}
