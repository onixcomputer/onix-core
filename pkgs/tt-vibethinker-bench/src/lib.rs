use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::path::PathBuf;

pub const PROMPT_TOKENS: u64 = 64;
pub const GENERATED_TOKENS: u64 = 32;
pub const REPETITIONS: usize = 3;
pub const BATCH_SIZE: u64 = 512;
pub const GPU_LAYERS: u64 = 999;
pub const BENCHMARK_THREADS: u64 = 16;
pub const SUMMARY_SCHEMA_VERSION: u32 = 1;
const EXPECTED_RECORD_COUNT: usize = 2;
const CLI_OPTION_WIDTH: usize = 2;
const PHYSICAL_DEVICE_ZERO: u8 = 0;
const PHYSICAL_DEVICE_ONE: u8 = 1;
const LOGICAL_DEVICE_ZERO: &str = "0";
const METALIUM_TRACE_DISABLED: &str = "0";
const MESH_ENVIRONMENT_SHAPE: &str = "2x1";
const REPORTED_MESH_FRAGMENT: &str = "Tenstorrent BLACKHOLE 1x2 mesh";
const MESH_DISCOVERY_FRAGMENT: &str = "Opening local chip ids/PCIe ids: {0, 1}/[0, 1]";
const LOGICAL_ADJACENCY_FRAGMENT: &str = "Logical multi-mesh adjacency";
const PHYSICAL_ADJACENCY_FRAGMENT: &str = "Physical multi-mesh adjacency";
const SINGLE_DEVICE_FRAGMENT: &str = "Tenstorrent BLACKHOLE";

#[derive(Clone, Debug, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum Selector {
    PhysicalDevice { physical_id: u8 },
    Mesh1x2,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize)]
pub struct BenchmarkCase {
    pub slug: &'static str,
    pub selector: Selector,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Config {
    pub llama_bench: PathBuf,
    pub model: PathBuf,
    pub output_root: PathBuf,
    pub cache_root: PathBuf,
    pub logs_root: PathBuf,
    pub mesh_descriptor: PathBuf,
    pub inspector_port: u16,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct BenchmarkRecord {
    pub gpu_info: String,
    pub n_prompt: u64,
    pub n_gen: u64,
    pub avg_ts: f64,
    pub samples_ts: Vec<f64>,
}

#[derive(Clone, Debug, Serialize)]
pub struct Measurement {
    pub tokens: u64,
    pub average_tokens_per_second: f64,
    pub samples_tokens_per_second: Vec<f64>,
}

#[derive(Clone, Debug, Serialize)]
pub struct CaseSummary {
    pub case: BenchmarkCase,
    pub gpu_info: String,
    pub prompt: Measurement,
    pub generation: Measurement,
}

#[derive(Clone, Debug, Serialize)]
pub struct BenchmarkSummary {
    pub schema_version: u32,
    pub created_unix_seconds: u64,
    pub run_directory: PathBuf,
    pub cases: Vec<CaseSummary>,
}

pub fn benchmark_cases() -> Vec<BenchmarkCase> {
    vec![
        BenchmarkCase {
            slug: "device-0",
            selector: Selector::PhysicalDevice {
                physical_id: PHYSICAL_DEVICE_ZERO,
            },
        },
        BenchmarkCase {
            slug: "device-1",
            selector: Selector::PhysicalDevice {
                physical_id: PHYSICAL_DEVICE_ONE,
            },
        },
        BenchmarkCase {
            slug: "mesh-1x2",
            selector: Selector::Mesh1x2,
        },
    ]
}

pub fn benchmark_arguments(model: &str) -> Vec<String> {
    vec![
        "-m".to_owned(),
        model.to_owned(),
        "-p".to_owned(),
        PROMPT_TOKENS.to_string(),
        "-n".to_owned(),
        GENERATED_TOKENS.to_string(),
        "-b".to_owned(),
        BATCH_SIZE.to_string(),
        "-ub".to_owned(),
        BATCH_SIZE.to_string(),
        "-ngl".to_owned(),
        GPU_LAYERS.to_string(),
        "-nkvo".to_owned(),
        "1".to_owned(),
        "-fa".to_owned(),
        "off".to_owned(),
        "-mmp".to_owned(),
        "0".to_owned(),
        "-t".to_owned(),
        BENCHMARK_THREADS.to_string(),
        "-r".to_owned(),
        REPETITIONS.to_string(),
        "-o".to_owned(),
        "json".to_owned(),
    ]
}

pub fn selector_environment(
    case: &BenchmarkCase,
    mesh_descriptor: &str,
) -> BTreeMap<&'static str, Option<String>> {
    let mut environment = BTreeMap::from([
        ("GGML_METALIUM_DEVICE_ID", None),
        ("GGML_METALIUM_MESH_SHAPE", None),
        ("TT_MESH_GRAPH_DESC_PATH", None),
        ("TT_VISIBLE_DEVICES", None),
    ]);

    match case.selector {
        Selector::PhysicalDevice { physical_id } => {
            environment.insert(
                "GGML_METALIUM_DEVICE_ID",
                Some(LOGICAL_DEVICE_ZERO.to_owned()),
            );
            environment.insert("TT_VISIBLE_DEVICES", Some(physical_id.to_string()));
        }
        Selector::Mesh1x2 => {
            environment.insert(
                "GGML_METALIUM_MESH_SHAPE",
                Some(MESH_ENVIRONMENT_SHAPE.to_owned()),
            );
            environment.insert("TT_MESH_GRAPH_DESC_PATH", Some(mesh_descriptor.to_owned()));
        }
    }

    environment.insert(
        "GGML_METALIUM_TRACE",
        Some(METALIUM_TRACE_DISABLED.to_owned()),
    );
    environment
}

pub fn extract_json_array(raw: &str) -> Result<&str, String> {
    for (start, character) in raw.char_indices() {
        if character != '[' {
            continue;
        }
        if let Some(end) = balanced_array_end(&raw[start..]) {
            let candidate = &raw[start..start + end];
            if serde_json::from_str::<serde_json::Value>(candidate).is_ok_and(|value| {
                value.as_array().is_some_and(|records| {
                    !records.is_empty() && records.iter().all(serde_json::Value::is_object)
                })
            }) {
                return Ok(candidate);
            }
        }
    }
    Err("llama-bench output did not contain a valid JSON array".to_owned())
}

fn balanced_array_end(candidate: &str) -> Option<usize> {
    let mut depth = 0_usize;
    let mut in_string = false;
    let mut escaped = false;

    for (offset, character) in candidate.char_indices() {
        if in_string {
            if escaped {
                escaped = false;
            } else if character == '\\' {
                escaped = true;
            } else if character == '"' {
                in_string = false;
            }
            continue;
        }

        match character {
            '"' => in_string = true,
            '[' => depth = depth.checked_add(1)?,
            ']' => {
                depth = depth.checked_sub(1)?;
                if depth == 0 {
                    return Some(offset + character.len_utf8());
                }
            }
            _ => {}
        }
    }
    None
}

pub fn parse_case_output(case: &BenchmarkCase, raw: &str) -> Result<CaseSummary, String> {
    validate_runtime_evidence(case, raw)?;
    let json = extract_json_array(raw)?;
    let records: Vec<BenchmarkRecord> = serde_json::from_str(json)
        .map_err(|error| format!("failed to parse llama-bench JSON: {error}"))?;
    if records.len() != EXPECTED_RECORD_COUNT {
        return Err(format!(
            "expected {EXPECTED_RECORD_COUNT} benchmark records, found {}",
            records.len()
        ));
    }

    for record in &records {
        validate_topology(case, &record.gpu_info)?;
        if !record.avg_ts.is_finite() || record.avg_ts <= 0.0 {
            return Err("benchmark throughput must be finite and positive".to_owned());
        }
        if record.samples_ts.len() != REPETITIONS {
            return Err(format!(
                "expected {REPETITIONS} throughput samples, found {}",
                record.samples_ts.len()
            ));
        }
        if record
            .samples_ts
            .iter()
            .any(|sample| !sample.is_finite() || *sample <= 0.0)
        {
            return Err("benchmark samples must be finite and positive".to_owned());
        }
    }

    let prompt = find_record(&records, PROMPT_TOKENS, 0, "prompt")?;
    let generation = find_record(&records, 0, GENERATED_TOKENS, "generation")?;
    if prompt.gpu_info != generation.gpu_info {
        return Err("prompt and generation records report different devices".to_owned());
    }

    Ok(CaseSummary {
        case: case.clone(),
        gpu_info: prompt.gpu_info.clone(),
        prompt: measurement(prompt, PROMPT_TOKENS),
        generation: measurement(generation, GENERATED_TOKENS),
    })
}

fn find_record<'a>(
    records: &'a [BenchmarkRecord],
    prompt_tokens: u64,
    generated_tokens: u64,
    name: &str,
) -> Result<&'a BenchmarkRecord, String> {
    let matches: Vec<&BenchmarkRecord> = records
        .iter()
        .filter(|record| record.n_prompt == prompt_tokens && record.n_gen == generated_tokens)
        .collect();
    if matches.len() != 1 {
        return Err(format!(
            "expected exactly one {name} record, found {}",
            matches.len()
        ));
    }
    Ok(matches[0])
}

fn measurement(record: &BenchmarkRecord, tokens: u64) -> Measurement {
    Measurement {
        tokens,
        average_tokens_per_second: record.avg_ts,
        samples_tokens_per_second: record.samples_ts.clone(),
    }
}

fn validate_runtime_evidence(case: &BenchmarkCase, raw: &str) -> Result<(), String> {
    if case.selector == Selector::Mesh1x2 {
        for required_fragment in [
            MESH_DISCOVERY_FRAGMENT,
            LOGICAL_ADJACENCY_FRAGMENT,
            PHYSICAL_ADJACENCY_FRAGMENT,
        ] {
            if !raw.contains(required_fragment) {
                return Err(format!(
                    "{} output is missing mesh runtime evidence: {required_fragment}",
                    case.slug
                ));
            }
        }
    }
    Ok(())
}

fn validate_topology(case: &BenchmarkCase, gpu_info: &str) -> Result<(), String> {
    match case.selector {
        Selector::PhysicalDevice { .. } => {
            if !gpu_info.contains(SINGLE_DEVICE_FRAGMENT) || gpu_info.contains("mesh") {
                return Err(format!(
                    "{} reported unexpected single-device topology: {gpu_info}",
                    case.slug
                ));
            }
        }
        Selector::Mesh1x2 => {
            if !gpu_info.contains(REPORTED_MESH_FRAGMENT) {
                return Err(format!(
                    "{} did not report the required 1x2 topology: {gpu_info}",
                    case.slug
                ));
            }
        }
    }
    Ok(())
}

impl Config {
    pub fn parse(arguments: &[String]) -> Result<Self, String> {
        let mut values = BTreeMap::new();
        let mut index = 0_usize;
        while index < arguments.len() {
            let flag = arguments
                .get(index)
                .ok_or_else(|| "missing option name".to_owned())?;
            let value = arguments
                .get(index + 1)
                .ok_or_else(|| format!("missing value for {flag}"))?;
            if !matches!(
                flag.as_str(),
                "--llama-bench"
                    | "--model"
                    | "--output-root"
                    | "--cache-root"
                    | "--logs-root"
                    | "--mesh-descriptor"
                    | "--inspector-port"
            ) {
                return Err(format!("unknown option: {flag}"));
            }
            if values.insert(flag.clone(), value.clone()).is_some() {
                return Err(format!("duplicate option: {flag}"));
            }
            index += CLI_OPTION_WIDTH;
        }

        let path = |name: &str| -> Result<PathBuf, String> {
            let value = values
                .get(name)
                .ok_or_else(|| format!("missing required option: {name}"))?;
            let path = PathBuf::from(value);
            if !path.is_absolute() {
                return Err(format!("{name} must be an absolute path"));
            }
            Ok(path)
        };
        let inspector_port = values
            .get("--inspector-port")
            .ok_or_else(|| "missing required option: --inspector-port".to_owned())?
            .parse::<u16>()
            .map_err(|error| format!("invalid --inspector-port: {error}"))?;
        if inspector_port == 0 {
            return Err("--inspector-port must be positive".to_owned());
        }

        Ok(Self {
            llama_bench: path("--llama-bench")?,
            model: path("--model")?,
            output_root: path("--output-root")?,
            cache_root: path("--cache-root")?,
            logs_root: path("--logs-root")?,
            mesh_descriptor: path("--mesh-descriptor")?,
            inspector_port,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const MATRIX_CASE_COUNT: usize = 3;
    const MESH_CASE_INDEX: usize = 2;
    const INSPECTOR_PORT: &str = "50061";
    const PROMPT_AVERAGE: f64 = 90.0;
    const PROMPT_SAMPLE_LOW: f64 = 89.0;
    const PROMPT_SAMPLE_HIGH: f64 = 91.0;
    const GENERATION_AVERAGE: f64 = 8.0;
    const GENERATION_SAMPLE_LOW: f64 = 7.9;
    const GENERATION_SAMPLE_HIGH: f64 = 8.1;

    fn valid_config_arguments() -> Vec<String> {
        [
            ("--llama-bench", "/nix/store/llama-bench"),
            ("--model", "/var/lib/models/vibe.gguf"),
            ("--output-root", "/var/lib/bench"),
            ("--cache-root", "/var/cache/bench"),
            ("--logs-root", "/var/log/bench"),
            ("--mesh-descriptor", "/nix/store/p150x2.textproto"),
            ("--inspector-port", INSPECTOR_PORT),
        ]
        .into_iter()
        .flat_map(|(flag, value)| [flag.to_owned(), value.to_owned()])
        .collect()
    }

    fn output(gpu_info: &str) -> String {
        format!(
            "runtime log before JSON\n{MESH_DISCOVERY_FRAGMENT}\n{LOGICAL_ADJACENCY_FRAGMENT}\n{PHYSICAL_ADJACENCY_FRAGMENT}\n[\n  {{\"gpu_info\":{gpu_info:?},\"n_prompt\":{PROMPT_TOKENS},\"n_gen\":0,\"avg_ts\":{PROMPT_AVERAGE},\"samples_ts\":[{PROMPT_SAMPLE_LOW},{PROMPT_AVERAGE},{PROMPT_SAMPLE_HIGH}]}},\n  {{\"gpu_info\":{gpu_info:?},\"n_prompt\":0,\"n_gen\":{GENERATED_TOKENS},\"avg_ts\":{GENERATION_AVERAGE},\"samples_ts\":[{GENERATION_SAMPLE_LOW},{GENERATION_AVERAGE},{GENERATION_SAMPLE_HIGH}]}}\n]\nruntime log after JSON\n"
        )
    }

    #[test]
    fn matrix_selects_two_physical_devices_and_reported_1x2_mesh() {
        let cases = benchmark_cases();
        assert_eq!(cases.len(), MATRIX_CASE_COUNT);
        assert_eq!(
            selector_environment(&cases[0], "/descriptor")["TT_VISIBLE_DEVICES"],
            Some("0".to_owned())
        );
        assert_eq!(
            selector_environment(&cases[1], "/descriptor")["TT_VISIBLE_DEVICES"],
            Some("1".to_owned())
        );
        let mesh = selector_environment(&cases[MESH_CASE_INDEX], "/descriptor");
        assert_eq!(mesh["GGML_METALIUM_MESH_SHAPE"], Some("2x1".to_owned()));
        assert_eq!(
            mesh["TT_MESH_GRAPH_DESC_PATH"],
            Some("/descriptor".to_owned())
        );
        assert_eq!(mesh["TT_VISIBLE_DEVICES"], None);
    }

    #[test]
    fn fixed_arguments_preserve_the_accepted_benchmark_shape() {
        let arguments = benchmark_arguments("/model");
        for required in ["64", "32", "512", "999", "16", "3", "json"] {
            assert!(arguments.iter().any(|argument| argument == required));
        }
        assert!(arguments.windows(2).any(|pair| pair == ["-nkvo", "1"]));
        assert!(arguments.windows(2).any(|pair| pair == ["-fa", "off"]));
        assert!(arguments.windows(2).any(|pair| pair == ["-mmp", "0"]));
    }

    #[test]
    fn parses_valid_single_device_and_mesh_results() {
        let cases = benchmark_cases();
        let single = parse_case_output(
            &cases[0],
            &output("Tenstorrent BLACKHOLE [grid: 13x10, id: 0]"),
        )
        .expect("single-device output must parse");
        assert_eq!(
            single.generation.average_tokens_per_second,
            GENERATION_AVERAGE
        );

        let mesh = parse_case_output(
            &cases[MESH_CASE_INDEX],
            &output("Tenstorrent BLACKHOLE 1x2 mesh [id: 0]"),
        )
        .expect("mesh output must parse");
        assert_eq!(mesh.prompt.tokens, PROMPT_TOKENS);
    }

    #[test]
    fn rejects_malformed_or_incomplete_output() {
        let case = &benchmark_cases()[0];
        assert!(parse_case_output(case, "no benchmark JSON").is_err());
        let incomplete = format!(
            "[{{\"gpu_info\":\"Tenstorrent BLACKHOLE\",\"n_prompt\":{PROMPT_TOKENS},\"n_gen\":0,\"avg_ts\":1.0,\"samples_ts\":[1.0,1.0,1.0]}}]"
        );
        assert!(parse_case_output(case, &incomplete).is_err());
    }

    #[test]
    fn rejects_wrong_mesh_orientation() {
        let mesh_case = &benchmark_cases()[MESH_CASE_INDEX];
        let error = parse_case_output(mesh_case, &output("Tenstorrent BLACKHOLE 2x1 mesh [id: 0]"))
            .expect_err("wrong mesh orientation must fail");
        assert!(error.contains("required 1x2 topology"));
    }

    #[test]
    fn rejects_mesh_without_two_chip_discovery_and_adjacency() {
        let mesh_case = &benchmark_cases()[MESH_CASE_INDEX];
        let output_without_discovery = output("Tenstorrent BLACKHOLE 1x2 mesh [id: 0]")
            .replace(MESH_DISCOVERY_FRAGMENT, "missing discovery")
            .replace(LOGICAL_ADJACENCY_FRAGMENT, "missing logical adjacency")
            .replace(PHYSICAL_ADJACENCY_FRAGMENT, "missing physical adjacency");
        let error = parse_case_output(mesh_case, &output_without_discovery)
            .expect_err("mesh output without runtime evidence must fail");
        assert!(error.contains("missing mesh runtime evidence"));
    }

    #[test]
    fn parses_complete_absolute_configuration() {
        let config = Config::parse(&valid_config_arguments()).expect("valid config must parse");
        assert_eq!(config.inspector_port.to_string(), INSPECTOR_PORT);
        assert!(config.output_root.is_absolute());
    }

    #[test]
    fn rejects_unknown_missing_relative_and_invalid_configuration() {
        let mut unknown = valid_config_arguments();
        unknown.extend(["--unknown".to_owned(), "value".to_owned()]);
        assert!(Config::parse(&unknown).is_err());

        let mut missing = valid_config_arguments();
        missing.truncate(missing.len() - 1);
        assert!(Config::parse(&missing).is_err());

        let mut relative = valid_config_arguments();
        let output_index = relative
            .iter()
            .position(|argument| argument == "--output-root")
            .expect("output option must exist")
            + 1;
        relative[output_index] = "relative".to_owned();
        assert!(Config::parse(&relative).is_err());

        let mut invalid_port = valid_config_arguments();
        let port_index = invalid_port
            .iter()
            .position(|argument| argument == "--inspector-port")
            .expect("port option must exist")
            + 1;
        invalid_port[port_index] = "0".to_owned();
        assert!(Config::parse(&invalid_port).is_err());
    }
}
