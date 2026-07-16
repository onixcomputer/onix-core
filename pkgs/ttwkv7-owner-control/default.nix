{
  lib,
  writeShellApplication,
  coreutils,
  systemd,
  lsof,
  commandName,
  ownerUnit,
  devicePath,
}:
let
  systemctlCommand = "${systemd}/bin/systemctl";
  lsofCommand = "${lsof}/bin/lsof";
  sudoCommand = "/run/wrappers/bin/sudo";
in
# r[impl onix.tenstorrent.native_runtime.ttwkv7.owner_control]
# r[impl onix.tenstorrent.native_runtime.ttwkv7.owner_control.sudo_wrapper]
writeShellApplication {
  name = commandName;
  runtimeInputs = [ coreutils ];
  text = ''
    readonly owner_unit=${lib.escapeShellArg ownerUnit}
    readonly device_path=${lib.escapeShellArg devicePath}
    readonly systemctl_command=${lib.escapeShellArg systemctlCommand}
    readonly lsof_command=${lib.escapeShellArg lsofCommand}
    readonly sudo_command=${lib.escapeShellArg sudoCommand}
    readonly expected_argument_count=1
    readonly no_owner_lsof_status=1
    readonly usage_error_status=2
    readonly generic_failure_status=1
    readonly restore_disarmed=0
    readonly restore_armed_value=1
    readonly interrupt_exit_status=130
    readonly hangup_exit_status=129
    readonly terminate_exit_status=143

    restore_armed=$restore_disarmed
    ownership_log=""

    usage() {
      local exit_status="$1"
      cat >&2 <<USAGE
    usage: ${commandName} --help|validate|isolate|restore
    USAGE
      exit "$exit_status"
    }

    fail() {
      printf '${commandName}: %s\n' "$1" >&2
      exit "$generic_failure_status"
    }

    # shellcheck disable=SC2329 # Registered as the EXIT trap below.
    cleanup() {
      local incoming_status="$?"
      local final_status="$incoming_status"
      local restore_status=0

      trap - EXIT INT HUP TERM
      set +e
      if [[ -n $ownership_log ]]; then
        rm -f -- "$ownership_log"
      fi
      if [[ $restore_armed -eq $restore_armed_value ]]; then
        "$sudo_command" -n "$systemctl_command" start "$owner_unit"
        restore_status="$?"
        if [[ $restore_status -ne 0 ]]; then
          final_status="$generic_failure_status"
        fi
      fi
      exit "$final_status"
    }

    trap cleanup EXIT
    trap 'exit "$interrupt_exit_status"' INT
    trap 'exit "$hangup_exit_status"' HUP
    trap 'exit "$terminate_exit_status"' TERM

    if [[ $# -ne $expected_argument_count ]]; then
      usage "$usage_error_status"
    fi

    mode="$1"
    case "$mode" in
      --help)
        usage 0
        ;;
      validate)
        "$sudo_command" -n -l "$systemctl_command" stop "$owner_unit" >/dev/null
        "$sudo_command" -n -l "$systemctl_command" start "$owner_unit" >/dev/null
        "$sudo_command" -n -l "$lsof_command" "$device_path" >/dev/null
        printf '${commandName}: capability validation PASS\n'
        ;;
      isolate)
        if ! "$systemctl_command" is-active --quiet "$owner_unit"; then
          fail "owner must be active before isolation"
        fi

        restore_armed=$restore_armed_value
        "$sudo_command" -n "$systemctl_command" stop "$owner_unit"
        if "$systemctl_command" is-active --quiet "$owner_unit"; then
          fail "owner remained active after stop"
        fi

        ownership_log="$(mktemp)"
        lsof_status=0
        if "$sudo_command" -n "$lsof_command" "$device_path" >"$ownership_log" 2>&1; then
          cat "$ownership_log" >&2
          fail "device still has an open file owner"
        else
          lsof_status="$?"
        fi
        if [[ $lsof_status -ne $no_owner_lsof_status || -s $ownership_log ]]; then
          cat "$ownership_log" >&2
          fail "device ownership inspection failed"
        fi

        restore_armed=$restore_disarmed
        printf '${commandName}: owner isolated\n'
        ;;
      restore)
        "$sudo_command" -n "$systemctl_command" start "$owner_unit"
        if ! "$systemctl_command" is-active --quiet "$owner_unit"; then
          fail "owner did not become active after start"
        fi
        printf '${commandName}: owner restored\n'
        ;;
      *)
        usage "$usage_error_status"
        ;;
    esac
  '';
}
