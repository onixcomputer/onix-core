#!/usr/bin/env bash
set -euo pipefail

readonly reviewed_base_commit="fd4954a78d15bde8ac534bf123a7e41a8d7bfda7"
readonly active_system_path="/nix/store/vb9zjhp20rpg7g1g4ypmmcsq7n4s9d3p-nixos-system-britton-desktop-26.11.20260629.7a1a647"
readonly package_path="/nix/store/kgm3azhdgva0bwrkvil2q35l7w132l7j-ttwkv7-unstable-2026-06-22"
readonly diagnostic_path="$package_path/bin/wkv7-diagnose"
readonly diagnostic_runtime_path="$package_path/libexec/ttwkv7/wkv7-diagnostic-runtime"
readonly expected_diagnostic_exec_line="  exec \"$diagnostic_runtime_path\" test all 1 1"
# shellcheck disable=SC2016 # This search pattern intentionally contains literal shell syntax.
readonly unsafe_diagnostic_exec_prefix='exec "$out/'
readonly kernel_path="/nix/store/8m898sjjhcvva2l8375r1wi5alp6cmj3-ttwkv7-kernels-unstable-2026-06-22/share/ttwkv7/kernels"
readonly owner_control_path="/nix/store/6m9zwmdfc1vyrxw2znbl39s78bz73ycp-ttwkv7-owner-control/bin/ttwkv7-owner-control"
readonly systemctl_path="/nix/store/rd05syhv5v5999907a2n1r37sgi19vpd-systemd-260.2/bin/systemctl"
readonly systemd_run_path="/nix/store/rd05syhv5v5999907a2n1r37sgi19vpd-systemd-260.2/bin/systemd-run"
readonly lsof_path="/nix/store/qqmbkipfjjc0i8p0p239zhzlrbfns4n3-lsof-4.99.7/bin/lsof"
readonly sudo_path="/run/wrappers/bin/sudo"
readonly tt_smi_path="/nix/store/akd33pm8f9ybsv47hx2xzjsxv169zfhm-tt-smi-5.2.0/bin/tt-smi"
readonly ssh_path="/nix/store/ww2wf5b928m0b53dp2bdifpgqqyfshvb-openssh-10.3p1/bin/ssh"
readonly ssh_keygen_path="/nix/store/ww2wf5b928m0b53dp2bdifpgqqyfshvb-openssh-10.3p1/bin/ssh-keygen"
readonly git_path="/nix/store/k3wl6cg7q50zkx47af3msmg1yrg1f203-git-2.54.0/bin/git"
readonly root_ssh_identity="/home/brittonr/.ssh/framework"
readonly expected_host_fingerprint="SHA256:0vd1vzTWrAONyquNKjwnsGY7a5bY2NJlvFamtxy/akY"
readonly expected_authorization="Authorize exactly one device-1 cross-kernel diagnostic process."
readonly run_root="/var/tmp/ttwkv7-cross-kernel-20260716T194725Z"
readonly cache_path="$run_root/cache"
readonly logs_path="$run_root/logs"
readonly known_hosts_path="$run_root/known_hosts"
readonly inspector_host="127.0.0.1"
readonly inspector_port="43133"
readonly inspector_address="$inspector_host:$inspector_port"
readonly owner_unit="docker-tt-inference-server-llama-3-1-8b-instruct-p150.service"
readonly owner_container="tt-inference-server-llama-3-1-8b-instruct-p150"
readonly health_url="http://127.0.0.1:8000/health"
readonly visible_device="1"
readonly device_path="/dev/tenstorrent/$visible_device"
readonly rollback_unit="ttwkv7-owner-rollback-20260716T194725Z"
readonly rollback_timer_unit="$rollback_unit.timer"
readonly rollback_service_unit="$rollback_unit.service"
readonly rollback_delay_seconds="300"
readonly rollback_accuracy_seconds="1"
readonly diagnostic_timeout_seconds="240"
readonly timeout_kill_grace_seconds="10"
readonly restoration_health_attempts="60"
readonly restoration_health_delay_seconds="2"
readonly heartbeat_sample_delay_seconds="2"
readonly health_request_timeout_seconds="5"
readonly expected_health_status="200"
readonly initial_counter_value="0"
readonly consumed_invocation_count="1"
readonly expected_argument_count="0"
readonly expected_runbook_mode="755"
readonly expected_exec_line_count="1"
readonly expected_device_owner_absence_status="1"
readonly generic_failure_status="1"
readonly interrupt_exit_status="130"
readonly hangup_exit_status="129"
readonly terminate_exit_status="143"
export PATH="$active_system_path/sw/bin"
readonly -a root_ssh_options=(
  -i "$root_ssh_identity"
  -o IdentitiesOnly=yes
  -o BatchMode=yes
  -o PasswordAuthentication=no
  -o KbdInteractiveAuthentication=no
  -o StrictHostKeyChecking=yes
  -o "UserKnownHostsFile=$known_hosts_path"
  root@127.0.0.1
)

owner_was_active=0
owner_isolation_attempted=0
rollback_armed=0

root_ssh() {
  "$ssh_path" "${root_ssh_options[@]}" "$@"
}

record_service_state() {
  local output_path="$1"
  "$systemctl_path" show "$owner_unit" \
    --property=ActiveState \
    --property=SubState \
    --property=Result \
    --property=NRestarts \
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

  if "$tt_smi_path" -s >"$output_path" 2>&1; then
    status=0
  else
    status="$?"
  fi
  printf '%s\n' "$status" >"$output_path.status"
  return "$status"
}

record_health_endpoint() {
  local label="$1"
  local body_path="$run_root/health-$label.body"
  local status_path="$run_root/health-$label.status"
  local curl_status_path="$run_root/health-$label.curl-status"
  local http_status=""
  local curl_status

  if http_status="$(
    curl --silent --show-error \
      --max-time "$health_request_timeout_seconds" \
      --output "$body_path" \
      --write-out '%{http_code}' \
      "$health_url"
  )"; then
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
  return "$generic_failure_status"
}

record_rollback_state() {
  local label="$1"
  local output_path="$run_root/rollback-$label.properties"
  local status_path="$run_root/rollback-$label.status"
  local status

  if root_ssh "$systemctl_path" show \
    "$rollback_timer_unit" \
    "$rollback_service_unit" \
    --property=Id \
    --property=LoadState \
    --property=ActiveState \
    --property=SubState \
    --property=Result \
    --property=TriggerUSecMonotonic \
    >"$output_path" 2>&1; then
    status=0
  else
    status="$?"
  fi
  printf '%s\n' "$status" >"$status_path"
  return "$status"
}

arm_rollback_timer() {
  root_ssh "$systemd_run_path" \
    --unit="$rollback_unit" \
    --on-active="${rollback_delay_seconds}s" \
    --timer-property="AccuracySec=${rollback_accuracy_seconds}s" \
    --collect \
    "$systemctl_path" start "$owner_unit" \
    >"$run_root/rollback-arm.log" 2>&1
  rollback_armed=1
  root_ssh "$systemctl_path" is-active --quiet "$rollback_timer_unit"
  record_rollback_state "armed"
}

# shellcheck disable=SC2329 # Reached through the EXIT-trap restoration path.
disarm_rollback_timer() {
  local stop_status

  if root_ssh "$systemctl_path" stop "$rollback_timer_unit" \
    >"$run_root/rollback-disarm.log" 2>&1; then
    stop_status=0
  else
    stop_status="$?"
    if ! root_ssh "$systemctl_path" is-active --quiet "$rollback_timer_unit"; then
      stop_status=0
    fi
  fi
  printf '%s\n' "$stop_status" >"$run_root/rollback-disarm-status.txt"
  if [[ $stop_status -eq 0 ]]; then
    rollback_armed=0
  fi
  return "$stop_status"
}

# shellcheck disable=SC2329 # Registered as the EXIT trap below.
restore_owner() {
  local incoming_status="$?"
  local final_status="$incoming_status"
  local restore_status=0
  local health_status=0
  local disarm_status=0

  trap - EXIT INT HUP TERM
  set +e
  printf '%s\n' "$incoming_status" >"$run_root/orchestration-incoming-status.txt"

  if [[ $owner_was_active -eq 1 && $owner_isolation_attempted -eq 1 ]]; then
    "$owner_control_path" restore >"$run_root/restore.log" 2>&1
    restore_status="$?"
    if [[ $restore_status -eq 0 ]]; then
      wait_for_restored_health
      health_status="$?"
    else
      health_status="$generic_failure_status"
    fi
  fi

  if [[ $rollback_armed -eq 1 ]]; then
    if [[ $owner_isolation_attempted -eq 0 || ($restore_status -eq 0 && $health_status -eq 0) ]]; then
      disarm_rollback_timer
      disarm_status="$?"
    else
      printf '%s\n' "armed" >"$run_root/rollback-left-armed.txt"
    fi
  fi

  record_rollback_state "after"
  record_service_state "$run_root/owner-after.properties"
  record_container_state "$run_root/container-after.txt"
  record_board_health "$run_root/board-after-first.txt"
  sleep "$heartbeat_sample_delay_seconds"
  record_board_health "$run_root/board-after-second.txt"

  printf '%s\n' "$restore_status" >"$run_root/restore-status.txt"
  printf '%s\n' "$health_status" >"$run_root/restored-health-status.txt"
  printf '%s\n' "$disarm_status" >"$run_root/rollback-final-disarm-status.txt"
  date -u +%Y-%m-%dT%H:%M:%SZ >"$run_root/finished-at.txt"

  if [[ $restore_status -ne 0 || $health_status -ne 0 || $disarm_status -ne 0 ]]; then
    final_status="$generic_failure_status"
  fi
  printf '%s\n' "$final_status" >"$run_root/orchestration-final-status.txt"
  exit "$final_status"
}

fail() {
  printf 'ttWKV7 cross-kernel one-shot: %s\n' "$1" >&2
  exit "$generic_failure_status"
}

[[ $# -eq $expected_argument_count ]] || fail "arguments are not accepted"
[[ -x $diagnostic_path ]] || fail "reviewed diagnostic is not executable: $diagnostic_path"
[[ -x $diagnostic_runtime_path ]] || fail "reviewed diagnostic runtime is not executable: $diagnostic_runtime_path"
[[ -x $owner_control_path ]] || fail "reviewed owner-control helper is not executable: $owner_control_path"
[[ -x $systemctl_path && -x $systemd_run_path ]] || fail "reviewed systemd commands are unavailable"
[[ -x $lsof_path && -x $sudo_path ]] || fail "reviewed ownership commands are unavailable"
[[ -x $tt_smi_path && -x $ssh_path && -x $ssh_keygen_path ]] || fail "reviewed evidence commands are unavailable"
[[ -r $root_ssh_identity ]] || fail "reviewed root SSH identity is unavailable"
[[ -e $device_path ]] || fail "reviewed device path does not exist: $device_path"
[[ -d $run_root ]] || fail "reviewed run root does not exist: $run_root"
[[ -d $cache_path && -w $cache_path ]] || fail "reviewed cache path is not writable"
[[ -d $logs_path && -w $logs_path ]] || fail "reviewed logs path is not writable"
[[ -f $known_hosts_path && -r $known_hosts_path ]] || fail "reviewed known_hosts is unavailable"
[[ $(stat -c '%a' "${BASH_SOURCE[0]}") == "$expected_runbook_mode" ]] || fail "runbook mode is not executable and exact"
[[ $(grep -Fxc -- "$expected_diagnostic_exec_line" "$diagnostic_path") -eq $expected_exec_line_count ]] ||
  fail "production diagnostic wrapper target or vector mismatch"
[[ $(grep -Ec '^[[:space:]]*exec ' "$diagnostic_path") -eq $expected_exec_line_count ]] ||
  fail "production diagnostic wrapper has an unexpected exec count"
if grep -F -- "$unsafe_diagnostic_exec_prefix" "$diagnostic_path" >"$run_root/production-wrapper-unsafe-target-at-execution.txt"; then
  fail "production diagnostic wrapper retained runtime out expansion"
fi
printf '%s\n' "$expected_diagnostic_exec_line" >"$run_root/production-wrapper-target-at-execution.txt"
[[ $(readlink -f /run/current-system) == "$active_system_path" ]] || fail "active system metadata mismatch"
[[ $(readlink -f /nix/var/nix/profiles/system) == "$active_system_path" ]] || fail "system profile metadata mismatch"
[[ $(readlink -f "$package_path/share/ttwkv7/kernels") == "$kernel_path" ]] || fail "kernel target mismatch"
[[ $(cat "$run_root/reviewed-base-commit.txt") == "$reviewed_base_commit" ]] || fail "base commit metadata mismatch"
[[ $(cat "$run_root/active-system-path.txt") == "$active_system_path" ]] || fail "active system path metadata mismatch"
[[ $(cat "$run_root/package-path.txt") == "$package_path" ]] || fail "package metadata mismatch"
[[ $(cat "$run_root/kernel-path.txt") == "$kernel_path" ]] || fail "kernel metadata mismatch"
[[ $(cat "$run_root/owner-control-path.txt") == "$owner_control_path" ]] || fail "owner-control metadata mismatch"
[[ $(cat "$run_root/inspector-address.txt") == "$inspector_address" ]] || fail "Inspector metadata mismatch"
[[ $(cat "$run_root/authorization.txt") == "$expected_authorization" ]] || fail "authorization metadata mismatch"
[[ $(cat "$run_root/invocation-count.txt") == "$initial_counter_value" ]] || fail "invocation budget is not zero"
[[ $(cat "$run_root/service-stop-attempted.txt") == "$initial_counter_value" ]] || fail "service-stop counter is not zero"
[[ $(cat "$run_root/rollback-arm-attempted.txt") == "$initial_counter_value" ]] || fail "rollback-arm counter is not zero"

runbook_root="$("$git_path" -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
readonly runbook_root
runbook_commit="$("$git_path" -C "$runbook_root" rev-parse HEAD)"
readonly runbook_commit
[[ -z $("$git_path" -C "$runbook_root" status --porcelain=v1) ]] || fail "runbook worktree is not clean"
[[ $(cat "$run_root/runbook-commit.txt") == "$runbook_commit" ]] || fail "runbook commit metadata mismatch"

fingerprint_output="$("$ssh_keygen_path" -lf "$known_hosts_path" -E sha256)"
readonly fingerprint_output
read -r _ actual_host_fingerprint _ <<<"$fingerprint_output"
readonly actual_host_fingerprint
[[ $actual_host_fingerprint == "$expected_host_fingerprint" ]] || fail "loopback host fingerprint mismatch"

trap restore_owner EXIT
trap 'exit "$interrupt_exit_status"' INT
trap 'exit "$hangup_exit_status"' HUP
trap 'exit "$terminate_exit_status"' TERM

root_ssh /run/current-system/sw/bin/true >"$run_root/root-ssh-preflight.log" 2>&1
"$owner_control_path" validate >"$run_root/owner-control-preflight.log" 2>&1

if [[ -n $(ss -H -ltn "sport = :$inspector_port") ]]; then
  fail "reviewed Inspector port is already in use"
fi

TT_VISIBLE_DEVICES="$visible_device" \
  TT_METAL_CACHE="$cache_path" \
  TT_METAL_LOGS_PATH="$logs_path" \
  TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$inspector_address" \
  "$diagnostic_path" validate-runtime \
  >"$run_root/preflight-at-execution.log" 2>&1

record_service_state "$run_root/owner-before.properties"
record_container_state "$run_root/container-before.txt"
record_health_endpoint "before" || fail "owner health endpoint is not ready"
record_board_health "$run_root/board-before.txt"

if "$systemctl_path" is-active --quiet "$owner_unit"; then
  owner_was_active=1
else
  fail "device-1 owner was not active before isolation"
fi

printf '%s\n' "$consumed_invocation_count" >"$run_root/rollback-arm-attempted.txt"
arm_rollback_timer
owner_isolation_attempted=1
printf '%s\n' "$consumed_invocation_count" >"$run_root/service-stop-attempted.txt"
"$owner_control_path" isolate >"$run_root/isolate.log" 2>&1

if "$systemctl_path" is-active --quiet "$owner_unit"; then
  fail "device-1 owner remained active after isolation"
fi
record_service_state "$run_root/owner-after-stop.properties"
record_container_state "$run_root/container-after-stop.txt"
[[ ! -s $run_root/container-after-stop.txt ]] || fail "device-1 owner container remained active"

set +e
"$sudo_path" -n "$lsof_path" "$device_path" \
  >"$run_root/device-owner-after-stop.txt" 2>&1
readonly ownership_status="$?"
set -e
printf '%s\n' "$ownership_status" >"$run_root/device-owner-after-stop.status"
[[ $ownership_status -eq $expected_device_owner_absence_status && ! -s $run_root/device-owner-after-stop.txt ]] ||
  fail "reviewed device ownership proof failed"
record_board_health "$run_root/board-after-stop.txt"

if [[ -n $(ss -H -ltn "sport = :$inspector_port") ]]; then
  fail "reviewed Inspector port became busy before invocation"
fi
date -u +%Y-%m-%dT%H:%M:%SZ >"$run_root/diagnostic-started-at.txt"
printf '%s\n' "$consumed_invocation_count" >"$run_root/invocation-count.txt"

set +e
timeout \
  --signal=TERM \
  --kill-after="${timeout_kill_grace_seconds}s" \
  "${diagnostic_timeout_seconds}s" \
  env \
  TT_VISIBLE_DEVICES="$visible_device" \
  TT_METAL_CACHE="$cache_path" \
  TT_METAL_LOGS_PATH="$logs_path" \
  TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$inspector_address" \
  "$diagnostic_path" diagnose \
  >"$run_root/diagnostic.log" 2>&1
readonly diagnostic_status="$?"
set -e

printf '%s\n' "$diagnostic_status" >"$run_root/diagnostic-status.txt"
exit "$diagnostic_status"
