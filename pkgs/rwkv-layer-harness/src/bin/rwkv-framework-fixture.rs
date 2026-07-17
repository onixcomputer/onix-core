use rwkv_layer_harness::run_framework_vector_fixture;
use std::error::Error;
use std::fs;
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::process::ExitCode;

const MODEL_PATH: Option<&str> = option_env!("RWKV_LAYER_MODEL");
const EXPECTED_BLAKE3: Option<&str> = option_env!("RWKV_LAYER_MODEL_BLAKE3");
const EXPECTED_ARGUMENT_COUNT: usize = 1;

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("rwkv-framework-fixture: {error}");
            ExitCode::FAILURE
        }
    }
}

fn run() -> Result<(), Box<dyn Error>> {
    let arguments = std::env::args().collect::<Vec<_>>();
    if arguments.len() != EXPECTED_ARGUMENT_COUNT {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "rwkv-framework-fixture does not accept arguments",
        )
        .into());
    }
    let configured_path = MODEL_PATH.ok_or_else(|| {
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
    let model_path = require_store_file(Path::new(configured_path))?;
    let checkpoint = fs::read(&model_path).map_err(|error| {
        io::Error::new(
            error.kind(),
            format!("failed to read {}: {error}", model_path.display()),
        )
    })?;
    let receipt =
        run_framework_vector_fixture(&checkpoint, expected_blake3).map_err(invalid_data)?;
    let stdout = io::stdout();
    let mut output = stdout.lock();
    serde_json::to_writer(&mut output, &receipt)?;
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
    let metadata = fs::metadata(&canonical)?;
    if !metadata.file_type().is_file() {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            format!(
                "embedded checkpoint must be a regular file: {}",
                canonical.display()
            ),
        )
        .into());
    }
    Ok(canonical)
}

fn invalid_data(message: String) -> io::Error {
    io::Error::new(io::ErrorKind::InvalidData, message)
}
