let { Session, .. } = import "../session-contract.ncl" in

{
  schema_version = 1,
  session_id = "invalid-session",
  stage = "data_movement",
  target = {
    package_path = "/nix/store/example-ttwkv7",
    kernel_path = "/nix/store/example-ttwkv7-kernels",
    executable = "/nix/store/example-ttwkv7/bin/wkv7-data-movement",
    arguments = ["probe"],
  },
  hardware = {
    architecture = "Blackhole P150",
    physical_device = 1,
    device_path = "/dev/tenstorrent/1",
    owner_unit = "owner.service",
    owner_control_path = "/nix/store/example-owner-control/bin/owner-control",
  },
  runtime = {
    run_root = "/var/tmp/rwkv-lab-invalid",
    cache_path = "/var/tmp/rwkv-lab-invalid/cache",
    logs_path = "/var/tmp/rwkv-lab-invalid/logs",
    inspector_address = "127.0.0.1:43137",
  },
  budget = {
    max_processes = "one",
    timeout_seconds = 600,
    timeout_exit_status = 124,
    kill_grace_seconds = 10,
  },
  restoration = {
    rollback_delay_seconds = 900,
    health_url = "http://127.0.0.1:8000/health",
    expected_health_status = 200,
  },
  evidence = {
    required_artifact_roles = ["diagnostic_log"],
    success_markers = ["PASS"],
  },
  claims = {
    success = "invalid",
    non_claims = ["invalid"],
  },
} | Session
