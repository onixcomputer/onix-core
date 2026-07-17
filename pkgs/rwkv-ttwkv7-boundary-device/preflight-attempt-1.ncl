let CounterSet = {
  execution_attempts | Number,
  process_attempts | Number,
  owner_isolation_attempts | Number,
  restoration_attempts | Number,
  service_stop_attempts | Number,
  rollback_arm_attempts | Number,
}
in
let Hashes = {
  classification_receipt_blake3 | String,
  known_hosts_blake3 | String,
  preflight_failure_blake3 | String,
  session_evidence_blake3 | String,
  ordered_evidence_hash_file_blake3 | String,
}
in
let PreflightReceipt = {
  schema_version | Number,
  plan_id | String,
  command | String,
  run_root | String,
  failure | String,
  expected_fingerprint | String,
  observed_fingerprint | String,
  counters | CounterSet,
  outcome | String,
  process_budget_exhausted | Bool,
  safety_issues | Array String,
  success_claim | Dyn,
  missing_artifact_roles | Array String,
  missing_success_markers | Array String,
  hashes | Hashes,
  claims
    | {
      device_path_metadata_checked | Bool,
      board_queried | Bool,
      device_opened | Bool,
      metalium_initialized | Bool,
      kernel_executed | Bool,
      owner_changed | Bool,
      device_process_started | Bool,
    },
}
in
let receipt_schema_version = 1 in
let zero_attempts = 0 in
{
  schema_version = receipt_schema_version,
  plan_id = "bdbc6834b6ba3da6e1404858697a01d68d1f58734401d81f4a0f0d2999a5b239",
  command = "./cairn/archive/2026-07-17-prepare-rwkv-ttwkv7-boundary-one-shot/run-one-shot.sh",
  run_root = "/var/tmp/rwkv-ttwkv7-boundary-device-1",
  failure = "loopback host fingerprint mismatch",
  expected_fingerprint = "SHA256:0vd1vzTWrAONyquNKjwnsGY7a5bY2NJlvFamtxy/akY",
  observed_fingerprint = "SHA256:DOOddCNRRRqCVbueQZovbR8Q//NwYeeMCaznz+GqxQE",
  counters = {
    execution_attempts = zero_attempts,
    process_attempts = zero_attempts,
    owner_isolation_attempts = zero_attempts,
    restoration_attempts = zero_attempts,
    service_stop_attempts = zero_attempts,
    rollback_arm_attempts = zero_attempts,
  },
  outcome = "not_run",
  process_budget_exhausted = false,
  safety_issues = [],
  success_claim = null,
  missing_artifact_roles = [
    "board_after",
    "boundary_manifest",
    "boundary_receipt",
    "diagnostic_log",
    "observed_output_bf16",
    "observed_post_state_bf16",
    "owner_after",
    "writer_raw_bf16",
  ],
  missing_success_markers = ["rwkv ttWKV7 boundary device probe: PASS"],
  hashes = {
    classification_receipt_blake3 = "a7169162e27db4a98b6b3cca834f1e601739ccd7c7398ad49ccd32bc09f38190",
    known_hosts_blake3 = "285f73e5f4bebea3633a468efe817e84c8a334ef1061784723e50fcde3211196",
    preflight_failure_blake3 = "6349613fd9c7fe46c5eacf50857f653bb8bd165dfd17d5b3019d4ea25b701b28",
    session_evidence_blake3 = "3bafd7d869f16dac5344039e1a8cdc37202191d0dc03c0675a34d75bdf3c06ac",
    ordered_evidence_hash_file_blake3 = "45cc0eaaf938b09e53aa5e52422536f44189b284ff1d99b9062548f0db2da9d5",
  },
  claims = {
    device_path_metadata_checked = true,
    board_queried = false,
    device_opened = false,
    metalium_initialized = false,
    kernel_executed = false,
    owner_changed = false,
    device_process_started = false,
  },
} | PreflightReceipt
