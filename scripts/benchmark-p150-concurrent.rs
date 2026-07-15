#!/usr/bin/env -S CARGO_TARGET_DIR=target/benchmark-p150-concurrent-script nix --option secret-key-files '' shell "github:nix-community/fenix?rev=8df3642541009d2a5f15520462a8dec719c5fddb#minimal.toolchain" nixpkgs#gcc -c cargo -q -Zscript
---
[package]
edition = "2024"

[dependencies]
blake3 = "1"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
---

use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use std::env;
use std::error::Error;
use std::fmt;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::{Arc, Barrier};
use std::thread;
use std::time::Instant;

const DEFAULT_ROUNDS: usize = 5;
const FIRST_ROUND: usize = 1;
const REQUEST_TIMEOUT_SECONDS: u64 = 300;
const DEFAULT_TOLERANCE_PERCENT: f64 = 5.0;
const PERCENT_SCALE: f64 = 100.0;
const SUMMARY_SCHEMA_VERSION: u32 = 1;
const VIBE_EXPECTED_TOKENS: u64 = 64;
const SUPRA_EXPECTED_TOKENS: u64 = 55;
const SUPRA_REQUIRED_FRAGMENTS: &[&str] = &["| Complexity:", "| Route:"];
const SUMMARY_FILE_NAME: &str = "summary.json";
const CURL_PROGRAM: &str = "curl";

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "lowercase")]
enum ServiceKind {
    Vibe,
    Supra,
}

impl ServiceKind {
    fn name(self) -> &'static str {
        match self {
            Self::Vibe => "vibe",
            Self::Supra => "supra",
        }
    }

    fn expected_tokens(self) -> u64 {
        match self {
            Self::Vibe => VIBE_EXPECTED_TOKENS,
            Self::Supra => SUPRA_EXPECTED_TOKENS,
        }
    }
}

#[derive(Clone, Debug)]
struct Endpoint {
    kind: ServiceKind,
    url: String,
    metrics_url: String,
    request_path: PathBuf,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
struct Sample {
    service: ServiceKind,
    phase: String,
    round: usize,
    elapsed_seconds: f64,
    decode_tokens_per_second: f64,
    tokens: u64,
    content_blake3: String,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
struct ServiceMetrics {
    median_decode_tokens_per_second: f64,
    median_elapsed_seconds: f64,
    samples: Vec<Sample>,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
struct PhaseMetrics {
    vibe: ServiceMetrics,
    supra: ServiceMetrics,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
struct BenchmarkSummary {
    schema_version: u32,
    rounds: usize,
    isolated: PhaseMetrics,
    concurrent: PhaseMetrics,
    concurrent_retention_geometric_mean: f64,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    traffic_accounting: Option<TrafficAccounting>,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
struct MetricSnapshot {
    predicted_tokens_total: u64,
    requests_processing: u64,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
struct ServiceTrafficAccounting {
    start: MetricSnapshot,
    end: MetricSnapshot,
    predicted_token_delta: u64,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
struct TrafficAccounting {
    vibe: ServiceTrafficAccounting,
    supra: ServiceTrafficAccounting,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
struct Comparison {
    accepted: bool,
    tolerance_percent: f64,
    isolated_vibe_change_percent: f64,
    isolated_supra_change_percent: f64,
    concurrent_vibe_change_percent: f64,
    concurrent_supra_change_percent: f64,
    retention_change_percent: f64,
    reasons: Vec<String>,
}

#[derive(Clone, Debug)]
struct ParsedResponse {
    decode_tokens_per_second: f64,
    tokens: u64,
    content_blake3: String,
}

#[derive(Debug)]
struct BenchmarkError(String);

impl fmt::Display for BenchmarkError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(&self.0)
    }
}

impl Error for BenchmarkError {}

type AnyError = Box<dyn Error + Send + Sync>;

fn error(message: impl Into<String>) -> AnyError {
    Box::new(BenchmarkError(message.into()))
}

fn required_value<'a>(value: &'a Value, path: &[&str]) -> Result<&'a Value, AnyError> {
    let mut current = value;
    for segment in path {
        current = match current {
            Value::Array(values) => {
                let index = segment.parse::<usize>().map_err(|parse_error| {
                    error(format!(
                        "array path segment is not an index at {}: {parse_error}",
                        path.join(".")
                    ))
                })?;
                values.get(index)
            }
            Value::Object(values) => values.get(*segment),
            _ => None,
        }
        .ok_or_else(|| error(format!("missing JSON field: {}", path.join("."))))?;
    }
    Ok(current)
}

fn required_u64(value: &Value, path: &[&str]) -> Result<u64, AnyError> {
    let current = required_value(value, path)?;
    current
        .as_u64()
        .or_else(|| current.as_f64().map(|number| number as u64))
        .ok_or_else(|| {
            error(format!(
                "field is not an unsigned number: {}",
                path.join(".")
            ))
        })
}

fn required_f64(value: &Value, path: &[&str]) -> Result<f64, AnyError> {
    let current = required_value(value, path)?;
    let number = current
        .as_f64()
        .ok_or_else(|| error(format!("field is not numeric: {}", path.join("."))))?;
    if !number.is_finite() || number <= 0.0 {
        return Err(error(format!(
            "field must be finite and positive: {}",
            path.join(".")
        )));
    }
    Ok(number)
}

fn required_string<'a>(value: &'a Value, path: &[&str]) -> Result<&'a str, AnyError> {
    required_value(value, path)?
        .as_str()
        .filter(|text| !text.is_empty())
        .ok_or_else(|| {
            error(format!(
                "field is not a non-empty string: {}",
                path.join(".")
            ))
        })
}

fn parse_prometheus_u64(text: &str, metric_name: &str) -> Result<u64, AnyError> {
    let prefix = format!("{metric_name} ");
    let line = text
        .lines()
        .find(|line| line.starts_with(&prefix))
        .ok_or_else(|| error(format!("missing Prometheus metric: {metric_name}")))?;
    let raw_value = line
        .strip_prefix(&prefix)
        .ok_or_else(|| error(format!("invalid Prometheus metric line: {line}")))?;
    let value = raw_value
        .parse::<f64>()
        .map_err(|parse_error| error(format!("invalid {metric_name} value: {parse_error}")))?;
    if !value.is_finite() || value < 0.0 || value.fract() != 0.0 {
        return Err(error(format!(
            "Prometheus metric must be a finite unsigned integer: {metric_name}"
        )));
    }
    Ok(value as u64)
}

fn parse_metric_snapshot(text: &str) -> Result<MetricSnapshot, AnyError> {
    Ok(MetricSnapshot {
        predicted_tokens_total: parse_prometheus_u64(text, "llamacpp:tokens_predicted_total")?,
        requests_processing: parse_prometheus_u64(text, "llamacpp:requests_processing")?,
    })
}

fn parse_response(kind: ServiceKind, text: &str) -> Result<ParsedResponse, AnyError> {
    let value: Value = serde_json::from_str(text)
        .map_err(|parse_error| error(format!("malformed response JSON: {parse_error}")))?;
    let decode_tokens_per_second = required_f64(&value, &["timings", "predicted_per_second"])?;

    let (tokens, content) = match kind {
        ServiceKind::Vibe => (
            required_u64(&value, &["timings", "predicted_n"])?,
            required_string(&value, &["choices", "0", "message", "content"])
                .or_else(|_| required_string(&value, &["content"]))?,
        ),
        ServiceKind::Supra => (
            required_u64(&value, &["tokens_predicted"])
                .or_else(|_| required_u64(&value, &["timings", "predicted_n"]))?,
            required_string(&value, &["content"])?,
        ),
    };

    let expected_tokens = kind.expected_tokens();
    if tokens != expected_tokens {
        return Err(error(format!(
            "{} token count mismatch: expected {expected_tokens}, got {tokens}",
            kind.name()
        )));
    }

    if kind == ServiceKind::Supra {
        for fragment in SUPRA_REQUIRED_FRAGMENTS {
            if !content.contains(fragment) {
                return Err(error(format!(
                    "Supra response missing required fragment: {fragment}"
                )));
            }
        }
    }

    Ok(ParsedResponse {
        decode_tokens_per_second,
        tokens,
        content_blake3: blake3::hash(content.as_bytes()).to_hex().to_string(),
    })
}

fn median(values: &[f64]) -> Result<f64, AnyError> {
    if values.is_empty() {
        return Err(error("cannot calculate the median of an empty sample"));
    }
    if values.iter().any(|value| !value.is_finite()) {
        return Err(error("median sample contains a non-finite value"));
    }

    let mut ordered = values.to_vec();
    ordered.sort_by(f64::total_cmp);
    let middle = ordered.len() / 2;
    if ordered.len() % 2 == 1 {
        Ok(ordered[middle])
    } else {
        Ok((ordered[middle - 1] + ordered[middle]) / 2.0)
    }
}

fn summarize_service(samples: Vec<Sample>) -> Result<ServiceMetrics, AnyError> {
    if samples.is_empty() {
        return Err(error("service summary requires at least one sample"));
    }
    let decode_rates = samples
        .iter()
        .map(|sample| sample.decode_tokens_per_second)
        .collect::<Vec<_>>();
    let elapsed = samples
        .iter()
        .map(|sample| sample.elapsed_seconds)
        .collect::<Vec<_>>();

    Ok(ServiceMetrics {
        median_decode_tokens_per_second: median(&decode_rates)?,
        median_elapsed_seconds: median(&elapsed)?,
        samples,
    })
}

fn retention(concurrent: f64, isolated: f64) -> Result<f64, AnyError> {
    if !concurrent.is_finite() || !isolated.is_finite() || concurrent <= 0.0 || isolated <= 0.0 {
        return Err(error("retention inputs must be finite and positive"));
    }
    Ok(concurrent / isolated)
}

fn summarize(
    rounds: usize,
    isolated_vibe: Vec<Sample>,
    isolated_supra: Vec<Sample>,
    concurrent_vibe: Vec<Sample>,
    concurrent_supra: Vec<Sample>,
) -> Result<BenchmarkSummary, AnyError> {
    let isolated = PhaseMetrics {
        vibe: summarize_service(isolated_vibe)?,
        supra: summarize_service(isolated_supra)?,
    };
    let concurrent = PhaseMetrics {
        vibe: summarize_service(concurrent_vibe)?,
        supra: summarize_service(concurrent_supra)?,
    };
    let vibe_retention = retention(
        concurrent.vibe.median_decode_tokens_per_second,
        isolated.vibe.median_decode_tokens_per_second,
    )?;
    let supra_retention = retention(
        concurrent.supra.median_decode_tokens_per_second,
        isolated.supra.median_decode_tokens_per_second,
    )?;

    Ok(BenchmarkSummary {
        schema_version: SUMMARY_SCHEMA_VERSION,
        rounds,
        isolated,
        concurrent,
        concurrent_retention_geometric_mean: (vibe_retention * supra_retention).sqrt(),
        traffic_accounting: None,
    })
}

fn percent_change(baseline: f64, candidate: f64) -> Result<f64, AnyError> {
    if !baseline.is_finite() || !candidate.is_finite() || baseline <= 0.0 || candidate <= 0.0 {
        return Err(error("comparison values must be finite and positive"));
    }
    Ok(PERCENT_SCALE * (candidate - baseline) / baseline)
}

fn compare(
    baseline: &BenchmarkSummary,
    candidate: &BenchmarkSummary,
    tolerance_percent: f64,
) -> Result<Comparison, AnyError> {
    if !tolerance_percent.is_finite() || tolerance_percent <= 0.0 {
        return Err(error("tolerance percent must be finite and positive"));
    }

    let isolated_vibe_change_percent = percent_change(
        baseline.isolated.vibe.median_decode_tokens_per_second,
        candidate.isolated.vibe.median_decode_tokens_per_second,
    )?;
    let isolated_supra_change_percent = percent_change(
        baseline.isolated.supra.median_decode_tokens_per_second,
        candidate.isolated.supra.median_decode_tokens_per_second,
    )?;
    let concurrent_vibe_change_percent = percent_change(
        baseline.concurrent.vibe.median_decode_tokens_per_second,
        candidate.concurrent.vibe.median_decode_tokens_per_second,
    )?;
    let concurrent_supra_change_percent = percent_change(
        baseline.concurrent.supra.median_decode_tokens_per_second,
        candidate.concurrent.supra.median_decode_tokens_per_second,
    )?;
    let retention_change_percent = percent_change(
        baseline.concurrent_retention_geometric_mean,
        candidate.concurrent_retention_geometric_mean,
    )?;

    let mut reasons = Vec::new();
    for (name, change) in [
        ("isolated VibeThinker", isolated_vibe_change_percent),
        ("isolated Supra", isolated_supra_change_percent),
        ("concurrent VibeThinker", concurrent_vibe_change_percent),
        ("concurrent Supra", concurrent_supra_change_percent),
    ] {
        if change < -tolerance_percent {
            reasons.push(format!("{name} regressed by {:.2}%", change.abs()));
        }
    }

    let concurrent_material_gain = concurrent_vibe_change_percent > tolerance_percent
        || concurrent_supra_change_percent > tolerance_percent;
    if !concurrent_material_gain {
        reasons.push("neither concurrent service improved beyond tolerance".to_string());
    }
    if retention_change_percent <= tolerance_percent {
        reasons.push(format!(
            "normalized retention improved by only {retention_change_percent:.2}%"
        ));
    }

    Ok(Comparison {
        accepted: reasons.is_empty(),
        tolerance_percent,
        isolated_vibe_change_percent,
        isolated_supra_change_percent,
        concurrent_vibe_change_percent,
        concurrent_supra_change_percent,
        retention_change_percent,
        reasons,
    })
}

fn fetch_metric_snapshot(endpoint: &Endpoint) -> Result<MetricSnapshot, AnyError> {
    let output = Command::new(CURL_PROGRAM)
        .arg("--fail")
        .arg("--silent")
        .arg("--show-error")
        .arg("--max-time")
        .arg(REQUEST_TIMEOUT_SECONDS.to_string())
        .arg(&endpoint.metrics_url)
        .output()
        .map_err(|run_error| error(format!("failed to execute metrics curl: {run_error}")))?;
    if !output.status.success() {
        return Err(error(format!(
            "{} metrics request failed with {}",
            endpoint.kind.name(),
            output.status
        )));
    }
    let text = String::from_utf8(output.stdout)
        .map_err(|utf8_error| error(format!("metrics response is not UTF-8: {utf8_error}")))?;
    parse_metric_snapshot(&text)
}

fn ensure_quiescent(kind: ServiceKind, snapshot: &MetricSnapshot) -> Result<(), AnyError> {
    if snapshot.requests_processing != 0 {
        return Err(error(format!(
            "{} has {} request(s) already processing; benchmark would be contaminated",
            kind.name(),
            snapshot.requests_processing
        )));
    }
    Ok(())
}

fn checked_traffic_accounting(
    kind: ServiceKind,
    start: MetricSnapshot,
    end: MetricSnapshot,
    rounds: usize,
) -> Result<ServiceTrafficAccounting, AnyError> {
    ensure_quiescent(kind, &end)?;
    let predicted_token_delta = end
        .predicted_tokens_total
        .checked_sub(start.predicted_tokens_total)
        .ok_or_else(|| error(format!("{} predicted-token counter decreased", kind.name())))?;
    let request_count = rounds
        .checked_mul(2)
        .ok_or_else(|| error("benchmark request count overflow"))?;
    let expected_delta = u64::try_from(request_count)
        .map_err(|conversion_error| {
            error(format!(
                "request count conversion failed: {conversion_error}"
            ))
        })?
        .checked_mul(kind.expected_tokens())
        .ok_or_else(|| error("expected predicted-token delta overflow"))?;
    if predicted_token_delta != expected_delta {
        return Err(error(format!(
            "{} traffic accounting mismatch: expected {expected_delta} predicted tokens, observed {predicted_token_delta}; another client may have used the service",
            kind.name()
        )));
    }

    Ok(ServiceTrafficAccounting {
        start,
        end,
        predicted_token_delta,
    })
}

fn response_path(output_dir: &Path, phase: &str, kind: ServiceKind, round: usize) -> PathBuf {
    output_dir.join(format!("{phase}-{}-{round}.json", kind.name()))
}

fn run_request(
    endpoint: &Endpoint,
    phase: &str,
    round: usize,
    output_dir: &Path,
) -> Result<Sample, AnyError> {
    let output_path = response_path(output_dir, phase, endpoint.kind, round);
    let started = Instant::now();
    let status = Command::new(CURL_PROGRAM)
        .arg("--fail")
        .arg("--silent")
        .arg("--show-error")
        .arg("--max-time")
        .arg(REQUEST_TIMEOUT_SECONDS.to_string())
        .arg("--header")
        .arg("Content-Type: application/json")
        .arg("--data-binary")
        .arg(format!("@{}", endpoint.request_path.display()))
        .arg("--output")
        .arg(&output_path)
        .arg(&endpoint.url)
        .status()
        .map_err(|run_error| error(format!("failed to execute curl: {run_error}")))?;
    let elapsed_seconds = started.elapsed().as_secs_f64();

    if !status.success() {
        return Err(error(format!(
            "{} {phase} round {round} request failed with {status}",
            endpoint.kind.name()
        )));
    }

    let response = fs::read_to_string(&output_path).map_err(|read_error| {
        error(format!(
            "failed to read response {}: {read_error}",
            output_path.display()
        ))
    })?;
    let parsed = parse_response(endpoint.kind, &response)?;

    Ok(Sample {
        service: endpoint.kind,
        phase: phase.to_string(),
        round,
        elapsed_seconds,
        decode_tokens_per_second: parsed.decode_tokens_per_second,
        tokens: parsed.tokens,
        content_blake3: parsed.content_blake3,
    })
}

fn run_concurrent_round(
    vibe: Endpoint,
    supra: Endpoint,
    round: usize,
    output_dir: PathBuf,
) -> Result<(Sample, Sample), AnyError> {
    let participant_count = 3;
    let barrier = Arc::new(Barrier::new(participant_count));

    let vibe_barrier = Arc::clone(&barrier);
    let vibe_output = output_dir.clone();
    let vibe_handle = thread::spawn(move || {
        vibe_barrier.wait();
        run_request(&vibe, "concurrent", round, &vibe_output)
    });

    let supra_barrier = Arc::clone(&barrier);
    let supra_handle = thread::spawn(move || {
        supra_barrier.wait();
        run_request(&supra, "concurrent", round, &output_dir)
    });

    barrier.wait();
    let vibe_sample = vibe_handle
        .join()
        .map_err(|_| error("VibeThinker benchmark thread panicked"))??;
    let supra_sample = supra_handle
        .join()
        .map_err(|_| error("Supra benchmark thread panicked"))??;
    Ok((vibe_sample, supra_sample))
}

fn run_benchmark(
    output_dir: &Path,
    rounds: usize,
    vibe: Endpoint,
    supra: Endpoint,
) -> Result<BenchmarkSummary, AnyError> {
    if rounds == 0 {
        return Err(error("round count must be positive"));
    }
    if output_dir.exists() {
        return Err(error(format!(
            "output directory already exists: {}",
            output_dir.display()
        )));
    }
    let vibe_start = fetch_metric_snapshot(&vibe)?;
    let supra_start = fetch_metric_snapshot(&supra)?;
    ensure_quiescent(vibe.kind, &vibe_start)?;
    ensure_quiescent(supra.kind, &supra_start)?;

    fs::create_dir_all(output_dir).map_err(|create_error| {
        error(format!(
            "failed to create output directory {}: {create_error}",
            output_dir.display()
        ))
    })?;

    let mut isolated_vibe = Vec::with_capacity(rounds);
    let mut isolated_supra = Vec::with_capacity(rounds);
    for round in FIRST_ROUND..=rounds {
        if round % 2 == FIRST_ROUND {
            isolated_vibe.push(run_request(&vibe, "isolated", round, output_dir)?);
            isolated_supra.push(run_request(&supra, "isolated", round, output_dir)?);
        } else {
            isolated_supra.push(run_request(&supra, "isolated", round, output_dir)?);
            isolated_vibe.push(run_request(&vibe, "isolated", round, output_dir)?);
        }
    }

    let mut concurrent_vibe = Vec::with_capacity(rounds);
    let mut concurrent_supra = Vec::with_capacity(rounds);
    for round in FIRST_ROUND..=rounds {
        let (vibe_sample, supra_sample) =
            run_concurrent_round(vibe.clone(), supra.clone(), round, output_dir.to_path_buf())?;
        concurrent_vibe.push(vibe_sample);
        concurrent_supra.push(supra_sample);
    }

    let vibe_end = fetch_metric_snapshot(&vibe)?;
    let supra_end = fetch_metric_snapshot(&supra)?;
    let traffic_accounting = TrafficAccounting {
        vibe: checked_traffic_accounting(vibe.kind, vibe_start, vibe_end, rounds)?,
        supra: checked_traffic_accounting(supra.kind, supra_start, supra_end, rounds)?,
    };
    let mut summary = summarize(
        rounds,
        isolated_vibe,
        isolated_supra,
        concurrent_vibe,
        concurrent_supra,
    )?;
    summary.traffic_accounting = Some(traffic_accounting);
    Ok(summary)
}

fn read_summary(path: &Path) -> Result<BenchmarkSummary, AnyError> {
    let text = fs::read_to_string(path)
        .map_err(|read_error| error(format!("failed to read {}: {read_error}", path.display())))?;
    let summary: BenchmarkSummary = serde_json::from_str(&text).map_err(|parse_error| {
        error(format!("invalid summary {}: {parse_error}", path.display()))
    })?;
    if summary.schema_version != SUMMARY_SCHEMA_VERSION {
        return Err(error(format!(
            "unsupported summary schema version: {}",
            summary.schema_version
        )));
    }
    Ok(summary)
}

fn write_pretty_json(path: &Path, value: &impl Serialize) -> Result<(), AnyError> {
    let mut text = serde_json::to_string_pretty(value)
        .map_err(|serialize_error| error(format!("failed to serialize JSON: {serialize_error}")))?;
    text.push('\n');
    fs::write(path, text)
        .map_err(|write_error| error(format!("failed to write {}: {write_error}", path.display())))
}

fn parse_run_args(args: &[String]) -> Result<(PathBuf, usize, Endpoint, Endpoint), AnyError> {
    let mut output = None;
    let mut rounds = DEFAULT_ROUNDS;
    let mut vibe_url = None;
    let mut vibe_metrics_url = None;
    let mut vibe_request = None;
    let mut supra_url = None;
    let mut supra_metrics_url = None;
    let mut supra_request = None;
    let mut index = 0;

    while index < args.len() {
        let flag = &args[index];
        let value = args
            .get(index + 1)
            .ok_or_else(|| error(format!("missing value for {flag}")))?;
        match flag.as_str() {
            "--output" => output = Some(PathBuf::from(value)),
            "--rounds" => {
                rounds = value
                    .parse::<usize>()
                    .map_err(|parse_error| error(format!("invalid round count: {parse_error}")))?
            }
            "--vibe-url" => vibe_url = Some(value.clone()),
            "--vibe-metrics-url" => vibe_metrics_url = Some(value.clone()),
            "--vibe-request" => vibe_request = Some(PathBuf::from(value)),
            "--supra-url" => supra_url = Some(value.clone()),
            "--supra-metrics-url" => supra_metrics_url = Some(value.clone()),
            "--supra-request" => supra_request = Some(PathBuf::from(value)),
            _ => return Err(error(format!("unknown run option: {flag}"))),
        }
        index += 2;
    }

    let vibe = Endpoint {
        kind: ServiceKind::Vibe,
        url: vibe_url.ok_or_else(|| error("missing --vibe-url"))?,
        metrics_url: vibe_metrics_url.ok_or_else(|| error("missing --vibe-metrics-url"))?,
        request_path: vibe_request.ok_or_else(|| error("missing --vibe-request"))?,
    };
    let supra = Endpoint {
        kind: ServiceKind::Supra,
        url: supra_url.ok_or_else(|| error("missing --supra-url"))?,
        metrics_url: supra_metrics_url.ok_or_else(|| error("missing --supra-metrics-url"))?,
        request_path: supra_request.ok_or_else(|| error("missing --supra-request"))?,
    };

    Ok((
        output.ok_or_else(|| error("missing --output"))?,
        rounds,
        vibe,
        supra,
    ))
}

fn parse_compare_args(args: &[String]) -> Result<(PathBuf, PathBuf, f64), AnyError> {
    let mut baseline = None;
    let mut candidate = None;
    let mut tolerance = DEFAULT_TOLERANCE_PERCENT;
    let mut index = 0;

    while index < args.len() {
        let flag = &args[index];
        let value = args
            .get(index + 1)
            .ok_or_else(|| error(format!("missing value for {flag}")))?;
        match flag.as_str() {
            "--baseline" => baseline = Some(PathBuf::from(value)),
            "--candidate" => candidate = Some(PathBuf::from(value)),
            "--tolerance-percent" => {
                tolerance = value.parse::<f64>().map_err(|parse_error| {
                    error(format!("invalid tolerance percent: {parse_error}"))
                })?
            }
            _ => return Err(error(format!("unknown compare option: {flag}"))),
        }
        index += 2;
    }

    Ok((
        baseline.ok_or_else(|| error("missing --baseline"))?,
        candidate.ok_or_else(|| error("missing --candidate"))?,
        tolerance,
    ))
}

fn synthetic_sample(kind: ServiceKind, phase: &str, round: usize, rate: f64) -> Sample {
    Sample {
        service: kind,
        phase: phase.to_string(),
        round,
        elapsed_seconds: 1.0 / rate,
        decode_tokens_per_second: rate,
        tokens: kind.expected_tokens(),
        content_blake3: "self-test".to_string(),
    }
}

fn synthetic_summary(
    isolated_vibe_rate: f64,
    isolated_supra_rate: f64,
    concurrent_vibe_rate: f64,
    concurrent_supra_rate: f64,
) -> BenchmarkSummary {
    summarize(
        FIRST_ROUND,
        vec![synthetic_sample(
            ServiceKind::Vibe,
            "isolated",
            FIRST_ROUND,
            isolated_vibe_rate,
        )],
        vec![synthetic_sample(
            ServiceKind::Supra,
            "isolated",
            FIRST_ROUND,
            isolated_supra_rate,
        )],
        vec![synthetic_sample(
            ServiceKind::Vibe,
            "concurrent",
            FIRST_ROUND,
            concurrent_vibe_rate,
        )],
        vec![synthetic_sample(
            ServiceKind::Supra,
            "concurrent",
            FIRST_ROUND,
            concurrent_supra_rate,
        )],
    )
    .expect("valid synthetic summary")
}

fn self_test() -> Result<(), AnyError> {
    let vibe_json = json!({
        "timings": {
            "predicted_n": VIBE_EXPECTED_TOKENS,
            "predicted_per_second": 20.0
        },
        "choices": [{"message": {"content": "deterministic answer"}}]
    });
    let supra_json = json!({
        "timings": {
            "predicted_n": SUPRA_EXPECTED_TOKENS,
            "predicted_per_second": 150.0
        },
        "tokens_predicted": SUPRA_EXPECTED_TOKENS,
        "content": "| Complexity: 2 | Route: small |"
    });
    assert_eq!(
        parse_response(ServiceKind::Vibe, &vibe_json.to_string())?.tokens,
        VIBE_EXPECTED_TOKENS
    );
    assert_eq!(
        parse_response(ServiceKind::Supra, &supra_json.to_string())?.tokens,
        SUPRA_EXPECTED_TOKENS
    );
    assert_eq!(median(&[3.0, 1.0, 2.0])?, 2.0);
    assert_eq!(median(&[4.0, 1.0, 2.0, 3.0])?, 2.5);
    let metric_snapshot = parse_metric_snapshot(
        "llamacpp:tokens_predicted_total 640\nllamacpp:requests_processing 0\n",
    )?;
    assert_eq!(metric_snapshot.predicted_tokens_total, 640);
    assert_eq!(metric_snapshot.requests_processing, 0);

    let baseline = synthetic_summary(20.0, 150.0, 18.0, 60.0);
    let accepted_candidate = synthetic_summary(20.0, 150.0, 18.5, 75.0);
    let accepted = compare(&baseline, &accepted_candidate, DEFAULT_TOLERANCE_PERCENT)?;
    assert!(
        accepted.accepted,
        "positive comparison must pass: {accepted:?}"
    );

    let regressed_candidate = synthetic_summary(18.0, 150.0, 16.0, 80.0);
    let rejected = compare(&baseline, &regressed_candidate, DEFAULT_TOLERANCE_PERCENT)?;
    assert!(!rejected.accepted, "negative comparison must fail");
    assert!(
        rejected
            .reasons
            .iter()
            .any(|reason| reason.contains("isolated VibeThinker"))
    );

    assert!(parse_response(ServiceKind::Vibe, "not-json").is_err());
    let wrong_tokens = json!({
        "timings": {"predicted_n": 1, "predicted_per_second": 20.0},
        "choices": [{"message": {"content": "answer"}}]
    });
    assert!(parse_response(ServiceKind::Vibe, &wrong_tokens.to_string()).is_err());
    let missing_schema = json!({
        "timings": {
            "predicted_n": SUPRA_EXPECTED_TOKENS,
            "predicted_per_second": 150.0
        },
        "tokens_predicted": SUPRA_EXPECTED_TOKENS,
        "content": "missing routing schema"
    });
    assert!(parse_response(ServiceKind::Supra, &missing_schema.to_string()).is_err());
    assert!(median(&[]).is_err());
    assert!(parse_metric_snapshot("llamacpp:requests_processing 0\n").is_err());
    assert!(
        ensure_quiescent(
            ServiceKind::Vibe,
            &MetricSnapshot {
                predicted_tokens_total: 0,
                requests_processing: 1,
            },
        )
        .is_err()
    );
    assert!(
        checked_traffic_accounting(
            ServiceKind::Supra,
            MetricSnapshot {
                predicted_tokens_total: 100,
                requests_processing: 0,
            },
            MetricSnapshot {
                predicted_tokens_total: 101,
                requests_processing: 0,
            },
            FIRST_ROUND,
        )
        .is_err()
    );

    println!("benchmark-p150-concurrent self-test passed");
    Ok(())
}

fn usage(program: &str) {
    eprintln!(
        "Usage:\n  {program} self-test\n  {program} run --output DIR --vibe-url URL --vibe-metrics-url URL --vibe-request FILE --supra-url URL --supra-metrics-url URL --supra-request FILE [--rounds N]\n  {program} compare --baseline SUMMARY --candidate SUMMARY [--tolerance-percent N]"
    );
}

fn main() -> Result<(), AnyError> {
    let args = env::args().collect::<Vec<_>>();
    let program = args
        .first()
        .map(String::as_str)
        .unwrap_or("benchmark-p150-concurrent");
    let command = args.get(1).map(String::as_str).unwrap_or("");

    match command {
        "self-test" => self_test(),
        "run" => {
            let (output_dir, rounds, vibe, supra) = parse_run_args(&args[2..])?;
            let summary = run_benchmark(&output_dir, rounds, vibe, supra)?;
            let summary_path = output_dir.join(SUMMARY_FILE_NAME);
            write_pretty_json(&summary_path, &summary)?;
            println!("{}", serde_json::to_string_pretty(&summary)?);
            Ok(())
        }
        "compare" => {
            let (baseline_path, candidate_path, tolerance_percent) =
                parse_compare_args(&args[2..])?;
            let baseline = read_summary(&baseline_path)?;
            let candidate = read_summary(&candidate_path)?;
            let comparison = compare(&baseline, &candidate, tolerance_percent)?;
            println!("{}", serde_json::to_string_pretty(&comparison)?);
            if comparison.accepted {
                Ok(())
            } else {
                Err(error(
                    "candidate failed the concurrent-serving acceptance rule",
                ))
            }
        }
        _ => {
            usage(program);
            Err(error("missing or unsupported command"))
        }
    }
}
