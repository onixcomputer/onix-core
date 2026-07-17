let { Session, .. } = import "../session-contract.ncl" in
let diagnostic_timeout_seconds = 600 in
let diagnostic_timeout_exit_status = 124 in
let timeout_kill_grace_seconds = 10 in
let independent_rollback_delay_seconds = 900 in
let owner_expected_health_status = 200 in
let inspector_port = 43137 in

{
  schema_version = 1,
  session_id = "reader-l1-repair-device-1",
  stage = "data_movement",
  target = {
    package_path = "/nix/store/example-ttwkv7",
    kernel_path = "/nix/store/example-ttwkv7-kernels/share/ttwkv7/kernels",
    executable = "/nix/store/example-ttwkv7/bin/wkv7-data-movement",
    arguments = ["probe"],
  },
  hardware = {
    architecture = "Blackhole P150",
    physical_device = 1,
    device_path = "/dev/tenstorrent/1",
    owner_unit = "docker-tt-inference-server-llama-3-1-8b-instruct-p150.service",
    owner_control_path = "/nix/store/example-owner-control/bin/ttwkv7-owner-control",
  },
  runtime = {
    run_root = "/var/tmp/rwkv-lab-reader-l1-repair-device-1",
    cache_path = "/var/tmp/rwkv-lab-reader-l1-repair-device-1/cache",
    logs_path = "/var/tmp/rwkv-lab-reader-l1-repair-device-1/logs",
    inspector_address = "127.0.0.1:%{inspector_port}",
  },
  budget = {
    max_processes = 1,
    timeout_seconds = diagnostic_timeout_seconds,
    timeout_exit_status = diagnostic_timeout_exit_status,
    kill_grace_seconds = timeout_kill_grace_seconds,
  },
  restoration = {
    rollback_delay_seconds = independent_rollback_delay_seconds,
    health_url = "http://127.0.0.1:8000/health",
    expected_health_status = owner_expected_health_status,
  },
  evidence = {
    required_artifact_roles = ["board_after", "diagnostic_log", "owner_after"],
    success_markers = ["data-movement device probe: PASS"],
  },
  claims = {
    success = "The exact data-movement session completed with its reviewed evidence.",
    non_claims = [
      "No full RWKV correctness is established.",
      "No general P150 compatibility is established.",
      "No token generation is established.",
    ],
  },
} | Session
