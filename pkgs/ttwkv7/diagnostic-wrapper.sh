#!/usr/bin/env bash
set -euo pipefail

minimum_inspector_port=1
maximum_inspector_port=65535
expected_argument_count=0
expected_visible_device=1
runtime_failure_status=1
invalid_mode_status=2

error_out() {
  printf 'wkv7-diagnose: %s\n' "$1" >&2
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
  local visible_devices="${TT_VISIBLE_DEVICES:-}"
  [[ $visible_devices == "$expected_visible_device" ]] ||
    error_out "TT_VISIBLE_DEVICES must select physical device 1 exactly"
}

validate_runtime_state() {
  local cache_path="${TT_METAL_CACHE:-}"
  local logs_path="${TT_METAL_LOGS_PATH:-}"
  local inspector_address="${TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS:-}"

  is_safe_absolute_directory_path "$cache_path" ||
    error_out "TT_METAL_CACHE must be an absolute writable path outside /nix/store"
  is_safe_absolute_directory_path "$logs_path" ||
    error_out "TT_METAL_LOGS_PATH must be an absolute writable path outside /nix/store"
  is_loopback_inspector_address "$inspector_address" ||
    error_out "TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS must be 127.0.0.1:<1-65535>"
}

prepare_directory() {
  local variable_name="$1"
  local directory_path="$2"

  mkdir -p -- "$directory_path" ||
    error_out "$variable_name could not be created: $directory_path"
  [[ -d $directory_path && -w $directory_path ]] ||
    error_out "$variable_name must name a writable directory: $directory_path"
}

prepare_runtime_state() {
  prepare_directory TT_METAL_CACHE "$TT_METAL_CACHE"
  prepare_directory TT_METAL_LOGS_PATH "$TT_METAL_LOGS_PATH"
}

require_no_suffix_arguments() {
  local mode="$1"
  local actual_argument_count="$2"
  if ((actual_argument_count != expected_argument_count)); then
    error_out "$mode does not accept additional arguments"
    return "$runtime_failure_status"
  fi
}

# r[impl onix.tenstorrent.native_runtime.ttwkv7.cross_kernel_diagnostic]
mode="${1:-}"
case "$mode" in
validate-runtime)
  shift
  require_no_suffix_arguments "$mode" "$#"
  validate_device_selection
  validate_runtime_state
  prepare_runtime_state
  printf 'ttWKV7 diagnostic runtime state preflight: PASS\n'
  ;;
diagnose)
  shift
  require_no_suffix_arguments "$mode" "$#"
  validate_device_selection
  validate_runtime_state
  prepare_runtime_state
  exec "@diagnosticExecutable@" test all 1 1
  ;;
*)
  printf 'wkv7-diagnose: usage: wkv7-diagnose validate-runtime|diagnose\n' >&2
  exit "$invalid_mode_status"
  ;;
esac
