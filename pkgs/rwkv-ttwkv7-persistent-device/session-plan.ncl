let { Session, .. } = import "session-contract.ncl" in
let process_timeout_seconds = 1800 in
let process_timeout_exit_status = 124 in
let timeout_kill_grace_seconds = 10 in
let independent_rollback_delay_seconds = 2100 in
let owner_health_window_seconds = 600 in
let owner_expected_health_status = 200 in
let inspector_port = 43158 in
let persistent_session_id = "rwkv-ttwkv7-persistent-device-4" in
let persistent_run_root = "/var/tmp/%{persistent_session_id}" in

{
  schema_version = 1,
  session_id = persistent_session_id,
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
    run_root = persistent_run_root,
    cache_path = "%{persistent_run_root}/cache",
    logs_path = "%{persistent_run_root}/logs",
    inspector_address = "127.0.0.1:%{inspector_port}",
  },
  budget = {
    max_processes = 1,
    timeout_seconds = process_timeout_seconds,
    timeout_exit_status = process_timeout_exit_status,
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
      "child_stderr",
      "child_stdout",
      "core_receipt",
      "diagnostic_log",
      "host_manifest",
      "host_receipt",
      "owner_after",
      "process_receipt",
      "server_summary",
      "transcript",
    ],
    success_markers = ["rwkv persistent physical ttWKV7 dispatch: PASS"],
  },
  claims = {
    success = "One persistent device-1 Metalium child completed exactly twenty-four canonical production DecodeL ttWKV7 calls across the third and fourth model tokens, with request-bound finite responses inside the numerical ceilings, twelve exact physical state-continuity edges, matching oracle rankings, complete evidence, healthy board state, and restored ownership within %{owner_health_window_seconds} seconds.",
    non_claims = [
      "No complete RWKV layer or model executes wholly on Tenstorrent devices.",
      "No exact BF16 parity is established by a tolerance pass.",
      "No general P150 compatibility is established.",
      "No hardware execution is authorized by this plan artifact alone.",
      "No serving, throughput, or latency claim is established.",
      "Only ttWKV7 executes on the device; model composition remains on the CPU host.",
      "Tasks 30, 64, and 281 remain terminal and are not reusable.",
    ],
  },
} | Session
