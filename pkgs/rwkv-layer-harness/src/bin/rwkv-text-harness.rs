use rwkv_layer_harness::{TokenizerAuthorityInputs, run_text_checkpoint};
use std::error::Error;
use std::fs;
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::process::ExitCode;

const MODEL_PATH: Option<&str> = option_env!("RWKV_LAYER_MODEL");
const EXPECTED_MODEL_BLAKE3: Option<&str> = option_env!("RWKV_LAYER_MODEL_BLAKE3");
const VOCABULARY_PATH: Option<&str> = option_env!("RWKV_TOKENIZER_VOCABULARY");
const TOKENIZER_CONFIG_PATH: Option<&str> = option_env!("RWKV_TOKENIZER_CONFIG");
const ADDED_TOKENS_PATH: Option<&str> = option_env!("RWKV_TOKENIZER_ADDED_TOKENS");
const TOKENIZER_IMPLEMENTATION_PATH: Option<&str> = option_env!("RWKV_TOKENIZER_IMPLEMENTATION");
const SPECIAL_TOKENS_MAP_PATH: Option<&str> = option_env!("RWKV_SPECIAL_TOKENS_MAP");
const MODEL_CONFIG_PATH: Option<&str> = option_env!("RWKV_MODEL_CONFIG");
const GENERATION_CONFIG_PATH: Option<&str> = option_env!("RWKV_GENERATION_CONFIG");
const EXPECTED_ARGUMENT_COUNT: usize = 1;

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("rwkv-text-harness: {error}");
            ExitCode::FAILURE
        }
    }
}

fn run() -> Result<(), Box<dyn Error>> {
    let arguments = std::env::args().collect::<Vec<_>>();
    if arguments.len() != EXPECTED_ARGUMENT_COUNT {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "rwkv-text-harness does not accept arguments",
        )
        .into());
    }

    let checkpoint = read_embedded_store_file(MODEL_PATH, "RWKV_LAYER_MODEL")?;
    let expected_model_blake3 = EXPECTED_MODEL_BLAKE3.ok_or_else(|| {
        io::Error::new(
            io::ErrorKind::NotFound,
            "RWKV_LAYER_MODEL_BLAKE3 was not embedded at build time",
        )
    })?;
    let vocabulary = read_embedded_store_file(VOCABULARY_PATH, "RWKV_TOKENIZER_VOCABULARY")?;
    let tokenizer_config =
        read_embedded_store_file(TOKENIZER_CONFIG_PATH, "RWKV_TOKENIZER_CONFIG")?;
    let added_tokens = read_embedded_store_file(ADDED_TOKENS_PATH, "RWKV_TOKENIZER_ADDED_TOKENS")?;
    let tokenizer_implementation = read_embedded_store_file(
        TOKENIZER_IMPLEMENTATION_PATH,
        "RWKV_TOKENIZER_IMPLEMENTATION",
    )?;
    let special_tokens_map =
        read_embedded_store_file(SPECIAL_TOKENS_MAP_PATH, "RWKV_SPECIAL_TOKENS_MAP")?;
    let model_config = read_embedded_store_file(MODEL_CONFIG_PATH, "RWKV_MODEL_CONFIG")?;
    let generation_config =
        read_embedded_store_file(GENERATION_CONFIG_PATH, "RWKV_GENERATION_CONFIG")?;
    let authority = TokenizerAuthorityInputs {
        vocabulary: &vocabulary,
        tokenizer_config: &tokenizer_config,
        added_tokens: &added_tokens,
        tokenizer_implementation: &tokenizer_implementation,
        special_tokens_map: &special_tokens_map,
        model_config: &model_config,
        generation_config: &generation_config,
    };
    let receipt =
        run_text_checkpoint(&checkpoint, expected_model_blake3, authority).map_err(invalid_data)?;
    let stdout = io::stdout();
    let mut output = stdout.lock();
    serde_json::to_writer_pretty(&mut output, &receipt)?;
    output.write_all(b"\n")?;
    Ok(())
}

fn read_embedded_store_file(
    configured_path: Option<&str>,
    variable_name: &str,
) -> Result<Vec<u8>, Box<dyn Error>> {
    let configured_path = configured_path.ok_or_else(|| {
        io::Error::new(
            io::ErrorKind::NotFound,
            format!("{variable_name} was not embedded at build time"),
        )
    })?;
    let path = require_store_file(Path::new(configured_path))?;
    fs::read(&path).map_err(|error| {
        io::Error::new(
            error.kind(),
            format!("failed to read {}: {error}", path.display()),
        )
        .into()
    })
}

fn require_store_file(path: &Path) -> Result<PathBuf, Box<dyn Error>> {
    let canonical = fs::canonicalize(path)?;
    if !canonical.starts_with("/nix/store/") {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            format!(
                "embedded authority must resolve under /nix/store: {}",
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
                "embedded authority must be a regular file: {}",
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
