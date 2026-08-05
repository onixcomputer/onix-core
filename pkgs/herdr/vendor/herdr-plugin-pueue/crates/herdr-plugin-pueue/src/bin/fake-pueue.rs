#![forbid(unsafe_code)]

use std::{
    io::{self, Write},
    process::ExitCode,
    time::Duration,
};

use herdr_plugin_pueue::process::{MAX_PROCESS_STDERR_BYTES, MAX_PROCESS_STDOUT_BYTES};

const FAKE_PREFIX: &str = "fake-pueue";
const TIMEOUT_SLEEP: Duration = Duration::from_secs(2);
const HERDR_POPUP_ARGUMENTS: &[&str] = &[
    "plugin",
    "pane",
    "open",
    "--plugin",
    "dev.herdr.pueue",
    "--entrypoint",
    "dashboard",
];
const HERDR_SPLIT_ARGUMENTS: &[&str] = &[
    "plugin",
    "pane",
    "open",
    "--plugin",
    "dev.herdr.pueue",
    "--entrypoint",
    "dashboard-split",
];
const HERDR_METADATA_ARGUMENTS: &[&str] = &[
    "workspace",
    "report-metadata",
    "wD",
    "--source",
    "plugin:dev.herdr.pueue",
    "--token",
    "pueue_status=Pueue · 1 running",
    "--token",
    "pueue_running_1=#2 tests",
    "--clear-token",
    "pueue_running_2",
    "--ttl-ms",
    "8000",
];

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(()) => ExitCode::FAILURE,
    }
}

fn run() -> Result<(), ()> {
    let scenario = scenario_from_executable()?;
    let arguments = std::env::args().skip(1).collect::<Vec<_>>();
    let expected_herdr_arguments = match scenario.as_str() {
        "herdr-valid-popup" => Some(HERDR_POPUP_ARGUMENTS),
        "herdr-valid-split" => Some(HERDR_SPLIT_ARGUMENTS),
        "herdr-valid-metadata" => Some(HERDR_METADATA_ARGUMENTS),
        _ => None,
    };
    if let Some(expected_arguments) = expected_herdr_arguments {
        return if arguments
            .iter()
            .map(String::as_str)
            .eq(expected_arguments.iter().copied())
        {
            Ok(())
        } else {
            Err(())
        };
    }
    if scenario == "herdr-metadata-failure" {
        return Err(());
    }
    if scenario == "timeout" {
        std::thread::sleep(TIMEOUT_SLEEP);
        return Ok(());
    }
    if arguments == ["--version"] {
        return write_version(&scenario);
    }
    if arguments == ["status", "--json"] {
        return write_status(&scenario);
    }
    if scenario == "control-failure" {
        return Err(());
    }
    println!("control accepted");
    Ok(())
}

fn scenario_from_executable() -> Result<String, ()> {
    let executable = std::env::current_exe().map_err(|_| ())?;
    let stem = executable
        .file_stem()
        .and_then(|value| value.to_str())
        .ok_or(())?;
    Ok(stem
        .strip_prefix(FAKE_PREFIX)
        .and_then(|value| value.strip_prefix('-'))
        .unwrap_or("success")
        .to_string())
}

fn write_version(scenario: &str) -> Result<(), ()> {
    if scenario == "unsupported-version" {
        println!("pueue 5.0.0");
    } else {
        print!(
            "{}",
            include_str!("../../../../fixtures/pueue-4.0.4/version.txt")
        );
    }
    io::stdout().flush().map_err(|_| ())
}

fn write_status(scenario: &str) -> Result<(), ()> {
    match scenario {
        "daemon" => {
            eprintln!("failed to connect to daemon socket");
            Err(())
        }
        "malformed-status" => {
            println!("{{");
            Ok(())
        }
        "secret-stderr" => {
            eprintln!("control failed with fixture-secret-do-not-display");
            Err(())
        }
        "unknown-status" => {
            println!(
                "{{\"tasks\":{{\"1\":{{\"id\":1,\"command\":\"x\",\"path\":\".\",\"group\":\"default\",\"label\":null,\"status\":\"Future\"}}}},\"groups\":{{\"default\":{{\"status\":\"Running\",\"parallel_tasks\":1}}}}}}"
            );
            Ok(())
        }
        "oversized-stdout" => write_repeated(io::stdout(), MAX_PROCESS_STDOUT_BYTES),
        "oversized-stderr" => write_repeated(io::stderr(), MAX_PROCESS_STDERR_BYTES),
        _ => {
            print!(
                "{}",
                include_str!("../../../../fixtures/pueue-4.0.4/status.json")
            );
            io::stdout().flush().map_err(|_| ())
        }
    }
}

fn write_repeated(mut writer: impl Write, max_bytes: usize) -> Result<(), ()> {
    let output = vec![b'x'; max_bytes.saturating_add(1)];
    writer.write_all(&output).map_err(|_| ())?;
    writer.flush().map_err(|_| ())
}
