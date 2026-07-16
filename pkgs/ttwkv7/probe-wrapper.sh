#!/usr/bin/env bash
set -euo pipefail

minimum_inspector_port=1
maximum_inspector_port=65535
preflight_argument_count=0

error_out() {
  printf 'wkv7-constant-probe: %s\n' "$1" >&2
  return 1
}

is_safe_absolute_directory_path() {
  local candidate="$1"
  case "$candidate" in
  /*) ;;
  *) return 1 ;;
  esac
  case "$candidate" in
  /nix/store | /nix/store/*) return 1 ;;
  *) return 0 ;;
  esac
}

is_loopback_inspector_address() {
  local address="$1"
  local host="${address%:*}"
  local port_text="${address##*:}"

  [[ $host == "127.0.0.1" ]] || return 1
  [[ $port_text =~ ^[0-9]+$ ]] || return 1

  local port_number=$((10#$port_text))
  ((port_number >= minimum_inspector_port && port_number <= maximum_inspector_port))
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

mode="${1:-}"
case "$mode" in
validate-runtime)
  shift
  if (("$#" != preflight_argument_count)); then
    error_out "validate-runtime does not accept additional arguments"
    exit 1
  fi
  validate_runtime_state
  prepare_runtime_state
  printf 'ttWKV7 runtime state preflight: PASS\n'
  ;;
probe)
  shift
  validate_runtime_state
  prepare_runtime_state
  exec "@probeExecutable@" probe "$@"
  ;;
*)
  exec "@probeExecutable@" "$@"
  ;;
esac
