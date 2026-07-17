use rwkv_lab::{SessionEvidence, SessionManifest, classify, plan_id, plan_receipt};
use serde::Serialize;
use serde::de::DeserializeOwned;
use std::error::Error;
use std::fs;
use std::io::{self, Write};
use std::path::Path;
use std::process::ExitCode;

const COMMAND_CHECK: &str = "check";
const COMMAND_PLAN_ID: &str = "plan-id";
const COMMAND_CLASSIFY: &str = "classify";
const COMMAND_HELP: &str = "--help";
const USAGE: &str = "usage: rwkv-lab check MANIFEST.json | plan-id MANIFEST.json | classify MANIFEST.json EVIDENCE.json";

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("rwkv-lab: {error}");
            ExitCode::FAILURE
        }
    }
}

fn run() -> Result<(), Box<dyn Error>> {
    let arguments = std::env::args().skip(1).collect::<Vec<_>>();
    match arguments.as_slice() {
        [command] if command == COMMAND_HELP => {
            println!("{USAGE}");
            Ok(())
        }
        [command, manifest_path] if command == COMMAND_CHECK => {
            let manifest = read_json::<SessionManifest>(Path::new(manifest_path), "manifest")?;
            let receipt = plan_receipt(manifest).map_err(invalid_data)?;
            write_json(&receipt)
        }
        [command, manifest_path] if command == COMMAND_PLAN_ID => {
            let manifest = read_json::<SessionManifest>(Path::new(manifest_path), "manifest")?;
            let identifier = plan_id(&manifest).map_err(invalid_data)?;
            println!("{identifier}");
            Ok(())
        }
        [command, manifest_path, evidence_path] if command == COMMAND_CLASSIFY => {
            let manifest = read_json::<SessionManifest>(Path::new(manifest_path), "manifest")?;
            let evidence = read_json::<SessionEvidence>(Path::new(evidence_path), "evidence")?;
            let receipt = classify(&manifest, &evidence).map_err(invalid_data)?;
            write_json(&receipt)
        }
        _ => Err(io::Error::new(io::ErrorKind::InvalidInput, USAGE).into()),
    }
}

fn read_json<T: DeserializeOwned>(path: &Path, description: &str) -> Result<T, Box<dyn Error>> {
    let canonical_path = fs::canonicalize(path).map_err(|error| {
        io::Error::new(
            error.kind(),
            format!(
                "failed to resolve {description} {}: {error}",
                path.display()
            ),
        )
    })?;
    let metadata = fs::metadata(&canonical_path)?;
    if !metadata.file_type().is_file() {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            format!(
                "{description} must resolve to a regular file: {}",
                path.display()
            ),
        )
        .into());
    }
    let bytes = fs::read(&canonical_path).map_err(|error| {
        io::Error::new(
            error.kind(),
            format!(
                "failed to read {description} {}: {error}",
                canonical_path.display()
            ),
        )
    })?;
    serde_json::from_slice(&bytes).map_err(|error| {
        io::Error::new(
            io::ErrorKind::InvalidData,
            format!(
                "failed to parse {description} {} as JSON: {error}",
                canonical_path.display()
            ),
        )
        .into()
    })
}

fn write_json<T: Serialize>(value: &T) -> Result<(), Box<dyn Error>> {
    let stdout = io::stdout();
    let mut output = stdout.lock();
    serde_json::to_writer_pretty(&mut output, value)?;
    output.write_all(b"\n")?;
    Ok(())
}

fn invalid_data(message: String) -> io::Error {
    io::Error::new(io::ErrorKind::InvalidData, message)
}
