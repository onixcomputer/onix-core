{
  lib,
  runCommand,
  b3sum,
  rustc,
  stdenv,
}:
let
  fixtureRoot = builtins.path {
    path = ./fixtures/ttwkv7-persistent-device-3;
    name = "rwkv-ttwkv7-persistent-device-3-evidence";
  };
  checkerSource = builtins.path {
    path = ./reference/rwkv_persistent_partial_diagnostic.rs;
    name = "rwkv-persistent-partial-diagnostic.rs";
  };
  expectedFixtureFileCount = 51;
  expectedManifestLineCount = 50;
  expectedManifestBlake3 = "f8b36780a6ab3800564ea14a46a39ef903291cafd62341402a2678b30db148e4";
  expectedCheckerBlake3 = "4c858937300b392f86d6f7d0ddddcc69dc6c01062e8b53278c5839a9825be5cf";
  expectedReceiptBlake3 = "4259c6a2aa5706fab7e8c862d90111c5b425a1a4a0b917d872ed5cccb6f1f4e8";
  expectedReceiptBytes = 707;
  lengthPrefixBytes = 8;
  requestFrameBytes = 107588;
  responseLoggerPrefixBytes = 3793;
  responseFrameBytes = 99940;
  validResponsePrefixBytes = responseFrameBytes - responseLoggerPrefixBytes;
  finiteRawOutputValues = 768;
  finitePartialPostStateValues = 47255;
  missingPostStateValues = 1897;
  completedPhysicalCallCount = 1;
  acceptedPhysicalResponseCount = 0;
  ownerHealthStatus = 200;
  pueueTaskId = 281;
  responseMagicOffset =
    lengthPrefixBytes + requestFrameBytes + lengthPrefixBytes + responseLoggerPrefixBytes;
  genericFailureStatus = 1;
  unexpectedArgument = "unexpected";
in
# r[impl onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_persistent_metalium_partial_diagnostic]
runCommand "rwkv-ttwkv7-persistent-partial-diagnostic"
  {
    nativeBuildInputs = [
      b3sum
      rustc
      stdenv.cc
    ];
  }
  ''
    set -euo pipefail

    fixture=${lib.escapeShellArg fixtureRoot}
    checker_source=${lib.escapeShellArg checkerSource}
    test "$(find "$fixture" -type f | wc -l)" -eq ${toString expectedFixtureFileCount}
    test "$(wc -l <"$fixture/manifest.tsv")" -eq ${toString expectedManifestLineCount}
    test "$(b3sum "$fixture/manifest.tsv" | cut -d' ' -f1)" = \
      ${lib.escapeShellArg expectedManifestBlake3}
    test "$(b3sum "$checker_source" | cut -d' ' -f1)" = \
      ${lib.escapeShellArg expectedCheckerBlake3}

    while IFS=$'\t' read -r relative_path expected_bytes expected_blake3; do
      test -n "$relative_path"
      case "$relative_path" in
        /*|*../*)
          echo "manifest path escaped the fixture root: $relative_path" >&2
          exit ${toString genericFailureStatus}
          ;;
      esac
      artifact="$fixture/$relative_path"
      test -f "$artifact"
      test "$(wc -c <"$artifact")" -eq "$expected_bytes"
      test "$(b3sum "$artifact" | cut -d' ' -f1)" = "$expected_blake3"
    done <"$fixture/manifest.tsv"

    rustc --edition=2024 "$checker_source" -o checker
    ./checker "$fixture" >receipt-first.json
    ./checker "$fixture" >receipt-second.json
    cmp receipt-first.json receipt-second.json
    test "$(wc -c <receipt-first.json)" -eq ${toString expectedReceiptBytes}
    test "$(b3sum receipt-first.json | cut -d' ' -f1)" = \
      ${lib.escapeShellArg expectedReceiptBlake3}
    grep -F '"classification": "partial_diagnostic"' receipt-first.json
    grep -F ${lib.escapeShellArg "\"completed_physical_wkv_call_count\": ${toString completedPhysicalCallCount}"} receipt-first.json
    grep -F ${lib.escapeShellArg "\"accepted_physical_response_count\": ${toString acceptedPhysicalResponseCount}"} receipt-first.json
    grep -F ${lib.escapeShellArg "\"physical_workload_commit_count\": ${toString completedPhysicalCallCount}"} receipt-first.json
    grep -F ${lib.escapeShellArg "\"logger_prefix_bytes\": ${toString responseLoggerPrefixBytes}"} receipt-first.json
    grep -F ${lib.escapeShellArg "\"valid_response_prefix_bytes\": ${toString validResponsePrefixBytes}"} receipt-first.json
    grep -F ${lib.escapeShellArg "\"finite_raw_output_values\": ${toString finiteRawOutputValues}"} receipt-first.json
    grep -F ${lib.escapeShellArg "\"finite_partial_post_state_values\": ${toString finitePartialPostStateValues}"} receipt-first.json
    grep -F ${lib.escapeShellArg "\"missing_post_state_values\": ${toString missingPostStateValues}"} receipt-first.json
    grep -F '"owner_restored": true' receipt-first.json
    grep -F ${lib.escapeShellArg "\"owner_health_status_after\": ${toString ownerHealthStatus}"} receipt-first.json
    grep -F ${lib.escapeShellArg "\"retry_count\": ${toString acceptedPhysicalResponseCount}"} receipt-first.json
    grep -F ${lib.escapeShellArg "\"pueue_task_id\": ${toString pueueTaskId}"} receipt-first.json

    expect_failure() {
      local name="$1"
      shift
      set +e
      "$@" >"$name.stdout" 2>"$name.stderr"
      local status="$?"
      set -e
      test "$status" -eq ${toString genericFailureStatus}
      test -s "$name.stderr"
    }

    expect_failure missing-argument ./checker
    expect_failure extra-argument ./checker "$fixture" ${lib.escapeShellArg unexpectedArgument}

    cp -R "$fixture" changed-magic
    chmod -R u+w changed-magic
    printf 'X' | dd of=changed-magic/transcript.bin bs=1 seek=${toString responseMagicOffset} conv=notrunc status=none
    expect_failure changed-magic ./checker changed-magic

    cp -R "$fixture" truncated-transcript
    chmod -R u+w truncated-transcript
    truncate -s -1 truncated-transcript/transcript.bin
    expect_failure truncated-transcript ./checker truncated-transcript

    cp -R "$fixture" changed-classification
    chmod -R u+w changed-classification
    substituteInPlace changed-classification/classification-receipt.json \
      --replace-fail '"outcome": "partial_diagnostic"' '"outcome": "failed"'
    expect_failure changed-classification ./checker changed-classification

    cp -R "$fixture" changed-workload
    chmod -R u+w changed-workload
    substituteInPlace changed-workload/inspector/mesh_workloads_log.yaml \
      --replace-fail 'status: Committed' 'status: InFlight'
    expect_failure changed-workload ./checker changed-workload

    cp -R "$fixture" changed-health
    chmod -R u+w changed-health
    printf '503\n' >changed-health/health-after.status
    expect_failure changed-health ./checker changed-health

    mkdir -p "$out"
    cp receipt-first.json "$out/receipt.json"
    cp "$fixture/manifest.tsv" "$out/fixture-manifest.tsv"
  ''
