#!/usr/bin/env -S CARGO_TARGET_DIR=target/rwkv-persistent-device-4-runbook nix --option secret-key-files '' shell "github:nix-community/fenix?rev=8df3642541009d2a5f15520462a8dec719c5fddb#minimal.toolchain" nixpkgs#gcc -c cargo -q -Zscript
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
    "cairn/changes/prepare-rwkv-persistent-metalium-device-4-run/run-one-shot.sh";
const ARCHIVED_RUNBOOK_RELATIVE_PATH: &str =
    "cairn/archive/2026-07-18-prepare-rwkv-persistent-metalium-device-4-run/run-one-shot.sh";
const SELF_TEST_ARGUMENT: &str = "--self-test";
const EXPECTED_WRAPPER_COMMAND_COUNT: usize = 2;
const EXPECTED_PROBE_COMMAND_COUNT: usize = 1;
const EXPECTED_PREFLIGHT_COMMAND_COUNT: usize = 1;

const REQUIRED_SINGLETONS: &[&str] = &[
    "readonly active_system_path=\"/nix/store/vb9zjhp20rpg7g1g4ypmmcsq7n4s9d3p-nixos-system-britton-desktop-26.11.20260629.7a1a647\"",
    "readonly persistent_package_path=\"/nix/store/pp97f3b6k13lb22qqh79iy7lnx3ha4qa-rwkv-ttwkv7-persistent-device-0.2.0\"",
    "readonly ordinary_package_path=\"/nix/store/zx0k9707wbxwm5n1wbmqwxff3dc5wgyk-ttwkv7-unstable-2026-06-22\"",
    "readonly harness_package_path=\"/nix/store/8vdazpj6lyay9g8vx346z0ss4bq6ldaz-rwkv-layer-harness-0.1.0\"",
    "readonly readiness_path=\"/nix/store/ahzsp9ihj70b1zhq5izc6nykbq22k8ss-rwkv-ttwkv7-persistent-device-check\"",
    "readonly expected_plan_id=\"7c1d1dbc06ba73e5d54f52f929f80aacac52084ad0610a3cce5da60b325df427\"",
    "readonly expected_plan_manifest_blake3=\"8261cc89daafa3118ae8da1ea7b46228978f4a1422443ae2c875d83d63791d4d\"",
    "readonly expected_plan_receipt_blake3=\"4cfb670fd9c9bc92b9e5d06c5a4adf4439d96b67b44b6de450cb93bf003464fc\"",
    "readonly expected_not_run_blake3=\"f1628fb83aac17fe3c39345f45239b8a5116a9434e6dfe4aa95a3f7eec28b6c7\"",
    "readonly expected_readiness_blake3=\"de303cd9b69aca918f9573ffc2529b6963f7f27ee961e80e9e8f9c32e0acc46e\"",
    "readonly expected_host_fingerprint=\"SHA256:DOOddCNRRRqCVbueQZovbR8Q//NwYeeMCaznz+GqxQE\"",
    "readonly owner_control_path=\"/nix/store/6m9zwmdfc1vyrxw2znbl39s78bz73ycp-ttwkv7-owner-control/bin/ttwkv7-owner-control\"",
    "readonly visible_device=\"1\"",
    "readonly device_path=\"/dev/tenstorrent/$visible_device\"",
    "readonly run_root=\"/var/tmp/rwkv-ttwkv7-persistent-device-4\"",
    "readonly artifact_root=\"$logs_path/rwkv-persistent-physical-dispatch\"",
    "readonly execution_lock_path=\"$run_root/execution-consumed.lock\"",
    "readonly inspector_address=\"127.0.0.1:43158\"",
    "readonly inspector_port=\"43158\"",
    "readonly rollback_unit=\"rwkv-ttwkv7-persistent-rollback-device-4\"",
    "readonly process_timeout_seconds=\"1800\"",
    "readonly timeout_kill_grace_seconds=\"10\"",
    "readonly rollback_delay_seconds=\"2100\"",
    "readonly restoration_health_attempts=\"120\"",
    "readonly restoration_health_delay_seconds=\"5\"",
    "readonly restoration_health_window_seconds=\"600\"",
    "readonly health_request_timeout_seconds=\"5\"",
    "readonly expected_transcript_bytes=\"4981056\"",
    "readonly expected_manifest_lines=\"7\"",
    "readonly expected_physical_call_count=\"24\"",
    "readonly expected_continuity_count=\"12\"",
    "readonly expected_response_connection_count=\"1\"",
    "readonly expected_success_marker=\"rwkv persistent physical ttWKV7 dispatch: PASS\"",
    "readonly expected_argument_count=\"0\"",
    "validate_persistent_artifacts() (",
    "validate_manifest_entry \"server_stdout\" \"server-stdout.log\" \"any\"",
    "[[ ! -e $artifact_root/response.sock ]]",
    "grep -Fq '\"response_channel\": \"unix_stream\"' \"$artifact_root/receipt.json\"",
    "grep -Fq '\"target\":\"rwkv_ttwkv7_persistent_dispatch_server\"' \"$artifact_root/server-summary.json\"",
    "grep -Fq '\"response_channel\":\"unix_stream\"' \"$artifact_root/server-summary.json\"",
    "append_artifact \"child_stdout\" \"$artifact_root/server-stdout.log\"",
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
    "rwkv-ttwkv7-boundary-device-1",
    "rwkv-ttwkv7-boundary-device-2",
    "rwkv-ttwkv7-persistent-device-3",
    "rwkv-ttwkv7-persistent-rollback-device-3",
    "iwwz6qm3zkvp916mxr4rzjvj6bkfqxic",
];

const ARGUMENT_CHECK: &str =
    "[[ $# -eq $expected_argument_count ]] || fail \"arguments are not accepted\"";
const PLAN_ROOT_CHECK: &str = r#"grep -Fq "\"run_root\": \"$run_root\"" "$plan_manifest_path" || fail "plan run root mismatch""#;
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
const PROBE_COMMAND: &str = r#"  "$wrapper_path" probe \"#;
const PROCESS_RECEIPT_WRITE: &str = "  >\"$run_root/process-receipt.json\"";
const EVIDENCE_VALIDATION_CALL: &str =
    "validate_persistent_artifacts >\"$run_root/evidence-completeness.log\" 2>&1";
const CLASSIFICATION_CALL: &str = r#"  "$rwkv_lab_path" classify \"#;
const WRAPPER_COMMAND_PREFIX: &str = "\n  \"$wrapper_path\" ";
const HEALTH_WINDOW_CHECK: &str = "[[ $((restoration_health_attempts * restoration_health_delay_seconds)) -eq $restoration_health_window_seconds ]] || fail \"restoration health window mismatch\"";

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
    if position(source, first)? >= position(source, second)? {
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
    for singleton in [
        ARGUMENT_CHECK,
        PLAN_ROOT_CHECK,
        EXECUTION_LOCK_ACQUIRE,
        ATTEMPT_COUNTER_WRITE,
        PROCESS_COUNTER_WRITE,
        RESTORATION_COUNTER_WRITE,
        TRAP_INSTALL,
        HOST_KEYSCAN_COMMAND,
        ROLLBACK_ATTEMPT_FLAG,
        ROLLBACK_CALL,
        ISOLATE_CALL,
        PROCESS_RECEIPT_WRITE,
        EVIDENCE_VALIDATION_CALL,
        CLASSIFICATION_CALL,
        HEALTH_WINDOW_CHECK,
    ] {
        require_count(source, singleton, 1)?;
    }

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
    require_before(source, PROBE_COMMAND, PROCESS_RECEIPT_WRITE)?;
    require_before(source, PROCESS_RECEIPT_WRITE, EVIDENCE_VALIDATION_CALL)?;
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

fn mutate_once(source: &str, from: &str, to: &str) -> Result<String, String> {
    require_count(source, from, 1)?;
    Ok(source.replacen(from, to, 1))
}

fn expect_rejected(name: &str, source: String) -> Result<(), String> {
    if validate_runbook(&source).is_ok() {
        return Err(format!("negative fixture was accepted: {name}"));
    }
    Ok(())
}

fn run_self_test(path: &Path) -> Result<(), String> {
    let source = validate_file(path)?;
    let replacements = [
        (
            "device",
            "readonly visible_device=\"1\"",
            "readonly visible_device=\"0\"",
        ),
        (
            "package",
            "pp97f3b6k13lb22qqh79iy7lnx3ha4qa",
            "xp97f3b6k13lb22qqh79iy7lnx3ha4qa",
        ),
        (
            "runtime",
            "zx0k9707wbxwm5n1wbmqwxff3dc5wgyk",
            "xx0k9707wbxwm5n1wbmqwxff3dc5wgyk",
        ),
        (
            "harness",
            "8vdazpj6lyay9g8vx346z0ss4bq6ldaz",
            "xvdazpj6lyay9g8vx346z0ss4bq6ldaz",
        ),
        (
            "readiness",
            "ahzsp9ihj70b1zhq5izc6nykbq22k8ss",
            "xhzsp9ihj70b1zhq5izc6nykbq22k8ss",
        ),
        (
            "plan",
            "7c1d1dbc06ba73e5d54f52f929f80aacac52084ad0610a3cce5da60b325df427",
            "ac1d1dbc06ba73e5d54f52f929f80aacac52084ad0610a3cce5da60b325df427",
        ),
        (
            "run root",
            "readonly run_root=\"/var/tmp/rwkv-ttwkv7-persistent-device-4\"",
            "readonly run_root=\"/var/tmp/rwkv-ttwkv7-persistent-device-5\"",
        ),
        (
            "port",
            "readonly inspector_port=\"43158\"",
            "readonly inspector_port=\"43159\"",
        ),
        (
            "rollback unit",
            "readonly rollback_unit=\"rwkv-ttwkv7-persistent-rollback-device-4\"",
            "readonly rollback_unit=\"rwkv-ttwkv7-persistent-rollback-device-5\"",
        ),
        (
            "timeout",
            "readonly process_timeout_seconds=\"1800\"",
            "readonly process_timeout_seconds=\"1801\"",
        ),
        (
            "health attempts",
            "readonly restoration_health_attempts=\"120\"",
            "readonly restoration_health_attempts=\"119\"",
        ),
        (
            "health window",
            "readonly restoration_health_window_seconds=\"600\"",
            "readonly restoration_health_window_seconds=\"599\"",
        ),
        (
            "manifest lines",
            "readonly expected_manifest_lines=\"7\"",
            "readonly expected_manifest_lines=\"6\"",
        ),
        (
            "response connections",
            "readonly expected_response_connection_count=\"1\"",
            "readonly expected_response_connection_count=\"2\"",
        ),
        (
            "physical calls",
            "readonly expected_physical_call_count=\"24\"",
            "readonly expected_physical_call_count=\"23\"",
        ),
        (
            "continuity",
            "readonly expected_continuity_count=\"12\"",
            "readonly expected_continuity_count=\"11\"",
        ),
        (
            "transcript",
            "readonly expected_transcript_bytes=\"4981056\"",
            "readonly expected_transcript_bytes=\"4981055\"",
        ),
        (
            "fingerprint",
            "SHA256:DOOddCNRRRqCVbueQZovbR8Q//NwYeeMCaznz+GqxQE",
            "SHA256:AOOddCNRRRqCVbueQZovbR8Q//NwYeeMCaznz+GqxQE",
        ),
        (
            "stdout role",
            "validate_manifest_entry \"server_stdout\" \"server-stdout.log\" \"any\"",
            "validate_manifest_entry \"server_stdout\" \"wrong.log\" \"any\"",
        ),
        (
            "response channel",
            "grep -Fq '\"response_channel\": \"unix_stream\"' \"$artifact_root/receipt.json\"",
            "grep -Fq '\"response_channel\": \"stdout\"' \"$artifact_root/receipt.json\"",
        ),
    ];
    for (name, from, to) in replacements {
        expect_rejected(name, mutate_once(&source, from, to)?)?;
    }

    let removals = [
        ("argument check", ARGUMENT_CHECK),
        ("plan root check", PLAN_ROOT_CHECK),
        ("lock", EXECUTION_LOCK_ACQUIRE),
        ("attempt counter", ATTEMPT_COUNTER_WRITE),
        ("trap", TRAP_INSTALL),
        ("host keyscan", HOST_KEYSCAN_COMMAND),
        ("rollback attempt", ROLLBACK_ATTEMPT_FLAG),
        ("rollback", ROLLBACK_CALL),
        ("isolation", ISOLATE_CALL),
        ("process counter", PROCESS_COUNTER_WRITE),
        ("restoration counter", RESTORATION_COUNTER_WRITE),
        ("probe", PROBE_COMMAND),
        ("process receipt", PROCESS_RECEIPT_WRITE),
        ("evidence validation", EVIDENCE_VALIDATION_CALL),
        ("classification", CLASSIFICATION_CALL),
        ("health-window check", HEALTH_WINDOW_CHECK),
    ];
    for (name, marker) in removals {
        expect_rejected(name, mutate_once(&source, marker, "")?)?;
    }

    expect_rejected(
        "trap relocation",
        mutate_once(&source, TRAP_INSTALL, "")?.replacen(
            HOST_KEYSCAN_COMMAND,
            &format!("{HOST_KEYSCAN_COMMAND}\n{TRAP_INSTALL}"),
            1,
        ),
    )?;
    expect_rejected(
        "probe duplication",
        mutate_once(
            &source,
            PROBE_COMMAND,
            &format!("{PROBE_COMMAND}\n{PROBE_COMMAND}"),
        )?,
    )?;
    expect_rejected(
        "direct runtime substitution",
        mutate_once(
            &source,
            PROBE_COMMAND,
            r#"  "$ordinary_package_path/bin/wkv7" serve \"#,
        )?,
    )?;
    expect_rejected(
        "authorization gate",
        mutate_once(
            &source,
            EXECUTION_LOCK_ACQUIRE,
            &format!(
                "[[ -f \"$run_root/authorization.txt\" ]] || fail \"authorization missing\"\n{EXECUTION_LOCK_ACQUIRE}"
            ),
        )?,
    )?;
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
            println!("rwkv persistent device-4 runbook check: PASS");
        }
        [argument] if argument == SELF_TEST_ARGUMENT => {
            run_self_test(&default_path)?;
            println!("rwkv persistent device-4 runbook self-test: PASS");
        }
        [path] => {
            validate_file(Path::new(path))?;
            println!("rwkv persistent device-4 runbook check: PASS");
        }
        [argument, path] if argument == SELF_TEST_ARGUMENT => {
            run_self_test(Path::new(path))?;
            println!("rwkv persistent device-4 runbook self-test: PASS");
        }
        _ => return Err("usage: check-runbook.rs [--self-test [RUNBOOK]|RUNBOOK]".to_owned()),
    }
    Ok(())
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("rwkv persistent device-4 runbook check: {error}");
            ExitCode::FAILURE
        }
    }
}
