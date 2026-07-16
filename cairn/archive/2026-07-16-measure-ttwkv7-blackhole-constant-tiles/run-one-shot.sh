#!/usr/bin/env bash
set -euo pipefail

readonly reviewed_commit="4910b700c08f4320ef0ed8f03973f01578f9b2ce"
readonly package_path="/nix/store/plr5vlpv1q5g4zl6c2q065bwsmbhxkrr-ttwkv7-unstable-2026-06-22"
readonly probe_path="$package_path/bin/wkv7-constant-probe"
readonly run_root="/var/tmp/ttwkv7-constant-probe-20260716T160230Z"
readonly cache_path="$run_root/cache"
readonly logs_path="$run_root/logs"
readonly inspector_host="127.0.0.1"
readonly inspector_port="43127"
readonly inspector_address="$inspector_host:$inspector_port"
readonly owner_unit="docker-tt-inference-server-llama-3-1-8b-instruct-p150.service"
readonly owner_container="tt-inference-server-llama-3-1-8b-instruct-p150"
readonly health_url="http://127.0.0.1:8000/health"
readonly visible_device="1"
readonly device_path="/dev/tenstorrent/$visible_device"
readonly lsof_path="/etc/profiles/per-user/brittonr/bin/lsof"
readonly probe_timeout_seconds="180"
readonly timeout_kill_grace_seconds="10"
readonly restoration_health_attempts="60"
readonly restoration_health_delay_seconds="2"
readonly heartbeat_sample_delay_seconds="2"
readonly expected_health_status="200"
readonly initial_invocation_count="0"
readonly consumed_invocation_count="1"
readonly generic_failure_status="1"
readonly interrupt_exit_status="130"
readonly hangup_exit_status="129"
readonly terminate_exit_status="143"

owner_was_active=0
owner_isolation_attempted=0

record_service_state() {
  local output_path="$1"
  systemctl show "$owner_unit" \
    -p ActiveState \
    -p SubState \
    -p Result \
    -p NRestarts \
    >"$output_path"
}

record_container_state() {
  local output_path="$1"
  docker ps --filter "name=$owner_container" \
    --format '{{.Names}}|{{.Status}}|{{.Ports}}' \
    >"$output_path"
}

record_board_health() {
  local output_path="$1"
  local status
  if tt-smi -s >"$output_path" 2>&1; then
    status=0
  else
    status="$?"
  fi
  printf '%s\n' "$status" >"$output_path.status"
}

record_health_endpoint() {
  local label="$1"
  local body_path="$run_root/health-$label.body"
  local status_path="$run_root/health-$label.status"
  local curl_status_path="$run_root/health-$label.curl-status"
  local http_status
  local curl_status

  if http_status="$(curl -sS -o "$body_path" -w '%{http_code}' "$health_url")"; then
    curl_status=0
  else
    curl_status="$?"
  fi
  printf '%s\n' "$http_status" >"$status_path"
  printf '%s\n' "$curl_status" >"$curl_status_path"
  [[ $curl_status -eq 0 && $http_status == "$expected_health_status" ]]
}

# shellcheck disable=SC2329 # Reached through the EXIT-trap restoration path.
wait_for_restored_health() {
  local attempt=0
  while ((attempt < restoration_health_attempts)); do
    if record_health_endpoint "after"; then
      return 0
    fi
    sleep "$restoration_health_delay_seconds"
    ((attempt += 1))
  done
  return 1
}

# shellcheck disable=SC2329 # Registered as the EXIT trap below.
restore_owner() {
  local incoming_status="$?"
  local final_status="$incoming_status"
  local restore_status=0
  local health_status=0

  trap - EXIT INT HUP TERM
  set +e

  if [[ $owner_was_active -eq 1 && $owner_isolation_attempted -eq 1 ]]; then
    sudo -n systemctl start "$owner_unit"
    restore_status="$?"
    if [[ $restore_status -eq 0 ]]; then
      wait_for_restored_health
      health_status="$?"
    else
      health_status="$generic_failure_status"
    fi
  fi

  record_service_state "$run_root/owner-after.properties"
  record_container_state "$run_root/container-after.txt"
  record_board_health "$run_root/board-after-first.txt"
  sleep "$heartbeat_sample_delay_seconds"
  record_board_health "$run_root/board-after-second.txt"

  printf '%s\n' "$restore_status" >"$run_root/restore-status.txt"
  printf '%s\n' "$health_status" >"$run_root/restored-health-status.txt"
  date -u +%Y-%m-%dT%H:%M:%SZ >"$run_root/finished-at.txt"

  if [[ $restore_status -ne 0 || $health_status -ne 0 ]]; then
    final_status="$generic_failure_status"
  fi
  exit "$final_status"
}

fail() {
  printf 'ttWKV7 one-shot: %s\n' "$1" >&2
  exit "$generic_failure_status"
}

trap restore_owner EXIT
trap 'exit "$interrupt_exit_status"' INT
trap 'exit "$hangup_exit_status"' HUP
trap 'exit "$terminate_exit_status"' TERM

[[ -x $probe_path ]] || fail "reviewed probe is not executable: $probe_path"
[[ -e $device_path ]] || fail "reviewed device path does not exist: $device_path"
[[ -x $lsof_path ]] || fail "reviewed lsof command is not executable: $lsof_path"
sudo -n true || fail "non-interactive privilege escalation is unavailable"
[[ -d $run_root ]] || fail "reviewed run root does not exist: $run_root"
[[ -d $cache_path && -w $cache_path ]] || fail "reviewed cache path is not writable"
[[ -d $logs_path && -w $logs_path ]] || fail "reviewed logs path is not writable"
[[ $(cat "$run_root/reviewed-commit.txt") == "$reviewed_commit" ]] || fail "reviewed commit metadata mismatch"
[[ $(cat "$run_root/package-path.txt") == "$package_path" ]] || fail "package metadata mismatch"
[[ $(cat "$run_root/inspector-address.txt") == "$inspector_address" ]] || fail "Inspector metadata mismatch"
[[ $(cat "$run_root/invocation-count.txt") == "$initial_invocation_count" ]] || fail "invocation budget is not zero"

resolved_kernel_path="$(readlink -f "$package_path/share/ttwkv7/kernels")"
readonly resolved_kernel_path
[[ $resolved_kernel_path == /nix/store/*-ttwkv7-kernels-*/share/ttwkv7/kernels ]] ||
  fail "kernel target is not the reviewed immutable output"
[[ $(cat "$run_root/kernel-path.txt") == "$resolved_kernel_path" ]] || fail "kernel metadata mismatch"

if [[ -n $(ss -H -ltn "sport = :$inspector_port") ]]; then
  fail "reviewed Inspector port is already in use"
fi

TT_METAL_CACHE="$cache_path" \
  TT_METAL_LOGS_PATH="$logs_path" \
  TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$inspector_address" \
  "$probe_path" validate-runtime \
  >"$run_root/preflight-at-execution.log" 2>&1

record_service_state "$run_root/owner-before.properties"
record_container_state "$run_root/container-before.txt"
record_health_endpoint "before" || fail "owner health endpoint is not ready"
record_board_health "$run_root/board-before.txt"

if systemctl is-active --quiet "$owner_unit"; then
  owner_was_active=1
else
  fail "device-1 owner was not active before isolation"
fi

owner_isolation_attempted=1
sudo -n systemctl stop "$owner_unit"
if systemctl is-active --quiet "$owner_unit"; then
  fail "device-1 owner remained active after stop"
fi
record_service_state "$run_root/owner-after-stop.properties"
record_container_state "$run_root/container-after-stop.txt"
[[ ! -s $run_root/container-after-stop.txt ]] || fail "device-1 owner container remained active"
if sudo -n "$lsof_path" "$device_path" 2>&1 |
  tee "$run_root/device-owner-after-stop.txt" >/dev/null; then
  fail "reviewed device still has an open file owner"
fi
record_board_health "$run_root/board-after-stop.txt"

if [[ -n $(ss -H -ltn "sport = :$inspector_port") ]]; then
  fail "reviewed Inspector port became busy before invocation"
fi
printf '%s\n' "$consumed_invocation_count" >"$run_root/invocation-count.txt"
date -u +%Y-%m-%dT%H:%M:%SZ >"$run_root/probe-started-at.txt"

set +e
timeout \
  --signal=TERM \
  --kill-after="${timeout_kill_grace_seconds}s" \
  "${probe_timeout_seconds}s" \
  env \
  TT_VISIBLE_DEVICES="$visible_device" \
  TT_METAL_CACHE="$cache_path" \
  TT_METAL_LOGS_PATH="$logs_path" \
  TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$inspector_address" \
  "$probe_path" probe \
  >"$run_root/probe.log" 2>&1
readonly probe_status="$?"
set -e

printf '%s\n' "$probe_status" >"$run_root/probe-status.txt"
exit "$probe_status"
