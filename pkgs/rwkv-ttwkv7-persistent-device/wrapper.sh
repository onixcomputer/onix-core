#!/usr/bin/env bash
set -euo pipefail

minimum_inspector_port=1
maximum_inspector_port=65535
expected_visible_device=1
expected_argument_count=0
runtime_failure_status=1
invalid_mode_status=2
artifact_directory_name="rwkv-persistent-physical-dispatch"
evidence_root="@evidenceRoot@"
host_executable="@hostExecutable@"
core_executable="@coreExecutable@"
cpu_server_executable="@cpuServerExecutable@"
metalium_server_executable="@metaliumServerExecutable@"

error_out() {
  printf 'rwkv-ttwkv7-persistent-device: %s\n' "$1" >&2
  return "$runtime_failure_status"
}

is_safe_absolute_directory_path() {
  local candidate="$1"
  case "$candidate" in
  /*) ;;
  *) return "$runtime_failure_status" ;;
  esac
  case "$candidate" in
  /nix/store | /nix/store/*) return "$runtime_failure_status" ;;
  *) return 0 ;;
  esac
}

is_loopback_inspector_address() {
  local address="$1"
  local host="${address%:*}"
  local port_text="${address##*:}"
  [[ $host == "127.0.0.1" ]] || return "$runtime_failure_status"
  [[ $port_text =~ ^[0-9]+$ ]] || return "$runtime_failure_status"
  local port_number=$((10#$port_text))
  ((port_number >= minimum_inspector_port && port_number <= maximum_inspector_port))
}

validate_device_selection() {
  [[ ${TT_VISIBLE_DEVICES:-} == "$expected_visible_device" ]] ||
    error_out "TT_VISIBLE_DEVICES must select physical device 1 exactly"
}

validate_runtime_state() {
  is_safe_absolute_directory_path "${TT_METAL_CACHE:-}" ||
    error_out "TT_METAL_CACHE must be an absolute writable path outside /nix/store"
  is_safe_absolute_directory_path "${TT_METAL_LOGS_PATH:-}" ||
    error_out "TT_METAL_LOGS_PATH must be an absolute writable path outside /nix/store"
  is_loopback_inspector_address "${TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS:-}" ||
    error_out "TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS must be 127.0.0.1:<1-65535>"
}

prepare_runtime_state() {
  mkdir -p -- "$TT_METAL_CACHE" "$TT_METAL_LOGS_PATH"
  [[ -d $TT_METAL_CACHE && -w $TT_METAL_CACHE ]] ||
    error_out "TT_METAL_CACHE must be writable"
  [[ -d $TT_METAL_LOGS_PATH && -w $TT_METAL_LOGS_PATH ]] ||
    error_out "TT_METAL_LOGS_PATH must be writable"
}

require_no_suffix_arguments() {
  local mode="$1"
  local actual_argument_count="$2"
  if ((actual_argument_count != expected_argument_count)); then
    error_out "$mode does not accept additional arguments"
    return "$runtime_failure_status"
  fi
}

unset RWKV_TTWKV7_CPU_SERVER_FAULT
mode="${1:-}"
case "$mode" in
self-test)
  shift
  require_no_suffix_arguments "$mode" "$#"
  self_test_parent="$(mktemp -d)"
  trap 'rm -rf -- "$self_test_parent"' EXIT
  "$host_executable" \
    --test-server "$cpu_server_executable" \
    --evidence-root "$evidence_root" \
    --artifact-root "$self_test_parent/artifacts"
  ;;
validate-runtime)
  shift
  require_no_suffix_arguments "$mode" "$#"
  validate_device_selection
  validate_runtime_state
  prepare_runtime_state
  "$metalium_server_executable" dispatch-server-self-test >/dev/null
  "$core_executable" --negative-response-self-test "$evidence_root" >/dev/null
  printf 'rwkv persistent physical dispatch runtime state preflight: PASS\n'
  ;;
probe)
  shift
  require_no_suffix_arguments "$mode" "$#"
  validate_device_selection
  validate_runtime_state
  prepare_runtime_state
  exec "$host_executable" \
    --server "$metalium_server_executable" \
    --evidence-root "$evidence_root" \
    --artifact-root "$TT_METAL_LOGS_PATH/$artifact_directory_name"
  ;;
*)
  printf 'rwkv-ttwkv7-persistent-device: usage: rwkv-ttwkv7-persistent-device self-test|validate-runtime|probe\n' >&2
  exit "$invalid_mode_status"
  ;;
esac
