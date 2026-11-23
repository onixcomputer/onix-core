# The cohort's real `kiln-implementer` must serve Kiln's GitHub DNS helper
# entry, which every GitHub client re-runs its own executable with
# (`<exe> --internal-github-status-dns <ppid>`). Mirrors Kiln's
# tests/support/dns_entry.rs: offline, either addresses or the helper's own
# named resolution failure; never "unexpected argument".
# Usage: resolver-check.sh KILN_IMPLEMENTER SCRATCH_DIR
set -u
implementer=$1
scratch=$2
mkdir -p "$scratch"
prefix="github status dns helper:"

# The helper refuses any PID that is not its parent, so it must be a direct
# child of this shell: `env -i` execs in place, keeping $$ as the parent.
env -i "$implementer" --internal-github-status-dns $$ > "$scratch/served.out" 2> "$scratch/served.err"
status=$?
stdout=$(cat "$scratch/served.out")
stderr=$(cat "$scratch/served.err")
case "$status" in
  0)
    if [ -n "$stderr" ] || [ -z "$stdout" ] || printf '%s\n' "$stdout" | grep -qvE '^[0-9a-fA-F.:\[\]]+:443$'; then
      echo "helper exited 0 without bounded ip:443 addresses: $stdout $stderr" >&2
      exit 1
    fi
    echo "served: resolved $(printf '%s' "$stdout" | tr '\n' ' ')"
    ;;
  1)
    case "$stderr" in
      "$prefix"*api.github.com*) ;;
      *) echo "helper failed without its named resolution failure: $stderr" >&2; exit 1 ;;
    esac
    if [ -n "$stdout" ]; then echo "helper failure wrote stdout: $stdout" >&2; exit 1; fi
    echo "served: offline, helper reported: $stderr"
    ;;
  *)
    echo "entry not served (exit $status): $stderr" >&2
    exit 1
    ;;
esac

# Malformed entries are refused by the helper itself, before any lookup.
env -i "$implementer" --internal-github-status-dns not-a-pid > "$scratch/malformed.out" 2> "$scratch/malformed.err"
status=$?
stderr=$(cat "$scratch/malformed.err")
case "$status:$stderr" in
  "2:$prefix"*) echo "malformed: refused by the helper as usage (exit 2): $stderr" ;;
  *) echo "malformed entry not refused by the helper as usage (exit $status): $stderr" >&2; exit 1 ;;
esac
