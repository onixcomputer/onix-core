use std::collections::BTreeSet;
use std::env;
use std::fs;
use std::path::Path;
use std::process::ExitCode;

const CALL_COUNT: usize = 24;
const LAYER_COUNT: usize = 12;
const TOKEN_COUNT: usize = 2;
const FIRST_TOKEN_INDEX: usize = 2;
const CONTINUITY_COUNT: usize = LAYER_COUNT * (TOKEN_COUNT - 1);
const LENGTH_PREFIX_BYTES: usize = 8;
const REQUEST_FRAME_BYTES: usize = 107_588;
const RESPONSE_FRAME_BYTES: usize = 99_940;
const REQUEST_HEADER_BYTES: usize = 68;
const RESPONSE_HEADER_BYTES: usize = 100;
const RESPONSE_REQUEST_ID_OFFSET: usize = 68;
const REQUEST_ID_BYTES: usize = 32;
const HIDDEN_SIZE: usize = 768;
const HEAD_SIZE: usize = 64;
const HEAD_COUNT: usize = 12;
const INPUT_ROLE_COUNT: usize = 6;
const BF16_BYTES: usize = 2;
const RAW_OUTPUT_BYTES: usize = HIDDEN_SIZE * BF16_BYTES;
const MATRIX_STATE_VALUE_COUNT: usize = HEAD_COUNT * HEAD_SIZE * HEAD_SIZE;
const MATRIX_STATE_BYTES: usize = MATRIX_STATE_VALUE_COUNT * BF16_BYTES;
const INPUT_BYTES: usize = INPUT_ROLE_COUNT * HIDDEN_SIZE * BF16_BYTES;
const REQUEST_PRE_STATE_OFFSET: usize = REQUEST_HEADER_BYTES + INPUT_BYTES;
const RESPONSE_POST_STATE_OFFSET: usize = RESPONSE_HEADER_BYTES + RAW_OUTPUT_BYTES;
const CALL_TRANSCRIPT_BYTES: usize =
    LENGTH_PREFIX_BYTES + REQUEST_FRAME_BYTES + LENGTH_PREFIX_BYTES + RESPONSE_FRAME_BYTES;
const TRANSCRIPT_BYTES: usize = CALL_COUNT * CALL_TRANSCRIPT_BYTES;
const REQUEST_VALUE_COUNT: usize = (REQUEST_FRAME_BYTES - REQUEST_HEADER_BYTES) / BF16_BYTES;
const RESPONSE_VALUE_COUNT: usize = (RESPONSE_FRAME_BYTES - RESPONSE_HEADER_BYTES) / BF16_BYTES;
const EXPECTED_SCHEMA_VERSION: u32 = 1;
const EXPECTED_ARGUMENT_COUNT: usize = 1;
const EXPECTED_RESPONSE_CONNECTION_COUNT: usize = 1;
const EXPECTED_GENERATED_TOKEN_ID: usize = 2;
const OWNER_HEALTH_STATUS: usize = 200;
const PUEUE_TASK_ID: usize = 25;
const BF16_EXPONENT_MASK: u16 = 0x7f80;
const EXPECTED_PLAN_ID: &str = "7c1d1dbc06ba73e5d54f52f929f80aacac52084ad0610a3cce5da60b325df427";
const EXPECTED_SEQUENCE_HEX: &str =
    "fa4adfb2828a49de825541858d886d7a6a59e2df62e96e25934b040cdf596aea";
const EXPECTED_TRANSCRIPT_BLAKE3: &str =
    "0469e5603660f8a06e2c6d4cc0ac6af48b57a413c02fd243708ad4084940cf47";
const EXPECTED_SESSION_TRANSCRIPT_BLAKE3: &str =
    "52e719c04634b8d306e4d09fd4b249dab40f31ba268b75a607e94645977e5be5";
const REQUEST_MAGIC: &[u8; 8] = b"RKW7REQ1";
const RESPONSE_MAGIC: &[u8; 8] = b"RKW7RSP1";

const EXPECTED_REQUEST_BLAKE3: [&str; CALL_COUNT] = [
    "90189e44d52b7835eae5bff0d8a993859b1fc04282b58880a4b9b322a740d247",
    "8b4467e1248f05dad89ab28330340e26ad9bef97013b3660b92075b188c41da2",
    "60b9024e6514b1dfd372f3a7b450d8a87bc0d6ec3a9758104ff2be84397e5d7e",
    "b97c5e71b319ecb5caa7441d91ef99fbd60ef178dda82222cc9bc1beb5d94613",
    "e05ca0e0622eac0fffd8bb86435771924cdaa24e46ced66d522701339d055d84",
    "343f55a5324de9a6efedf732d84d5ac0c35027d4fe48dffda3ae95502e097b93",
    "a89c2cbd6e524c857c08c62054ff65e2cef39b35bb036f477a947dee167e2017",
    "52fe16370218122076e6213532331a3a5246f6c723e527477fa7d3a98eef933d",
    "23d7ac62e7d13acd70a14e6d09d9d4e30d8649d4d83ced8efd5a4b3bc28956da",
    "986452ae4179cc1620d78b893c5a58f54e3cfffbf694b39318168aea92bc376b",
    "8de0e4d8e6861ce97d62875ae2f936dd297e16de2529508ad7fb13d2e6812690",
    "306c7a8bd889f4892cfba324ef444563f35c8bb3508e883602096aa5753e58ac",
    "4a3ddc456def86d16c259fd86d10b75a7673db436d5b938811ac111732e46a91",
    "21a8c5d3dc2f484f52fb44258651e219b8d3079f5cca03993442a2415697d8c2",
    "03893b47acb1794d7d8fcf1f582c239c63bfe57e76713074af7e0ef8cd6d5dde",
    "33e926989e592a9cb124f7038afca38d3e85aed5c128db51ab6a36154f8b81ce",
    "b75f8fa2f277b34a6c9892b4b6513dbc2bb514fae68fac1c04e1cd117dc8c443",
    "020fd11c332b655a813a53b27ed8a0fa8d1ee080c5364c539a7d9fc838e80429",
    "ae90c6ee6a8d483f01ea142f98e4e90d07bd5749129a5c77039fa76fa2918768",
    "ed0d590548436142406836452d80733e00e4bb5e700ebe5d5564a570cb3c9739",
    "e58892bb23060e8a44b63afe4a799d1989e40ddb8689dbe68d7fca4a58c5bb36",
    "6ed87fd72154fb773ef7a166c36f55ef1dff874b6285083932b63afebff6c27b",
    "6c245a8214c151f082bd4f94a9d68c28ed108e93f1ec528431c66de7d6faea70",
    "a2d38787cace4d69319c9d41e63971d497285e7190ed1dd8c4bc0cfc6980b203",
];

const EXPECTED_RESPONSE_BLAKE3: [&str; CALL_COUNT] = [
    "9e8c5f7f6864fe1c6ea26ed534d20a849551e853f6af84a4df6f9ab5461d7ecc",
    "779e1cc4d632ba4637c56f7853776aaf36c8a268d7636b2b17d48ef542314413",
    "374be611c6a588888960e2f22e74dfd80b6c92ca026700534a00ae9e2aaa0027",
    "9d95df012c7c5cb713f09285f2f402a87aaf390c4fcb401e8fc7dac63f531c99",
    "972fad1b0e00fdfe47027bd06a18d2dd723c55fa527531f98a39310feb935bb0",
    "0ba1c2fdb2fe32fb7e7e850a437c5923a38a6d9c0dd4d88f87073a8eb7edde35",
    "d34fdafa1afb092cf0f2ee747fe18abf2af9c32a6f939836aa2b469cc6c5c70c",
    "1cc07d9f9840d81b96df7a4d506d8a3466bdc8c600994a8f03524bcd5eda8fe3",
    "559e402f6b22e2289a112c506dbf0a273611c6e5511e66735602712344e729c1",
    "dc5ff13d7aaa6a353ffae17536934ae2963c8199677d46feea6d742563013402",
    "28ec91d513acf3712d530bd6a39f3b759de70bd623b293d2e5cfbcc91f18a172",
    "0169cbce1a5103cfe2654e8a7b3cfb423d6341c9968348d374dce7016bca406c",
    "43cc683001b113fb7d84db2d44cbe8bc30bacdb43e63732893ac9a873d3981dd",
    "d97907e61bb704bb1837e6d83ffa14320f70c05b02ad5688dc94e6cdda060742",
    "c814ef1543aa47ec95b4bfd5a5d1ed9b325e9bde648fccfc1b795a3500b6d1ef",
    "4f0e785a87df1ddc2363c5a22ec9929a2db4c299c24e9d5eb774eadf647e267c",
    "1fc434c1fe138c2414dc9ab9f504425c72cdc5c01e25488f3aab9957bcd5affb",
    "2dcc47bb4e242667e9e183a1aafcafe99de162c25dc5fb299479d6a924e45b2b",
    "83f8141d98aa3aa735e9d2d4a97a0ac6a808f9a435a3032c960c0b265e78f41b",
    "fdc8f8829a8389b7b3f7b6409d90e1b33ad53d0d36c9cfb3929dfcedb9622b0e",
    "9ef60d1aa79e79c253aaf80b9515b3646addccc836a0b900446355cbc92e98cc",
    "138c84027fbf39d09234eb35489bad518f4bf48d26f4908e7d0a2330a2fb53ce",
    "493fcc904d57be518e176e48c5a469f9aa3fa3a2a0aa7173c4d825e30caf45ff",
    "652bbfb7bb94fce988b85cdf3c9e4fef40161d7efedf79fba24efe581d52abf5",
];

#[derive(Debug, Eq, PartialEq)]
struct TranscriptSummary {
    request_count: usize,
    response_count: usize,
    continuity_count: usize,
    finite_request_values: usize,
    finite_response_values: usize,
}

struct Evidence<'a> {
    classification: &'a str,
    session: &'a str,
    process: &'a str,
    diagnostic: &'a str,
    completeness_status: &'a str,
    orchestration_incoming: &'a str,
    orchestration_final: &'a str,
    postprocess: &'a str,
    pueue_task: &'a str,
    pueue_log: &'a str,
    owner_after: &'a str,
    health_after: &'a str,
    rollback_after: &'a str,
    board_first: &'a str,
    board_second: &'a str,
    host_receipt: &'a str,
    core_receipt: &'a str,
    server_summary: &'a str,
    artifact_manifest: &'a str,
    mesh_devices: &'a str,
    mesh_workloads: &'a str,
    kernels: &'a str,
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

fn decode_hex_32(source: &str) -> Result<[u8; REQUEST_ID_BYTES], String> {
    const HEX_CHARS_PER_BYTE: usize = 2;
    const EXPECTED_HEX_CHARS: usize = REQUEST_ID_BYTES * HEX_CHARS_PER_BYTE;
    if source.len() != EXPECTED_HEX_CHARS {
        return Err("reviewed BLAKE3 identity width drifted".to_owned());
    }
    let mut result = [0_u8; REQUEST_ID_BYTES];
    for (index, destination) in result.iter_mut().enumerate() {
        let start = index * HEX_CHARS_PER_BYTE;
        let end = start + HEX_CHARS_PER_BYTE;
        *destination = u8::from_str_radix(&source[start..end], 16)
            .map_err(|error| format!("reviewed BLAKE3 identity is not hexadecimal: {error}"))?;
    }
    Ok(result)
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

fn require_contains(source: &str, needle: &str, name: &str) -> Result<(), String> {
    if !source.contains(needle) {
        return Err(format!("{name} is missing {needle:?}"));
    }
    Ok(())
}

fn finite_bf16_count(bytes: &[u8], name: &str) -> Result<usize, String> {
    if !bytes.len().is_multiple_of(BF16_BYTES) {
        return Err(format!("{name} ends with a partial BF16 value"));
    }
    let mut count = 0;
    for pair in bytes.chunks_exact(BF16_BYTES) {
        let bits = u16::from_le_bytes([pair[0], pair[1]]);
        if bits & BF16_EXPONENT_MASK == BF16_EXPONENT_MASK {
            return Err(format!("{name} contains a non-finite BF16 value"));
        }
        count += 1;
    }
    Ok(count)
}

fn validate_frame_authority(
    request: &[u8],
    response: &[u8],
    call: usize,
    sequence: &[u8; REQUEST_ID_BYTES],
) -> Result<(usize, usize), String> {
    const VERSION_OFFSET: usize = 8;
    const SEQUENCE_OFFSET: usize = 12;
    const CALL_OFFSET: usize = 44;
    const TOKEN_OFFSET: usize = 48;
    const LAYER_OFFSET: usize = 52;
    const HEAD_COUNT_OFFSET: usize = 56;
    const HEAD_SIZE_OFFSET: usize = 60;
    const HIDDEN_SIZE_OFFSET: usize = 64;

    if !request.starts_with(REQUEST_MAGIC) || !response.starts_with(RESPONSE_MAGIC) {
        return Err(format!("call {call} frame magic drifted"));
    }
    if read_u32(request, VERSION_OFFSET, "request schema")? != EXPECTED_SCHEMA_VERSION
        || read_u32(response, VERSION_OFFSET, "response schema")? != EXPECTED_SCHEMA_VERSION
    {
        return Err(format!("call {call} schema drifted"));
    }
    let sequence_end = SEQUENCE_OFFSET + sequence.len();
    if request.get(SEQUENCE_OFFSET..sequence_end) != Some(sequence)
        || response.get(SEQUENCE_OFFSET..sequence_end) != Some(sequence)
    {
        return Err(format!("call {call} sequence authority drifted"));
    }
    let token = FIRST_TOKEN_INDEX + call / LAYER_COUNT;
    let layer = call % LAYER_COUNT;
    for (offset, expected, name) in [
        (CALL_OFFSET, call, "call"),
        (TOKEN_OFFSET, token, "token"),
        (LAYER_OFFSET, layer, "layer"),
        (HEAD_COUNT_OFFSET, HEAD_COUNT, "head count"),
        (HEAD_SIZE_OFFSET, HEAD_SIZE, "head size"),
        (HIDDEN_SIZE_OFFSET, HIDDEN_SIZE, "hidden size"),
    ] {
        let expected = u32::try_from(expected).map_err(|_| format!("{name} does not fit u32"))?;
        if read_u32(request, offset, name)? != expected
            || read_u32(response, offset, name)? != expected
        {
            return Err(format!("call {call} {name} authority drifted"));
        }
    }
    let request_identity_end = RESPONSE_REQUEST_ID_OFFSET + REQUEST_ID_BYTES;
    let expected_request_identity = decode_hex_32(EXPECTED_REQUEST_BLAKE3[call])?;
    if response.get(RESPONSE_REQUEST_ID_OFFSET..request_identity_end)
        != Some(expected_request_identity.as_slice())
    {
        return Err(format!("call {call} response request identity drifted"));
    }
    let finite_request_values = finite_bf16_count(
        &request[REQUEST_HEADER_BYTES..],
        &format!("call {call} request payload"),
    )?;
    let finite_response_values = finite_bf16_count(
        &response[RESPONSE_HEADER_BYTES..],
        &format!("call {call} response payload"),
    )?;
    if finite_request_values != REQUEST_VALUE_COUNT
        || finite_response_values != RESPONSE_VALUE_COUNT
    {
        return Err(format!("call {call} finite value count drifted"));
    }
    Ok((finite_request_values, finite_response_values))
}

fn analyze_transcript(transcript: &[u8]) -> Result<TranscriptSummary, String> {
    if transcript.len() != TRANSCRIPT_BYTES {
        return Err(format!(
            "transcript has {} bytes, expected {TRANSCRIPT_BYTES}",
            transcript.len()
        ));
    }
    if REQUEST_PRE_STATE_OFFSET + MATRIX_STATE_BYTES != REQUEST_FRAME_BYTES
        || RESPONSE_POST_STATE_OFFSET + MATRIX_STATE_BYTES != RESPONSE_FRAME_BYTES
    {
        return Err("reviewed frame shape arithmetic drifted".to_owned());
    }
    let sequence = decode_hex_32(EXPECTED_SEQUENCE_HEX)?;
    let mut requests = Vec::with_capacity(CALL_COUNT);
    let mut responses = Vec::with_capacity(CALL_COUNT);
    let mut finite_request_values = 0;
    let mut finite_response_values = 0;
    let mut offset = 0;
    for call in 0..CALL_COUNT {
        if read_u64(transcript, offset, "request length")? != REQUEST_FRAME_BYTES as u64 {
            return Err(format!("call {call} request length drifted"));
        }
        let request_start = offset + LENGTH_PREFIX_BYTES;
        let request_end = request_start + REQUEST_FRAME_BYTES;
        let response_length_offset = request_end;
        if read_u64(transcript, response_length_offset, "response length")?
            != RESPONSE_FRAME_BYTES as u64
        {
            return Err(format!("call {call} response length drifted"));
        }
        let response_start = response_length_offset + LENGTH_PREFIX_BYTES;
        let response_end = response_start + RESPONSE_FRAME_BYTES;
        let request = transcript
            .get(request_start..request_end)
            .ok_or_else(|| format!("call {call} request is truncated"))?;
        let response = transcript
            .get(response_start..response_end)
            .ok_or_else(|| format!("call {call} response is truncated"))?;
        let (request_values, response_values) =
            validate_frame_authority(request, response, call, &sequence)?;
        finite_request_values += request_values;
        finite_response_values += response_values;
        requests.push(request);
        responses.push(response);
        offset = response_end;
    }
    if offset != transcript.len() {
        return Err("transcript has trailing bytes".to_owned());
    }
    if requests.iter().copied().collect::<BTreeSet<_>>().len() != CALL_COUNT
        || responses.iter().copied().collect::<BTreeSet<_>>().len() != CALL_COUNT
    {
        return Err("transcript contains duplicate request or response frames".to_owned());
    }
    let mut continuity_count = 0;
    for layer in 0..LAYER_COUNT {
        let prior_state = &responses[layer]
            [RESPONSE_POST_STATE_OFFSET..RESPONSE_POST_STATE_OFFSET + MATRIX_STATE_BYTES];
        let next_state = &requests[LAYER_COUNT + layer]
            [REQUEST_PRE_STATE_OFFSET..REQUEST_PRE_STATE_OFFSET + MATRIX_STATE_BYTES];
        if prior_state != next_state {
            return Err(format!("layer {layer} retained-state continuity drifted"));
        }
        continuity_count += 1;
    }
    if continuity_count != CONTINUITY_COUNT {
        return Err("retained-state continuity count drifted".to_owned());
    }
    Ok(TranscriptSummary {
        request_count: requests.len(),
        response_count: responses.len(),
        continuity_count,
        finite_request_values,
        finite_response_values,
    })
}

fn validate_hash_authorities(evidence: &Evidence<'_>) -> Result<(), String> {
    for (index, request) in EXPECTED_REQUEST_BLAKE3.iter().enumerate() {
        require_count(
            evidence.host_receipt,
            request,
            2,
            "host receipt request hashes",
        )?;
        require_count(
            evidence.core_receipt,
            request,
            2,
            "core receipt request hashes",
        )?;
        require_count(evidence.server_summary, request, 1, "server request hashes")?;
        let response = EXPECTED_RESPONSE_BLAKE3[index];
        require_count(
            evidence.host_receipt,
            response,
            2,
            "host receipt response hashes",
        )?;
        require_count(
            evidence.core_receipt,
            response,
            2,
            "core receipt response hashes",
        )?;
        require_count(
            evidence.server_summary,
            response,
            1,
            "server response hashes",
        )?;
    }
    require_contains(
        evidence.host_receipt,
        EXPECTED_SESSION_TRANSCRIPT_BLAKE3,
        "host receipt transcript authority",
    )?;
    require_contains(
        evidence.core_receipt,
        EXPECTED_SESSION_TRANSCRIPT_BLAKE3,
        "core receipt transcript authority",
    )?;
    require_contains(
        evidence.server_summary,
        EXPECTED_SESSION_TRANSCRIPT_BLAKE3,
        "server transcript authority",
    )?;
    require_contains(
        evidence.artifact_manifest,
        EXPECTED_TRANSCRIPT_BLAKE3,
        "artifact transcript authority",
    )?;
    Ok(())
}

fn validate_evidence(evidence: &Evidence<'_>) -> Result<(), String> {
    for marker in [
        &format!("\"plan_id\": \"{EXPECTED_PLAN_ID}\""),
        "\"outcome\": \"passed\"",
        "\"process_budget_exhausted\": true",
        "\"missing_artifact_roles\": []",
        "\"missing_success_markers\": []",
        "\"safety_issues\": []",
        "twenty-four canonical production DecodeL ttWKV7 calls",
        "twelve exact physical state-continuity edges",
    ] {
        require_contains(evidence.classification, marker, "classification")?;
    }
    for marker in [
        "\"wrapper_invocation_count\": 1",
        "\"metalium_child_process_budget\": 1",
        "\"response_connection_budget\": 1",
        "\"physical_call_budget\": 24",
        "\"exit_status\": 0",
        "\"timed_out\": false",
        "\"retry_count\": 0",
        "\"reconnect_count\": 0",
    ] {
        require_contains(evidence.process, marker, "process receipt")?;
    }
    for marker in [
        "\"process_attempts\": 1",
        "\"owner_isolation_attempts\": 1",
        "\"restoration_attempts\": 1",
        "\"process\": {\"exit_status\":0,\"timed_out\":false}",
        "\"owner_active_after\": true",
        "\"owner_health_status_after\": 200",
        "\"board_healthy_after\": true",
    ] {
        require_contains(evidence.session, marker, "session evidence")?;
    }
    if evidence.diagnostic != "rwkv persistent physical ttWKV7 dispatch: PASS\n" {
        return Err("diagnostic success marker drifted".to_owned());
    }
    if evidence.completeness_status != "1\n"
        || evidence.orchestration_incoming != "1\n"
        || evidence.orchestration_final != "1\n"
    {
        return Err("post-process failure status drifted".to_owned());
    }
    for marker in [
        "\"classification_outcome\": \"passed\"",
        "\"physical_process_exit_status\": 0",
        "\"artifact_validator_exit_status\": 1",
        "\"orchestration_exit_status\": 1",
        "\"first_failing_runbook_line\": 286",
        "\"stale_expected_field\": \"session_call_count\"",
        "\"accepted_replacement_path\": \"core.session.call_count\"",
        "\"rerun_authorized\": false",
    ] {
        require_contains(evidence.postprocess, marker, "post-process diagnostic")?;
    }
    require_contains(evidence.pueue_task, "\"pueue_task_id\": 25", "pueue task")?;
    require_contains(evidence.pueue_task, "\"task_exit_status\": 1", "pueue task")?;
    require_contains(evidence.pueue_task, "\"status\": \"failed\"", "pueue task")?;
    require_contains(
        evidence.pueue_log,
        "Task 25:    failed with exit code 1",
        "pueue log",
    )?;
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
    for state in ["ActiveState=inactive", "SubState=dead", "Result=success"] {
        require_contains(evidence.rollback_after, state, "rollback state")?;
    }
    for board in [evidence.board_first, evidence.board_second] {
        require_count(board, "\"DDR_STATUS\": \"0x5555\"", 2, "board health")?;
        require_count(board, "\"GDDR_UNCORR_ERRS\": \"0x0\"", 2, "board health")?;
        require_count(board, "\"THERM_TRIP_COUNT\": \"0x0\"", 2, "board health")?;
    }
    require_contains(
        evidence.board_first,
        "\"TIMER_HEARTBEAT\": \"0x13e9d2\"",
        "first board sample",
    )?;
    require_contains(
        evidence.board_second,
        "\"TIMER_HEARTBEAT\": \"0x13e9e9\"",
        "second board sample",
    )?;
    for marker in [
        "\"host_process_count\": 1",
        "\"metalium_child_process_count\": 1",
        "\"device_open_count\": 1",
        "\"workload_enqueue_count\": 24",
        "\"physical_wkv_call_count\": 24",
        "\"response_channel\": \"unix_stream\"",
        "\"response_connection_count\": 1",
        "\"same_layer_state_continuity_count\": 12",
        "\"child_exit_status\": 0",
        "\"selected_fourth_token_id\": 2",
        "\"nmse_ceiling\": 0.06",
        "\"success_marker\": \"rwkv persistent physical ttWKV7 dispatch: PASS\"",
    ] {
        require_contains(evidence.host_receipt, marker, "host receipt")?;
    }
    require_count(
        evidence.host_receipt,
        "\"call_ordinal\":",
        CALL_COUNT,
        "host calls",
    )?;
    require_count(
        evidence.host_receipt,
        "\"passed\": true",
        CALL_COUNT * 2,
        "host comparisons",
    )?;
    require_count(
        evidence.host_receipt,
        "\"ranking\":",
        TOKEN_COUNT * 2,
        "host rankings",
    )?;
    require_count(
        evidence.host_receipt,
        "\"generated_token_id\": 2",
        TOKEN_COUNT * 2,
        "host generated tokens",
    )?;
    require_count(
        evidence.host_receipt,
        "\"runner_up_token_id\": 33",
        TOKEN_COUNT * 2,
        "host runner-up tokens",
    )?;
    require_count(
        evidence.host_receipt,
        "\"direct_bf16_head_deviation\": 0.0",
        TOKEN_COUNT * 2,
        "host head comparisons",
    )?;
    require_count(
        evidence.host_receipt,
        "\"nmse\":",
        CALL_COUNT * 2,
        "host NMSE comparisons",
    )?;
    require_count(
        evidence.host_receipt,
        "\"ceiling\": 0.06",
        CALL_COUNT * 2,
        "host NMSE ceilings",
    )?;
    for marker in [
        "\"physical_wkv_call_count\": 24",
        "\"selected_fourth_token_id\": 2",
        "\"call_count\": 24",
        "\"same_layer_state_continuity_count\": 12",
        "\"terminal_state\": \"closed\"",
    ] {
        require_contains(evidence.core_receipt, marker, "core receipt")?;
    }
    for marker in [
        "\"call_count\":24",
        "\"device_open_count\":1",
        "\"response_channel\":\"unix_stream\"",
        "\"response_connection_count\":1",
        "\"same_layer_state_continuity_count\":12",
        "\"terminal_state\":\"closed\"",
        "\"workload_enqueue_count\":24",
    ] {
        require_contains(evidence.server_summary, marker, "server summary")?;
    }
    require_count(
        evidence.artifact_manifest,
        "\n",
        7,
        "artifact manifest lines",
    )?;
    require_count(
        evidence.mesh_devices,
        "mesh_device_initialized:",
        1,
        "mesh device inspector",
    )?;
    for marker in [
        ("mesh_workload_created:", CALL_COUNT),
        ("status: InFlight", CALL_COUNT),
        ("status: Committed", CALL_COUNT),
        ("mesh_workload_destroyed:", CALL_COUNT),
    ] {
        require_count(
            evidence.mesh_workloads,
            marker.0,
            marker.1,
            "mesh workload inspector",
        )?;
    }
    for kernel in ["wkv7_decodeL_reader", "wkv7_decodeL_compute", "wkv7_writer"] {
        require_count(
            evidence.kernels,
            &format!("name: {kernel}"),
            CALL_COUNT,
            "kernel inspector",
        )?;
    }
    validate_hash_authorities(evidence)?;
    Ok(())
}

fn read_text(root: &Path, relative: &str) -> Result<String, String> {
    fs::read_to_string(root.join(relative)).map_err(|error| format!("{relative}: {error}"))
}

fn run() -> Result<(), String> {
    let arguments: Vec<String> = env::args().skip(1).collect();
    if arguments.len() != EXPECTED_ARGUMENT_COUNT {
        return Err("usage: rwkv_persistent_passed_evidence FIXTURE_ROOT".to_owned());
    }
    let root = Path::new(&arguments[0]);
    let transcript = fs::read(root.join("artifact/transcript.bin"))
        .map_err(|error| format!("artifact/transcript.bin: {error}"))?;
    let classification = read_text(root, "classification-receipt.json")?;
    let session = read_text(root, "session-evidence.json")?;
    let process = read_text(root, "process-receipt.json")?;
    let diagnostic = read_text(root, "diagnostic.log")?;
    let completeness_status = read_text(root, "evidence-completeness-status.txt")?;
    let orchestration_incoming = read_text(root, "orchestration-incoming-status.txt")?;
    let orchestration_final = read_text(root, "orchestration-final-status.txt")?;
    let postprocess = read_text(root, "postprocess-diagnostic.json")?;
    let pueue_task = read_text(root, "pueue-task.json")?;
    let pueue_log = read_text(root, "pueue-task.log")?;
    let owner_after = read_text(root, "owner-after.properties")?;
    let health_after = read_text(root, "health-after.status")?;
    let rollback_after = read_text(root, "rollback-after.properties")?;
    let board_first = read_text(root, "board-after-first.txt")?;
    let board_second = read_text(root, "board-after-second.txt")?;
    let host_receipt = read_text(root, "artifact/receipt.json")?;
    let core_receipt = read_text(root, "artifact/core-receipt.json")?;
    let server_summary = read_text(root, "artifact/server-summary.json")?;
    let artifact_manifest = read_text(root, "artifact/manifest.tsv")?;
    let mesh_devices = read_text(root, "inspector/mesh_devices_log.yaml")?;
    let mesh_workloads = read_text(root, "inspector/mesh_workloads_log.yaml")?;
    let kernels = read_text(root, "inspector/kernels.yaml")?;
    validate_evidence(&Evidence {
        classification: &classification,
        session: &session,
        process: &process,
        diagnostic: &diagnostic,
        completeness_status: &completeness_status,
        orchestration_incoming: &orchestration_incoming,
        orchestration_final: &orchestration_final,
        postprocess: &postprocess,
        pueue_task: &pueue_task,
        pueue_log: &pueue_log,
        owner_after: &owner_after,
        health_after: &health_after,
        rollback_after: &rollback_after,
        board_first: &board_first,
        board_second: &board_second,
        host_receipt: &host_receipt,
        core_receipt: &core_receipt,
        server_summary: &server_summary,
        artifact_manifest: &artifact_manifest,
        mesh_devices: &mesh_devices,
        mesh_workloads: &mesh_workloads,
        kernels: &kernels,
    })?;
    let summary = analyze_transcript(&transcript)?;
    println!("{{");
    println!(
        "  \"accepted_physical_response_count\": {},",
        summary.response_count
    );
    println!("  \"artifact_validator_exit_status\": 1,");
    println!("  \"classification\": \"passed\",");
    println!("  \"device_open_count\": 1,");
    println!(
        "  \"finite_request_bf16_values\": {},",
        summary.finite_request_values
    );
    println!(
        "  \"finite_response_bf16_values\": {},",
        summary.finite_response_values
    );
    println!("  \"orchestration_exit_status\": 1,");
    println!("  \"owner_health_status_after\": {OWNER_HEALTH_STATUS},");
    println!("  \"owner_restored\": true,");
    println!("  \"physical_process_exit_status\": 0,");
    println!("  \"physical_workload_commit_count\": {CALL_COUNT},");
    println!("  \"physical_wkv_call_count\": {},", summary.request_count);
    println!("  \"pueue_task_id\": {PUEUE_TASK_ID},");
    println!("  \"response_channel\": \"unix_stream\",");
    println!("  \"response_connection_count\": {EXPECTED_RESPONSE_CONNECTION_COUNT},");
    println!("  \"retry_count\": 0,");
    println!(
        "  \"same_layer_state_continuity_count\": {},",
        summary.continuity_count
    );
    println!("  \"schema_version\": 1,");
    println!("  \"selected_fourth_token_id\": {EXPECTED_GENERATED_TOKEN_ID},");
    println!("  \"target\": \"rwkv_ttwkv7_persistent_passed_evidence\",");
    println!("  \"transcript_bytes\": {TRANSCRIPT_BYTES}");
    println!("}}");
    Ok(())
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("rwkv persistent passed evidence: {error}");
            ExitCode::FAILURE
        }
    }
}
