let Artifact = {
  role | String,
  filename | String,
  byte_count | Number,
  blake3 | String,
}
in
let Terminal = {
  plan_id | String,
  session_id | String,
  outcome | String,
  process_budget_exhausted | Bool,
  safety_issues | Array String,
  success_claim | Dyn,
}
in
let HardwareComparison = {
  device_initialized | Bool,
  workload_enqueue_count | Number,
  process_exit_status | Number,
  process_timed_out | Bool,
  nmse_ceiling | Number,
  output_nmse | Number,
  output_pcc | Number,
  output_maximum_absolute_error | Number,
  output_exact_bit_mismatch_count | Number,
  post_state_nmse | Number,
  post_state_pcc | Number,
  post_state_maximum_absolute_error | Number,
  post_state_exact_bit_mismatch_count | Number,
}
in
let PostRunRecovery = {
  owner_active | Bool,
  owner_health_status | Number,
  owner_restart_count | Number,
  rollback_completed | Bool,
  terminal_classification_rewritten | Bool,
}
in
let Receipt = {
  schema_version | Number,
  target | String,
  terminal | Terminal,
  hardware_comparison | HardwareComparison,
  artifacts | Array Artifact,
  post_run_recovery | PostRunRecovery,
}
in
let receipt_schema_version = 1 in
let zero = 0 in
{
  schema_version = receipt_schema_version,
  target = "rwkv_ttwkv7_observed_layer_evidence",
  terminal = {
    plan_id = "d4886116b76df2cf63090e3a1f7efff35aa215aa2d05652d7accaa9b61a9abb1",
    session_id = "rwkv-ttwkv7-boundary-device-2",
    outcome = "unsafe",
    process_budget_exhausted = true,
    safety_issues = ["owner health status did not match the manifest"],
    success_claim = null,
  },
  hardware_comparison = {
    device_initialized = true,
    workload_enqueue_count = 1,
    process_exit_status = zero,
    process_timed_out = false,
    nmse_ceiling = 0.06,
    output_nmse = 0.000014987897011677202,
    output_pcc = 0.9999933336644342,
    output_maximum_absolute_error = 0.00048828125,
    output_exact_bit_mismatch_count = 541,
    post_state_nmse = 0.000015454054999825693,
    post_state_pcc = 0.999994067952902,
    post_state_maximum_absolute_error = 0.0078125,
    post_state_exact_bit_mismatch_count = 23816,
  },
  artifacts = [
    {
      role = "board_after",
      filename = "board-after-second.json",
      byte_count = 8722,
      blake3 = "532278a6f786713d51e5a1e36450d1fd64555f2e5ad947ff548b88a06d709ab6",
    },
    {
      role = "boundary_manifest",
      filename = "boundary-manifest.tsv",
      byte_count = 389,
      blake3 = "7f62e65f31033b12709a19897fb81779c8236e187ab734a56d6c553bf36550e9",
    },
    {
      role = "boundary_receipt",
      filename = "boundary-receipt.json",
      byte_count = 4175,
      blake3 = "ed95aeeeef6fd579f5b257c6ff7fe63eeae260f616e6a52b9b192c9b37f35436",
    },
    {
      role = "classification_receipt",
      filename = "classification-receipt.json",
      byte_count = 712,
      blake3 = "30577762498fccc1f00c29c9ec01d9cacdc509a332211ff6ef7e8fa67fc1f9bd",
    },
    {
      role = "diagnostic_log",
      filename = "diagnostic.log",
      byte_count = 41554,
      blake3 = "6fba33e0b51530d63346415f25565283f68b05e0260d7f89024abb58bac60fdd",
    },
    {
      role = "observed_output_bf16",
      filename = "observed-output.bf16",
      byte_count = 1536,
      blake3 = "417a583d87e901c5488266e84f3f9cfba98e2bbe45fc8da952c8cb4b06afc66a",
    },
    {
      role = "observed_post_state_bf16",
      filename = "observed-post-state.bf16",
      byte_count = 98304,
      blake3 = "b3321aeb38963fb96a720ae33d9477e8fbfb83b3750213abc64786885d3771a9",
    },
    {
      role = "owner_after",
      filename = "owner-after.properties",
      byte_count = 63,
      blake3 = "ca21ead27b78c78bf3bf23fa04f42cc3922190ca93e1cdedc1d64b36c5b24d85",
    },
    {
      role = "plan_receipt",
      filename = "plan-receipt.json",
      byte_count = 2548,
      blake3 = "307efa0052ae9b5b003d7c6026ba0340e527cbea4a6e057bfa70df84c53e0291",
    },
    {
      role = "prepared_receipt",
      filename = "prepared.json",
      byte_count = 253,
      blake3 = "4e14b262c41077507987002d1a48bed1a3af58e342ac26ad0379caac52ae50cd",
    },
    {
      role = "session_evidence",
      filename = "session-evidence.json",
      byte_count = 1364,
      blake3 = "612a4156b76771911297fb762f3e3ba0ea2792c1d839d61cd1824d122c923aa7",
    },
    {
      role = "session_manifest",
      filename = "session-manifest.json",
      byte_count = 2306,
      blake3 = "d248124f88d5cd933cf6a5c6335ab8a7e9cbad5e59289380c16bbda9b3c82812",
    },
    {
      role = "writer_raw_bf16",
      filename = "writer-raw.bf16",
      byte_count = 147456,
      blake3 = "a8d4304ca77c69cb58e55360755acd25a5847a2ca5884fbe807fe634d89a0c18",
    },
  ],
  post_run_recovery = {
    owner_active = true,
    owner_health_status = 200,
    owner_restart_count = zero,
    rollback_completed = true,
    terminal_classification_rewritten = false,
  },
} | Receipt
