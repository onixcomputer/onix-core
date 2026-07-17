let { Session, .. } = import "session-contract.ncl" in
let hardware_timeout_seconds = 900 in
let hardware_timeout_exit_status = 124 in
let timeout_kill_grace_seconds = 10 in
let independent_rollback_delay_seconds = 1200 in
let owner_expected_health_status = 200 in
let inspector_port = 43147 in

{
  schema_version = 1,
  session_id = "rwkv-ttwkv7-boundary-device-1",
  stage = "operator",
  target = {
    package_path = "@packagePath@",
    kernel_path = "@kernelPath@",
    executable = "@executablePath@",
    arguments = ["probe"],
  },
  hardware = {
    architecture = "Blackhole P150",
    physical_device = 1,
    device_path = "/dev/tenstorrent/1",
    owner_unit = "docker-tt-inference-server-llama-3-1-8b-instruct-p150.service",
    owner_control_path = "@ownerControlPath@",
  },
  runtime = {
    run_root = "/var/tmp/rwkv-ttwkv7-boundary-device-1",
    cache_path = "/var/tmp/rwkv-ttwkv7-boundary-device-1/cache",
    logs_path = "/var/tmp/rwkv-ttwkv7-boundary-device-1/logs",
    inspector_address = "127.0.0.1:%{inspector_port}",
  },
  budget = {
    max_processes = 1,
    timeout_seconds = hardware_timeout_seconds,
    timeout_exit_status = hardware_timeout_exit_status,
    kill_grace_seconds = timeout_kill_grace_seconds,
  },
  restoration = {
    rollback_delay_seconds = independent_rollback_delay_seconds,
    health_url = "http://127.0.0.1:8000/health",
    expected_health_status = owner_expected_health_status,
  },
  evidence = {
    required_artifact_roles = [
      "board_after",
      "boundary_manifest",
      "boundary_receipt",
      "diagnostic_log",
      "observed_output_bf16",
      "observed_post_state_bf16",
      "owner_after",
      "writer_raw_bf16",
    ],
    success_markers = ["rwkv ttWKV7 boundary device probe: PASS"],
  },
  claims = {
    success = "The exact retained-state BF16 boundary completed one production DecodeL workload within the predeclared output and state NMSE ceilings, with complete evidence and restored ownership.",
    non_claims = [
      "No exact BF16 parity is established by a tolerance pass.",
      "No full RWKV layer or model execution is established.",
      "No general P150 compatibility is established.",
      "No generation or serving behavior is established.",
      "No hardware execution is authorized by this plan artifact.",
      "No throughput or latency claim is established.",
    ],
  },
} | Session
