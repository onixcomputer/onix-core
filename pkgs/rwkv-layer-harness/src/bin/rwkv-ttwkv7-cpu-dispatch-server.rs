use rwkv_layer_harness::emulate_ttwkv7_dispatch_response_frame;
use serde::Serialize;
use std::error::Error;
use std::fs::OpenOptions;
use std::io::{self, Read, Write};
use std::path::Path;
use std::process::ExitCode;

const SERVER_MODE: &str = "dispatch-server";
const EXPECTED_ARGUMENT_COUNT: usize = 2;
const SERVER_SUMMARY_ENVIRONMENT: &str = "RWKV_TTWKV7_DISPATCH_SERVER_SUMMARY";
const FAULT_ENVIRONMENT: &str = "RWKV_TTWKV7_CPU_SERVER_FAULT";
const TRUNCATED_FAULT: &str = "truncated";
const STALE_FAULT: &str = "stale";
const EARLY_EXIT_FAULT: &str = "early-exit";
const REQUEST_FRAME_BYTE_COUNT: usize = 107588;
const RESPONSE_FRAME_BYTE_COUNT: usize = 99940;
const DISPATCH_CALL_COUNT: usize = 24;
const SAME_LAYER_CONTINUITY_COUNT: usize = 12;
const SCHEMA_VERSION: u32 = 1;
const TRANSCRIPT_DOMAIN: &[u8] = b"rwkv-ttwkv7-dispatch-abi-transcript-v1";

#[derive(Serialize)]
struct CpuServerSummary {
    schema_version: u32,
    target: &'static str,
    call_count: usize,
    device_open_count: usize,
    workload_enqueue_count: usize,
    request_frame_byte_count: usize,
    response_frame_byte_count: usize,
    same_layer_state_continuity_count: usize,
    ordered_request_blake3: Vec<String>,
    ordered_response_blake3: Vec<String>,
    runtime_argument_blake3: Vec<String>,
    transcript_blake3: String,
    terminal_state: &'static str,
    test_only_cpu_server: bool,
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("rwkv-ttwkv7-cpu-dispatch-server: {error}");
            ExitCode::FAILURE
        }
    }
}

fn run() -> Result<(), Box<dyn Error>> {
    let arguments = std::env::args().collect::<Vec<_>>();
    if arguments.len() != EXPECTED_ARGUMENT_COUNT || arguments[1] != SERVER_MODE {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "rwkv-ttwkv7-cpu-dispatch-server accepts only dispatch-server",
        )
        .into());
    }
    let summary_path = std::env::var_os(SERVER_SUMMARY_ENVIRONMENT).ok_or_else(|| {
        io::Error::new(
            io::ErrorKind::InvalidInput,
            "CPU dispatch server summary path is not configured",
        )
    })?;
    let summary_path = Path::new(&summary_path);
    if !summary_path.is_absolute() || summary_path.starts_with("/nix/store") {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "CPU dispatch server summary path must be absolute and outside /nix/store",
        )
        .into());
    }
    let fault = std::env::var(FAULT_ENVIRONMENT).unwrap_or_default();
    if !fault.is_empty()
        && fault != TRUNCATED_FAULT
        && fault != STALE_FAULT
        && fault != EARLY_EXIT_FAULT
    {
        return Err(invalid_data(format!("unknown CPU server fault: {fault}")).into());
    }
    let mut input = io::stdin().lock();
    let mut output = io::stdout().lock();
    let mut ordered_request_blake3 = Vec::with_capacity(DISPATCH_CALL_COUNT);
    let mut ordered_response_blake3 = Vec::with_capacity(DISPATCH_CALL_COUNT);
    let mut transcript = blake3::Hasher::new();
    transcript.update(TRANSCRIPT_DOMAIN);
    let mut previous_response = None;
    for call in 0..DISPATCH_CALL_COUNT {
        if fault == EARLY_EXIT_FAULT && call == 0 {
            return Err(invalid_data("injected early exit".to_owned()).into());
        }
        let mut request = vec![0_u8; REQUEST_FRAME_BYTE_COUNT];
        input.read_exact(&mut request)?;
        let generated = emulate_ttwkv7_dispatch_response_frame(&request).map_err(invalid_data)?;
        if generated.len() != RESPONSE_FRAME_BYTE_COUNT {
            return Err(invalid_data("CPU dispatch response size changed".to_owned()).into());
        }
        let response = if fault == STALE_FAULT && call == 1 {
            previous_response
                .clone()
                .ok_or_else(|| invalid_data("stale response fixture is absent".to_owned()))?
        } else {
            generated
        };
        if fault == TRUNCATED_FAULT && call == 0 {
            let truncated_length = response
                .len()
                .checked_sub(1)
                .ok_or_else(|| invalid_data("response fixture is empty".to_owned()))?;
            output.write_all(&response[..truncated_length])?;
            output.flush()?;
            return Err(invalid_data("injected truncated response".to_owned()).into());
        }
        ordered_request_blake3.push(blake3::hash(&request).to_hex().to_string());
        ordered_response_blake3.push(blake3::hash(&response).to_hex().to_string());
        update_transcript(&mut transcript, &request, &response)?;
        output.write_all(&response)?;
        output.flush()?;
        previous_response = Some(response);
    }
    let mut trailing = Vec::new();
    input.read_to_end(&mut trailing)?;
    if !trailing.is_empty() {
        return Err(
            invalid_data("CPU dispatch request stream contains trailing data".to_owned()).into(),
        );
    }
    let summary = CpuServerSummary {
        schema_version: SCHEMA_VERSION,
        target: "rwkv_ttwkv7_persistent_dispatch_server",
        call_count: DISPATCH_CALL_COUNT,
        device_open_count: 0,
        workload_enqueue_count: 0,
        request_frame_byte_count: REQUEST_FRAME_BYTE_COUNT,
        response_frame_byte_count: RESPONSE_FRAME_BYTE_COUNT,
        same_layer_state_continuity_count: SAME_LAYER_CONTINUITY_COUNT,
        runtime_argument_blake3: ordered_request_blake3.clone(),
        transcript_blake3: transcript.finalize().to_hex().to_string(),
        ordered_request_blake3,
        ordered_response_blake3,
        terminal_state: "closed",
        test_only_cpu_server: true,
    };
    let mut summary_bytes = serde_json::to_vec(&summary)?;
    summary_bytes.push(b'\n');
    let mut file = OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(summary_path)?;
    file.write_all(&summary_bytes)?;
    file.flush()?;
    file.sync_all()?;
    Ok(())
}

fn update_transcript(
    transcript: &mut blake3::Hasher,
    request: &[u8],
    response: &[u8],
) -> Result<(), Box<dyn Error>> {
    let request_length = u64::try_from(request.len())
        .map_err(|_| invalid_data("request length does not fit u64".to_owned()))?;
    let response_length = u64::try_from(response.len())
        .map_err(|_| invalid_data("response length does not fit u64".to_owned()))?;
    transcript.update(&request_length.to_le_bytes());
    transcript.update(request);
    transcript.update(&response_length.to_le_bytes());
    transcript.update(response);
    Ok(())
}

fn invalid_data(message: String) -> io::Error {
    io::Error::new(io::ErrorKind::InvalidData, message)
}
