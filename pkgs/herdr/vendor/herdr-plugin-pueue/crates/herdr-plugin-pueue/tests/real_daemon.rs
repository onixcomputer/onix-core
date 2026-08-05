#![cfg(unix)]

use std::{
    ffi::{OsStr, OsString},
    path::PathBuf,
    process::{Child, Command, Stdio},
    sync::atomic::{AtomicU64, Ordering},
    time::Duration,
};

use herdr_plugin_pueue::process::{ProcessLimits, PueueClient};
use pueue_plugin_core::{ControlOperation, PueueRequest, TaskId, TaskState};

const CLIENT_ENVIRONMENT: &str = "PUEUE_REAL_CLIENT";
const DAEMON_ENVIRONMENT: &str = "PUEUE_REAL_DAEMON";
const PUEUE_CONFIG_PATH_ENVIRONMENT: &str = "PUEUE_CONFIG_PATH";
const DEFAULT_CLIENT: &str = "pueue";
const DEFAULT_DAEMON: &str = "pueued";
const DAEMON_START_POLL: Duration = Duration::from_millis(50);
const DAEMON_START_ATTEMPTS: usize = 100;
const TASK_POLL: Duration = Duration::from_millis(50);
const TASK_POLL_ATTEMPTS: usize = 100;
const SMOKE_TASK_ID: TaskId = TaskId::new(0);
static NEXT_TEST_ID: AtomicU64 = AtomicU64::new(1);

struct IsolatedDaemon {
    child: Child,
    directory: PathBuf,
    config_path: PathBuf,
}

impl IsolatedDaemon {
    fn start(program: &OsStr) -> Result<Self, Box<dyn std::error::Error>> {
        let test_id = NEXT_TEST_ID.fetch_add(1, Ordering::Relaxed);
        let directory = std::env::temp_dir().join(format!(
            "herdr-plugin-pueue-real-{}-{test_id}",
            std::process::id()
        ));
        std::fs::create_dir_all(&directory)?;
        let socket_path = directory.join("pueue.socket");
        let config_path = directory.join("pueue.yml");
        let secret_path = directory.join("shared-secret");
        let config = format!(
            "shared:\n  pueue_directory: \"{}\"\n  runtime_directory: \"{}\"\n  unix_socket_path: \"{}\"\n  shared_secret_path: \"{}\"\n",
            directory.display(),
            directory.display(),
            socket_path.display(),
            secret_path.display()
        );
        std::fs::write(&config_path, config)?;
        let child = Command::new(program)
            .arg("--config")
            .arg(&config_path)
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn()?;
        let daemon = Self {
            child,
            directory,
            config_path,
        };
        for _attempt in 0..DAEMON_START_ATTEMPTS {
            if socket_path.exists() {
                return Ok(daemon);
            }
            std::thread::sleep(DAEMON_START_POLL);
        }
        Err("isolated pueued did not create its socket before the timeout".into())
    }
}

impl Drop for IsolatedDaemon {
    fn drop(&mut self) {
        let _kill_result = self.child.kill();
        let _wait_result = self.child.wait();
        let _cleanup_result = std::fs::remove_dir_all(&self.directory);
    }
}

#[test]
#[ignore = "requires installed pueue and pueued 4.x binaries"]
fn isolated_real_daemon_smoke_does_not_use_operator_state() -> Result<(), Box<dyn std::error::Error>>
{
    // r[verify herdr.pueue_plugin.verification.isolated]
    let client_program =
        std::env::var_os(CLIENT_ENVIRONMENT).unwrap_or_else(|| OsString::from(DEFAULT_CLIENT));
    let daemon_program =
        std::env::var_os(DAEMON_ENVIRONMENT).unwrap_or_else(|| OsString::from(DEFAULT_DAEMON));
    let daemon = IsolatedDaemon::start(&daemon_program)?;
    let environment = vec![(
        OsString::from(PUEUE_CONFIG_PATH_ENVIRONMENT),
        daemon.config_path.clone().into_os_string(),
    )];
    let client = PueueClient::with_program_and_environment(
        client_program.clone(),
        environment,
        ProcessLimits::pueue(),
    );
    assert!(client.read_queue()?.tasks().is_empty());

    add_stashed_task(&client_program, daemon.config_path.as_os_str())?;
    let queue = client.read_queue()?;
    assert_eq!(
        queue.task(SMOKE_TASK_ID).map(|task| task.state),
        Some(TaskState::Stashed)
    );

    client.control(PueueRequest::new(ControlOperation::Enqueue, SMOKE_TASK_ID))?;
    wait_for_completion(&client)?;
    client.control(PueueRequest::new(ControlOperation::Remove, SMOKE_TASK_ID))?;
    assert!(client.read_queue()?.tasks().is_empty());
    Ok(())
}

fn add_stashed_task(
    client_program: &OsStr,
    config_path: &OsStr,
) -> Result<(), Box<dyn std::error::Error>> {
    let status = Command::new(client_program)
        .arg("--config")
        .arg(config_path)
        .args(["add", "--stashed", "--print-task-id", "true"])
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()?;
    if !status.success() {
        return Err("isolated pueue add command failed".into());
    }
    Ok(())
}

fn wait_for_completion(client: &PueueClient) -> Result<(), Box<dyn std::error::Error>> {
    for _attempt in 0..TASK_POLL_ATTEMPTS {
        let state = client.read_queue()?;
        if state
            .task(SMOKE_TASK_ID)
            .is_some_and(|task| matches!(task.state, TaskState::Completed(_)))
        {
            return Ok(());
        }
        std::thread::sleep(TASK_POLL);
    }
    Err("isolated Pueue task did not complete before the timeout".into())
}
