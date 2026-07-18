use rwkv_layer_harness::{
    Ttwkv7ObservedLayerEvidence, Ttwkv7PersistentPhysicalCoreReceipt,
    begin_ttwkv7_persistent_physical_model_driver,
};
use serde::Serialize;
use serde_json::Value;
use std::error::Error;
use std::fs::{self, File, OpenOptions};
use std::io::{self, Read, Write};
use std::path::{Path, PathBuf};
use std::process::{Child, Command, ExitCode, Stdio};

const MODEL_PATH: Option<&str> = option_env!("RWKV_LAYER_MODEL");
const EXPECTED_BLAKE3: Option<&str> = option_env!("RWKV_LAYER_MODEL_BLAKE3");
const EXPECTED_ARGUMENT_COUNT: usize = 7;
const SERVER_OPTION: &str = "--server";
const TEST_SERVER_OPTION: &str = "--test-server";
const EVIDENCE_ROOT_OPTION: &str = "--evidence-root";
const ARTIFACT_ROOT_OPTION: &str = "--artifact-root";
const SERVER_MODE: &str = "dispatch-server";
const SERVER_SUMMARY_ENVIRONMENT: &str = "RWKV_TTWKV7_DISPATCH_SERVER_SUMMARY";
const REQUEST_FRAME_BYTE_COUNT: usize = 107588;
const RESPONSE_FRAME_BYTE_COUNT: usize = 99940;
const DISPATCH_CALL_COUNT: usize = 24;
const SAME_LAYER_CONTINUITY_COUNT: usize = 12;
const LENGTH_PREFIX_WIDTH: usize = 8;
const SCHEMA_VERSION: u32 = 1;
const HISTORICAL_PHYSICAL_WKV_CALL_COUNT: usize = 1;
const CORE_RECEIPT_FILENAME: &str = "core-receipt.json";
const SERVER_SUMMARY_FILENAME: &str = "server-summary.json";
const TRANSCRIPT_FILENAME: &str = "transcript.bin";
const CHILD_STDERR_FILENAME: &str = "server-stderr.log";
const HOST_RECEIPT_FILENAME: &str = "receipt.json";
const MANIFEST_FILENAME: &str = "manifest.tsv";
const SUCCESS_MARKER: &str = "rwkv persistent physical ttWKV7 dispatch: PASS";
const SELF_TEST_MARKER: &str = "rwkv persistent dispatch process shell self-test: PASS";
const SELF_TEST_RECEIPT_FILENAME: &str = "self-test.json";
const CLASSIFICATION_FILENAME: &str = "classification-receipt.json";
const SESSION_EVIDENCE_FILENAME: &str = "session-evidence.json";
const DIAGNOSTIC_FILENAME: &str = "diagnostic.log";
const BOARD_AFTER_FILENAME: &str = "board-after-second.json";
const OWNER_AFTER_FILENAME: &str = "owner-after.properties";
const BOUNDARY_MANIFEST_FILENAME: &str = "boundary-manifest.tsv";
const PREPARED_FILENAME: &str = "prepared.json";
const BOUNDARY_RECEIPT_FILENAME: &str = "boundary-receipt.json";
const WRITER_RAW_FILENAME: &str = "writer-raw.bf16";
const OBSERVED_OUTPUT_FILENAME: &str = "observed-output.bf16";
const OBSERVED_POST_STATE_FILENAME: &str = "observed-post-state.bf16";
const SESSION_MANIFEST_FILENAME: &str = "session-manifest.json";
const PLAN_RECEIPT_FILENAME: &str = "plan-receipt.json";

#[derive(Serialize)]
struct ArtifactReceipt {
    role: &'static str,
    filename: &'static str,
    byte_count: usize,
    blake3: String,
}

#[derive(Serialize)]
struct PersistentPhysicalHostReceipt {
    schema_version: u32,
    target: &'static str,
    server_path: String,
    server_blake3: String,
    host_process_count: usize,
    metalium_child_process_count: usize,
    device_open_count: usize,
    workload_enqueue_count: usize,
    physical_wkv_call_count: usize,
    historical_physical_wkv_call_count: usize,
    total_physical_wkv_call_count: usize,
    request_frame_byte_count: usize,
    response_frame_byte_count: usize,
    same_layer_state_continuity_count: usize,
    child_exit_status: i32,
    core: Ttwkv7PersistentPhysicalCoreReceipt,
    artifacts: Vec<ArtifactReceipt>,
    retry_count: usize,
    reconnect_count: usize,
    terminal_state: &'static str,
    success_marker: &'static str,
    non_claims: [&'static str; 7],
}

struct ChildGuard {
    child: Child,
    reaped: bool,
}

impl ChildGuard {
    fn new(child: Child) -> Self {
        Self {
            child,
            reaped: false,
        }
    }

    fn wait(&mut self) -> io::Result<std::process::ExitStatus> {
        let status = self.child.wait()?;
        self.reaped = true;
        Ok(status)
    }
}

impl Drop for ChildGuard {
    fn drop(&mut self) {
        if !self.reaped {
            let _ = self.child.kill();
            let _ = self.child.wait();
            self.reaped = true;
        }
    }
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("rwkv-ttwkv7-persistent-physical-dispatch: {error}");
            ExitCode::FAILURE
        }
    }
}

fn run() -> Result<(), Box<dyn Error>> {
    let arguments = std::env::args().collect::<Vec<_>>();
    if arguments.len() != EXPECTED_ARGUMENT_COUNT
        || (arguments[1] != SERVER_OPTION && arguments[1] != TEST_SERVER_OPTION)
        || arguments[3] != EVIDENCE_ROOT_OPTION
        || arguments[5] != ARTIFACT_ROOT_OPTION
    {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "usage: rwkv-ttwkv7-persistent-physical-dispatch --server PATH --evidence-root PATH --artifact-root PATH",
        )
        .into());
    }
    let test_server = arguments[1] == TEST_SERVER_OPTION;
    let configured_model = MODEL_PATH.ok_or_else(|| {
        io::Error::new(
            io::ErrorKind::NotFound,
            "RWKV_LAYER_MODEL was not embedded at build time",
        )
    })?;
    let expected_blake3 = EXPECTED_BLAKE3.ok_or_else(|| {
        io::Error::new(
            io::ErrorKind::NotFound,
            "RWKV_LAYER_MODEL_BLAKE3 was not embedded at build time",
        )
    })?;
    let model_path = require_store_file(Path::new(configured_model), "checkpoint")?;
    let server_path = require_store_file(Path::new(&arguments[2]), "dispatch server")?;
    let evidence_root = require_directory(Path::new(&arguments[4]), "evidence root")?;
    let artifact_root = require_new_output_directory(Path::new(&arguments[6]))?;
    let checkpoint = read_file(&model_path)?;
    let evidence_files = read_evidence(&evidence_root)?;
    let evidence = evidence_files.as_evidence();
    let mut driver =
        begin_ttwkv7_persistent_physical_model_driver(&checkpoint, expected_blake3, &evidence)
            .map_err(invalid_data)?;

    fs::create_dir(&artifact_root)?;
    let summary_path = artifact_root.join(SERVER_SUMMARY_FILENAME);
    let child_stderr_path = artifact_root.join(CHILD_STDERR_FILENAME);
    let child_stderr = create_new_file(&child_stderr_path)?;
    let child = Command::new(&server_path)
        .arg(SERVER_MODE)
        .env(SERVER_SUMMARY_ENVIRONMENT, &summary_path)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::from(child_stderr))
        .spawn()?;
    let mut child = ChildGuard::new(child);
    let mut child_stdin = child
        .child
        .stdin
        .take()
        .ok_or_else(|| io::Error::other("dispatch child stdin is unavailable"))?;
    let mut child_stdout = child
        .child
        .stdout
        .take()
        .ok_or_else(|| io::Error::other("dispatch child stdout is unavailable"))?;
    let transcript_path = artifact_root.join(TRANSCRIPT_FILENAME);
    let mut transcript = create_new_file(&transcript_path)?;

    for expected_call in 0..DISPATCH_CALL_COUNT {
        let request = driver.prepare_next_request().map_err(invalid_data)?;
        if request.call_ordinal != expected_call || request.frame.len() != REQUEST_FRAME_BYTE_COUNT
        {
            return Err(invalid_data(format!(
                "dispatch request contract mismatch at call {expected_call}: ordinal={} bytes={}",
                request.call_ordinal,
                request.frame.len()
            ))
            .into());
        }
        write_framed(&mut transcript, &request.frame)?;
        child_stdin.write_all(&request.frame)?;
        child_stdin.flush()?;
        let mut response = vec![0_u8; RESPONSE_FRAME_BYTE_COUNT];
        child_stdout.read_exact(&mut response)?;
        write_framed(&mut transcript, &response)?;
        let progress = driver.accept_response(&response).map_err(invalid_data)?;
        if progress.accepted_call_count != expected_call + 1 {
            return Err(invalid_data("dispatch progress count changed".to_owned()).into());
        }
    }
    drop(child_stdin);
    let status = child.wait()?;
    let child_exit_status = status
        .code()
        .ok_or_else(|| io::Error::other("dispatch child terminated without an exit status"))?;
    if !status.success() {
        return Err(io::Error::other(format!(
            "dispatch child exited with status {child_exit_status}"
        ))
        .into());
    }
    transcript.flush()?;
    transcript.sync_all()?;
    drop(transcript);

    let core = driver.finish().map_err(invalid_data)?;
    let summary_bytes = read_regular_file(&summary_path, "server summary")?;
    let summary: Value = serde_json::from_slice(&summary_bytes)?;
    validate_server_summary(&summary, &core, test_server)?;
    let core_bytes = pretty_json_bytes(&core)?;
    write_new_file(&artifact_root.join(CORE_RECEIPT_FILENAME), &core_bytes)?;
    if test_server {
        let self_test = serde_json::json!({
            "device_initialized": false,
            "dispatch_call_count": DISPATCH_CALL_COUNT,
            "metalium_child_process_count": 0,
            "process_shell_exercised": true,
            "self_test_passed": true,
            "target": "rwkv_ttwkv7_persistent_dispatch_process_shell_self_test",
        });
        let self_test_bytes = pretty_json_bytes(&self_test)?;
        write_new_file(
            &artifact_root.join(SELF_TEST_RECEIPT_FILENAME),
            &self_test_bytes,
        )?;
        println!("{SELF_TEST_MARKER}");
        return Ok(());
    }

    let server_bytes = read_file(&server_path)?;
    let transcript_bytes = read_regular_file(&transcript_path, "dispatch transcript")?;
    let child_stderr_bytes = read_regular_file(&child_stderr_path, "server stderr")?;
    let artifacts = vec![
        artifact_receipt("core_receipt", CORE_RECEIPT_FILENAME, &core_bytes),
        artifact_receipt("server_summary", SERVER_SUMMARY_FILENAME, &summary_bytes),
        artifact_receipt("transcript", TRANSCRIPT_FILENAME, &transcript_bytes),
        artifact_receipt("server_stderr", CHILD_STDERR_FILENAME, &child_stderr_bytes),
    ];
    let receipt = PersistentPhysicalHostReceipt {
        schema_version: SCHEMA_VERSION,
        target: "rwkv_ttwkv7_persistent_physical_dispatch",
        server_path: server_path.display().to_string(),
        server_blake3: blake3::hash(&server_bytes).to_hex().to_string(),
        host_process_count: 1,
        metalium_child_process_count: 1,
        device_open_count: 1,
        workload_enqueue_count: DISPATCH_CALL_COUNT,
        physical_wkv_call_count: DISPATCH_CALL_COUNT,
        historical_physical_wkv_call_count: HISTORICAL_PHYSICAL_WKV_CALL_COUNT,
        total_physical_wkv_call_count: HISTORICAL_PHYSICAL_WKV_CALL_COUNT + DISPATCH_CALL_COUNT,
        request_frame_byte_count: REQUEST_FRAME_BYTE_COUNT,
        response_frame_byte_count: RESPONSE_FRAME_BYTE_COUNT,
        same_layer_state_continuity_count: SAME_LAYER_CONTINUITY_COUNT,
        child_exit_status,
        core,
        artifacts,
        retry_count: 0,
        reconnect_count: 0,
        terminal_state: "closed",
        success_marker: SUCCESS_MARKER,
        non_claims: [
            "A tolerance pass does not establish exact BF16 parity.",
            "Only ttWKV7 executes on the device; model composition remains on the CPU host.",
            "No complete RWKV layer or model executes wholly on Tenstorrent devices.",
            "No general P150 compatibility is established.",
            "No serving, throughput, or latency claim is established.",
            "Owner safety is established only by the enclosing runbook classification.",
            "Tasks 30 and 64 remain terminal and are not reused.",
        ],
    };
    let receipt_bytes = pretty_json_bytes(&receipt)?;
    write_new_file(&artifact_root.join(HOST_RECEIPT_FILENAME), &receipt_bytes)?;
    let manifest = artifact_manifest(&artifact_root, &receipt_bytes)?;
    write_new_file(&artifact_root.join(MANIFEST_FILENAME), manifest.as_bytes())?;
    println!("{SUCCESS_MARKER}");
    Ok(())
}

fn write_framed(output: &mut File, frame: &[u8]) -> io::Result<()> {
    let length = u64::try_from(frame.len())
        .map_err(|_| io::Error::other("dispatch frame length does not fit u64"))?;
    let bytes = length.to_le_bytes();
    if bytes.len() != LENGTH_PREFIX_WIDTH {
        return Err(io::Error::other("dispatch length prefix width changed"));
    }
    output.write_all(&bytes)?;
    output.write_all(frame)
}

fn validate_server_summary(
    summary: &Value,
    core: &Ttwkv7PersistentPhysicalCoreReceipt,
    test_server: bool,
) -> Result<(), Box<dyn Error>> {
    let expected_device_open_count = if test_server { 0 } else { 1 };
    let expected_workload_enqueue_count = if test_server {
        0
    } else {
        DISPATCH_CALL_COUNT as u64
    };
    if summary
        .get("test_only_cpu_server")
        .and_then(Value::as_bool)
        .unwrap_or(false)
        != test_server
    {
        return Err(invalid_data("server test authority mismatch".to_owned()).into());
    }
    for (name, expected) in [
        ("schema_version", u64::from(SCHEMA_VERSION)),
        ("call_count", DISPATCH_CALL_COUNT as u64),
        ("device_open_count", expected_device_open_count),
        ("workload_enqueue_count", expected_workload_enqueue_count),
        (
            "same_layer_state_continuity_count",
            SAME_LAYER_CONTINUITY_COUNT as u64,
        ),
        ("request_frame_byte_count", REQUEST_FRAME_BYTE_COUNT as u64),
        (
            "response_frame_byte_count",
            RESPONSE_FRAME_BYTE_COUNT as u64,
        ),
    ] {
        if summary.get(name).and_then(Value::as_u64) != Some(expected) {
            return Err(invalid_data(format!("server summary {name} authority mismatch")).into());
        }
    }
    if summary.get("target").and_then(Value::as_str)
        != Some("rwkv_ttwkv7_persistent_dispatch_server")
        || summary.get("terminal_state").and_then(Value::as_str) != Some("closed")
        || summary.get("transcript_blake3").and_then(Value::as_str)
            != Some(&core.session.transcript_blake3)
    {
        return Err(invalid_data("server summary identity mismatch".to_owned()).into());
    }
    let request_hashes = summary
        .get("ordered_request_blake3")
        .and_then(Value::as_array)
        .ok_or_else(|| invalid_data("server request hashes are absent".to_owned()))?;
    let response_hashes = summary
        .get("ordered_response_blake3")
        .and_then(Value::as_array)
        .ok_or_else(|| invalid_data("server response hashes are absent".to_owned()))?;
    if request_hashes.len() != DISPATCH_CALL_COUNT
        || response_hashes.len() != DISPATCH_CALL_COUNT
        || request_hashes
            .iter()
            .zip(&core.session.ordered_request_blake3)
            .any(|(actual, expected)| actual.as_str() != Some(expected))
        || response_hashes
            .iter()
            .zip(&core.session.ordered_response_blake3)
            .any(|(actual, expected)| actual.as_str() != Some(expected))
    {
        return Err(invalid_data("server frame hash authority mismatch".to_owned()).into());
    }
    Ok(())
}

fn artifact_receipt(role: &'static str, filename: &'static str, bytes: &[u8]) -> ArtifactReceipt {
    ArtifactReceipt {
        role,
        filename,
        byte_count: bytes.len(),
        blake3: blake3::hash(bytes).to_hex().to_string(),
    }
}

fn artifact_manifest(root: &Path, receipt_bytes: &[u8]) -> Result<String, Box<dyn Error>> {
    let mut rows = vec![artifact_receipt(
        "host_receipt",
        HOST_RECEIPT_FILENAME,
        receipt_bytes,
    )];
    for (role, filename) in [
        ("core_receipt", CORE_RECEIPT_FILENAME),
        ("server_summary", SERVER_SUMMARY_FILENAME),
        ("transcript", TRANSCRIPT_FILENAME),
        ("server_stderr", CHILD_STDERR_FILENAME),
    ] {
        let bytes = read_regular_file(&root.join(filename), role)?;
        rows.push(artifact_receipt(role, filename, &bytes));
    }
    let mut manifest = String::from("role\tfilename\tbytes\tblake3\n");
    for row in rows {
        manifest.push_str(&format!(
            "{}\t{}\t{}\t{}\n",
            row.role, row.filename, row.byte_count, row.blake3
        ));
    }
    Ok(manifest)
}

fn pretty_json_bytes<T: Serialize>(value: &T) -> Result<Vec<u8>, Box<dyn Error>> {
    let mut bytes = serde_json::to_vec_pretty(value)?;
    bytes.push(b'\n');
    Ok(bytes)
}

fn require_store_file(path: &Path, name: &str) -> Result<PathBuf, Box<dyn Error>> {
    let canonical = fs::canonicalize(path)?;
    if !canonical.starts_with("/nix/store/") {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            format!(
                "{name} must resolve under /nix/store: {}",
                canonical.display()
            ),
        )
        .into());
    }
    require_regular_file(&canonical, name)?;
    Ok(canonical)
}

fn require_directory(path: &Path, name: &str) -> Result<PathBuf, Box<dyn Error>> {
    let canonical = fs::canonicalize(path)?;
    let metadata = fs::metadata(&canonical)?;
    if !metadata.file_type().is_dir() {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            format!("{name} must be a directory: {}", canonical.display()),
        )
        .into());
    }
    Ok(canonical)
}

fn require_new_output_directory(path: &Path) -> Result<PathBuf, Box<dyn Error>> {
    if !path.is_absolute() || path.starts_with("/nix/store") || path.exists() {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            format!(
                "artifact root must be a new absolute path outside /nix/store: {}",
                path.display()
            ),
        )
        .into());
    }
    let parent = path.parent().ok_or_else(|| {
        io::Error::new(io::ErrorKind::InvalidInput, "artifact root has no parent")
    })?;
    let canonical_parent = fs::canonicalize(parent)?;
    let filename = path
        .file_name()
        .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "artifact root has no name"))?;
    Ok(canonical_parent.join(filename))
}

fn create_new_file(path: &Path) -> io::Result<File> {
    OpenOptions::new().write(true).create_new(true).open(path)
}

fn write_new_file(path: &Path, bytes: &[u8]) -> io::Result<()> {
    let mut file = create_new_file(path)?;
    file.write_all(bytes)?;
    file.flush()?;
    file.sync_all()
}

fn require_regular_file(path: &Path, name: &str) -> Result<(), Box<dyn Error>> {
    let metadata = fs::metadata(path)?;
    if !metadata.file_type().is_file() {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            format!("{name} must be a regular file: {}", path.display()),
        )
        .into());
    }
    Ok(())
}

fn read_regular_file(path: &Path, name: &str) -> Result<Vec<u8>, Box<dyn Error>> {
    require_regular_file(path, name)?;
    read_file(path)
}

fn read_file(path: &Path) -> Result<Vec<u8>, Box<dyn Error>> {
    fs::read(path).map_err(|error| {
        io::Error::new(
            error.kind(),
            format!("failed to read {}: {error}", path.display()),
        )
        .into()
    })
}

struct EvidenceFiles {
    classification_receipt: Vec<u8>,
    session_evidence: Vec<u8>,
    diagnostic_log: Vec<u8>,
    board_after: Vec<u8>,
    owner_after: Vec<u8>,
    boundary_manifest: Vec<u8>,
    prepared_receipt: Vec<u8>,
    boundary_receipt: Vec<u8>,
    writer_raw_bf16: Vec<u8>,
    observed_output_bf16: Vec<u8>,
    observed_post_state_bf16: Vec<u8>,
    session_manifest: Vec<u8>,
    plan_receipt: Vec<u8>,
}

impl EvidenceFiles {
    fn as_evidence(&self) -> Ttwkv7ObservedLayerEvidence<'_> {
        Ttwkv7ObservedLayerEvidence {
            classification_receipt: &self.classification_receipt,
            session_evidence: &self.session_evidence,
            diagnostic_log: &self.diagnostic_log,
            board_after: &self.board_after,
            owner_after: &self.owner_after,
            boundary_manifest: &self.boundary_manifest,
            prepared_receipt: &self.prepared_receipt,
            boundary_receipt: &self.boundary_receipt,
            writer_raw_bf16: &self.writer_raw_bf16,
            observed_output_bf16: &self.observed_output_bf16,
            observed_post_state_bf16: &self.observed_post_state_bf16,
            session_manifest: &self.session_manifest,
            plan_receipt: &self.plan_receipt,
        }
    }
}

fn read_evidence(root: &Path) -> Result<EvidenceFiles, Box<dyn Error>> {
    let read = |filename| read_regular_file(&root.join(filename), filename);
    Ok(EvidenceFiles {
        classification_receipt: read(CLASSIFICATION_FILENAME)?,
        session_evidence: read(SESSION_EVIDENCE_FILENAME)?,
        diagnostic_log: read(DIAGNOSTIC_FILENAME)?,
        board_after: read(BOARD_AFTER_FILENAME)?,
        owner_after: read(OWNER_AFTER_FILENAME)?,
        boundary_manifest: read(BOUNDARY_MANIFEST_FILENAME)?,
        prepared_receipt: read(PREPARED_FILENAME)?,
        boundary_receipt: read(BOUNDARY_RECEIPT_FILENAME)?,
        writer_raw_bf16: read(WRITER_RAW_FILENAME)?,
        observed_output_bf16: read(OBSERVED_OUTPUT_FILENAME)?,
        observed_post_state_bf16: read(OBSERVED_POST_STATE_FILENAME)?,
        session_manifest: read(SESSION_MANIFEST_FILENAME)?,
        plan_receipt: read(PLAN_RECEIPT_FILENAME)?,
    })
}

fn invalid_data(message: String) -> io::Error {
    io::Error::new(io::ErrorKind::InvalidData, message)
}
