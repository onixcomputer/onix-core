use rwkv_layer_harness::{Ttwkv7ObservedLayerEvidence, run_ttwkv7_observed_state_carry_checkpoint};
use std::error::Error;
use std::fs;
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::process::ExitCode;

const MODEL_PATH: Option<&str> = option_env!("RWKV_LAYER_MODEL");
const EXPECTED_BLAKE3: Option<&str> = option_env!("RWKV_LAYER_MODEL_BLAKE3");
const EVIDENCE_ROOT_OPTION: &str = "--evidence-root";
const EXPECTED_ARGUMENT_COUNT: usize = 3;
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

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("rwkv-ttwkv7-observed-state-carry: {error}");
            ExitCode::FAILURE
        }
    }
}

fn run() -> Result<(), Box<dyn Error>> {
    let arguments = std::env::args().collect::<Vec<_>>();
    if arguments.len() != EXPECTED_ARGUMENT_COUNT || arguments[1] != EVIDENCE_ROOT_OPTION {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "usage: rwkv-ttwkv7-observed-state-carry --evidence-root PATH",
        )
        .into());
    }
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
    let model_path = require_store_file(Path::new(configured_model))?;
    let evidence_root = require_directory(Path::new(&arguments[2]))?;
    let checkpoint = read_file(&model_path)?;
    let classification_receipt = read_evidence_file(&evidence_root, CLASSIFICATION_FILENAME)?;
    let session_evidence = read_evidence_file(&evidence_root, SESSION_EVIDENCE_FILENAME)?;
    let diagnostic_log = read_evidence_file(&evidence_root, DIAGNOSTIC_FILENAME)?;
    let board_after = read_evidence_file(&evidence_root, BOARD_AFTER_FILENAME)?;
    let owner_after = read_evidence_file(&evidence_root, OWNER_AFTER_FILENAME)?;
    let boundary_manifest = read_evidence_file(&evidence_root, BOUNDARY_MANIFEST_FILENAME)?;
    let prepared_receipt = read_evidence_file(&evidence_root, PREPARED_FILENAME)?;
    let boundary_receipt = read_evidence_file(&evidence_root, BOUNDARY_RECEIPT_FILENAME)?;
    let writer_raw_bf16 = read_evidence_file(&evidence_root, WRITER_RAW_FILENAME)?;
    let observed_output_bf16 = read_evidence_file(&evidence_root, OBSERVED_OUTPUT_FILENAME)?;
    let observed_post_state_bf16 =
        read_evidence_file(&evidence_root, OBSERVED_POST_STATE_FILENAME)?;
    let session_manifest = read_evidence_file(&evidence_root, SESSION_MANIFEST_FILENAME)?;
    let plan_receipt = read_evidence_file(&evidence_root, PLAN_RECEIPT_FILENAME)?;
    let evidence = Ttwkv7ObservedLayerEvidence {
        classification_receipt: &classification_receipt,
        session_evidence: &session_evidence,
        diagnostic_log: &diagnostic_log,
        board_after: &board_after,
        owner_after: &owner_after,
        boundary_manifest: &boundary_manifest,
        prepared_receipt: &prepared_receipt,
        boundary_receipt: &boundary_receipt,
        writer_raw_bf16: &writer_raw_bf16,
        observed_output_bf16: &observed_output_bf16,
        observed_post_state_bf16: &observed_post_state_bf16,
        session_manifest: &session_manifest,
        plan_receipt: &plan_receipt,
    };
    let receipt =
        run_ttwkv7_observed_state_carry_checkpoint(&checkpoint, expected_blake3, &evidence)
            .map_err(invalid_data)?;
    let stdout = io::stdout();
    let mut output = stdout.lock();
    serde_json::to_writer_pretty(&mut output, &receipt)?;
    output.write_all(b"\n")?;
    Ok(())
}

fn require_store_file(path: &Path) -> Result<PathBuf, Box<dyn Error>> {
    let canonical = fs::canonicalize(path)?;
    if !canonical.starts_with("/nix/store/") {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            format!(
                "embedded checkpoint must resolve under /nix/store: {}",
                canonical.display()
            ),
        )
        .into());
    }
    require_regular_file(&canonical)?;
    Ok(canonical)
}

fn require_directory(path: &Path) -> Result<PathBuf, Box<dyn Error>> {
    let canonical = fs::canonicalize(path)?;
    let metadata = fs::metadata(&canonical)?;
    if !metadata.file_type().is_dir() {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            format!("evidence root must be a directory: {}", canonical.display()),
        )
        .into());
    }
    Ok(canonical)
}

fn read_evidence_file(root: &Path, filename: &str) -> Result<Vec<u8>, Box<dyn Error>> {
    let path = root.join(filename);
    require_regular_file(&path)?;
    read_file(&path)
}

fn require_regular_file(path: &Path) -> Result<(), Box<dyn Error>> {
    let metadata = fs::metadata(path)?;
    if !metadata.file_type().is_file() {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            format!("evidence path must be a regular file: {}", path.display()),
        )
        .into());
    }
    Ok(())
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

fn invalid_data(message: String) -> io::Error {
    io::Error::new(io::ErrorKind::InvalidData, message)
}
