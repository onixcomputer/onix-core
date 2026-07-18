use std::env;
use std::fs;
use std::path::Path;
use std::process::ExitCode;

const TRANSCRIPT_BYTES: usize = 207_544;
const LENGTH_PREFIX_BYTES: usize = 8;
const REQUEST_FRAME_BYTES: usize = 107_588;
const RESPONSE_FRAME_BYTES: usize = 99_940;
const RESPONSE_HEADER_BYTES: usize = 100;
const RESPONSE_LOG_PREFIX_BYTES: usize = 3_793;
const HIDDEN_SIZE: usize = 768;
const BF16_BYTES: usize = 2;
const RAW_OUTPUT_BYTES: usize = HIDDEN_SIZE * BF16_BYTES;
const MATRIX_STATE_VALUE_COUNT: usize = 49_152;
const MATRIX_STATE_BYTES: usize = MATRIX_STATE_VALUE_COUNT * BF16_BYTES;
const EXPECTED_PARTIAL_STATE_VALUE_COUNT: usize = 47_255;
const EXPECTED_MISSING_STATE_VALUE_COUNT: usize = 1_897;
const EXPECTED_ARGUMENT_COUNT: usize = 1;
const EXPECTED_SCHEMA_VERSION: u32 = 1;
const EXPECTED_CALL_ORDINAL: u32 = 0;
const EXPECTED_TOKEN_ORDINAL: u32 = 2;
const EXPECTED_LAYER_ORDINAL: u32 = 0;
const EXPECTED_HEAD_COUNT: u32 = 12;
const EXPECTED_HEAD_SIZE: u32 = 64;
const EXPECTED_HIDDEN_SIZE: u32 = 768;
const RESPONSE_MAGIC: &[u8; 8] = b"RKW7RSP1";
const REQUEST_MAGIC: &[u8; 8] = b"RKW7REQ1";
const LOGGER_PREFIX: &str =
    "2026-07-18 03:25:56.289 | info     |          Device | Opening user mode device driver";

#[derive(Debug, Eq, PartialEq)]
struct Diagnostic {
    logger_prefix_bytes: usize,
    valid_response_prefix_bytes: usize,
    finite_raw_output_values: usize,
    finite_partial_state_values: usize,
    missing_state_values: usize,
}

struct Evidence<'a> {
    classification: &'a str,
    session: &'a str,
    process: &'a str,
    diagnostic: &'a str,
    owner_after: &'a str,
    health_after: &'a str,
    board_first: &'a str,
    board_second: &'a str,
    rollback_after: &'a str,
    mesh_devices: &'a str,
    mesh_workloads: &'a str,
    programs: &'a str,
    server_stderr: &'a str,
}

fn read_u32(bytes: &[u8], offset: usize, name: &str) -> Result<u32, String> {
    let end = offset
        .checked_add(size_of::<u32>())
        .ok_or_else(|| format!("{name} offset overflow"))?;
    let value = bytes
        .get(offset..end)
        .ok_or_else(|| format!("{name} is truncated"))?;
    Ok(u32::from_le_bytes(
        value
            .try_into()
            .map_err(|_| format!("{name} width mismatch"))?,
    ))
}

fn read_u64(bytes: &[u8], offset: usize, name: &str) -> Result<u64, String> {
    let end = offset
        .checked_add(size_of::<u64>())
        .ok_or_else(|| format!("{name} offset overflow"))?;
    let value = bytes
        .get(offset..end)
        .ok_or_else(|| format!("{name} is truncated"))?;
    Ok(u64::from_le_bytes(
        value
            .try_into()
            .map_err(|_| format!("{name} width mismatch"))?,
    ))
}

fn require_contains(source: &str, needle: &str, name: &str) -> Result<(), String> {
    if !source.contains(needle) {
        return Err(format!("{name} is missing {needle:?}"));
    }
    Ok(())
}

fn require_count(source: &str, needle: &str, expected: usize, name: &str) -> Result<(), String> {
    let actual = source.matches(needle).count();
    if actual != expected {
        return Err(format!(
            "{name} contains {actual} occurrence(s) of {needle:?}, expected {expected}"
        ));
    }
    Ok(())
}

fn finite_bf16_count(bytes: &[u8], name: &str) -> Result<usize, String> {
    if !bytes.len().is_multiple_of(BF16_BYTES) {
        return Err(format!("{name} ends with a partial BF16 value"));
    }
    let mut finite_count = 0;
    for pair in bytes.chunks_exact(BF16_BYTES) {
        let bits = u16::from_le_bytes([pair[0], pair[1]]);
        if bits & 0x7f80 == 0x7f80 {
            return Err(format!("{name} contains a non-finite BF16 value"));
        }
        finite_count += 1;
    }
    Ok(finite_count)
}

fn find_magic_offsets(bytes: &[u8]) -> Vec<usize> {
    bytes
        .windows(RESPONSE_MAGIC.len())
        .enumerate()
        .filter_map(|(offset, window)| (window == RESPONSE_MAGIC).then_some(offset))
        .collect()
}

fn validate_metadata(frame: &[u8], request: &[u8]) -> Result<(), String> {
    const VERSION_OFFSET: usize = 8;
    const SEQUENCE_OFFSET: usize = 12;
    const SEQUENCE_BYTES: usize = 32;
    const CALL_OFFSET: usize = 44;
    const TOKEN_OFFSET: usize = 48;
    const LAYER_OFFSET: usize = 52;
    const HEAD_COUNT_OFFSET: usize = 56;
    const HEAD_SIZE_OFFSET: usize = 60;
    const HIDDEN_SIZE_OFFSET: usize = 64;

    if read_u32(frame, VERSION_OFFSET, "response schema")? != EXPECTED_SCHEMA_VERSION {
        return Err("response schema version drifted".to_owned());
    }
    let sequence_end = SEQUENCE_OFFSET + SEQUENCE_BYTES;
    if frame.get(SEQUENCE_OFFSET..sequence_end) != request.get(SEQUENCE_OFFSET..sequence_end) {
        return Err("response sequence does not match the request".to_owned());
    }
    for (offset, expected, name) in [
        (CALL_OFFSET, EXPECTED_CALL_ORDINAL, "call ordinal"),
        (TOKEN_OFFSET, EXPECTED_TOKEN_ORDINAL, "token ordinal"),
        (LAYER_OFFSET, EXPECTED_LAYER_ORDINAL, "layer ordinal"),
        (HEAD_COUNT_OFFSET, EXPECTED_HEAD_COUNT, "head count"),
        (HEAD_SIZE_OFFSET, EXPECTED_HEAD_SIZE, "head size"),
        (HIDDEN_SIZE_OFFSET, EXPECTED_HIDDEN_SIZE, "hidden size"),
    ] {
        if read_u32(frame, offset, name)? != expected {
            return Err(format!("response {name} drifted"));
        }
        if read_u32(request, offset, name)? != expected {
            return Err(format!("request {name} drifted"));
        }
    }
    Ok(())
}

fn analyze_transcript(transcript: &[u8]) -> Result<Diagnostic, String> {
    if transcript.len() != TRANSCRIPT_BYTES {
        return Err(format!(
            "transcript has {} bytes, expected {TRANSCRIPT_BYTES}",
            transcript.len()
        ));
    }
    if read_u64(transcript, 0, "request length")? != REQUEST_FRAME_BYTES as u64 {
        return Err("request length prefix drifted".to_owned());
    }
    let request_offset = LENGTH_PREFIX_BYTES;
    let request_end = request_offset + REQUEST_FRAME_BYTES;
    let request = &transcript[request_offset..request_end];
    if !request.starts_with(REQUEST_MAGIC) {
        return Err("request magic mismatch".to_owned());
    }
    let response_length_offset = request_end;
    if read_u64(transcript, response_length_offset, "response length")?
        != RESPONSE_FRAME_BYTES as u64
    {
        return Err("response length prefix drifted".to_owned());
    }
    let captured_response_offset = response_length_offset + LENGTH_PREFIX_BYTES;
    let captured_response = &transcript[captured_response_offset..];
    if captured_response.starts_with(RESPONSE_MAGIC) {
        return Err("captured response unexpectedly begins with canonical magic".to_owned());
    }
    let magic_offsets = find_magic_offsets(captured_response);
    if magic_offsets != [RESPONSE_LOG_PREFIX_BYTES] {
        return Err(format!("response magic offsets drifted: {magic_offsets:?}"));
    }
    let logger_prefix = std::str::from_utf8(&captured_response[..RESPONSE_LOG_PREFIX_BYTES])
        .map_err(|error| format!("logger prefix is not UTF-8: {error}"))?;
    if !logger_prefix.starts_with(LOGGER_PREFIX) {
        return Err("captured response logger prefix drifted".to_owned());
    }
    let valid_response_prefix = &captured_response[RESPONSE_LOG_PREFIX_BYTES..];
    validate_metadata(valid_response_prefix, request)?;
    let raw_output_end = RESPONSE_HEADER_BYTES + RAW_OUTPUT_BYTES;
    let raw_output = valid_response_prefix
        .get(RESPONSE_HEADER_BYTES..raw_output_end)
        .ok_or_else(|| "physical raw output is truncated".to_owned())?;
    let finite_raw_output_values = finite_bf16_count(raw_output, "physical raw output")?;
    if finite_raw_output_values != HIDDEN_SIZE {
        return Err("physical raw output value count drifted".to_owned());
    }
    let captured_state = &valid_response_prefix[raw_output_end..];
    let complete_state_bytes = captured_state.len() - captured_state.len() % BF16_BYTES;
    let finite_partial_state_values = finite_bf16_count(
        &captured_state[..complete_state_bytes],
        "captured physical post-state prefix",
    )?;
    if finite_partial_state_values != EXPECTED_PARTIAL_STATE_VALUE_COUNT {
        return Err(format!(
            "captured physical post-state has {finite_partial_state_values} complete values"
        ));
    }
    let missing_state_values = MATRIX_STATE_VALUE_COUNT - finite_partial_state_values;
    if missing_state_values != EXPECTED_MISSING_STATE_VALUE_COUNT {
        return Err("missing physical post-state count drifted".to_owned());
    }
    if valid_response_prefix.len() >= RESPONSE_FRAME_BYTES {
        return Err("captured canonical response is unexpectedly complete".to_owned());
    }
    if RESPONSE_HEADER_BYTES + RAW_OUTPUT_BYTES + MATRIX_STATE_BYTES != RESPONSE_FRAME_BYTES {
        return Err("reviewed response shape arithmetic drifted".to_owned());
    }
    Ok(Diagnostic {
        logger_prefix_bytes: RESPONSE_LOG_PREFIX_BYTES,
        valid_response_prefix_bytes: valid_response_prefix.len(),
        finite_raw_output_values,
        finite_partial_state_values,
        missing_state_values,
    })
}

fn validate_evidence(evidence: &Evidence<'_>) -> Result<(), String> {
    require_contains(
        evidence.classification,
        "\"outcome\": \"partial_diagnostic\"",
        "classification",
    )?;
    require_contains(
        evidence.classification,
        "\"process_budget_exhausted\": true",
        "classification",
    )?;
    require_contains(
        evidence.classification,
        "\"safety_issues\": []",
        "classification",
    )?;
    require_contains(
        evidence.classification,
        "\"success_claim\": null",
        "classification",
    )?;
    for missing in [
        "core_receipt",
        "host_manifest",
        "host_receipt",
        "server_summary",
    ] {
        require_contains(evidence.classification, missing, "classification")?;
    }
    require_contains(
        evidence.session,
        "\"process_attempts\": 1",
        "session evidence",
    )?;
    require_contains(
        evidence.session,
        "\"owner_isolation_attempts\": 1",
        "session evidence",
    )?;
    require_contains(
        evidence.session,
        "\"restoration_attempts\": 1",
        "session evidence",
    )?;
    require_contains(evidence.session, "\"exit_status\":1", "session evidence")?;
    require_contains(evidence.session, "\"timed_out\":false", "session evidence")?;
    require_contains(
        evidence.session,
        "\"owner_active_after\": true",
        "session evidence",
    )?;
    require_contains(
        evidence.session,
        "\"owner_health_status_after\": 200",
        "session evidence",
    )?;
    require_contains(
        evidence.session,
        "\"board_healthy_after\": true",
        "session evidence",
    )?;
    require_contains(
        evidence.process,
        "\"wrapper_invocation_count\": 1",
        "process receipt",
    )?;
    require_contains(evidence.process, "\"exit_status\": 1", "process receipt")?;
    require_contains(evidence.process, "\"retry_count\": 0", "process receipt")?;
    require_contains(
        evidence.process,
        "\"reconnect_count\": 0",
        "process receipt",
    )?;
    if evidence.diagnostic.trim()
        != "rwkv-ttwkv7-persistent-physical-dispatch: persistent dispatch rejected pending response: response magic mismatch"
    {
        return Err("diagnostic log drifted".to_owned());
    }
    for state in [
        "ActiveState=active",
        "SubState=running",
        "Result=success",
        "NRestarts=0",
    ] {
        require_contains(evidence.owner_after, state, "owner after")?;
    }
    if evidence.health_after != "200\n" {
        return Err("owner health status is not exactly 200".to_owned());
    }
    for board in [evidence.board_first, evidence.board_second] {
        require_count(board, "\"DDR_STATUS\": \"0x5555\"", 2, "board health")?;
        require_count(board, "\"GDDR_UNCORR_ERRS\": \"0x0\"", 2, "board health")?;
        require_count(board, "\"THERM_TRIP_COUNT\": \"0x0\"", 2, "board health")?;
    }
    require_contains(
        evidence.board_first,
        "\"TIMER_HEARTBEAT\": \"0x10b3ca\"",
        "first board sample",
    )?;
    require_contains(
        evidence.board_second,
        "\"TIMER_HEARTBEAT\": \"0x10b3e1\"",
        "second board sample",
    )?;
    for state in ["ActiveState=inactive", "SubState=dead", "Result=success"] {
        require_contains(evidence.rollback_after, state, "rollback state")?;
    }
    require_count(
        evidence.mesh_devices,
        "mesh_device_initialized:",
        1,
        "mesh device inspector",
    )?;
    require_count(
        evidence.mesh_workloads,
        "mesh_workload_created:",
        1,
        "mesh workload inspector",
    )?;
    require_count(
        evidence.mesh_workloads,
        "status: Committed",
        1,
        "mesh workload inspector",
    )?;
    require_count(
        evidence.mesh_workloads,
        "mesh_workload_destroyed:",
        1,
        "mesh workload inspector",
    )?;
    for kernel in ["wkv7_decodeL_reader", "wkv7_decodeL_compute", "wkv7_writer"] {
        require_count(
            evidence.programs,
            &format!("name: {kernel}"),
            1,
            "program inspector",
        )?;
    }
    require_contains(
        evidence.server_stderr,
        "wkv7_decodeL_compute.cpp",
        "server stderr",
    )?;
    require_contains(evidence.server_stderr, "warning:", "server stderr")?;
    Ok(())
}

fn read_text(root: &Path, relative: &str) -> Result<String, String> {
    fs::read_to_string(root.join(relative)).map_err(|error| format!("{relative}: {error}"))
}

fn run() -> Result<(), String> {
    let arguments: Vec<String> = env::args().skip(1).collect();
    if arguments.len() != EXPECTED_ARGUMENT_COUNT {
        return Err("usage: rwkv_persistent_partial_diagnostic FIXTURE_ROOT".to_owned());
    }
    let root = Path::new(&arguments[0]);
    let transcript = fs::read(root.join("transcript.bin"))
        .map_err(|error| format!("transcript.bin: {error}"))?;
    let classification = read_text(root, "classification-receipt.json")?;
    let session = read_text(root, "session-evidence.json")?;
    let process = read_text(root, "process-receipt.json")?;
    let diagnostic = read_text(root, "diagnostic.log")?;
    let owner_after = read_text(root, "owner-after.properties")?;
    let health_after = read_text(root, "health-after.status")?;
    let board_first = read_text(root, "board-after-first.txt")?;
    let board_second = read_text(root, "board-after-second.txt")?;
    let rollback_after = read_text(root, "rollback-after.properties")?;
    let mesh_devices = read_text(root, "inspector/mesh_devices_log.yaml")?;
    let mesh_workloads = read_text(root, "inspector/mesh_workloads_log.yaml")?;
    let programs = read_text(root, "inspector/programs_log.yaml")?;
    let server_stderr = read_text(root, "server-stderr.log")?;
    validate_evidence(&Evidence {
        classification: &classification,
        session: &session,
        process: &process,
        diagnostic: &diagnostic,
        owner_after: &owner_after,
        health_after: &health_after,
        board_first: &board_first,
        board_second: &board_second,
        rollback_after: &rollback_after,
        mesh_devices: &mesh_devices,
        mesh_workloads: &mesh_workloads,
        programs: &programs,
        server_stderr: &server_stderr,
    })?;
    let receipt = analyze_transcript(&transcript)?;
    println!("{{");
    println!("  \"accepted_physical_response_count\": 0,");
    println!("  \"classification\": \"partial_diagnostic\",");
    println!("  \"completed_physical_wkv_call_count\": 1,");
    println!("  \"device_open_count\": 1,");
    println!(
        "  \"finite_partial_post_state_values\": {},",
        receipt.finite_partial_state_values
    );
    println!(
        "  \"finite_raw_output_values\": {},",
        receipt.finite_raw_output_values
    );
    println!(
        "  \"logger_prefix_bytes\": {},",
        receipt.logger_prefix_bytes
    );
    println!(
        "  \"missing_post_state_values\": {},",
        receipt.missing_state_values
    );
    println!("  \"new_hardware_attempt_count\": 1,");
    println!("  \"owner_health_status_after\": 200,");
    println!("  \"owner_restored\": true,");
    println!("  \"physical_workload_commit_count\": 1,");
    println!("  \"pueue_task_id\": 281,");
    println!(
        "  \"response_transport_failure\": \"Metalium logger bytes preceded the canonical response magic on stdout\","
    );
    println!("  \"retry_count\": 0,");
    println!("  \"schema_version\": 1,");
    println!("  \"target\": \"rwkv_ttwkv7_persistent_partial_diagnostic\",");
    println!(
        "  \"valid_response_prefix_bytes\": {}",
        receipt.valid_response_prefix_bytes
    );
    println!("}}");
    Ok(())
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("rwkv persistent partial diagnostic: {error}");
            ExitCode::FAILURE
        }
    }
}
