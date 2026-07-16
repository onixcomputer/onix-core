use std::error::Error;
use std::ffi::OsStr;
use std::fs;
use std::io;
use std::path::{Path, PathBuf};
use std::process::{Command, ExitCode};
use std::time::{SystemTime, UNIX_EPOCH};
use tt_vibethinker_bench::{
    BenchmarkSummary, Config, SUMMARY_SCHEMA_VERSION, benchmark_arguments, benchmark_cases,
    extract_json_array, parse_case_output, selector_environment,
};

const LATEST_SUMMARY_FILE: &str = "latest-summary.json";
const SUMMARY_FILE: &str = "summary.json";
const RAW_STDOUT_SUFFIX: &str = "stdout.log";
const RAW_STDERR_SUFFIX: &str = "stderr.log";
const CLEAN_JSON_SUFFIX: &str = "json";

fn main() -> ExitCode {
    match run() {
        Ok(summary_path) => {
            println!("benchmark summary: {}", summary_path.display());
            ExitCode::SUCCESS
        }
        Err(error) => {
            eprintln!("tt-vibethinker-bench: {error}");
            ExitCode::FAILURE
        }
    }
}

fn run() -> Result<PathBuf, Box<dyn Error>> {
    let arguments: Vec<String> = std::env::args().skip(1).collect();
    let config = Config::parse(&arguments).map_err(invalid_input)?;
    validate_inputs(&config)?;

    let created_unix_seconds = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs();
    let run_name = format!("run-{created_unix_seconds}-{}", std::process::id());
    let run_directory = config.output_root.join(&run_name);
    fs::create_dir_all(&run_directory)?;

    let mut case_summaries = Vec::new();
    for case in benchmark_cases() {
        let case_directory = run_directory.join(case.slug);
        let case_cache = config.cache_root.join(case.slug);
        let case_logs = config.logs_root.join(&run_name).join(case.slug);
        fs::create_dir_all(&case_directory)?;
        fs::create_dir_all(&case_cache)?;
        fs::create_dir_all(&case_logs)?;

        let output = execute_case(&config, &case, &case_directory, &case_cache, &case_logs)?;
        let stdout_path = case_directory.join(format!("{}.{}", case.slug, RAW_STDOUT_SUFFIX));
        let stderr_path = case_directory.join(format!("{}.{}", case.slug, RAW_STDERR_SUFFIX));
        fs::write(&stdout_path, &output.stdout)?;
        fs::write(&stderr_path, &output.stderr)?;
        if !output.status.success() {
            return Err(io::Error::other(format!(
                "{} failed with {}; inspect {} and {}",
                case.slug,
                output.status,
                stdout_path.display(),
                stderr_path.display()
            ))
            .into());
        }

        let raw_stdout = String::from_utf8(output.stdout).map_err(|error| {
            io::Error::new(
                io::ErrorKind::InvalidData,
                format!("{} stdout was not UTF-8: {error}", case.slug),
            )
        })?;
        let clean_json = extract_json_array(&raw_stdout).map_err(invalid_data)?;
        let clean_json_path = case_directory.join(format!("{}.{}", case.slug, CLEAN_JSON_SUFFIX));
        fs::write(&clean_json_path, clean_json)?;
        let summary = parse_case_output(&case, &raw_stdout).map_err(invalid_data)?;
        case_summaries.push(summary);
    }

    let summary = BenchmarkSummary {
        schema_version: SUMMARY_SCHEMA_VERSION,
        created_unix_seconds,
        run_directory: run_directory.clone(),
        cases: case_summaries,
    };
    let summary_json = serde_json::to_vec_pretty(&summary)?;
    let summary_path = run_directory.join(SUMMARY_FILE);
    fs::write(&summary_path, &summary_json)?;
    publish_latest_summary(&config.output_root, &summary_json)?;
    Ok(summary_path)
}

fn validate_inputs(config: &Config) -> Result<(), Box<dyn Error>> {
    require_file(&config.llama_bench, "llama-bench executable")?;
    require_file(&config.model, "model")?;
    require_file(&config.mesh_descriptor, "mesh descriptor")?;
    Ok(())
}

fn require_file(path: &Path, description: &str) -> Result<(), Box<dyn Error>> {
    if !path.is_file() {
        return Err(io::Error::new(
            io::ErrorKind::NotFound,
            format!("{description} does not exist: {}", path.display()),
        )
        .into());
    }
    Ok(())
}

fn execute_case(
    config: &Config,
    case: &tt_vibethinker_bench::BenchmarkCase,
    case_directory: &Path,
    case_cache: &Path,
    case_logs: &Path,
) -> Result<std::process::Output, Box<dyn Error>> {
    let model = path_text(&config.model, "model")?;
    let descriptor = path_text(&config.mesh_descriptor, "mesh descriptor")?;
    let mut command = Command::new(&config.llama_bench);
    command
        .args(benchmark_arguments(model))
        .current_dir(case_directory)
        .env("HOME", &config.output_root)
        .env("TT_METAL_CACHE", case_cache)
        .env("TT_METAL_LOGS_PATH", case_logs)
        .env(
            "TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS",
            format!("127.0.0.1:{}", config.inspector_port),
        );

    for (name, value) in selector_environment(case, descriptor) {
        match value {
            Some(value) => {
                command.env(name, value);
            }
            None => {
                command.env_remove(name);
            }
        }
    }

    command.output().map_err(|error| {
        io::Error::other(format!(
            "failed to execute {} for {}: {error}",
            config.llama_bench.display(),
            case.slug
        ))
        .into()
    })
}

fn path_text<'a>(path: &'a Path, description: &str) -> Result<&'a str, Box<dyn Error>> {
    path.as_os_str().to_str().ok_or_else(|| {
        io::Error::new(
            io::ErrorKind::InvalidInput,
            format!("{description} path is not UTF-8: {}", path.display()),
        )
        .into()
    })
}

fn publish_latest_summary(output_root: &Path, summary: &[u8]) -> Result<(), Box<dyn Error>> {
    let latest_path = output_root.join(LATEST_SUMMARY_FILE);
    let partial_path = with_extra_extension(&latest_path, OsStr::new("partial"));
    fs::write(&partial_path, summary)?;
    fs::rename(partial_path, latest_path)?;
    Ok(())
}

fn with_extra_extension(path: &Path, extension: &OsStr) -> PathBuf {
    let mut value = path.as_os_str().to_owned();
    value.push(".");
    value.push(extension);
    PathBuf::from(value)
}

fn invalid_input(message: String) -> io::Error {
    io::Error::new(io::ErrorKind::InvalidInput, message)
}

fn invalid_data(message: String) -> io::Error {
    io::Error::new(io::ErrorKind::InvalidData, message)
}
