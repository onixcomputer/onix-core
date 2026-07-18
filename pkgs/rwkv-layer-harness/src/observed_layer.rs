use super::*;
use serde::de::DeserializeOwned;
use std::collections::BTreeMap;

const OBSERVED_TARGET: &str = "rwkv_ttwkv7_observed_layer_replay";
const OBSERVED_PLAN_ID: &str = "d4886116b76df2cf63090e3a1f7efff35aa215aa2d05652d7accaa9b61a9abb1";
const OBSERVED_SESSION_ID: &str = "rwkv-ttwkv7-boundary-device-2";
const OBSERVED_SESSION_OUTCOME: &str = "unsafe";
const OBSERVED_SAFETY_ISSUE: &str = "owner health status did not match the manifest";
const OBSERVED_SUCCESS_MARKER: &str = "rwkv ttWKV7 boundary device probe: PASS";
const OBSERVED_RUN_ROOT: &str = "/var/tmp/rwkv-ttwkv7-boundary-device-2";
const OBSERVED_DEVICE_PATH: &str = "/dev/tenstorrent/1";
const OBSERVED_ARCHITECTURE: &str = "Blackhole P150";
const OBSERVED_OWNER_UNIT: &str = "docker-tt-inference-server-llama-3-1-8b-instruct-p150.service";
const OBSERVED_PACKAGE_PATH: &str =
    "/nix/store/av4m3qy5m0qjvrrfrn1dckjxnd7vzbkv-rwkv-ttwkv7-boundary-device-0.2.0";
const OBSERVED_KERNEL_PATH: &str =
    "/nix/store/5alwcj7ff65s1zg6q475akwayafmh0bz-ttwkv7-unstable-2026-06-22/share/ttwkv7/kernels";
const OBSERVED_EXECUTABLE_PATH: &str = "/nix/store/av4m3qy5m0qjvrrfrn1dckjxnd7vzbkv-rwkv-ttwkv7-boundary-device-0.2.0/bin/wkv7-rwkv-boundary";
const OBSERVED_OWNER_CONTROL_PATH: &str =
    "/nix/store/6m9zwmdfc1vyrxw2znbl39s78bz73ycp-ttwkv7-owner-control/bin/ttwkv7-owner-control";
const OBSERVED_INSPECTOR_ADDRESS: &str = "127.0.0.1:43147";
const OBSERVED_HEALTH_URL: &str = "http://127.0.0.1:8000/health";
const OBSERVED_ARGUMENT: &str = "probe";
const OBSERVED_STAGE: &str = "operator";
const OBSERVED_PROCESS_COUNT: usize = 1;
const OBSERVED_PHYSICAL_DEVICE: usize = 1;
const OBSERVED_PROCESS_TIMEOUT_SECONDS: usize = 900;
const OBSERVED_TIMEOUT_EXIT_STATUS: i32 = 124;
const OBSERVED_KILL_GRACE_SECONDS: usize = 10;
const OBSERVED_ROLLBACK_DELAY_SECONDS: usize = 1_200;
const OBSERVED_HEALTH_STATUS: u16 = 200;
const OBSERVED_NMSE_CEILING: f64 = 6.0e-2;
const OBSERVED_OUTPUT_BYTE_COUNT: usize = HIDDEN_SIZE * BF16_BYTE_WIDTH;
const OBSERVED_STATE_ELEMENT_COUNT: usize = HEAD_COUNT * HEAD_SIZE * HEAD_SIZE;
const OBSERVED_STATE_BYTE_COUNT: usize = OBSERVED_STATE_ELEMENT_COUNT * BF16_BYTE_WIDTH;
const OBSERVED_WRITER_ELEMENT_COUNT: usize = 73_728;
const OBSERVED_WRITER_BYTE_COUNT: usize = OBSERVED_WRITER_ELEMENT_COUNT * BF16_BYTE_WIDTH;
const OBSERVED_SCHEMA_VERSION: u32 = 1;
const OBSERVED_ARTIFACT_ROLE_COUNT: usize = 8;
const OBSERVED_DEVICE_ARTIFACT_COUNT: usize = 3;
const ZERO_DEVIATION: f32 = 0.0;
const OBSERVED_EVIDENCE_HASH_DOMAIN: &[u8] = b"rwkv-ttwkv7-observed-layer-evidence-v1";
const OBSERVED_CLASSIFICATION_BLAKE3: &str =
    "30577762498fccc1f00c29c9ec01d9cacdc509a332211ff6ef7e8fa67fc1f9bd";
const OBSERVED_SESSION_EVIDENCE_BLAKE3: &str =
    "612a4156b76771911297fb762f3e3ba0ea2792c1d839d61cd1824d122c923aa7";
const OBSERVED_DIAGNOSTIC_BLAKE3: &str =
    "6fba33e0b51530d63346415f25565283f68b05e0260d7f89024abb58bac60fdd";
const OBSERVED_BOARD_BLAKE3: &str =
    "532278a6f786713d51e5a1e36450d1fd64555f2e5ad947ff548b88a06d709ab6";
const OBSERVED_OWNER_BLAKE3: &str =
    "ca21ead27b78c78bf3bf23fa04f42cc3922190ca93e1cdedc1d64b36c5b24d85";
const OBSERVED_BOUNDARY_MANIFEST_BLAKE3: &str =
    "7f62e65f31033b12709a19897fb81779c8236e187ab734a56d6c553bf36550e9";
const OBSERVED_PREPARED_BLAKE3: &str =
    "4e14b262c41077507987002d1a48bed1a3af58e342ac26ad0379caac52ae50cd";
const OBSERVED_BOUNDARY_RECEIPT_BLAKE3: &str =
    "ed95aeeeef6fd579f5b257c6ff7fe63eeae260f616e6a52b9b192c9b37f35436";
const OBSERVED_WRITER_BLAKE3: &str =
    "a8d4304ca77c69cb58e55360755acd25a5847a2ca5884fbe807fe634d89a0c18";
const OBSERVED_OUTPUT_BLAKE3: &str =
    "417a583d87e901c5488266e84f3f9cfba98e2bbe45fc8da952c8cb4b06afc66a";
const OBSERVED_POST_STATE_BLAKE3: &str =
    "b3321aeb38963fb96a720ae33d9477e8fbfb83b3750213abc64786885d3771a9";
const OBSERVED_PLAN_RECEIPT_BLAKE3: &str =
    "307efa0052ae9b5b003d7c6026ba0340e527cbea4a6e057bfa70df84c53e0291";
const OBSERVED_SESSION_MANIFEST_BLAKE3: &str =
    "d248124f88d5cd933cf6a5c6335ab8a7e9cbad5e59289380c16bbda9b3c82812";
const EXPECTED_BOUNDARY_OUTPUT_BLAKE3: &str =
    "9af55cd740a0534c91e6656da5e0fca63386e06ded01d183157d07cba6ea50e8";
const EXPECTED_BOUNDARY_POST_STATE_BLAKE3: &str =
    "c76c943bab4cda028b5edae8393919ae3f93f35b79b6a02648d4617e21b414d6";
const EXPECTED_ORDERED_ARTIFACT_BLAKE3: &str =
    "44d91ad223079fa9ae5f6f0dc9943fc6d13cc25cb09262111ad433c7e6288494";
const EXPECTED_FIXTURE_BLAKE3: &str =
    "731f44866c869300ca330f703f1adad4c3ae7ee62b832fa881a6bf4ea90211cd";
const EXPECTED_READER_BLAKE3: &str =
    "221a9e9cb987902e99e4e50bfe5dce2d9f44a5252720b5d3dcbd13fbadb85fca";
const EXPECTED_COMPUTE_BLAKE3: &str =
    "bbda1f84aa2fcef7a946de76e0a0a03202e068c822f54b80c9cab5f4e13e35d0";
const EXPECTED_WRITER_BLAKE3: &str =
    "80ecf2f848144aa1a693f6b3b854542d2fd752bed8c83d9cbce31bd16e261b74";
const EXPECTED_RUNTIME_ARGUMENT_BLAKE3: &str =
    "63721d96d69b5d525a2c32e1e31bbc3b3804bef7419fc5fc4bd72bcb9b04061b";
const EXPECTED_COMBINED_DEVICE_EVIDENCE_BLAKE3: &str =
    "31e0cca463afef9e89b004b2b1cb20b2001aec3c274e399a3ccd15b1f0243585";
const EXPECTED_SOURCE_LAYER_OUTPUT_BLAKE3: &str =
    "cca5dded173404e19115bc749f25aab0c26200282a739bb3da98923d2d9a8e26";
const EXPECTED_SOURCE_STATE_BLAKE3: &str =
    "63718d8139e7a70770d8ca7b0663faca0d87ea3d5b99a45a5d895a827cec868f";
const EXPECTED_OWNER_PROPERTIES: &str =
    "ActiveState=active\nSubState=running\nResult=success\nNRestarts=0\n";
const EXPECTED_BOUNDARY_MANIFEST: &str = "role\tfilename\telements\tbytes\tblake3\nobserved_output_bf16\tobserved-output.bf16\t768\t1536\t417a583d87e901c5488266e84f3f9cfba98e2bbe45fc8da952c8cb4b06afc66a\nobserved_post_state_bf16\tobserved-post-state.bf16\t49152\t98304\tb3321aeb38963fb96a720ae33d9477e8fbfb83b3750213abc64786885d3771a9\nwriter_raw_bf16\twriter-raw.bf16\t73728\t147456\ta8d4304ca77c69cb58e55360755acd25a5847a2ca5884fbe807fe634d89a0c18\n";
const OBSERVED_NON_CLAIMS: [&str; 8] = [
    "The terminal rwkv-lab session remains unsafe despite later owner health recovery.",
    "No exact BF16 parity is established by a tolerance pass.",
    "No complete RWKV layer ran wholly on a Tenstorrent device.",
    "No all-layer device execution is established.",
    "No hardware-backed token generation is established.",
    "No general P150 compatibility is established.",
    "No serving, throughput, or latency claim is established.",
    "No new hardware execution is authorized by this replay.",
];
const STATE_CARRY_TARGET: &str = "rwkv_ttwkv7_observed_state_carry";
const STATE_CARRY_TOKEN_COUNT: usize = 3;
const STATE_CARRY_OBSERVED_RECEIPT_BLAKE3: &str =
    "0f2e08a9966672ab8d076ec2a601e336c0e0022ea4af023e472a7bbc05ba6d18";
const STATE_CARRY_RESET_STATE_DIVERGENCE_FLOOR: f32 = 1.0e-7;
const STATE_CARRY_RESET_OUTPUT_DIVERGENCE_FLOOR: f32 = 1.0e-7;
const STATE_CARRY_NON_CLAIMS: [&str; 9] = [
    "The terminal rwkv-lab session remains unsafe and is not reclassified.",
    "The next recurrent WKV step is executed by the CPU equation, not physical hardware.",
    "BF16 transport emulation does not establish a physical next-step WKV execution.",
    "No complete RWKV layer ran wholly on a Tenstorrent device.",
    "No all-layer retained-state execution is established.",
    "No hardware-backed token generation is established.",
    "No general P150 compatibility is established.",
    "No serving, throughput, or latency claim is established.",
    "No new hardware execution is authorized by this replay.",
];
const MODEL_CARRY_TARGET: &str = "rwkv_ttwkv7_observed_model_carry";
const MODEL_CARRY_TOKEN_COUNT: usize = 3;
const MODEL_CARRY_PHYSICAL_TOKEN_ORDINAL: usize = 2;
const MODEL_CARRY_PHYSICAL_WKV_COUNT: usize = 1;
const MODEL_CARRY_CPU_SECOND_TOKEN_LAYER_COUNT: usize = MODEL_LAYER_COUNT - 1;
const MODEL_CARRY_CPU_THIRD_TOKEN_LAYER_COUNT: usize = MODEL_LAYER_COUNT;
const MODEL_CARRY_STATE_RECEIPT_BLAKE3: &str =
    "58e433a04a10319293b18d6003659b53a04a95e9cf9cc7b540c2448c98ed6a33";
const MODEL_CARRY_DIVERGENCE_FLOOR: f32 = 1.0e-7;
const MODEL_CARRY_NON_CLAIMS: [&str; 11] = [
    "The terminal rwkv-lab session remains unsafe and is not reclassified.",
    "Only the accepted layer-zero second-token WKV output and post-state came from physical execution.",
    "The third-token layer-zero WKV step is executed by the CPU equation with BF16 transport emulation.",
    "Second-token layers 1 through 11 and all third-token layers execute on CPU.",
    "No complete RWKV layer ran wholly on a Tenstorrent device.",
    "No complete RWKV model ran wholly on Tenstorrent devices.",
    "The selected logits do not establish hardware-backed token generation.",
    "No general P150 compatibility is established.",
    "No serving, throughput, or latency claim is established.",
    "No additional physical workload is executed by this replay.",
    "No new hardware execution is authorized by this replay.",
];

pub struct Ttwkv7ObservedLayerEvidence<'a> {
    pub classification_receipt: &'a [u8],
    pub session_evidence: &'a [u8],
    pub diagnostic_log: &'a [u8],
    pub board_after: &'a [u8],
    pub owner_after: &'a [u8],
    pub boundary_manifest: &'a [u8],
    pub prepared_receipt: &'a [u8],
    pub boundary_receipt: &'a [u8],
    pub writer_raw_bf16: &'a [u8],
    pub observed_output_bf16: &'a [u8],
    pub observed_post_state_bf16: &'a [u8],
    pub session_manifest: &'a [u8],
    pub plan_receipt: &'a [u8],
}

#[derive(Clone, Debug, Serialize)]
pub struct ObservedEvidenceAuthorityReceipt {
    pub plan_id: &'static str,
    pub session_id: &'static str,
    pub terminal_outcome: &'static str,
    pub terminal_safety_issue: &'static str,
    pub classification_receipt_blake3: &'static str,
    pub session_evidence_blake3: &'static str,
    pub diagnostic_log_blake3: &'static str,
    pub board_after_blake3: &'static str,
    pub owner_after_blake3: &'static str,
    pub boundary_manifest_blake3: &'static str,
    pub prepared_receipt_blake3: &'static str,
    pub boundary_receipt_blake3: &'static str,
    pub writer_raw_bf16_blake3: &'static str,
    pub observed_output_bf16_blake3: &'static str,
    pub observed_post_state_bf16_blake3: &'static str,
    pub session_manifest_blake3: &'static str,
    pub plan_receipt_blake3: &'static str,
    pub evidence_bundle_blake3: String,
}

#[derive(Clone, Debug, Serialize)]
pub struct ObservedHardwareComparisonReceipt {
    pub nmse_ceiling: f64,
    pub output_nmse: f64,
    pub output_pcc: f64,
    pub output_maximum_absolute_error: f64,
    pub output_exact_bit_mismatch_count: usize,
    pub post_state_nmse: f64,
    pub post_state_pcc: f64,
    pub post_state_maximum_absolute_error: f64,
    pub post_state_exact_bit_mismatch_count: usize,
    pub device_initialized: bool,
    pub workload_enqueue_count: usize,
    pub process_exit_status: i32,
    pub process_timed_out: bool,
    pub terminal_owner_active: bool,
    pub terminal_owner_health_status: Option<u16>,
    pub terminal_board_healthy: bool,
}

#[derive(Clone, Debug, Serialize)]
pub struct ObservedLayerPathReceipt {
    pub raw_wkv_output: NumericReceipt,
    pub post_state: NumericReceipt,
    pub attention_output: NumericReceipt,
    pub final_layer_output: NumericReceipt,
}

#[derive(Clone, Debug, Serialize)]
pub struct ObservedLayerDeviationReceipt {
    pub expected_raw_output_vs_source_fp32: f32,
    pub observed_raw_output_vs_expected_bf16: f32,
    pub observed_raw_output_vs_source_fp32: f32,
    pub expected_post_state_vs_source_fp32: f32,
    pub observed_post_state_vs_expected_bf16: f32,
    pub observed_post_state_vs_source_fp32: f32,
    pub expected_attention_output_vs_source_fp32: f32,
    pub observed_attention_output_vs_expected_bf16: f32,
    pub observed_attention_output_vs_source_fp32: f32,
    pub expected_final_layer_output_vs_source_fp32: f32,
    pub observed_final_layer_output_vs_expected_bf16: f32,
    pub observed_final_layer_output_vs_source_fp32: f32,
}

#[derive(Clone, Debug, Serialize)]
pub struct Ttwkv7ObservedLayerReplayReceipt {
    pub schema_version: u32,
    pub target: &'static str,
    pub model: ModelReceipt,
    pub dimensions: Dimensions,
    pub layer_index: usize,
    pub prefix_token_ids: [usize; TOKEN_COUNT],
    pub evidence: ObservedEvidenceAuthorityReceipt,
    pub hardware_comparison: ObservedHardwareComparisonReceipt,
    pub source_fp32: ObservedLayerPathReceipt,
    pub expected_bf16_boundary: ObservedLayerPathReceipt,
    pub observed_device: ObservedLayerPathReceipt,
    pub maximum_absolute_deviations: ObservedLayerDeviationReceipt,
    pub non_claims: Vec<&'static str>,
}

#[derive(Clone, Debug, Serialize)]
pub struct StateCarryWkvInputReceipt {
    pub r: NumericReceipt,
    pub w: NumericReceipt,
    pub k: NumericReceipt,
    pub v: NumericReceipt,
    pub a: NumericReceipt,
    pub b: NumericReceipt,
}

#[derive(Clone, Debug, Serialize)]
pub struct StateCarryPathReceipt {
    pub wkv_executor: &'static str,
    pub transport_precision: &'static str,
    pub seed_attention_previous: NumericReceipt,
    pub seed_ffn_previous: NumericReceipt,
    pub wkv_inputs: StateCarryWkvInputReceipt,
    pub pre_state: NumericReceipt,
    pub raw_wkv_output: NumericReceipt,
    pub post_state: NumericReceipt,
    pub attention_output: NumericReceipt,
    pub ffn_input: NumericReceipt,
    pub final_layer_output: NumericReceipt,
}

#[derive(Clone, Debug, Serialize)]
pub struct StateCarryDeviationReceipt {
    pub expected_raw_output_vs_source_fp32: f32,
    pub observed_raw_output_vs_expected_bf16: f32,
    pub observed_raw_output_vs_source_fp32: f32,
    pub expected_post_state_vs_source_fp32: f32,
    pub observed_post_state_vs_expected_bf16: f32,
    pub observed_post_state_vs_source_fp32: f32,
    pub expected_final_layer_output_vs_source_fp32: f32,
    pub observed_final_layer_output_vs_expected_bf16: f32,
    pub observed_final_layer_output_vs_source_fp32: f32,
    pub observed_post_state_vs_reset_state: f32,
    pub observed_final_layer_output_vs_reset_state: f32,
    pub observed_post_state_vs_transposed_state: f32,
    pub observed_final_layer_output_vs_transposed_state: f32,
}

#[derive(Clone, Debug, Serialize)]
pub struct Ttwkv7ObservedStateCarryReceipt {
    pub schema_version: u32,
    pub target: &'static str,
    pub model: ModelReceipt,
    pub dimensions: Dimensions,
    pub layer_index: usize,
    pub token_ids: [usize; STATE_CARRY_TOKEN_COUNT],
    pub observed_layer_receipt_blake3: String,
    pub terminal_session_outcome: &'static str,
    pub evidence_bundle_blake3: String,
    pub physical_seed_post_state_blake3: &'static str,
    pub source_fp32: StateCarryPathReceipt,
    pub expected_bf16_boundary: StateCarryPathReceipt,
    pub observed_physical_state_cpu_continuation: StateCarryPathReceipt,
    pub reset_state_control: StateCarryPathReceipt,
    pub transposed_state_control: StateCarryPathReceipt,
    pub maximum_absolute_deviations: StateCarryDeviationReceipt,
    pub reset_state_divergence_floor: f32,
    pub reset_output_divergence_floor: f32,
    pub non_claims: Vec<&'static str>,
}

#[derive(Clone, Debug, Serialize)]
pub struct ObservedModelRankingReceipt {
    pub generated_token_id: usize,
    pub generated_logit: f32,
    pub runner_up_token_id: usize,
    pub runner_up_logit: f32,
    pub greedy_margin: f32,
    pub direct_bf16_head_deviation: f32,
}

#[derive(Clone, Debug, Serialize)]
pub struct ObservedModelPathReceipt {
    pub second_token_layer_zero_raw_output: NumericReceipt,
    pub second_token_layer_zero_post_state: NumericReceipt,
    pub second_token_layer_zero_output: NumericReceipt,
    pub third_token_layer_zero_pre_state: NumericReceipt,
    pub third_token_layer_zero_raw_output: NumericReceipt,
    pub third_token_layer_zero_post_state: NumericReceipt,
    pub third_token_layer_outputs: Vec<NumericReceipt>,
    pub final_layer_output: NumericReceipt,
    pub final_hidden: NumericReceipt,
    pub logits: NumericReceipt,
    pub attention_states: NumericReceipt,
    pub channel_states: NumericReceipt,
    pub matrix_states: NumericReceipt,
    pub complete_recurrent_state: NumericReceipt,
    pub ranking: ObservedModelRankingReceipt,
}

#[derive(Clone, Debug, Serialize)]
pub struct ObservedModelDeviationReceipt {
    pub expected_final_hidden_vs_source_fp32: f32,
    pub observed_final_hidden_vs_expected_bf16: f32,
    pub observed_final_hidden_vs_source_fp32: f32,
    pub expected_logits_vs_source_fp32: f32,
    pub observed_logits_vs_expected_bf16: f32,
    pub observed_logits_vs_source_fp32: f32,
    pub expected_complete_state_vs_source_fp32: f32,
    pub observed_complete_state_vs_expected_bf16: f32,
    pub observed_complete_state_vs_source_fp32: f32,
    pub observed_logits_vs_reset_state: f32,
    pub observed_complete_state_vs_reset_state: f32,
    pub observed_logits_vs_transposed_state: f32,
    pub observed_complete_state_vs_transposed_state: f32,
}

#[derive(Clone, Debug, Serialize)]
pub struct Ttwkv7ObservedModelCarryReceipt {
    pub schema_version: u32,
    pub target: &'static str,
    pub model: ModelReceipt,
    pub dimensions: Dimensions,
    pub layer_count: usize,
    pub token_ids: [usize; MODEL_CARRY_TOKEN_COUNT],
    pub physical_evidence_layer_index: usize,
    pub physical_evidence_token_ordinal: usize,
    pub physical_wkv_call_count: usize,
    pub cpu_second_token_layer_count: usize,
    pub cpu_third_token_layer_count: usize,
    pub observed_layer_receipt_blake3: String,
    pub observed_state_carry_receipt_blake3: String,
    pub terminal_session_outcome: &'static str,
    pub evidence_bundle_blake3: String,
    pub source_fp32: ObservedModelPathReceipt,
    pub expected_bf16_boundary: ObservedModelPathReceipt,
    pub observed_physical_seed: ObservedModelPathReceipt,
    pub reset_state_control: ObservedModelPathReceipt,
    pub transposed_state_control: ObservedModelPathReceipt,
    pub maximum_absolute_deviations: ObservedModelDeviationReceipt,
    pub divergence_floor: f32,
    pub non_claims: Vec<&'static str>,
}

#[derive(Clone, Debug)]
struct ObservedModelPath {
    second_token: ModelTokenExecution,
    third_token: ModelTokenExecution,
    final_hidden: Vec<f32>,
    logits: Vec<f32>,
    ranking: TopTwo,
    direct_bf16_head_deviation: f32,
}

#[derive(Clone, Debug, Deserialize)]
struct DeviceArtifactEvidence {
    role: String,
    blake3: String,
    byte_count: usize,
}

#[derive(Clone, Copy, Debug, Deserialize)]
struct ComparisonMetricsEvidence {
    exact_bit_mismatch_count: usize,
    finite: bool,
    maximum_absolute_error: f64,
    nmse: f64,
    pcc: f64,
}

#[derive(Clone, Copy, Debug, Deserialize)]
struct DeviceComparisonEvidence {
    nmse_ceiling: f64,
    output: ComparisonMetricsEvidence,
    passed: bool,
    post_state: ComparisonMetricsEvidence,
}

#[derive(Clone, Debug, Deserialize)]
struct ProductionSourceEvidence {
    decode_compute: String,
    decode_reader: String,
    writer: String,
}

#[derive(Clone, Debug, Deserialize)]
struct BoundaryDeviceReceiptEvidence {
    schema_version: u32,
    artifacts: Vec<DeviceArtifactEvidence>,
    combined_evidence_blake3: String,
    comparison: DeviceComparisonEvidence,
    device_initialized: bool,
    fixture_blake3: String,
    ordered_artifact_blake3: String,
    production_source_blake3: ProductionSourceEvidence,
    runtime_argument_blake3: String,
    workload_enqueue_count: usize,
}

#[derive(Clone, Debug, Deserialize)]
struct ProcessEvidence {
    exit_status: i32,
    timed_out: bool,
}

#[derive(Clone, Debug, Deserialize)]
struct SessionArtifactEvidence {
    role: String,
    blake3: String,
    bytes: usize,
}

#[derive(Clone, Debug, Deserialize)]
struct SessionEvidence {
    schema_version: u32,
    plan_id: String,
    process_attempts: usize,
    owner_isolation_attempts: usize,
    restoration_attempts: usize,
    process: ProcessEvidence,
    owner_active_after: bool,
    owner_health_status_after: Option<u16>,
    board_healthy_after: bool,
    artifacts: Vec<SessionArtifactEvidence>,
    observed_markers: Vec<String>,
}

#[derive(Clone, Debug, Deserialize)]
struct ClassificationEvidence {
    schema_version: u32,
    plan_id: String,
    outcome: String,
    process_budget_exhausted: bool,
    missing_artifact_roles: Vec<String>,
    missing_success_markers: Vec<String>,
    safety_issues: Vec<String>,
    success_claim: Option<String>,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Eq)]
struct PlanTargetEvidence {
    package_path: String,
    kernel_path: String,
    executable: String,
    arguments: Vec<String>,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Eq)]
struct PlanHardwareEvidence {
    architecture: String,
    physical_device: usize,
    device_path: String,
    owner_unit: String,
    owner_control_path: String,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Eq)]
struct PlanRuntimeEvidence {
    run_root: String,
    cache_path: String,
    logs_path: String,
    inspector_address: String,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Eq)]
struct PlanBudgetEvidence {
    max_processes: usize,
    timeout_seconds: usize,
    timeout_exit_status: i32,
    kill_grace_seconds: usize,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Eq)]
struct PlanRestorationEvidence {
    rollback_delay_seconds: usize,
    health_url: String,
    expected_health_status: u16,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Eq)]
struct PlanRequiredEvidence {
    required_artifact_roles: Vec<String>,
    success_markers: Vec<String>,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Eq)]
struct PlanEvidence {
    schema_version: u32,
    session_id: String,
    stage: String,
    target: PlanTargetEvidence,
    hardware: PlanHardwareEvidence,
    runtime: PlanRuntimeEvidence,
    budget: PlanBudgetEvidence,
    restoration: PlanRestorationEvidence,
    evidence: PlanRequiredEvidence,
}

#[derive(Clone, Debug, Deserialize)]
struct PlanReceiptEvidence {
    schema_version: u32,
    plan_id: String,
    plan: PlanEvidence,
}

#[derive(Clone, Debug, Deserialize)]
struct PreparedEvidence {
    device_initialized: bool,
    fixture_blake3: String,
    ordered_artifact_blake3: String,
    target: String,
}

struct ExpectedBoundaryValues {
    raw_output: Vec<f32>,
    post_state: Vec<f32>,
}

// r[impl onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_observed_layer_replay]
pub fn run_ttwkv7_observed_layer_checkpoint(
    checkpoint: &[u8],
    expected_model_blake3: &str,
    evidence: &Ttwkv7ObservedLayerEvidence<'_>,
) -> Result<Ttwkv7ObservedLayerReplayReceipt, String> {
    verify_checkpoint_digest(checkpoint, expected_model_blake3)?;
    let byte_count = u64::try_from(checkpoint.len())
        .map_err(|error| format!("checkpoint byte count does not fit u64: {error}"))?;
    if byte_count != MODEL_BYTE_COUNT {
        return Err(format!(
            "checkpoint byte count must be {MODEL_BYTE_COUNT}, found {byte_count}"
        ));
    }

    let validated = validate_observed_evidence(evidence)?;
    let tensors = SafeTensors::deserialize(checkpoint)
        .map_err(|error| format!("failed to decode safetensors checkpoint: {error}"))?;
    let dimensions = Dimensions::reviewed();
    let weights = load_layer_zero(&tensors, dimensions)?;
    let embedding = tensors
        .tensor("model.embeddings.weight")
        .map_err(|error| format!("missing model.embeddings.weight: {error}"))?;
    let model_config_bos = embedding_row(
        &embedding,
        MODEL_CONFIG_BOS_TOKEN_ID,
        dimensions.hidden_size,
    )?;
    let model_config_eos = embedding_row(
        &embedding,
        MODEL_CONFIG_EOS_TOKEN_ID,
        dimensions.hidden_size,
    )?;
    let source = run_sequence(&weights, [&model_config_bos, &model_config_eos])?;
    let source_output_receipt = numeric_receipt(&source.final_output)?;
    if source_output_receipt.blake3 != EXPECTED_SOURCE_LAYER_OUTPUT_BLAKE3 {
        return Err("accepted source FP32 layer output identity changed".to_owned());
    }
    let source_state_receipt = numeric_receipt(&source.final_state)?;
    if source_state_receipt.blake3 != EXPECTED_SOURCE_STATE_BLAKE3 {
        return Err("accepted source FP32 recurrent state identity changed".to_owned());
    }

    let expected = expected_boundary_values(&source, dimensions)?;
    let observed_raw_output = decode_bf16_bytes(
        evidence.observed_output_bf16,
        "observed device raw WKV output",
    )?;
    let observed_post_state = decode_bf16_bytes(
        evidence.observed_post_state_bf16,
        "observed device post-state",
    )?;
    require_length(
        &observed_raw_output,
        dimensions.hidden_size,
        "observed device raw WKV output",
    )?;
    require_length(
        &observed_post_state,
        OBSERVED_STATE_ELEMENT_COUNT,
        "observed device post-state",
    )?;

    let source_attention = finish_time_mix_attention(
        &weights,
        &source.second_preparation,
        &source.second_raw_output,
    )?;
    let expected_attention =
        finish_time_mix_attention(&weights, &source.second_preparation, &expected.raw_output)?;
    let observed_attention =
        finish_time_mix_attention(&weights, &source.second_preparation, &observed_raw_output)?;
    let source_suffix = finish_layer_suffix(
        &weights,
        &source.second_residual,
        &source_attention,
        &source.second_ffn_previous,
    )?;
    let expected_suffix = finish_layer_suffix(
        &weights,
        &source.second_residual,
        &expected_attention,
        &source.second_ffn_previous,
    )?;
    let observed_suffix = finish_layer_suffix(
        &weights,
        &source.second_residual,
        &observed_attention,
        &source.second_ffn_previous,
    )?;
    let source_replay_deviation =
        max_abs_difference(&source_suffix.final_output, &source.final_output)?;
    if source_replay_deviation != ZERO_DEVIATION {
        return Err(format!(
            "shared source layer suffix replay changed output by {source_replay_deviation}"
        ));
    }

    let deviations = ObservedLayerDeviationReceipt {
        expected_raw_output_vs_source_fp32: max_abs_difference(
            &expected.raw_output,
            &source.second_raw_output,
        )?,
        observed_raw_output_vs_expected_bf16: max_abs_difference(
            &observed_raw_output,
            &expected.raw_output,
        )?,
        observed_raw_output_vs_source_fp32: max_abs_difference(
            &observed_raw_output,
            &source.second_raw_output,
        )?,
        expected_post_state_vs_source_fp32: max_abs_difference(
            &expected.post_state,
            &source.final_state,
        )?,
        observed_post_state_vs_expected_bf16: max_abs_difference(
            &observed_post_state,
            &expected.post_state,
        )?,
        observed_post_state_vs_source_fp32: max_abs_difference(
            &observed_post_state,
            &source.final_state,
        )?,
        expected_attention_output_vs_source_fp32: max_abs_difference(
            &expected_attention,
            &source_attention,
        )?,
        observed_attention_output_vs_expected_bf16: max_abs_difference(
            &observed_attention,
            &expected_attention,
        )?,
        observed_attention_output_vs_source_fp32: max_abs_difference(
            &observed_attention,
            &source_attention,
        )?,
        expected_final_layer_output_vs_source_fp32: max_abs_difference(
            &expected_suffix.final_output,
            &source.final_output,
        )?,
        observed_final_layer_output_vs_expected_bf16: max_abs_difference(
            &observed_suffix.final_output,
            &expected_suffix.final_output,
        )?,
        observed_final_layer_output_vs_source_fp32: max_abs_difference(
            &observed_suffix.final_output,
            &source.final_output,
        )?,
    };

    Ok(Ttwkv7ObservedLayerReplayReceipt {
        schema_version: RECEIPT_SCHEMA_VERSION,
        target: OBSERVED_TARGET,
        model: ModelReceipt {
            model_id: MODEL_ID,
            revision: MODEL_REVISION,
            sha256_sri: MODEL_SHA256_SRI,
            blake3: blake3::hash(checkpoint).to_hex().to_string(),
            byte_count,
        },
        dimensions,
        layer_index: LAYER_INDEX,
        prefix_token_ids: [MODEL_CONFIG_BOS_TOKEN_ID, MODEL_CONFIG_EOS_TOKEN_ID],
        evidence: ObservedEvidenceAuthorityReceipt {
            plan_id: OBSERVED_PLAN_ID,
            session_id: OBSERVED_SESSION_ID,
            terminal_outcome: OBSERVED_SESSION_OUTCOME,
            terminal_safety_issue: OBSERVED_SAFETY_ISSUE,
            classification_receipt_blake3: OBSERVED_CLASSIFICATION_BLAKE3,
            session_evidence_blake3: OBSERVED_SESSION_EVIDENCE_BLAKE3,
            diagnostic_log_blake3: OBSERVED_DIAGNOSTIC_BLAKE3,
            board_after_blake3: OBSERVED_BOARD_BLAKE3,
            owner_after_blake3: OBSERVED_OWNER_BLAKE3,
            boundary_manifest_blake3: OBSERVED_BOUNDARY_MANIFEST_BLAKE3,
            prepared_receipt_blake3: OBSERVED_PREPARED_BLAKE3,
            boundary_receipt_blake3: OBSERVED_BOUNDARY_RECEIPT_BLAKE3,
            writer_raw_bf16_blake3: OBSERVED_WRITER_BLAKE3,
            observed_output_bf16_blake3: OBSERVED_OUTPUT_BLAKE3,
            observed_post_state_bf16_blake3: OBSERVED_POST_STATE_BLAKE3,
            session_manifest_blake3: OBSERVED_SESSION_MANIFEST_BLAKE3,
            plan_receipt_blake3: OBSERVED_PLAN_RECEIPT_BLAKE3,
            evidence_bundle_blake3: observed_evidence_bundle_blake3(evidence)?,
        },
        hardware_comparison: ObservedHardwareComparisonReceipt {
            nmse_ceiling: validated.comparison.nmse_ceiling,
            output_nmse: validated.comparison.output.nmse,
            output_pcc: validated.comparison.output.pcc,
            output_maximum_absolute_error: validated.comparison.output.maximum_absolute_error,
            output_exact_bit_mismatch_count: validated.comparison.output.exact_bit_mismatch_count,
            post_state_nmse: validated.comparison.post_state.nmse,
            post_state_pcc: validated.comparison.post_state.pcc,
            post_state_maximum_absolute_error: validated
                .comparison
                .post_state
                .maximum_absolute_error,
            post_state_exact_bit_mismatch_count: validated
                .comparison
                .post_state
                .exact_bit_mismatch_count,
            device_initialized: validated.device_initialized,
            workload_enqueue_count: validated.workload_enqueue_count,
            process_exit_status: validated.session.process.exit_status,
            process_timed_out: validated.session.process.timed_out,
            terminal_owner_active: validated.session.owner_active_after,
            terminal_owner_health_status: validated.session.owner_health_status_after,
            terminal_board_healthy: validated.session.board_healthy_after,
        },
        source_fp32: ObservedLayerPathReceipt {
            raw_wkv_output: numeric_receipt(&source.second_raw_output)?,
            post_state: source_state_receipt,
            attention_output: numeric_receipt(&source_attention)?,
            final_layer_output: source_output_receipt,
        },
        expected_bf16_boundary: ObservedLayerPathReceipt {
            raw_wkv_output: numeric_receipt(&expected.raw_output)?,
            post_state: numeric_receipt(&expected.post_state)?,
            attention_output: numeric_receipt(&expected_attention)?,
            final_layer_output: numeric_receipt(&expected_suffix.final_output)?,
        },
        observed_device: ObservedLayerPathReceipt {
            raw_wkv_output: numeric_receipt(&observed_raw_output)?,
            post_state: numeric_receipt(&observed_post_state)?,
            attention_output: numeric_receipt(&observed_attention)?,
            final_layer_output: numeric_receipt(&observed_suffix.final_output)?,
        },
        maximum_absolute_deviations: deviations,
        non_claims: OBSERVED_NON_CLAIMS.to_vec(),
    })
}

#[derive(Clone, Copy, Debug)]
enum StateCarryArithmetic {
    SourceFp32,
    Bf16Transport,
}

#[derive(Clone, Debug)]
struct StateCarrySeed {
    attention_previous: Vec<f32>,
    ffn_previous: Vec<f32>,
    matrix: Vec<f32>,
}

#[derive(Clone, Debug)]
struct StateCarryStep {
    seed: StateCarrySeed,
    consumed_inputs: WkvInputs,
    consumed_pre_state: Vec<f32>,
    raw_wkv_output: Vec<f32>,
    post_state: Vec<f32>,
    attention_output: Vec<f32>,
    ffn_input: Vec<f32>,
    final_layer_output: Vec<f32>,
    arithmetic: StateCarryArithmetic,
}

// r[impl onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_observed_state_carry]
pub fn run_ttwkv7_observed_state_carry_checkpoint(
    checkpoint: &[u8],
    expected_model_blake3: &str,
    evidence: &Ttwkv7ObservedLayerEvidence<'_>,
) -> Result<Ttwkv7ObservedStateCarryReceipt, String> {
    let observed_layer =
        run_ttwkv7_observed_layer_checkpoint(checkpoint, expected_model_blake3, evidence)?;
    let observed_layer_receipt_blake3 = canonical_receipt_blake3(&observed_layer)?;
    if observed_layer_receipt_blake3 != STATE_CARRY_OBSERVED_RECEIPT_BLAKE3 {
        return Err(format!(
            "accepted observed-layer receipt identity changed: expected {STATE_CARRY_OBSERVED_RECEIPT_BLAKE3}, found {observed_layer_receipt_blake3}"
        ));
    }

    let tensors = SafeTensors::deserialize(checkpoint)
        .map_err(|error| format!("failed to decode safetensors checkpoint: {error}"))?;
    let dimensions = Dimensions::reviewed();
    let weights = load_layer_zero(&tensors, dimensions)?;
    let embedding = tensors
        .tensor("model.embeddings.weight")
        .map_err(|error| format!("missing model.embeddings.weight: {error}"))?;
    let model_config_bos = embedding_row(
        &embedding,
        MODEL_CONFIG_BOS_TOKEN_ID,
        dimensions.hidden_size,
    )?;
    let model_config_eos = embedding_row(
        &embedding,
        MODEL_CONFIG_EOS_TOKEN_ID,
        dimensions.hidden_size,
    )?;
    let source = run_sequence(&weights, [&model_config_bos, &model_config_eos])?;
    let expected_second = expected_boundary_values(&source, dimensions)?;
    let observed_second_raw = decode_bf16_bytes(
        evidence.observed_output_bf16,
        "observed device raw WKV output",
    )?;
    let observed_second_state = decode_bf16_bytes(
        evidence.observed_post_state_bf16,
        "observed device post-state",
    )?;

    let source_second_attention = finish_time_mix_attention(
        &weights,
        &source.second_preparation,
        &source.second_raw_output,
    )?;
    let expected_second_attention = finish_time_mix_attention(
        &weights,
        &source.second_preparation,
        &expected_second.raw_output,
    )?;
    let observed_second_attention =
        finish_time_mix_attention(&weights, &source.second_preparation, &observed_second_raw)?;
    let source_second_suffix = finish_layer_suffix(
        &weights,
        &source.second_residual,
        &source_second_attention,
        &source.second_ffn_previous,
    )?;
    let expected_second_suffix = finish_layer_suffix(
        &weights,
        &source.second_residual,
        &expected_second_attention,
        &source.second_ffn_previous,
    )?;
    let observed_second_suffix = finish_layer_suffix(
        &weights,
        &source.second_residual,
        &observed_second_attention,
        &source.second_ffn_previous,
    )?;
    let source_host_state_deviation =
        max_abs_difference(&source.final_ffn_previous, &source_second_suffix.ffn_input)?;
    if source_host_state_deviation != ZERO_DEVIATION {
        return Err(format!(
            "source final channel state changed under suffix replay by {source_host_state_deviation}"
        ));
    }

    let source_seed = StateCarrySeed {
        attention_previous: source.final_attention_previous.clone(),
        ffn_previous: source.final_ffn_previous.clone(),
        matrix: source.final_state.clone(),
    };
    let expected_seed = StateCarrySeed {
        attention_previous: source.final_attention_previous.clone(),
        ffn_previous: expected_second_suffix.ffn_input,
        matrix: expected_second.post_state,
    };
    let observed_seed = StateCarrySeed {
        attention_previous: source.final_attention_previous,
        ffn_previous: observed_second_suffix.ffn_input,
        matrix: observed_second_state,
    };
    let reset_seed = StateCarrySeed {
        attention_previous: observed_seed.attention_previous.clone(),
        ffn_previous: observed_seed.ffn_previous.clone(),
        matrix: vec![0.0; OBSERVED_STATE_ELEMENT_COUNT],
    };
    let transposed_seed = StateCarrySeed {
        attention_previous: observed_seed.attention_previous.clone(),
        ffn_previous: observed_seed.ffn_previous.clone(),
        matrix: transpose_head_matrices(&observed_seed.matrix, dimensions)?,
    };

    let source_step = run_state_carry_step(
        &weights,
        &model_config_eos,
        source_seed,
        StateCarryArithmetic::SourceFp32,
    )?;
    let expected_step = run_state_carry_step(
        &weights,
        &model_config_eos,
        expected_seed,
        StateCarryArithmetic::Bf16Transport,
    )?;
    let observed_step = run_state_carry_step(
        &weights,
        &model_config_eos,
        observed_seed,
        StateCarryArithmetic::Bf16Transport,
    )?;
    let reset_step = run_state_carry_step(
        &weights,
        &model_config_eos,
        reset_seed,
        StateCarryArithmetic::Bf16Transport,
    )?;
    let transposed_step = run_state_carry_step(
        &weights,
        &model_config_eos,
        transposed_seed,
        StateCarryArithmetic::Bf16Transport,
    )?;

    let deviations = StateCarryDeviationReceipt {
        expected_raw_output_vs_source_fp32: max_abs_difference(
            &expected_step.raw_wkv_output,
            &source_step.raw_wkv_output,
        )?,
        observed_raw_output_vs_expected_bf16: max_abs_difference(
            &observed_step.raw_wkv_output,
            &expected_step.raw_wkv_output,
        )?,
        observed_raw_output_vs_source_fp32: max_abs_difference(
            &observed_step.raw_wkv_output,
            &source_step.raw_wkv_output,
        )?,
        expected_post_state_vs_source_fp32: max_abs_difference(
            &expected_step.post_state,
            &source_step.post_state,
        )?,
        observed_post_state_vs_expected_bf16: max_abs_difference(
            &observed_step.post_state,
            &expected_step.post_state,
        )?,
        observed_post_state_vs_source_fp32: max_abs_difference(
            &observed_step.post_state,
            &source_step.post_state,
        )?,
        expected_final_layer_output_vs_source_fp32: max_abs_difference(
            &expected_step.final_layer_output,
            &source_step.final_layer_output,
        )?,
        observed_final_layer_output_vs_expected_bf16: max_abs_difference(
            &observed_step.final_layer_output,
            &expected_step.final_layer_output,
        )?,
        observed_final_layer_output_vs_source_fp32: max_abs_difference(
            &observed_step.final_layer_output,
            &source_step.final_layer_output,
        )?,
        observed_post_state_vs_reset_state: max_abs_difference(
            &observed_step.post_state,
            &reset_step.post_state,
        )?,
        observed_final_layer_output_vs_reset_state: max_abs_difference(
            &observed_step.final_layer_output,
            &reset_step.final_layer_output,
        )?,
        observed_post_state_vs_transposed_state: max_abs_difference(
            &observed_step.post_state,
            &transposed_step.post_state,
        )?,
        observed_final_layer_output_vs_transposed_state: max_abs_difference(
            &observed_step.final_layer_output,
            &transposed_step.final_layer_output,
        )?,
    };
    if deviations.observed_post_state_vs_reset_state <= STATE_CARRY_RESET_STATE_DIVERGENCE_FLOOR {
        return Err(format!(
            "observed post-state carry divergence {} does not exceed {}",
            deviations.observed_post_state_vs_reset_state, STATE_CARRY_RESET_STATE_DIVERGENCE_FLOOR
        ));
    }
    if deviations.observed_final_layer_output_vs_reset_state
        <= STATE_CARRY_RESET_OUTPUT_DIVERGENCE_FLOOR
    {
        return Err(format!(
            "observed output carry divergence {} does not exceed {}",
            deviations.observed_final_layer_output_vs_reset_state,
            STATE_CARRY_RESET_OUTPUT_DIVERGENCE_FLOOR
        ));
    }
    if deviations.observed_post_state_vs_expected_bf16
        >= deviations.observed_post_state_vs_transposed_state
    {
        return Err(format!(
            "observed post-state is not closer to expected state than to transposed-state control: {} versus {}",
            deviations.observed_post_state_vs_expected_bf16,
            deviations.observed_post_state_vs_transposed_state
        ));
    }
    if deviations.observed_final_layer_output_vs_expected_bf16
        >= deviations.observed_final_layer_output_vs_transposed_state
    {
        return Err(format!(
            "observed output is not closer to expected output than to transposed-state control: {} versus {}",
            deviations.observed_final_layer_output_vs_expected_bf16,
            deviations.observed_final_layer_output_vs_transposed_state
        ));
    }

    Ok(Ttwkv7ObservedStateCarryReceipt {
        schema_version: RECEIPT_SCHEMA_VERSION,
        target: STATE_CARRY_TARGET,
        model: observed_layer.model,
        dimensions,
        layer_index: LAYER_INDEX,
        token_ids: [
            MODEL_CONFIG_BOS_TOKEN_ID,
            MODEL_CONFIG_EOS_TOKEN_ID,
            MODEL_CONFIG_EOS_TOKEN_ID,
        ],
        observed_layer_receipt_blake3,
        terminal_session_outcome: OBSERVED_SESSION_OUTCOME,
        evidence_bundle_blake3: observed_layer.evidence.evidence_bundle_blake3,
        physical_seed_post_state_blake3: OBSERVED_POST_STATE_BLAKE3,
        source_fp32: state_carry_path_receipt(&source_step)?,
        expected_bf16_boundary: state_carry_path_receipt(&expected_step)?,
        observed_physical_state_cpu_continuation: state_carry_path_receipt(&observed_step)?,
        reset_state_control: state_carry_path_receipt(&reset_step)?,
        transposed_state_control: state_carry_path_receipt(&transposed_step)?,
        maximum_absolute_deviations: deviations,
        reset_state_divergence_floor: STATE_CARRY_RESET_STATE_DIVERGENCE_FLOOR,
        reset_output_divergence_floor: STATE_CARRY_RESET_OUTPUT_DIVERGENCE_FLOOR,
        non_claims: STATE_CARRY_NON_CLAIMS.to_vec(),
    })
}

// r[impl onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_observed_model_carry]
pub fn run_ttwkv7_observed_model_carry_checkpoint(
    checkpoint: &[u8],
    expected_model_blake3: &str,
    evidence: &Ttwkv7ObservedLayerEvidence<'_>,
) -> Result<Ttwkv7ObservedModelCarryReceipt, String> {
    let observed_layer =
        run_ttwkv7_observed_layer_checkpoint(checkpoint, expected_model_blake3, evidence)?;
    let observed_layer_receipt_blake3 = canonical_receipt_blake3(&observed_layer)?;
    if observed_layer_receipt_blake3 != STATE_CARRY_OBSERVED_RECEIPT_BLAKE3 {
        return Err(format!(
            "accepted observed-layer receipt identity changed: expected {STATE_CARRY_OBSERVED_RECEIPT_BLAKE3}, found {observed_layer_receipt_blake3}"
        ));
    }
    let state_carry =
        run_ttwkv7_observed_state_carry_checkpoint(checkpoint, expected_model_blake3, evidence)?;
    let observed_state_carry_receipt_blake3 = canonical_receipt_blake3(&state_carry)?;
    if observed_state_carry_receipt_blake3 != MODEL_CARRY_STATE_RECEIPT_BLAKE3 {
        return Err(format!(
            "accepted observed-state-carry receipt identity changed: expected {MODEL_CARRY_STATE_RECEIPT_BLAKE3}, found {observed_state_carry_receipt_blake3}"
        ));
    }

    let tensors = SafeTensors::deserialize(checkpoint)
        .map_err(|error| format!("failed to decode safetensors checkpoint: {error}"))?;
    let dimensions = Dimensions::reviewed();
    let weights = (0..MODEL_LAYER_COUNT)
        .map(|layer_index| load_layer(&tensors, dimensions, layer_index))
        .collect::<Result<Vec<_>, _>>()?;
    validate_model_weights(&weights)?;
    let embedding = tensors
        .tensor("model.embeddings.weight")
        .map_err(|error| format!("missing model.embeddings.weight: {error}"))?;
    let model_config_bos = embedding_row(
        &embedding,
        MODEL_CONFIG_BOS_TOKEN_ID,
        dimensions.hidden_size,
    )?;
    let model_config_eos = embedding_row(
        &embedding,
        MODEL_CONFIG_EOS_TOKEN_ID,
        dimensions.hidden_size,
    )?;
    let final_norm_weight = vector(&tensors, "model.norm.weight", dimensions.hidden_size)?;
    let final_norm_bias = vector(&tensors, "model.norm.bias", dimensions.hidden_size)?;
    let head_tensor = tensors
        .tensor("lm_head.weight")
        .map_err(|error| format!("missing lm_head.weight: {error}"))?;
    let head = matrix(
        &tensors,
        "lm_head.weight",
        VOCABULARY_SIZE,
        dimensions.hidden_size,
    )?;

    let first_token = run_model_token_with_layer_zero_mode(
        &weights,
        &model_config_bos,
        ModelExecutionState::zero(dimensions)?,
        LayerZeroWkvMode::SourceFp32,
    )?;
    let source_second = run_model_token_with_layer_zero_mode(
        &weights,
        &model_config_eos,
        first_token.execution.clone(),
        LayerZeroWkvMode::SourceFp32,
    )?;
    let expected_second = run_model_token_with_layer_zero_mode(
        &weights,
        &model_config_eos,
        first_token.execution.clone(),
        LayerZeroWkvMode::Bf16Cpu,
    )?;
    let observed_raw_output = decode_bf16_bytes(
        evidence.observed_output_bf16,
        "observed model raw WKV output",
    )?;
    let observed_post_state = decode_bf16_bytes(
        evidence.observed_post_state_bf16,
        "observed model post-state",
    )?;
    let observed_second = run_model_token_with_layer_zero_mode(
        &weights,
        &model_config_eos,
        first_token.execution,
        LayerZeroWkvMode::Observed {
            raw_output: &observed_raw_output,
            post_state: &observed_post_state,
        },
    )?;

    validate_observed_layer_token(
        &source_second,
        &observed_layer.source_fp32,
        "source second token",
    )?;
    validate_observed_layer_token(
        &expected_second,
        &observed_layer.expected_bf16_boundary,
        "expected second token",
    )?;
    validate_observed_layer_token(
        &observed_second,
        &observed_layer.observed_device,
        "observed second token",
    )?;

    let source = advance_observed_model_path(
        &weights,
        &model_config_eos,
        source_second,
        LayerZeroWkvMode::SourceFp32,
        &final_norm_weight,
        &final_norm_bias,
        &head,
        &head_tensor,
    )?;
    let expected = advance_observed_model_path(
        &weights,
        &model_config_eos,
        expected_second,
        LayerZeroWkvMode::Bf16Cpu,
        &final_norm_weight,
        &final_norm_bias,
        &head,
        &head_tensor,
    )?;
    let observed = advance_observed_model_path(
        &weights,
        &model_config_eos,
        observed_second.clone(),
        LayerZeroWkvMode::Bf16Cpu,
        &final_norm_weight,
        &final_norm_bias,
        &head,
        &head_tensor,
    )?;

    let reset_matrix = vec![0.0_f32; observed_post_state.len()];
    let reset_second = replace_model_layer_zero_matrix(observed_second.clone(), reset_matrix)?;
    let reset = advance_observed_model_path(
        &weights,
        &model_config_eos,
        reset_second,
        LayerZeroWkvMode::Bf16Cpu,
        &final_norm_weight,
        &final_norm_bias,
        &head,
        &head_tensor,
    )?;
    let transposed_matrix = transpose_head_matrices(&observed_post_state, dimensions)?;
    let transposed_second = replace_model_layer_zero_matrix(observed_second, transposed_matrix)?;
    let transposed = advance_observed_model_path(
        &weights,
        &model_config_eos,
        transposed_second,
        LayerZeroWkvMode::Bf16Cpu,
        &final_norm_weight,
        &final_norm_bias,
        &head,
        &head_tensor,
    )?;

    validate_state_carry_token(
        &source.third_token,
        &state_carry.source_fp32,
        "source third token",
    )?;
    validate_state_carry_token(
        &expected.third_token,
        &state_carry.expected_bf16_boundary,
        "expected third token",
    )?;
    validate_state_carry_token(
        &observed.third_token,
        &state_carry.observed_physical_state_cpu_continuation,
        "observed third token",
    )?;
    validate_state_carry_token(
        &reset.third_token,
        &state_carry.reset_state_control,
        "reset third token",
    )?;
    validate_state_carry_token(
        &transposed.third_token,
        &state_carry.transposed_state_control,
        "transposed third token",
    )?;

    if observed.ranking.first.token_id != expected.ranking.first.token_id
        || observed.ranking.second.token_id != expected.ranking.second.token_id
    {
        return Err(format!(
            "observed top-two ranking [{}, {}] differs from expected BF16 [{}, {}]",
            observed.ranking.first.token_id,
            observed.ranking.second.token_id,
            expected.ranking.first.token_id,
            expected.ranking.second.token_id
        ));
    }

    let source_complete_state = source.third_token.execution.flattened_complete_state();
    let expected_complete_state = expected.third_token.execution.flattened_complete_state();
    let observed_complete_state = observed.third_token.execution.flattened_complete_state();
    let reset_complete_state = reset.third_token.execution.flattened_complete_state();
    let transposed_complete_state = transposed.third_token.execution.flattened_complete_state();
    let deviations = ObservedModelDeviationReceipt {
        expected_final_hidden_vs_source_fp32: max_abs_difference(
            &expected.final_hidden,
            &source.final_hidden,
        )?,
        observed_final_hidden_vs_expected_bf16: max_abs_difference(
            &observed.final_hidden,
            &expected.final_hidden,
        )?,
        observed_final_hidden_vs_source_fp32: max_abs_difference(
            &observed.final_hidden,
            &source.final_hidden,
        )?,
        expected_logits_vs_source_fp32: max_abs_difference(&expected.logits, &source.logits)?,
        observed_logits_vs_expected_bf16: max_abs_difference(&observed.logits, &expected.logits)?,
        observed_logits_vs_source_fp32: max_abs_difference(&observed.logits, &source.logits)?,
        expected_complete_state_vs_source_fp32: max_abs_difference(
            &expected_complete_state,
            &source_complete_state,
        )?,
        observed_complete_state_vs_expected_bf16: max_abs_difference(
            &observed_complete_state,
            &expected_complete_state,
        )?,
        observed_complete_state_vs_source_fp32: max_abs_difference(
            &observed_complete_state,
            &source_complete_state,
        )?,
        observed_logits_vs_reset_state: max_abs_difference(&observed.logits, &reset.logits)?,
        observed_complete_state_vs_reset_state: max_abs_difference(
            &observed_complete_state,
            &reset_complete_state,
        )?,
        observed_logits_vs_transposed_state: max_abs_difference(
            &observed.logits,
            &transposed.logits,
        )?,
        observed_complete_state_vs_transposed_state: max_abs_difference(
            &observed_complete_state,
            &transposed_complete_state,
        )?,
    };
    validate_observed_model_deviations(&deviations)?;

    Ok(Ttwkv7ObservedModelCarryReceipt {
        schema_version: RECEIPT_SCHEMA_VERSION,
        target: MODEL_CARRY_TARGET,
        model: state_carry.model,
        dimensions,
        layer_count: MODEL_LAYER_COUNT,
        token_ids: [
            MODEL_CONFIG_BOS_TOKEN_ID,
            MODEL_CONFIG_EOS_TOKEN_ID,
            MODEL_CONFIG_EOS_TOKEN_ID,
        ],
        physical_evidence_layer_index: LAYER_INDEX,
        physical_evidence_token_ordinal: MODEL_CARRY_PHYSICAL_TOKEN_ORDINAL,
        physical_wkv_call_count: MODEL_CARRY_PHYSICAL_WKV_COUNT,
        cpu_second_token_layer_count: MODEL_CARRY_CPU_SECOND_TOKEN_LAYER_COUNT,
        cpu_third_token_layer_count: MODEL_CARRY_CPU_THIRD_TOKEN_LAYER_COUNT,
        observed_layer_receipt_blake3,
        observed_state_carry_receipt_blake3,
        terminal_session_outcome: OBSERVED_SESSION_OUTCOME,
        evidence_bundle_blake3: state_carry.evidence_bundle_blake3,
        source_fp32: observed_model_path_receipt(&source)?,
        expected_bf16_boundary: observed_model_path_receipt(&expected)?,
        observed_physical_seed: observed_model_path_receipt(&observed)?,
        reset_state_control: observed_model_path_receipt(&reset)?,
        transposed_state_control: observed_model_path_receipt(&transposed)?,
        maximum_absolute_deviations: deviations,
        divergence_floor: MODEL_CARRY_DIVERGENCE_FLOOR,
        non_claims: MODEL_CARRY_NON_CLAIMS.to_vec(),
    })
}

fn advance_observed_model_path(
    weights: &[LayerWeights],
    embedding: &[f32],
    second_token: ModelTokenExecution,
    layer_zero_mode: LayerZeroWkvMode<'_>,
    final_norm_weight: &[f32],
    final_norm_bias: &[f32],
    head: &Matrix,
    head_tensor: &TensorView<'_>,
) -> Result<ObservedModelPath, String> {
    let dimensions = Dimensions::reviewed();
    let third_token = run_model_token_with_layer_zero_mode(
        weights,
        embedding,
        second_token.execution.clone(),
        layer_zero_mode,
    )?;
    if third_token.layer_outputs.len() != MODEL_LAYER_COUNT {
        return Err(format!(
            "third token requires {MODEL_LAYER_COUNT} layer outputs, found {}",
            third_token.layer_outputs.len()
        ));
    }
    let final_hidden = layer_norm(
        &third_token.final_output,
        final_norm_weight,
        final_norm_bias,
        LAYER_NORM_EPSILON,
    )?;
    let logits = matvec(head, &final_hidden)?;
    let ranking = rank_top_two(
        logits
            .iter()
            .copied()
            .enumerate()
            .map(|(token_id, logit)| RankedLogit { token_id, logit }),
    )?;
    let direct_ranking =
        direct_bf16_head_top_two(head_tensor, &final_hidden, dimensions.hidden_size)?;
    if ranking.first.token_id != direct_ranking.first.token_id
        || ranking.second.token_id != direct_ranking.second.token_id
    {
        return Err(format!(
            "observed-model LM-head ranking mismatch: production [{}, {}], direct [{}, {}]",
            ranking.first.token_id,
            ranking.second.token_id,
            direct_ranking.first.token_id,
            direct_ranking.second.token_id
        ));
    }
    let direct_bf16_head_deviation = (ranking.first.logit - direct_ranking.first.logit)
        .abs()
        .max((ranking.second.logit - direct_ranking.second.logit).abs());
    if direct_bf16_head_deviation > ORACLE_TOLERANCE {
        return Err(format!(
            "observed-model LM-head deviation {direct_bf16_head_deviation} exceeds {ORACLE_TOLERANCE}"
        ));
    }
    Ok(ObservedModelPath {
        second_token,
        third_token,
        final_hidden,
        logits,
        ranking,
        direct_bf16_head_deviation,
    })
}

fn replace_model_layer_zero_matrix(
    mut second_token: ModelTokenExecution,
    matrix: Vec<f32>,
) -> Result<ModelTokenExecution, String> {
    require_length(
        &matrix,
        OBSERVED_STATE_ELEMENT_COUNT,
        "replacement model layer-zero matrix",
    )?;
    require_finite(&matrix, "replacement model layer-zero matrix")?;
    second_token.execution.layers[LAYER_INDEX].matrix = matrix.clone();
    second_token.execution.oracle_matrices[LAYER_INDEX] = matrix;
    Ok(second_token)
}

fn validate_observed_layer_token(
    token: &ModelTokenExecution,
    expected: &ObservedLayerPathReceipt,
    name: &str,
) -> Result<(), String> {
    require_numeric_identity(
        &token.layer_zero_raw_output,
        &expected.raw_wkv_output,
        &format!("{name} raw WKV output"),
    )?;
    require_numeric_identity(
        &token.layer_zero_post_state,
        &expected.post_state,
        &format!("{name} post-state"),
    )?;
    let layer_zero_output = token
        .layer_outputs
        .get(LAYER_INDEX)
        .ok_or_else(|| format!("{name} is missing layer-zero output"))?;
    require_numeric_identity(
        layer_zero_output,
        &expected.final_layer_output,
        &format!("{name} final layer-zero output"),
    )
}

fn validate_state_carry_token(
    token: &ModelTokenExecution,
    expected: &StateCarryPathReceipt,
    name: &str,
) -> Result<(), String> {
    require_numeric_identity(
        &token.layer_zero_pre_state,
        &expected.pre_state,
        &format!("{name} pre-state"),
    )?;
    require_numeric_identity(
        &token.layer_zero_raw_output,
        &expected.raw_wkv_output,
        &format!("{name} raw WKV output"),
    )?;
    require_numeric_identity(
        &token.layer_zero_post_state,
        &expected.post_state,
        &format!("{name} post-state"),
    )?;
    let layer_zero_output = token
        .layer_outputs
        .get(LAYER_INDEX)
        .ok_or_else(|| format!("{name} is missing layer-zero output"))?;
    require_numeric_identity(
        layer_zero_output,
        &expected.final_layer_output,
        &format!("{name} final layer-zero output"),
    )
}

fn require_numeric_identity(
    values: &[f32],
    expected: &NumericReceipt,
    name: &str,
) -> Result<(), String> {
    let observed = numeric_receipt(values)?;
    if observed.blake3 != expected.blake3 || observed.element_count != expected.element_count {
        return Err(format!(
            "{name} identity changed: expected {} elements with BLAKE3 {}, found {} elements with BLAKE3 {}",
            expected.element_count, expected.blake3, observed.element_count, observed.blake3
        ));
    }
    Ok(())
}

fn observed_model_path_receipt(
    path: &ObservedModelPath,
) -> Result<ObservedModelPathReceipt, String> {
    let attention_states = path.third_token.execution.flattened_attention_previous();
    let channel_states = path.third_token.execution.flattened_ffn_previous();
    let matrix_states = path.third_token.execution.flattened_matrices();
    let complete_recurrent_state = path.third_token.execution.flattened_complete_state();
    let second_token_layer_zero_output = path
        .second_token
        .layer_outputs
        .get(LAYER_INDEX)
        .ok_or_else(|| "second token is missing layer-zero output".to_owned())?;
    let greedy_margin = path.ranking.first.logit - path.ranking.second.logit;
    if !greedy_margin.is_finite() || greedy_margin < ZERO_DEVIATION {
        return Err(format!(
            "invalid observed-model greedy margin {greedy_margin}"
        ));
    }
    Ok(ObservedModelPathReceipt {
        second_token_layer_zero_raw_output: numeric_receipt(
            &path.second_token.layer_zero_raw_output,
        )?,
        second_token_layer_zero_post_state: numeric_receipt(
            &path.second_token.layer_zero_post_state,
        )?,
        second_token_layer_zero_output: numeric_receipt(second_token_layer_zero_output)?,
        third_token_layer_zero_pre_state: numeric_receipt(&path.third_token.layer_zero_pre_state)?,
        third_token_layer_zero_raw_output: numeric_receipt(
            &path.third_token.layer_zero_raw_output,
        )?,
        third_token_layer_zero_post_state: numeric_receipt(
            &path.third_token.layer_zero_post_state,
        )?,
        third_token_layer_outputs: path
            .third_token
            .layer_outputs
            .iter()
            .map(|output| numeric_receipt(output))
            .collect::<Result<Vec<_>, _>>()?,
        final_layer_output: numeric_receipt(&path.third_token.final_output)?,
        final_hidden: numeric_receipt(&path.final_hidden)?,
        logits: numeric_receipt(&path.logits)?,
        attention_states: numeric_receipt(&attention_states)?,
        channel_states: numeric_receipt(&channel_states)?,
        matrix_states: numeric_receipt(&matrix_states)?,
        complete_recurrent_state: numeric_receipt(&complete_recurrent_state)?,
        ranking: ObservedModelRankingReceipt {
            generated_token_id: path.ranking.first.token_id,
            generated_logit: path.ranking.first.logit,
            runner_up_token_id: path.ranking.second.token_id,
            runner_up_logit: path.ranking.second.logit,
            greedy_margin,
            direct_bf16_head_deviation: path.direct_bf16_head_deviation,
        },
    })
}

fn validate_observed_model_deviations(
    deviations: &ObservedModelDeviationReceipt,
) -> Result<(), String> {
    let control_divergences = [
        (
            "reset-state logits",
            deviations.observed_logits_vs_reset_state,
        ),
        (
            "reset-state complete state",
            deviations.observed_complete_state_vs_reset_state,
        ),
        (
            "transposed-state logits",
            deviations.observed_logits_vs_transposed_state,
        ),
        (
            "transposed-state complete state",
            deviations.observed_complete_state_vs_transposed_state,
        ),
    ];
    for (name, divergence) in control_divergences {
        if !divergence.is_finite() || divergence <= MODEL_CARRY_DIVERGENCE_FLOOR {
            return Err(format!(
                "{name} divergence {divergence} does not exceed {MODEL_CARRY_DIVERGENCE_FLOOR}"
            ));
        }
    }
    if deviations.observed_logits_vs_expected_bf16 >= deviations.observed_logits_vs_reset_state
        || deviations.observed_logits_vs_expected_bf16
            >= deviations.observed_logits_vs_transposed_state
    {
        return Err(
            "observed logits are not closer to expected BF16 than to both controls".to_owned(),
        );
    }
    if deviations.observed_complete_state_vs_expected_bf16
        >= deviations.observed_complete_state_vs_reset_state
        || deviations.observed_complete_state_vs_expected_bf16
            >= deviations.observed_complete_state_vs_transposed_state
    {
        return Err(
            "observed complete state is not closer to expected BF16 than to both controls"
                .to_owned(),
        );
    }
    Ok(())
}

fn run_state_carry_step(
    weights: &LayerWeights,
    embedding: &[f32],
    seed: StateCarrySeed,
    arithmetic: StateCarryArithmetic,
) -> Result<StateCarryStep, String> {
    let dimensions = weights.dimensions;
    require_length(embedding, dimensions.hidden_size, "state-carry embedding")?;
    require_length(
        &seed.attention_previous,
        dimensions.hidden_size,
        "state-carry attention previous",
    )?;
    require_length(
        &seed.ffn_previous,
        dimensions.hidden_size,
        "state-carry FFN previous",
    )?;
    require_length(
        &seed.matrix,
        OBSERVED_STATE_ELEMENT_COUNT,
        "state-carry matrix",
    )?;
    require_finite(&seed.attention_previous, "state-carry attention previous")?;
    require_finite(&seed.ffn_previous, "state-carry FFN previous")?;
    require_finite(&seed.matrix, "state-carry matrix")?;

    let residual = apply_pre_norm(weights, embedding)?;
    let attention_input = layer_norm(
        &residual,
        &weights.attn_norm_weight,
        &weights.attn_norm_bias,
        LAYER_NORM_EPSILON,
    )?;
    let preparation = prepare_time_mix(weights, &attention_input, &seed.attention_previous, None)?;
    let (consumed_inputs, consumed_pre_state) = match arithmetic {
        StateCarryArithmetic::SourceFp32 => (preparation.wkv_inputs.clone(), seed.matrix.clone()),
        StateCarryArithmetic::Bf16Transport => (
            quantize_wkv_inputs(&preparation.wkv_inputs)?,
            quantize_bf16_values(&seed.matrix, "state-carry pre-state")?,
        ),
    };
    let (matrix_post_state, matrix_output) =
        wkv_step_matrix(&consumed_pre_state, &consumed_inputs, dimensions)?;
    let (post_state, raw_wkv_output) = match arithmetic {
        StateCarryArithmetic::SourceFp32 => (matrix_post_state, matrix_output),
        StateCarryArithmetic::Bf16Transport => (
            quantize_bf16_values(&matrix_post_state, "state-carry post-state")?,
            quantize_bf16_values(&matrix_output, "state-carry raw output")?,
        ),
    };
    let attention_output = finish_time_mix_attention(weights, &preparation, &raw_wkv_output)?;
    let suffix = finish_layer_suffix(weights, &residual, &attention_output, &seed.ffn_previous)?;

    Ok(StateCarryStep {
        seed,
        consumed_inputs,
        consumed_pre_state,
        raw_wkv_output,
        post_state,
        attention_output,
        ffn_input: suffix.ffn_input,
        final_layer_output: suffix.final_output,
        arithmetic,
    })
}

pub(super) fn transpose_head_matrices(
    state: &[f32],
    dimensions: Dimensions,
) -> Result<Vec<f32>, String> {
    require_length(
        state,
        OBSERVED_STATE_ELEMENT_COUNT,
        "state-carry transpose input",
    )?;
    require_finite(state, "state-carry transpose input")?;
    let matrix_elements = dimensions
        .head_size
        .checked_mul(dimensions.head_size)
        .ok_or_else(|| "state-carry head matrix element count overflows usize".to_owned())?;
    let mut transposed = vec![0.0_f32; state.len()];
    for head in 0..dimensions.head_count {
        let matrix_base = head * matrix_elements;
        for row in 0..dimensions.head_size {
            for column in 0..dimensions.head_size {
                let destination = matrix_base + row * dimensions.head_size + column;
                let source = matrix_base + column * dimensions.head_size + row;
                transposed[destination] = state[source];
            }
        }
    }
    require_finite(&transposed, "state-carry transposed state")?;
    Ok(transposed)
}

fn state_carry_path_receipt(step: &StateCarryStep) -> Result<StateCarryPathReceipt, String> {
    let (wkv_executor, transport_precision) = match step.arithmetic {
        StateCarryArithmetic::SourceFp32 => ("cpu_matrix_recurrence", "fp32"),
        StateCarryArithmetic::Bf16Transport => {
            ("cpu_matrix_recurrence", "bf16_round_trip_around_cpu_fp32")
        }
    };
    Ok(StateCarryPathReceipt {
        wkv_executor,
        transport_precision,
        seed_attention_previous: numeric_receipt(&step.seed.attention_previous)?,
        seed_ffn_previous: numeric_receipt(&step.seed.ffn_previous)?,
        wkv_inputs: StateCarryWkvInputReceipt {
            r: numeric_receipt(&step.consumed_inputs.r)?,
            w: numeric_receipt(&step.consumed_inputs.w)?,
            k: numeric_receipt(&step.consumed_inputs.k)?,
            v: numeric_receipt(&step.consumed_inputs.v)?,
            a: numeric_receipt(&step.consumed_inputs.a)?,
            b: numeric_receipt(&step.consumed_inputs.b)?,
        },
        pre_state: numeric_receipt(&step.consumed_pre_state)?,
        raw_wkv_output: numeric_receipt(&step.raw_wkv_output)?,
        post_state: numeric_receipt(&step.post_state)?,
        attention_output: numeric_receipt(&step.attention_output)?,
        ffn_input: numeric_receipt(&step.ffn_input)?,
        final_layer_output: numeric_receipt(&step.final_layer_output)?,
    })
}

fn canonical_receipt_blake3<T: Serialize>(receipt: &T) -> Result<String, String> {
    let mut bytes = serde_json::to_vec_pretty(receipt)
        .map_err(|error| format!("failed to serialize canonical receipt: {error}"))?;
    bytes.push(b'\n');
    Ok(blake3::hash(&bytes).to_hex().to_string())
}

struct ValidatedObservedEvidence {
    comparison: DeviceComparisonEvidence,
    device_initialized: bool,
    workload_enqueue_count: usize,
    session: SessionEvidence,
}

fn validate_observed_evidence(
    evidence: &Ttwkv7ObservedLayerEvidence<'_>,
) -> Result<ValidatedObservedEvidence, String> {
    require_exact_blake3(
        evidence.classification_receipt,
        OBSERVED_CLASSIFICATION_BLAKE3,
        "classification receipt",
    )?;
    require_exact_blake3(
        evidence.session_evidence,
        OBSERVED_SESSION_EVIDENCE_BLAKE3,
        "session evidence",
    )?;
    require_exact_blake3(
        evidence.diagnostic_log,
        OBSERVED_DIAGNOSTIC_BLAKE3,
        "diagnostic log",
    )?;
    require_exact_blake3(
        evidence.board_after,
        OBSERVED_BOARD_BLAKE3,
        "board evidence",
    )?;
    require_exact_blake3(
        evidence.owner_after,
        OBSERVED_OWNER_BLAKE3,
        "owner evidence",
    )?;
    require_exact_blake3(
        evidence.boundary_manifest,
        OBSERVED_BOUNDARY_MANIFEST_BLAKE3,
        "boundary manifest",
    )?;
    require_exact_blake3(
        evidence.prepared_receipt,
        OBSERVED_PREPARED_BLAKE3,
        "prepared receipt",
    )?;
    require_exact_blake3(
        evidence.boundary_receipt,
        OBSERVED_BOUNDARY_RECEIPT_BLAKE3,
        "boundary receipt",
    )?;
    require_exact_blake3(
        evidence.writer_raw_bf16,
        OBSERVED_WRITER_BLAKE3,
        "writer raw BF16",
    )?;
    require_exact_blake3(
        evidence.observed_output_bf16,
        OBSERVED_OUTPUT_BLAKE3,
        "observed output BF16",
    )?;
    require_exact_blake3(
        evidence.observed_post_state_bf16,
        OBSERVED_POST_STATE_BLAKE3,
        "observed post-state BF16",
    )?;
    require_exact_blake3(
        evidence.session_manifest,
        OBSERVED_SESSION_MANIFEST_BLAKE3,
        "session manifest",
    )?;
    require_exact_blake3(
        evidence.plan_receipt,
        OBSERVED_PLAN_RECEIPT_BLAKE3,
        "plan receipt",
    )?;

    if evidence.writer_raw_bf16.len() != OBSERVED_WRITER_BYTE_COUNT {
        return Err(format!(
            "writer raw BF16 byte count must be {OBSERVED_WRITER_BYTE_COUNT}, found {}",
            evidence.writer_raw_bf16.len()
        ));
    }
    if evidence.observed_output_bf16.len() != OBSERVED_OUTPUT_BYTE_COUNT {
        return Err(format!(
            "observed output BF16 byte count must be {OBSERVED_OUTPUT_BYTE_COUNT}, found {}",
            evidence.observed_output_bf16.len()
        ));
    }
    if evidence.observed_post_state_bf16.len() != OBSERVED_STATE_BYTE_COUNT {
        return Err(format!(
            "observed post-state BF16 byte count must be {OBSERVED_STATE_BYTE_COUNT}, found {}",
            evidence.observed_post_state_bf16.len()
        ));
    }

    let classification: ClassificationEvidence =
        parse_json(evidence.classification_receipt, "classification receipt")?;
    validate_classification(&classification)?;
    let session: SessionEvidence = parse_json(evidence.session_evidence, "session evidence")?;
    validate_session(&session, evidence)?;
    let boundary: BoundaryDeviceReceiptEvidence =
        parse_json(evidence.boundary_receipt, "boundary receipt")?;
    validate_boundary_receipt(&boundary, evidence)?;
    let prepared: PreparedEvidence = parse_json(evidence.prepared_receipt, "prepared receipt")?;
    validate_prepared(&prepared)?;
    let plan_receipt: PlanReceiptEvidence = parse_json(evidence.plan_receipt, "plan receipt")?;
    let session_manifest: PlanEvidence = parse_json(evidence.session_manifest, "session manifest")?;
    validate_plan(&plan_receipt, &session_manifest)?;
    let _: serde_json::Value = parse_json(evidence.board_after, "board evidence")?;
    let diagnostic = std::str::from_utf8(evidence.diagnostic_log)
        .map_err(|error| format!("diagnostic log is not UTF-8: {error}"))?;
    let marker_count = diagnostic
        .lines()
        .filter(|line| *line == OBSERVED_SUCCESS_MARKER)
        .count();
    if marker_count != OBSERVED_PROCESS_COUNT {
        return Err(format!(
            "diagnostic log requires one exact success marker, found {marker_count}"
        ));
    }
    if evidence.owner_after != EXPECTED_OWNER_PROPERTIES.as_bytes() {
        return Err("owner evidence does not match the exact terminal active state".to_owned());
    }
    if evidence.boundary_manifest != EXPECTED_BOUNDARY_MANIFEST.as_bytes() {
        return Err("boundary manifest content or row order changed".to_owned());
    }

    Ok(ValidatedObservedEvidence {
        comparison: boundary.comparison,
        device_initialized: boundary.device_initialized,
        workload_enqueue_count: boundary.workload_enqueue_count,
        session,
    })
}

fn validate_classification(classification: &ClassificationEvidence) -> Result<(), String> {
    if classification.schema_version != OBSERVED_SCHEMA_VERSION
        || classification.plan_id != OBSERVED_PLAN_ID
        || classification.outcome != OBSERVED_SESSION_OUTCOME
        || !classification.process_budget_exhausted
        || !classification.missing_artifact_roles.is_empty()
        || !classification.missing_success_markers.is_empty()
        || classification.safety_issues != [OBSERVED_SAFETY_ISSUE]
        || classification.success_claim.is_some()
    {
        return Err("terminal session classification semantics changed".to_owned());
    }
    Ok(())
}

fn validate_session(
    session: &SessionEvidence,
    evidence: &Ttwkv7ObservedLayerEvidence<'_>,
) -> Result<(), String> {
    if session.schema_version != OBSERVED_SCHEMA_VERSION
        || session.plan_id != OBSERVED_PLAN_ID
        || session.process_attempts != OBSERVED_PROCESS_COUNT
        || session.owner_isolation_attempts != OBSERVED_PROCESS_COUNT
        || session.restoration_attempts != OBSERVED_PROCESS_COUNT
        || session.process.exit_status != 0
        || session.process.timed_out
        || !session.owner_active_after
        || session.owner_health_status_after.is_some()
        || !session.board_healthy_after
        || session.observed_markers != [OBSERVED_SUCCESS_MARKER]
    {
        return Err("terminal session evidence semantics changed".to_owned());
    }

    let expected = BTreeMap::from([
        (
            "board_after",
            (OBSERVED_BOARD_BLAKE3, evidence.board_after.len()),
        ),
        (
            "boundary_manifest",
            (
                OBSERVED_BOUNDARY_MANIFEST_BLAKE3,
                evidence.boundary_manifest.len(),
            ),
        ),
        (
            "boundary_receipt",
            (
                OBSERVED_BOUNDARY_RECEIPT_BLAKE3,
                evidence.boundary_receipt.len(),
            ),
        ),
        (
            "diagnostic_log",
            (OBSERVED_DIAGNOSTIC_BLAKE3, evidence.diagnostic_log.len()),
        ),
        (
            "observed_output_bf16",
            (OBSERVED_OUTPUT_BLAKE3, evidence.observed_output_bf16.len()),
        ),
        (
            "observed_post_state_bf16",
            (
                OBSERVED_POST_STATE_BLAKE3,
                evidence.observed_post_state_bf16.len(),
            ),
        ),
        (
            "owner_after",
            (OBSERVED_OWNER_BLAKE3, evidence.owner_after.len()),
        ),
        (
            "writer_raw_bf16",
            (OBSERVED_WRITER_BLAKE3, evidence.writer_raw_bf16.len()),
        ),
    ]);
    validate_artifact_map(&session.artifacts, &expected, OBSERVED_ARTIFACT_ROLE_COUNT)
}

fn validate_artifact_map(
    artifacts: &[SessionArtifactEvidence],
    expected: &BTreeMap<&str, (&str, usize)>,
    expected_count: usize,
) -> Result<(), String> {
    if artifacts.len() != expected_count {
        return Err(format!(
            "session evidence requires {expected_count} artifacts, found {}",
            artifacts.len()
        ));
    }
    let mut observed = BTreeMap::new();
    for artifact in artifacts {
        if observed
            .insert(
                artifact.role.as_str(),
                (artifact.blake3.as_str(), artifact.bytes),
            )
            .is_some()
        {
            return Err(format!("duplicate session artifact role {}", artifact.role));
        }
    }
    if &observed != expected {
        return Err("session artifact authorities changed".to_owned());
    }
    Ok(())
}

fn validate_boundary_receipt(
    receipt: &BoundaryDeviceReceiptEvidence,
    evidence: &Ttwkv7ObservedLayerEvidence<'_>,
) -> Result<(), String> {
    if receipt.schema_version != OBSERVED_SCHEMA_VERSION
        || receipt.fixture_blake3 != EXPECTED_FIXTURE_BLAKE3
        || receipt.ordered_artifact_blake3 != EXPECTED_ORDERED_ARTIFACT_BLAKE3
        || receipt.combined_evidence_blake3 != EXPECTED_COMBINED_DEVICE_EVIDENCE_BLAKE3
        || receipt.runtime_argument_blake3 != EXPECTED_RUNTIME_ARGUMENT_BLAKE3
        || receipt.production_source_blake3.decode_reader != EXPECTED_READER_BLAKE3
        || receipt.production_source_blake3.decode_compute != EXPECTED_COMPUTE_BLAKE3
        || receipt.production_source_blake3.writer != EXPECTED_WRITER_BLAKE3
        || !receipt.device_initialized
        || receipt.workload_enqueue_count != OBSERVED_PROCESS_COUNT
    {
        return Err("boundary device receipt authorities changed".to_owned());
    }
    validate_comparison(&receipt.comparison)?;

    if receipt.artifacts.len() != OBSERVED_DEVICE_ARTIFACT_COUNT {
        return Err(format!(
            "boundary device receipt requires {OBSERVED_DEVICE_ARTIFACT_COUNT} artifacts, found {}",
            receipt.artifacts.len()
        ));
    }
    let expected = BTreeMap::from([
        (
            "observed_output_bf16",
            (OBSERVED_OUTPUT_BLAKE3, evidence.observed_output_bf16.len()),
        ),
        (
            "observed_post_state_bf16",
            (
                OBSERVED_POST_STATE_BLAKE3,
                evidence.observed_post_state_bf16.len(),
            ),
        ),
        (
            "writer_raw_bf16",
            (OBSERVED_WRITER_BLAKE3, evidence.writer_raw_bf16.len()),
        ),
    ]);
    let mut observed = BTreeMap::new();
    for artifact in &receipt.artifacts {
        if observed
            .insert(
                artifact.role.as_str(),
                (artifact.blake3.as_str(), artifact.byte_count),
            )
            .is_some()
        {
            return Err(format!(
                "duplicate boundary artifact role {}",
                artifact.role
            ));
        }
    }
    if observed != expected {
        return Err("boundary device artifact authorities changed".to_owned());
    }
    Ok(())
}

fn validate_comparison(comparison: &DeviceComparisonEvidence) -> Result<(), String> {
    if comparison.nmse_ceiling != OBSERVED_NMSE_CEILING
        || !comparison.passed
        || !comparison.output.finite
        || !comparison.post_state.finite
        || !comparison.output.nmse.is_finite()
        || !comparison.post_state.nmse.is_finite()
        || !comparison.output.pcc.is_finite()
        || !comparison.post_state.pcc.is_finite()
        || !comparison.output.maximum_absolute_error.is_finite()
        || !comparison.post_state.maximum_absolute_error.is_finite()
        || comparison.output.nmse >= comparison.nmse_ceiling
        || comparison.post_state.nmse >= comparison.nmse_ceiling
    {
        return Err("boundary device comparison is not a finite strict tolerance pass".to_owned());
    }
    Ok(())
}

fn validate_prepared(prepared: &PreparedEvidence) -> Result<(), String> {
    if prepared.device_initialized
        || prepared.fixture_blake3 != EXPECTED_FIXTURE_BLAKE3
        || prepared.ordered_artifact_blake3 != EXPECTED_ORDERED_ARTIFACT_BLAKE3
        || prepared.target != "rwkv_ttwkv7_boundary_device_harness"
    {
        return Err("prepared boundary authority changed".to_owned());
    }
    Ok(())
}

fn validate_plan(receipt: &PlanReceiptEvidence, manifest: &PlanEvidence) -> Result<(), String> {
    if receipt.schema_version != OBSERVED_SCHEMA_VERSION
        || receipt.plan_id != OBSERVED_PLAN_ID
        || &receipt.plan != manifest
        || manifest.schema_version != OBSERVED_SCHEMA_VERSION
        || manifest.session_id != OBSERVED_SESSION_ID
        || manifest.stage != OBSERVED_STAGE
        || manifest.target.package_path != OBSERVED_PACKAGE_PATH
        || manifest.target.kernel_path != OBSERVED_KERNEL_PATH
        || manifest.target.executable != OBSERVED_EXECUTABLE_PATH
        || manifest.target.arguments != [OBSERVED_ARGUMENT]
        || manifest.hardware.architecture != OBSERVED_ARCHITECTURE
        || manifest.hardware.physical_device != OBSERVED_PHYSICAL_DEVICE
        || manifest.hardware.device_path != OBSERVED_DEVICE_PATH
        || manifest.hardware.owner_unit != OBSERVED_OWNER_UNIT
        || manifest.hardware.owner_control_path != OBSERVED_OWNER_CONTROL_PATH
        || manifest.runtime.run_root != OBSERVED_RUN_ROOT
        || manifest.runtime.cache_path != format!("{OBSERVED_RUN_ROOT}/cache")
        || manifest.runtime.logs_path != format!("{OBSERVED_RUN_ROOT}/logs")
        || manifest.runtime.inspector_address != OBSERVED_INSPECTOR_ADDRESS
        || manifest.budget.max_processes != OBSERVED_PROCESS_COUNT
        || manifest.budget.timeout_seconds != OBSERVED_PROCESS_TIMEOUT_SECONDS
        || manifest.budget.timeout_exit_status != OBSERVED_TIMEOUT_EXIT_STATUS
        || manifest.budget.kill_grace_seconds != OBSERVED_KILL_GRACE_SECONDS
        || manifest.restoration.rollback_delay_seconds != OBSERVED_ROLLBACK_DELAY_SECONDS
        || manifest.restoration.health_url != OBSERVED_HEALTH_URL
        || manifest.restoration.expected_health_status != OBSERVED_HEALTH_STATUS
        || manifest.evidence.required_artifact_roles.len() != OBSERVED_ARTIFACT_ROLE_COUNT
        || manifest.evidence.success_markers != [OBSERVED_SUCCESS_MARKER]
    {
        return Err("observed session plan authority changed".to_owned());
    }
    Ok(())
}

fn expected_boundary_values(
    source: &SequenceResult,
    dimensions: Dimensions,
) -> Result<ExpectedBoundaryValues, String> {
    let vector_shape = [dimensions.head_count, dimensions.head_size];
    let state_shape = [
        dimensions.head_count,
        dimensions.head_size,
        dimensions.head_size,
    ];
    let encoded_a =
        encode_bf16_artifact("a", &vector_shape, &source.second_preparation.wkv_inputs.a)?;
    let encoded_w =
        encode_bf16_artifact("w", &vector_shape, &source.second_preparation.wkv_inputs.w)?;
    let encoded_k =
        encode_bf16_artifact("k", &vector_shape, &source.second_preparation.wkv_inputs.k)?;
    let encoded_v =
        encode_bf16_artifact("v", &vector_shape, &source.second_preparation.wkv_inputs.v)?;
    let encoded_r =
        encode_bf16_artifact("r", &vector_shape, &source.second_preparation.wkv_inputs.r)?;
    let encoded_b =
        encode_bf16_artifact("b", &vector_shape, &source.second_preparation.wkv_inputs.b)?;
    let encoded_pre_state =
        encode_bf16_artifact("pre_state", &state_shape, &source.second_pre_state)?;
    let quantized_inputs = WkvInputs {
        r: decode_bf16_bytes(&encoded_r.bytes, "quantized r")?,
        w: decode_bf16_bytes(&encoded_w.bytes, "quantized w")?,
        k: decode_bf16_bytes(&encoded_k.bytes, "quantized k")?,
        v: decode_bf16_bytes(&encoded_v.bytes, "quantized v")?,
        a: decode_bf16_bytes(&encoded_a.bytes, "quantized a")?,
        b: decode_bf16_bytes(&encoded_b.bytes, "quantized b")?,
    };
    let quantized_pre_state = decode_bf16_bytes(&encoded_pre_state.bytes, "quantized pre-state")?;
    let (post_state, raw_output) =
        wkv_step_matrix(&quantized_pre_state, &quantized_inputs, dimensions)?;
    let encoded_output = encode_bf16_artifact("expected_output", &vector_shape, &raw_output)?;
    let encoded_post_state =
        encode_bf16_artifact("expected_post_state", &state_shape, &post_state)?;
    if encoded_output.receipt.blake3 != EXPECTED_BOUNDARY_OUTPUT_BLAKE3
        || encoded_post_state.receipt.blake3 != EXPECTED_BOUNDARY_POST_STATE_BLAKE3
    {
        return Err("recomputed BF16 boundary identities changed".to_owned());
    }
    Ok(ExpectedBoundaryValues {
        raw_output: decode_bf16_bytes(&encoded_output.bytes, "expected BF16 raw output")?,
        post_state: decode_bf16_bytes(&encoded_post_state.bytes, "expected BF16 post-state")?,
    })
}

fn require_exact_blake3(bytes: &[u8], expected: &str, name: &str) -> Result<(), String> {
    let actual = blake3::hash(bytes).to_hex().to_string();
    if actual != expected {
        return Err(format!(
            "{name} BLAKE3 mismatch: expected {expected}, found {actual}"
        ));
    }
    Ok(())
}

fn parse_json<T: DeserializeOwned>(bytes: &[u8], name: &str) -> Result<T, String> {
    serde_json::from_slice(bytes).map_err(|error| format!("failed to parse {name}: {error}"))
}

fn observed_evidence_bundle_blake3(
    evidence: &Ttwkv7ObservedLayerEvidence<'_>,
) -> Result<String, String> {
    let ordered = [
        evidence.classification_receipt,
        evidence.session_evidence,
        evidence.diagnostic_log,
        evidence.board_after,
        evidence.owner_after,
        evidence.boundary_manifest,
        evidence.prepared_receipt,
        evidence.boundary_receipt,
        evidence.writer_raw_bf16,
        evidence.observed_output_bf16,
        evidence.observed_post_state_bf16,
        evidence.session_manifest,
        evidence.plan_receipt,
    ];
    let mut hasher = blake3::Hasher::new();
    hasher.update(OBSERVED_EVIDENCE_HASH_DOMAIN);
    for bytes in ordered {
        let byte_count = u64::try_from(bytes.len())
            .map_err(|error| format!("evidence byte count does not fit u64: {error}"))?;
        hasher.update(&byte_count.to_le_bytes());
        hasher.update(bytes);
    }
    Ok(hasher.finalize().to_hex().to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    const TEST_FINITE_ERROR: f64 = 1.0e-3;
    const TEST_FINITE_PCC: f64 = 0.999;
    const DUPLICATE_ARTIFACT_COUNT: usize = 2;

    // r[verify onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_observed_layer_replay]
    #[test]
    fn finite_comparison_requires_strict_nmse_ceiling() {
        let passing = DeviceComparisonEvidence {
            nmse_ceiling: OBSERVED_NMSE_CEILING,
            output: ComparisonMetricsEvidence {
                exact_bit_mismatch_count: 1,
                finite: true,
                maximum_absolute_error: TEST_FINITE_ERROR,
                nmse: TEST_FINITE_ERROR,
                pcc: TEST_FINITE_PCC,
            },
            passed: true,
            post_state: ComparisonMetricsEvidence {
                exact_bit_mismatch_count: 1,
                finite: true,
                maximum_absolute_error: TEST_FINITE_ERROR,
                nmse: TEST_FINITE_ERROR,
                pcc: TEST_FINITE_PCC,
            },
        };
        assert!(validate_comparison(&passing).is_ok());

        let mut threshold_equal = passing;
        threshold_equal.output.nmse = OBSERVED_NMSE_CEILING;
        assert!(validate_comparison(&threshold_equal).is_err());

        let mut non_finite = passing;
        non_finite.post_state.pcc = f64::NAN;
        assert!(validate_comparison(&non_finite).is_err());
    }

    #[test]
    fn terminal_classification_must_remain_unsafe() {
        let accepted = ClassificationEvidence {
            schema_version: OBSERVED_SCHEMA_VERSION,
            plan_id: OBSERVED_PLAN_ID.to_owned(),
            outcome: OBSERVED_SESSION_OUTCOME.to_owned(),
            process_budget_exhausted: true,
            missing_artifact_roles: Vec::new(),
            missing_success_markers: Vec::new(),
            safety_issues: vec![OBSERVED_SAFETY_ISSUE.to_owned()],
            success_claim: None,
        };
        assert!(validate_classification(&accepted).is_ok());

        let mut rewritten = accepted;
        rewritten.outcome = "passed".to_owned();
        assert!(validate_classification(&rewritten).is_err());
    }

    #[test]
    fn artifact_roles_are_complete_and_unique() {
        let expected = BTreeMap::from([("role", ("digest", 1_usize))]);
        let accepted = [SessionArtifactEvidence {
            role: "role".to_owned(),
            blake3: "digest".to_owned(),
            bytes: 1,
        }];
        assert!(validate_artifact_map(&accepted, &expected, 1).is_ok());

        let duplicate = [
            SessionArtifactEvidence {
                role: "role".to_owned(),
                blake3: "digest".to_owned(),
                bytes: 1,
            },
            SessionArtifactEvidence {
                role: "role".to_owned(),
                blake3: "digest".to_owned(),
                bytes: 1,
            },
        ];
        assert!(validate_artifact_map(&duplicate, &expected, DUPLICATE_ARTIFACT_COUNT).is_err());
        assert!(validate_artifact_map(&[], &expected, 1).is_err());
    }

    #[test]
    fn evidence_bundle_binds_ordered_bytes() {
        let accepted = test_evidence(b"a");
        let repeated = test_evidence(b"a");
        let changed = test_evidence(b"b");
        let accepted_hash = observed_evidence_bundle_blake3(&accepted).expect("hash must succeed");
        let repeated_hash = observed_evidence_bundle_blake3(&repeated).expect("hash must succeed");
        let changed_hash = observed_evidence_bundle_blake3(&changed).expect("hash must succeed");
        assert_eq!(accepted_hash, repeated_hash);
        assert_ne!(accepted_hash, changed_hash);
    }

    fn test_evidence(classification_receipt: &[u8]) -> Ttwkv7ObservedLayerEvidence<'_> {
        Ttwkv7ObservedLayerEvidence {
            classification_receipt,
            session_evidence: b"session",
            diagnostic_log: b"diagnostic",
            board_after: b"board",
            owner_after: b"owner",
            boundary_manifest: b"manifest",
            prepared_receipt: b"prepared",
            boundary_receipt: b"receipt",
            writer_raw_bf16: b"writer",
            observed_output_bf16: b"output",
            observed_post_state_bf16: b"state",
            session_manifest: b"session-manifest",
            plan_receipt: b"plan",
        }
    }
}
