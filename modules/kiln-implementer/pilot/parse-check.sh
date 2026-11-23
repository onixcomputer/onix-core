# shellcheck shell=bash
# Kiln's own parsers on a generated pilot configuration, offline.
# Usage: parse-check.sh KILN_IMPLEMENTER CONFIGURATION_DIR SCRATCH_DIR
# Kiln has no side-effect-free policy validator, so this drives `poll` with an
# absent secret: it parses enrollment and the intake policy, then stops at the
# secret before any database, network or provider call. A negative control
# with `base.contract_version` removed must fail before the secret. The host
# owner registration is admitted into a throwaway ledger by Kiln itself.
set -eu
implementer=$1
configuration=$2
scratch=$3
mkdir -p "$scratch"

parsed_to_secret() {
  if output=$("$implementer" poll --database "$scratch/poll.sqlite" --enrollment "$configuration/enrollment.json" \
    --policy "$1" --secret-file "$scratch/absent-secret" --max-pages 1 2>&1); then
    echo "poll unexpectedly succeeded offline" >&2
    exit 1
  fi
  printf '%s\n' "$output" >"$2"
  case "$output" in
  *"secret file is unreadable"*) return 0 ;;
  *) return 1 ;;
  esac
}

if ! parsed_to_secret "$configuration/github-policy.json" "$scratch/positive.out"; then
  echo "Kiln rejected the generated intake policy before reaching the secret:" >&2
  cat "$scratch/positive.out" >&2
  exit 1
fi
echo "positive: Kiln parsed github-policy.json and stopped at: $(cat "$scratch/positive.out")"

jq 'del(.base.contract_version)' "$configuration/github-policy.json" >"$scratch/negative-policy.json"
if parsed_to_secret "$scratch/negative-policy.json" "$scratch/negative.out"; then
  echo "negative control without base.contract_version was accepted" >&2
  exit 1
fi
echo "negative: without base.contract_version Kiln refused: $(cat "$scratch/negative.out")"

# Kiln's own intake preflight (poll's validation plus a dry admission probe),
# the same command the guest's policy-check stage runs.
"$implementer" policy-check --policy "$configuration/github-policy.json" \
  --enrollment "$configuration/enrollment.json" >"$scratch/policy-check.out"
echo "policy-check: Kiln admitted github-policy.json: $(cat "$scratch/policy-check.out")"
if "$implementer" policy-check --policy "$scratch/negative-policy.json" \
  --enrollment "$configuration/enrollment.json" >/dev/null 2>"$scratch/policy-check-negative.err"; then
  echo "policy-check accepted the policy without base.contract_version" >&2
  exit 1
fi
echo "policy-check negative: Kiln refused: $(cat "$scratch/policy-check-negative.err")"

"$implementer" host-owner-admit --database "$scratch/owner.sqlite" --enrollment "$configuration/enrollment.json" \
  --local-operator parse-check --profile "$configuration/host-owner.json" >"$scratch/host-owner.out"
echo "host-owner: Kiln admitted host-owner.json: $(cat "$scratch/host-owner.out")"
