#!/usr/bin/env -S CARGO_TARGET_DIR=target/ttwkv7-boundary-preflight-recovery nix --option secret-key-files '' shell "github:nix-community/fenix?rev=8df3642541009d2a5f15520462a8dec719c5fddb#minimal.toolchain" nixpkgs#gcc -c cargo -q -Zscript
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
const ACTIVE_RUNBOOK_RELATIVE_PATH: &str =
    "cairn/changes/recover-rwkv-ttwkv7-boundary-preflight/run-one-shot.sh";
const ARCHIVED_RUNBOOK_RELATIVE_PATH: &str =
    "cairn/archive/2026-07-17-recover-rwkv-ttwkv7-boundary-preflight/run-one-shot.sh";
const SELF_TEST_ARGUMENT: &str = "--self-test";
const EXPECTED_WRAPPER_COMMAND_COUNT: usize = 2;
const EXPECTED_PROBE_COMMAND_COUNT: usize = 1;
const EXPECTED_PREFLIGHT_COMMAND_COUNT: usize = 1;

const REQUIRED_SINGLETONS: &[&str] = &[
    "readonly active_system_path=\"/nix/store/vb9zjhp20rpg7g1g4ypmmcsq7n4s9d3p-nixos-system-britton-desktop-26.11.20260629.7a1a647\"",
    "readonly boundary_package_path=\"/nix/store/av4m3qy5m0qjvrrfrn1dckjxnd7vzbkv-rwkv-ttwkv7-boundary-device-0.2.0\"",
    "readonly ordinary_package_path=\"/nix/store/5alwcj7ff65s1zg6q475akwayafmh0bz-ttwkv7-unstable-2026-06-22\"",
    "readonly readiness_path=\"/nix/store/hjjrp20xidsgig1yzfn5zydbn9wp8n7a-rwkv-ttwkv7-boundary-device-check\"",
    "readonly expected_plan_id=\"d4886116b76df2cf63090e3a1f7efff35aa215aa2d05652d7accaa9b61a9abb1\"",
    "readonly expected_plan_receipt_blake3=\"307efa0052ae9b5b003d7c6026ba0340e527cbea4a6e057bfa70df84c53e0291\"",
    "readonly expected_readiness_blake3=\"bac896f69c9d2f8c68764aafd696c9902d21220e3368a0bfe92f7b976e8a2d1e\"",
    "readonly expected_host_fingerprint=\"SHA256:DOOddCNRRRqCVbueQZovbR8Q//NwYeeMCaznz+GqxQE\"",
    "readonly owner_control_path=\"/nix/store/6m9zwmdfc1vyrxw2znbl39s78bz73ycp-ttwkv7-owner-control/bin/ttwkv7-owner-control\"",
    "readonly visible_device=\"1\"",
    "readonly device_path=\"/dev/tenstorrent/$visible_device\"",
    "readonly run_root=\"/var/tmp/rwkv-ttwkv7-boundary-device-2\"",
    "readonly execution_lock_path=\"$run_root/execution-consumed.lock\"",
    "readonly process_timeout_seconds=\"900\"",
    "readonly timeout_kill_grace_seconds=\"10\"",
    "readonly rollback_delay_seconds=\"1200\"",
    "readonly expected_writer_bytes=\"147456\"",
    "readonly expected_output_bytes=\"1536\"",
    "readonly expected_post_state_bytes=\"98304\"",
    "readonly expected_success_marker=\"rwkv ttWKV7 boundary device probe: PASS\"",
    "readonly expected_argument_count=\"0\"",
    "validate_boundary_artifacts() (",
    "materialize_classification() {",
    "restore_owner() {",
    "if [[ $owner_isolation_attempted -eq 0 ]]; then",
    "if [[ $rollback_arm_attempted -eq 1 ]]; then",
    "\"$run_root/preflight-failure.txt\"",
    "\"$run_root/host-fingerprint.txt\"",
];

const FORBIDDEN_MARKERS: &[&str] = &[
    "authorization.txt",
    "expected_authorization",
    "Authorize exactly",
    "boundary-run ",
    "test decodeL",
    "bench decodeL",
    "while retry",
];

const ARGUMENT_CHECK: &str =
    "[[ $# -eq $expected_argument_count ]] || fail \"arguments are not accepted\"";
const PLAN_ROOT_CHECK: &str = "grep -Fq \"\\\"run_root\\\": \\\"$run_root\\\"\" \"$plan_manifest_path\" || fail \"plan run root mismatch\"";
const RUN_ROOT_CREATE: &str =
    "mkdir \"$run_root\" || fail \"run root could not be created atomically\"";
const EXECUTION_LOCK_ACQUIRE: &str =
    "mkdir \"$execution_lock_path\" || fail \"execution attempt lock could not be acquired\"";
const ATTEMPT_COUNTER_WRITE: &str =
    "printf '%s\\n' \"$consumed_counter_value\" >\"$run_root/execution-attempt-count.txt\"";
const TRAP_INSTALL: &str = "trap restore_owner EXIT";
const HOST_KEYSCAN_COMMAND: &str =
    "\"$ssh_keyscan_path\" -T \"$health_request_timeout_seconds\" -t ed25519 127.0.0.1";
const ROLLBACK_ATTEMPT_FLAG: &str = "rollback_arm_attempted=1";
const ROLLBACK_CALL: &str = "\narm_rollback_timer\n";
const ISOLATE_CALL: &str = "\"$owner_control_path\" isolate >\"$run_root/isolate.log\" 2>&1";
const PROCESS_COUNTER_WRITE: &str =
    "printf '%s\\n' \"$consumed_counter_value\" >\"$run_root/invocation-count.txt\"";
const RESTORATION_COUNTER_WRITE: &str =
    "printf '%s\\n' \"$consumed_counter_value\" >\"$run_root/restoration-attempted.txt\"";
const PREFLIGHT_COMMAND: &str =
    "  \"$wrapper_path\" validate-runtime >\"$run_root/preflight.log\" 2>&1";
const PROBE_COMMAND: &str = "  \"$wrapper_path\" probe \\";
const EVIDENCE_VALIDATION_CALL: &str =
    "validate_boundary_artifacts >\"$run_root/evidence-completeness.log\" 2>&1";
const CLASSIFICATION_CALL: &str = "  \"$rwkv_lab_path\" classify \\";
const WRAPPER_COMMAND_PREFIX: &str = "\n  \"$wrapper_path\" ";

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

fn validate_runbook(source: &str) -> Result<(), String> {
    for singleton in REQUIRED_SINGLETONS {
        require_count(source, singleton, 1)?;
    }
    for forbidden in FORBIDDEN_MARKERS {
        require_count(source, forbidden, 0)?;
    }
    require_count(
        source,
        WRAPPER_COMMAND_PREFIX,
        EXPECTED_WRAPPER_COMMAND_COUNT,
    )?;
    require_count(source, PREFLIGHT_COMMAND, EXPECTED_PREFLIGHT_COMMAND_COUNT)?;
    require_count(source, PROBE_COMMAND, EXPECTED_PROBE_COMMAND_COUNT)?;
    require_count(source, ARGUMENT_CHECK, 1)?;
    require_count(source, PLAN_ROOT_CHECK, 1)?;
    require_count(source, EXECUTION_LOCK_ACQUIRE, 1)?;
    require_count(source, ATTEMPT_COUNTER_WRITE, 1)?;
    require_count(source, PROCESS_COUNTER_WRITE, 1)?;
    require_count(source, RESTORATION_COUNTER_WRITE, 1)?;
    require_count(source, TRAP_INSTALL, 1)?;
    require_count(source, HOST_KEYSCAN_COMMAND, 1)?;
    require_count(source, ROLLBACK_ATTEMPT_FLAG, 1)?;
    require_count(source, ROLLBACK_CALL, 1)?;
    require_count(source, ISOLATE_CALL, 1)?;
    require_count(source, EVIDENCE_VALIDATION_CALL, 1)?;
    require_count(source, CLASSIFICATION_CALL, 1)?;

    require_before(source, RUN_ROOT_CREATE, TRAP_INSTALL)?;
    require_before(source, TRAP_INSTALL, HOST_KEYSCAN_COMMAND)?;
    require_before(source, HOST_KEYSCAN_COMMAND, PREFLIGHT_COMMAND)?;
    require_before(source, PREFLIGHT_COMMAND, EXECUTION_LOCK_ACQUIRE)?;
    require_before(source, EXECUTION_LOCK_ACQUIRE, ATTEMPT_COUNTER_WRITE)?;
    require_before(source, ATTEMPT_COUNTER_WRITE, ROLLBACK_ATTEMPT_FLAG)?;
    require_before(source, ROLLBACK_ATTEMPT_FLAG, ROLLBACK_CALL)?;
    require_before(source, ROLLBACK_CALL, ISOLATE_CALL)?;
    require_before(source, ISOLATE_CALL, PROCESS_COUNTER_WRITE)?;
    require_before(source, PROCESS_COUNTER_WRITE, PROBE_COMMAND)?;
    require_before(source, PROBE_COMMAND, EVIDENCE_VALIDATION_CALL)?;
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
    let mutations = [
        (
            "device mutation",
            source.replacen(
                "readonly visible_device=\"1\"",
                "readonly visible_device=\"0\"",
                1,
            ),
        ),
        (
            "package mutation",
            source.replacen("av4m3qy5m0qjvrrfrn1dckjxnd7vzbkv", "xv4m3qy5m0qjvrrfrn1dckjxnd7vzbkv", 1),
        ),
        (
            "plan mutation",
            source.replacen("d4886116b76df2cf63090e3a1f7efff35aa215aa2d05652d7accaa9b61a9abb1", "a4886116b76df2cf63090e3a1f7efff35aa215aa2d05652d7accaa9b61a9abb1", 1),
        ),
        (
            "readiness mutation",
            source.replacen("hjjrp20xidsgig1yzfn5zydbn9wp8n7a", "xjjrp20xidsgig1yzfn5zydbn9wp8n7a", 1),
        ),
        (
            "timeout mutation",
            source.replacen(
                "readonly process_timeout_seconds=\"900\"",
                "readonly process_timeout_seconds=\"901\"",
                1,
            ),
        ),
        (
            "rollback delay mutation",
            source.replacen(
                "readonly rollback_delay_seconds=\"1200\"",
                "readonly rollback_delay_seconds=\"1201\"",
                1,
            ),
        ),
        (
            "fingerprint mutation",
            source.replacen(
                "SHA256:DOOddCNRRRqCVbueQZovbR8Q//NwYeeMCaznz+GqxQE",
                "SHA256:AOOddCNRRRqCVbueQZovbR8Q//NwYeeMCaznz+GqxQE",
                1,
            ),
        ),
        (
            "run root mutation",
            source.replacen(
                "readonly run_root=\"/var/tmp/rwkv-ttwkv7-boundary-device-2\"",
                "readonly run_root=\"/var/tmp/rwkv-ttwkv7-boundary-device-3\"",
                1,
            ),
        ),
        ("argument check removal", source.replacen(ARGUMENT_CHECK, "", 1)),
        ("plan root check removal", source.replacen(PLAN_ROOT_CHECK, "", 1)),
        ("lock removal", source.replacen(EXECUTION_LOCK_ACQUIRE, "", 1)),
        ("attempt counter removal", source.replacen(ATTEMPT_COUNTER_WRITE, "", 1)),
        ("trap removal", source.replacen(TRAP_INSTALL, "", 1)),
        (
            "trap relocation after host keyscan",
            source
                .replacen(TRAP_INSTALL, "", 1)
                .replacen(
                    HOST_KEYSCAN_COMMAND,
                    &format!("{HOST_KEYSCAN_COMMAND}\n{TRAP_INSTALL}"),
                    1,
                ),
        ),
        (
            "host keyscan removal",
            source.replacen(HOST_KEYSCAN_COMMAND, "", 1),
        ),
        (
            "pre-isolation classification removal",
            source.replacen("if [[ $owner_isolation_attempted -eq 0 ]]; then", "if false; then", 1),
        ),
        (
            "pre-isolation rollback cleanup removal",
            source.replacen("if [[ $rollback_arm_attempted -eq 1 ]]; then", "if false; then", 1),
        ),
        (
            "rollback attempt flag removal",
            source.replacen(ROLLBACK_ATTEMPT_FLAG, "", 1),
        ),
        ("rollback removal", source.replacen(ROLLBACK_CALL, "\n", 1)),
        ("isolation removal", source.replacen(ISOLATE_CALL, "", 1)),
        ("process counter removal", source.replacen(PROCESS_COUNTER_WRITE, "", 1)),
        (
            "restoration counter removal",
            source.replacen(RESTORATION_COUNTER_WRITE, "", 1),
        ),
        ("probe removal", source.replacen(PROBE_COMMAND, "", 1)),
        (
            "probe duplication",
            source.replacen(PROBE_COMMAND, &format!("{PROBE_COMMAND}\n{PROBE_COMMAND}"), 1),
        ),
        (
            "evidence validation removal",
            source.replacen(EVIDENCE_VALIDATION_CALL, "", 1),
        ),
        (
            "classification removal",
            source.replacen(CLASSIFICATION_CALL, "", 1),
        ),
        (
            "direct boundary run",
            source.replacen(PROBE_COMMAND, "  \"$wrapper_path\" boundary-run \\", 1),
        ),
        (
            "authorization gate reintroduction",
            source.replacen(
                EXECUTION_LOCK_ACQUIRE,
                &format!(
                    "[[ -f \"$run_root/authorization.txt\" ]] || fail \"authorization missing\"\n{EXECUTION_LOCK_ACQUIRE}"
                ),
                1,
            ),
        ),
    ];
    for (name, mutation) in mutations {
        expect_rejected(name, mutation)?;
    }
    Ok(())
}

fn default_runbook_path() -> Result<PathBuf, String> {
    let repository_root = env::current_dir()
        .map_err(|error| format!("current directory could not be read: {error}"))?;
    let active_path = repository_root.join(ACTIVE_RUNBOOK_RELATIVE_PATH);
    if active_path.is_file() {
        return Ok(active_path);
    }
    Ok(repository_root.join(ARCHIVED_RUNBOOK_RELATIVE_PATH))
}

fn run() -> Result<(), String> {
    let arguments: Vec<String> = env::args().skip(1).collect();
    let default_path = default_runbook_path()?;
    match arguments.as_slice() {
        [] => {
            validate_file(&default_path)?;
            println!("rwkv ttWKV7 boundary runbook check: PASS");
        }
        [argument] if argument == SELF_TEST_ARGUMENT => {
            run_self_test(&default_path)?;
            println!("rwkv ttWKV7 boundary runbook self-test: PASS");
        }
        [path] => {
            validate_file(Path::new(path))?;
            println!("rwkv ttWKV7 boundary runbook check: PASS");
        }
        _ => return Err("usage: check-runbook.rs [--self-test|RUNBOOK]".to_owned()),
    }
    Ok(())
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("rwkv ttWKV7 boundary runbook check: {error}");
            ExitCode::FAILURE
        }
    }
}
