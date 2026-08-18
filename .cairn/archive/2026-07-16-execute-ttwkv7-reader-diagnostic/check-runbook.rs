#!/usr/bin/env -S CARGO_TARGET_DIR=target/check-ttwkv7-runbook-script nix --option secret-key-files '' shell "github:nix-community/fenix?rev=8df3642541009d2a5f15520462a8dec719c5fddb#minimal.toolchain" nixpkgs#gcc -c cargo -q -Zscript
---
[package]
edition = "2024"
---

use std::env;
use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};
use std::process::ExitCode;

const EXPECTED_MODE: u32 = 0o755;
const EXPECTED_RECORD_COUNT: usize = 13;
const EXPECTED_DIRECT_WRAPPER_COMMAND_COUNT: usize = 2;
const EXPECTED_VISIBLE_DEVICE_USE_COUNT: usize = 2;
const RUNBOOK_FILENAME: &str = "run-one-shot.sh";
const SELF_TEST_ARGUMENT: &str = "--self-test";

const REQUIRED_SINGLETONS: &[&str] = &[
    "readonly reviewed_base_commit=\"db012b71eab56d7aa86f1bcf8f5a16f6fc6ec6e9\"",
    "readonly package_path=\"/nix/store/l5a5lkkwn7wcp2hvr8c3m5zp4wfyg36y-ttwkv7-unstable-2026-06-22\"",
    "readonly kernel_path=\"/nix/store/bag2glrys891mvg2pifn8q4iqjd0qm25-ttwkv7-kernels-unstable-2026-06-22/share/ttwkv7/kernels\"",
    "readonly expected_authorization=\"Authorize exactly one device-1 reader diagnostic process.\"",
    "readonly run_root=\"/var/tmp/ttwkv7-reader-diagnostic-20260716T221616Z\"",
    "readonly inspector_port=\"43136\"",
    "readonly execution_lock_path=\"$run_root/execution-consumed.lock\"",
    "readonly visible_device=\"1\"",
    "readonly expected_record_count=\"13\"",
    "readonly expected_manifest_entry_count=\"52\"",
    "readonly expected_manifest_line_count=\"53\"",
    "validate_completed_evidence() (",
    "mkdir \"$execution_lock_path\" || fail \"execution attempt lock could not be acquired\"",
    "printf '%s\\n' \"$consumed_invocation_count\" >\"$run_root/execution-attempt-count.txt\"",
    "printf '%s\\n' \"$consumed_invocation_count\" >\"$run_root/invocation-count.txt\"",
    "  \"$diagnostic_path\" probe \\",
    "validate_completed_evidence >\"$run_root/evidence-completeness.log\" 2>&1",
];

const RECORD_NAMES: &[&str] = &[
    "cb21-loopback",
    "input-upload-0",
    "input-upload-1",
    "input-upload-2",
    "input-upload-3",
    "input-upload-4",
    "input-upload-5",
    "state-upload",
    "decode-L1",
    "chunked-partial-L1",
    "chunked-full-L32",
    "chunked-writer",
    "decodeL-writer",
];

const AUTHORIZATION_CHECK: &str =
    "[[ $(cat \"$run_root/authorization.txt\") == \"$expected_authorization\" ]]";
const EXECUTION_LOCK_ACQUIRE: &str =
    "mkdir \"$execution_lock_path\" || fail \"execution attempt lock could not be acquired\"";
const TRAP_INSTALL: &str = "trap restore_owner EXIT";
const ROLLBACK_CALL: &str = "\narm_rollback_timer\n";
const ISOLATE_CALL: &str = "\"$owner_control_path\" isolate >\"$run_root/isolate.log\" 2>&1";
const INVOCATION_COUNTER_WRITE: &str =
    "printf '%s\\n' \"$consumed_invocation_count\" >\"$run_root/invocation-count.txt\"";
const DIAGNOSTIC_COMMAND: &str = "  \"$diagnostic_path\" probe \\";
const EVIDENCE_VALIDATION_CALL: &str =
    "validate_completed_evidence >\"$run_root/evidence-completeness.log\" 2>&1";
const DIRECT_WRAPPER_COMMAND_PREFIX: &str = "\n  \"$diagnostic_path\" ";
const DIRECT_RUNTIME_COMMAND_PREFIX: &str = "\n  \"$diagnostic_runtime_path\" ";
const VISIBLE_DEVICE_USE: &str = "TT_VISIBLE_DEVICES=\"$visible_device\"";

fn require_count(source: &str, needle: &str, expected: usize) -> Result<(), String> {
    let actual = source.matches(needle).count();
    if actual != expected {
        return Err(format!(
            "expected {expected} occurrence(s) of {needle:?}, found {actual}"
        ));
    }
    Ok(())
}

fn position(source: &str, needle: &str) -> Result<usize, String> {
    source
        .find(needle)
        .ok_or_else(|| format!("required ordering marker missing: {needle:?}"))
}

fn require_before(source: &str, first: &str, second: &str) -> Result<(), String> {
    let first_position = position(source, first)?;
    let second_position = position(source, second)?;
    if first_position >= second_position {
        return Err(format!(
            "ordering violation: {first:?} must precede {second:?}"
        ));
    }
    Ok(())
}

fn array_block<'a>(source: &'a str, declaration: &str) -> Result<&'a str, String> {
    let start = position(source, declaration)?;
    let remainder = &source[start + declaration.len()..];
    let end = remainder
        .find("\n)")
        .ok_or_else(|| format!("unterminated array declaration: {declaration}"))?;
    Ok(&remainder[..end])
}

fn validate_runbook(source: &str) -> Result<(), String> {
    for singleton in REQUIRED_SINGLETONS {
        require_count(source, singleton, 1)?;
    }
    if RECORD_NAMES.len() != EXPECTED_RECORD_COUNT {
        return Err("checker record cardinality drifted".to_string());
    }

    let record_block = array_block(source, "readonly -a expected_record_names=(")?;
    let log_block = array_block(source, "readonly -a expected_log_records=(")?;
    for name in RECORD_NAMES {
        require_count(record_block, name, 1)?;
    }
    require_count(
        source,
        DIRECT_WRAPPER_COMMAND_PREFIX,
        EXPECTED_DIRECT_WRAPPER_COMMAND_COUNT,
    )?;
    require_count(source, DIRECT_RUNTIME_COMMAND_PREFIX, 0)?;
    require_count(
        source,
        VISIBLE_DEVICE_USE,
        EXPECTED_VISIBLE_DEVICE_USE_COUNT,
    )?;
    require_count(log_block, "phase=", EXPECTED_RECORD_COUNT)?;

    require_before(source, AUTHORIZATION_CHECK, EXECUTION_LOCK_ACQUIRE)?;
    require_before(source, EXECUTION_LOCK_ACQUIRE, TRAP_INSTALL)?;
    require_before(source, TRAP_INSTALL, ROLLBACK_CALL)?;
    require_before(source, ROLLBACK_CALL, ISOLATE_CALL)?;
    require_before(source, ISOLATE_CALL, INVOCATION_COUNTER_WRITE)?;
    require_before(source, INVOCATION_COUNTER_WRITE, DIAGNOSTIC_COMMAND)?;
    require_before(source, DIAGNOSTIC_COMMAND, EVIDENCE_VALIDATION_CALL)?;
    Ok(())
}

fn validate_file(path: &Path) -> Result<String, String> {
    let metadata = fs::metadata(path).map_err(|error| format!("{}: {error}", path.display()))?;
    let mode = metadata.permissions().mode() & 0o777;
    if mode != EXPECTED_MODE {
        return Err(format!(
            "{} has mode {mode:o}, expected {EXPECTED_MODE:o}",
            path.display()
        ));
    }
    let source =
        fs::read_to_string(path).map_err(|error| format!("{}: {error}", path.display()))?;
    validate_runbook(&source)?;
    Ok(source)
}

fn expect_rejected(name: &str, source: String) -> Result<(), String> {
    if validate_runbook(&source).is_ok() {
        return Err(format!("negative fixture was accepted: {name}"));
    }
    Ok(())
}

fn run_self_test(path: &Path) -> Result<(), String> {
    let source = validate_file(path)?;
    expect_rejected(
        "device mutation",
        source.replacen(
            "readonly visible_device=\"1\"",
            "readonly visible_device=\"0\"",
            1,
        ),
    )?;
    expect_rejected(
        "authorization mutation",
        source.replacen(
            "Authorize exactly one device-1 reader diagnostic process.",
            "Authorize a reader diagnostic.",
            1,
        ),
    )?;
    expect_rejected(
        "attempt lock removal",
        source.replacen(EXECUTION_LOCK_ACQUIRE, "", 1),
    )?;
    expect_rejected(
        "counter removal",
        source.replacen(INVOCATION_COUNTER_WRITE, "", 1),
    )?;
    expect_rejected(
        "duplicate invocation",
        source.replacen(
            DIAGNOSTIC_COMMAND,
            &format!("{DIAGNOSTIC_COMMAND}\n{DIAGNOSTIC_COMMAND}"),
            1,
        ),
    )?;
    expect_rejected(
        "evidence validation removal",
        source.replacen(EVIDENCE_VALIDATION_CALL, "", 1),
    )?;
    Ok(())
}

fn run() -> Result<(), String> {
    let arguments: Vec<String> = env::args().skip(1).collect();
    let default_path = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join(RUNBOOK_FILENAME);
    match arguments.as_slice() {
        [] => {
            validate_file(&default_path)?;
            println!("ttWKV7 reader runbook check: PASS");
        }
        [argument] if argument == SELF_TEST_ARGUMENT => {
            run_self_test(&default_path)?;
            println!("ttWKV7 reader runbook self-test: PASS");
        }
        [path] => {
            validate_file(Path::new(path))?;
            println!("ttWKV7 reader runbook check: PASS");
        }
        _ => return Err("usage: check-runbook.rs [--self-test|RUNBOOK]".to_string()),
    }
    Ok(())
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("ttWKV7 reader runbook check: {error}");
            ExitCode::FAILURE
        }
    }
}
