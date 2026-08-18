#!/usr/bin/env bash
set -euo pipefail

readonly active_system_path="/nix/store/vb9zjhp20rpg7g1g4ypmmcsq7n4s9d3p-nixos-system-britton-desktop-26.11.20260629.7a1a647"
readonly boundary_package_path="/nix/store/av4m3qy5m0qjvrrfrn1dckjxnd7vzbkv-rwkv-ttwkv7-boundary-device-0.2.0"
readonly ordinary_package_path="/nix/store/5alwcj7ff65s1zg6q475akwayafmh0bz-ttwkv7-unstable-2026-06-22"
readonly readiness_path="/nix/store/hjjrp20xidsgig1yzfn5zydbn9wp8n7a-rwkv-ttwkv7-boundary-device-check"
readonly wrapper_path="$boundary_package_path/bin/wkv7-rwkv-boundary"
readonly plan_manifest_path="$boundary_package_path/share/rwkv-ttwkv7-boundary-device/session/manifest.json"
readonly plan_receipt_path="$boundary_package_path/share/rwkv-ttwkv7-boundary-device/session/plan-receipt.json"
readonly expected_plan_id="d4886116b76df2cf63090e3a1f7efff35aa215aa2d05652d7accaa9b61a9abb1"
readonly expected_plan_receipt_blake3="307efa0052ae9b5b003d7c6026ba0340e527cbea4a6e057bfa70df84c53e0291"
readonly expected_readiness_blake3="bac896f69c9d2f8c68764aafd696c9902d21220e3368a0bfe92f7b976e8a2d1e"
readonly expected_fixture_blake3="731f44866c869300ca330f703f1adad4c3ae7ee62b832fa881a6bf4ea90211cd"
readonly owner_control_path="/nix/store/6m9zwmdfc1vyrxw2znbl39s78bz73ycp-ttwkv7-owner-control/bin/ttwkv7-owner-control"
readonly rwkv_lab_path="/nix/store/28kaci6hqqpjvfskf1f5z70kwfhjzxv9-rwkv-lab-0.1.0/bin/rwkv-lab"
readonly b3sum_path="/nix/store/n0iqwjqk8d95hqjdz829va22476cz257-b3sum-1.8.5/bin/b3sum"
readonly systemctl_path="/nix/store/rd05syhv5v5999907a2n1r37sgi19vpd-systemd-260.2/bin/systemctl"
readonly systemd_run_path="/nix/store/rd05syhv5v5999907a2n1r37sgi19vpd-systemd-260.2/bin/systemd-run"
readonly lsof_path="/nix/store/qqmbkipfjjc0i8p0p239zhzlrbfns4n3-lsof-4.99.7/bin/lsof"
readonly sudo_path="/run/wrappers/bin/sudo"
readonly tt_smi_path="/nix/store/akd33pm8f9ybsv47hx2xzjsxv169zfhm-tt-smi-5.2.0/bin/tt-smi"
readonly ssh_path="/nix/store/ww2wf5b928m0b53dp2bdifpgqqyfshvb-openssh-10.3p1/bin/ssh"
readonly ssh_keyscan_path="/nix/store/ww2wf5b928m0b53dp2bdifpgqqyfshvb-openssh-10.3p1/bin/ssh-keyscan"
readonly ssh_keygen_path="/nix/store/ww2wf5b928m0b53dp2bdifpgqqyfshvb-openssh-10.3p1/bin/ssh-keygen"
readonly root_ssh_identity="/home/brittonr/.ssh/framework"
readonly expected_host_fingerprint="SHA256:DOOddCNRRRqCVbueQZovbR8Q//NwYeeMCaznz+GqxQE"
readonly run_root="/var/tmp/rwkv-ttwkv7-boundary-device-2"
readonly cache_path="$run_root/cache"
readonly logs_path="$run_root/logs"
readonly artifact_root="$logs_path/rwkv-boundary-device"
readonly known_hosts_path="$run_root/known_hosts"
readonly execution_lock_path="$run_root/execution-consumed.lock"
readonly inspector_address="127.0.0.1:43147"
readonly inspector_port="43147"
readonly owner_unit="docker-tt-inference-server-llama-3-1-8b-instruct-p150.service"
readonly owner_container="tt-inference-server-llama-3-1-8b-instruct-p150"
readonly health_url="http://127.0.0.1:8000/health"
readonly visible_device="1"
readonly device_path="/dev/tenstorrent/$visible_device"
readonly rollback_unit="rwkv-ttwkv7-boundary-rollback-device-2"
readonly rollback_timer_unit="$rollback_unit.timer"
readonly rollback_service_unit="$rollback_unit.service"
readonly rollback_delay_seconds="1200"
readonly rollback_accuracy_seconds="1"
readonly process_timeout_seconds="900"
readonly timeout_kill_grace_seconds="10"
readonly restoration_health_attempts="60"
readonly restoration_health_delay_seconds="2"
readonly heartbeat_sample_delay_seconds="2"
readonly health_request_timeout_seconds="5"
readonly expected_health_status="200"
readonly initial_counter_value="0"
readonly consumed_counter_value="1"
readonly expected_argument_count="0"
readonly expected_runbook_mode="755"
readonly expected_process_timeout_status="124"
readonly expected_owner_absence_status="1"
readonly expected_writer_bytes="147456"
readonly expected_output_bytes="1536"
readonly expected_post_state_bytes="98304"
readonly expected_manifest_lines="4"
readonly expected_success_marker="rwkv ttWKV7 boundary device probe: PASS"
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
rollback_arm_attempted=0
rollback_armed=0
process_attempted=0
process_status=0
evidence_completeness_status=1
restore_status=0
health_status=0
disarm_status=0
board_after_status=1

root_ssh() {
  "$ssh_path" "${root_ssh_options[@]}" "$@"
}

fail() {
  local diagnostic="$1"
  if [[ -d $run_root ]]; then
    printf 'rwkv ttWKV7 boundary one-shot: %s\n' "$diagnostic" >"$run_root/preflight-failure.txt" || true
  fi
  printf 'rwkv ttWKV7 boundary one-shot: %s\n' "$diagnostic" >&2
  exit "$generic_failure_status"
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

validate_manifest_entry() {
  local role="$1"
  local filename="$2"
  local expected_bytes="$3"
  local file_path="$artifact_root/$filename"
  local actual_bytes
  local actual_blake3
  [[ -s $file_path ]]
  actual_bytes="$(wc -c <"$file_path")"
  [[ $actual_bytes -eq $expected_bytes ]]
  actual_blake3="$($b3sum_path "$file_path" | cut -d' ' -f1)"
  [[ $(grep -Fxc "$role"$'\t'"$filename"$'\t'"$((expected_bytes / 2))"$'\t'"$expected_bytes"$'\t'"$actual_blake3" "$artifact_root/manifest.tsv") -eq 1 ]]
}

validate_boundary_artifacts() (
  set -e
  [[ -s $artifact_root/prepared.json ]]
  [[ -s $artifact_root/manifest.tsv ]]
  [[ -s $artifact_root/receipt.json ]]
  [[ $(wc -l <"$artifact_root/manifest.tsv") -eq $expected_manifest_lines ]]
  validate_manifest_entry "observed_output_bf16" "observed-output.bf16" "$expected_output_bytes"
  validate_manifest_entry "observed_post_state_bf16" "observed-post-state.bf16" "$expected_post_state_bytes"
  validate_manifest_entry "writer_raw_bf16" "writer-raw.bf16" "$expected_writer_bytes"
  grep -Fq '"device_initialized":true' "$artifact_root/receipt.json"
  grep -Fq '"fixture_blake3":"'"$expected_fixture_blake3"'"' "$artifact_root/receipt.json"
  grep -Fq '"passed":true' "$artifact_root/receipt.json"
  grep -Fq '"workload_enqueue_count":1' "$artifact_root/receipt.json"
  [[ $(grep -o '"finite":true' "$artifact_root/receipt.json" | wc -l) -eq 2 ]]
  [[ $(grep -Fxc "$expected_success_marker" "$run_root/diagnostic.log") -eq 1 ]]
)

# shellcheck disable=SC2329 # Reached through post-restoration classification.
append_artifact() {
  local role="$1"
  local path="$2"
  local bytes
  local digest
  [[ -s $path ]] || return 0
  bytes="$(wc -c <"$path")"
  digest="$($b3sum_path "$path" | cut -d' ' -f1)"
  if [[ -n $artifact_entries ]]; then
    artifact_entries+=","
  fi
  artifact_entries+="{\"role\":\"$role\",\"blake3\":\"$digest\",\"bytes\":$bytes}"
}

# shellcheck disable=SC2329 # Reached through the EXIT-trap restoration path.
materialize_classification() {
  local timed_out=false
  local process_json=null
  local owner_active_after=null
  local owner_health_after=null
  local board_healthy_after=null
  local marker_json="[]"
  local restoration_attempts=0
  artifact_entries=""

  if [[ $process_attempted -eq 1 ]]; then
    if [[ $process_status -eq $expected_process_timeout_status ]]; then
      timed_out=true
    fi
    process_json="{\"exit_status\":$process_status,\"timed_out\":$timed_out}"
  fi
  if [[ $owner_isolation_attempted -eq 1 ]]; then
    restoration_attempts=1
    if [[ $restore_status -eq 0 ]]; then owner_active_after=true; else owner_active_after=false; fi
    if [[ $health_status -eq 0 ]]; then owner_health_after=$expected_health_status; fi
    if [[ $board_after_status -eq 0 ]]; then board_healthy_after=true; else board_healthy_after=false; fi
  fi
  if [[ -s $run_root/diagnostic.log ]] &&
    grep -Fqx "$expected_success_marker" "$run_root/diagnostic.log"; then
    marker_json="[\"$expected_success_marker\"]"
  fi

  append_artifact "board_after" "$run_root/board-after-second.txt"
  append_artifact "boundary_manifest" "$artifact_root/manifest.tsv"
  append_artifact "boundary_receipt" "$artifact_root/receipt.json"
  append_artifact "diagnostic_log" "$run_root/diagnostic.log"
  append_artifact "observed_output_bf16" "$artifact_root/observed-output.bf16"
  append_artifact "observed_post_state_bf16" "$artifact_root/observed-post-state.bf16"
  append_artifact "owner_after" "$run_root/owner-after.properties"
  append_artifact "writer_raw_bf16" "$artifact_root/writer-raw.bf16"

  printf '%s\n' \
    "{" \
    '  "schema_version": 1,' \
    "  \"plan_id\": \"$expected_plan_id\"," \
    "  \"process_attempts\": $process_attempted," \
    "  \"owner_isolation_attempts\": $owner_isolation_attempted," \
    "  \"restoration_attempts\": $restoration_attempts," \
    "  \"process\": $process_json," \
    "  \"owner_active_after\": $owner_active_after," \
    "  \"owner_health_status_after\": $owner_health_after," \
    "  \"board_healthy_after\": $board_healthy_after," \
    "  \"artifacts\": [$artifact_entries]," \
    "  \"observed_markers\": $marker_json" \
    "}" \
    >"$run_root/session-evidence.json"
  "$rwkv_lab_path" classify \
    "$plan_manifest_path" \
    "$run_root/session-evidence.json" \
    >"$run_root/classification-receipt.json"
}

# shellcheck disable=SC2329 # Registered as the EXIT trap below.
restore_owner() {
  local incoming_status="$?"
  local final_status="$incoming_status"
  trap - EXIT INT HUP TERM
  set +e
  printf '%s\n' "$incoming_status" >"$run_root/orchestration-incoming-status.txt"

  if [[ $owner_isolation_attempted -eq 0 ]]; then
    if [[ $rollback_arm_attempted -eq 1 ]]; then
      disarm_rollback_timer
      disarm_status="$?"
      record_rollback_state "after"
    fi
    printf '%s\n' "$disarm_status" >"$run_root/rollback-final-disarm-status.txt"
    materialize_classification
    classification_status="$?"
    if [[ $disarm_status -ne 0 || $classification_status -ne 0 ]]; then
      final_status="$generic_failure_status"
    fi
    printf '%s\n' "$final_status" >"$run_root/orchestration-final-status.txt"
    exit "$final_status"
  fi

  if [[ $owner_was_active -eq 1 ]]; then
    printf '%s\n' "$consumed_counter_value" >"$run_root/restoration-attempted.txt"
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
  board_after_status="$?"
  sleep "$heartbeat_sample_delay_seconds"
  if ! record_board_health "$run_root/board-after-second.txt"; then
    board_after_status="$generic_failure_status"
  fi
  printf '%s\n' "$restore_status" >"$run_root/restore-status.txt"
  printf '%s\n' "$health_status" >"$run_root/restored-health-status.txt"
  printf '%s\n' "$disarm_status" >"$run_root/rollback-final-disarm-status.txt"
  printf '%s\n' "$evidence_completeness_status" >"$run_root/evidence-completeness-status.txt"
  materialize_classification
  classification_status="$?"

  if [[ $restore_status -ne 0 || $health_status -ne 0 ||
    $disarm_status -ne 0 || $board_after_status -ne 0 ||
    $classification_status -ne 0 ]]; then
    final_status="$generic_failure_status"
  fi
  printf '%s\n' "$final_status" >"$run_root/orchestration-final-status.txt"
  exit "$final_status"
}

# r[impl onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_boundary_one_shot]
[[ $# -eq $expected_argument_count ]] || fail "arguments are not accepted"
[[ $(stat -c '%a' "${BASH_SOURCE[0]}") == "$expected_runbook_mode" ]] || fail "runbook mode is not executable and exact"
[[ -x $wrapper_path && -x $owner_control_path && -x $rwkv_lab_path && -x $b3sum_path ]] || fail "immutable executables are unavailable"
[[ -x $systemctl_path && -x $systemd_run_path && -x $lsof_path && -x $tt_smi_path ]] || fail "reviewed host tools are unavailable"
[[ -x $ssh_path && -x $ssh_keyscan_path && -x $ssh_keygen_path ]] || fail "reviewed SSH tools are unavailable"
[[ -r $root_ssh_identity ]] || fail "reviewed root SSH identity is unavailable"
[[ -e $device_path ]] || fail "reviewed device path does not exist"
[[ $(readlink -f /run/current-system) == "$active_system_path" ]] || fail "active system metadata mismatch"
[[ $(readlink -f /nix/var/nix/profiles/system) == "$active_system_path" ]] || fail "system profile metadata mismatch"
[[ $($b3sum_path "$plan_receipt_path" | cut -d' ' -f1) == "$expected_plan_receipt_blake3" ]] || fail "plan receipt identity mismatch"
[[ $($b3sum_path "$readiness_path/receipt.json" | cut -d' ' -f1) == "$expected_readiness_blake3" ]] || fail "readiness receipt identity mismatch"
grep -Fq "\"plan_id\": \"$expected_plan_id\"" "$plan_receipt_path" || fail "plan ID mismatch"
grep -Fq '"outcome": "not_run"' "$readiness_path/not-run-receipt.json" || fail "initial outcome is not not_run"
grep -Fq "\"package_path\": \"$boundary_package_path\"" "$plan_manifest_path" || fail "plan package mismatch"
grep -Fq "\"kernel_path\": \"$ordinary_package_path/share/ttwkv7/kernels\"" "$plan_manifest_path" || fail "plan kernel mismatch"
grep -Fq "\"run_root\": \"$run_root\"" "$plan_manifest_path" || fail "plan run root mismatch"
[[ ! -e $run_root ]] || fail "run root already exists"
mkdir "$run_root" || fail "run root could not be created atomically"
trap restore_owner EXIT
trap 'exit "$interrupt_exit_status"' INT
trap 'exit "$hangup_exit_status"' HUP
trap 'exit "$terminate_exit_status"' TERM
printf '%s\n' "$initial_counter_value" >"$run_root/execution-attempt-count.txt"
printf '%s\n' "$initial_counter_value" >"$run_root/invocation-count.txt"
printf '%s\n' "$initial_counter_value" >"$run_root/service-stop-attempted.txt"
printf '%s\n' "$initial_counter_value" >"$run_root/rollback-arm-attempted.txt"
printf '%s\n' "$initial_counter_value" >"$run_root/restoration-attempted.txt"
"$ssh_keyscan_path" -T "$health_request_timeout_seconds" -t ed25519 127.0.0.1 >"$known_hosts_path" 2>"$run_root/ssh-keyscan.log"
fingerprint_output="$("$ssh_keygen_path" -lf "$known_hosts_path" -E sha256)"
read -r _ actual_host_fingerprint _ <<<"$fingerprint_output"
printf 'expected=%s\nobserved=%s\n' \
  "$expected_host_fingerprint" \
  "$actual_host_fingerprint" \
  >"$run_root/host-fingerprint.txt"
[[ $actual_host_fingerprint == "$expected_host_fingerprint" ]] || fail "loopback host fingerprint mismatch"

TT_VISIBLE_DEVICES="$visible_device" \
  TT_METAL_CACHE="$cache_path" \
  TT_METAL_LOGS_PATH="$logs_path" \
  TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$inspector_address" \
  "$wrapper_path" validate-runtime >"$run_root/preflight.log" 2>&1
[[ -d $cache_path && -d $logs_path ]] || fail "runtime paths were not prepared"
[[ -n $(ss -H -ltn "sport = :$inspector_port") ]] && fail "reviewed Inspector port is already in use"
record_service_state "$run_root/owner-before.properties"
record_container_state "$run_root/container-before.txt"
record_health_endpoint "before" || fail "owner health endpoint is not ready"
record_board_health "$run_root/board-before.txt" || fail "board health preflight failed"
"$systemctl_path" is-active --quiet "$owner_unit" || fail "device owner was not active"
owner_was_active=1
"$owner_control_path" validate >"$run_root/owner-control-preflight.log" 2>&1
root_ssh /run/current-system/sw/bin/true >"$run_root/root-ssh-preflight.log" 2>&1

mkdir "$execution_lock_path" || fail "execution attempt lock could not be acquired"
printf '%s\n' "$consumed_counter_value" >"$run_root/execution-attempt-count.txt"
rollback_arm_attempted=1
printf '%s\n' "$consumed_counter_value" >"$run_root/rollback-arm-attempted.txt"
arm_rollback_timer
owner_isolation_attempted=1
printf '%s\n' "$consumed_counter_value" >"$run_root/service-stop-attempted.txt"
"$owner_control_path" isolate >"$run_root/isolate.log" 2>&1
"$systemctl_path" is-active --quiet "$owner_unit" && fail "device owner remained active after isolation"
record_service_state "$run_root/owner-after-stop.properties"
record_container_state "$run_root/container-after-stop.txt"
[[ ! -s $run_root/container-after-stop.txt ]] || fail "owner container remained active"
set +e
"$sudo_path" -n "$lsof_path" "$device_path" >"$run_root/device-owner-after-stop.txt" 2>&1
ownership_status="$?"
set -e
printf '%s\n' "$ownership_status" >"$run_root/device-owner-after-stop.status"
[[ $ownership_status -eq $expected_owner_absence_status && ! -s $run_root/device-owner-after-stop.txt ]] || fail "device ownership proof failed"
record_board_health "$run_root/board-after-stop.txt" || fail "board health failed after isolation"
[[ -n $(ss -H -ltn "sport = :$inspector_port") ]] && fail "Inspector port became busy before invocation"

process_attempted=1
printf '%s\n' "$consumed_counter_value" >"$run_root/invocation-count.txt"
set +e
timeout \
  --signal=TERM \
  --kill-after="${timeout_kill_grace_seconds}s" \
  "${process_timeout_seconds}s" \
  env \
  TT_VISIBLE_DEVICES="$visible_device" \
  TT_METAL_CACHE="$cache_path" \
  TT_METAL_LOGS_PATH="$logs_path" \
  TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$inspector_address" \
  "$wrapper_path" probe \
  >"$run_root/diagnostic.log" 2>&1
process_status="$?"
set -e
printf '%s\n' "$process_status" >"$run_root/diagnostic-status.txt"
set +e
validate_boundary_artifacts >"$run_root/evidence-completeness.log" 2>&1
evidence_completeness_status="$?"
set -e
if [[ $evidence_completeness_status -ne 0 ]]; then
  exit "$generic_failure_status"
fi
exit "$process_status"
