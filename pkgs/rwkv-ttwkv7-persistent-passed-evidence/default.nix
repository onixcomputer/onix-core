{
  lib,
  runCommand,
  b3sum,
  rustc,
  stdenv,
}:
let
  fixtureRoot = builtins.path {
    path = ./fixtures/ttwkv7-persistent-device-4;
    name = "rwkv-ttwkv7-persistent-device-4-passed-evidence";
  };
  checkerSource = builtins.path {
    path = ./reference/rwkv_persistent_passed_evidence.rs;
    name = "rwkv-persistent-passed-evidence.rs";
  };
  runbookSource = builtins.path {
    path = ../../cairn/archive/2026-07-18-prepare-rwkv-persistent-metalium-device-4-run/run-one-shot.sh;
    name = "rwkv-persistent-device-4-run-one-shot.sh";
  };
  expectedFixtureFileCount = 72;
  expectedManifestLineCount = 71;
  expectedManifestBlake3 = "731a43dcab29614b72616388352246b42f2dfdea7f02b3160902c1f804bad010";
  expectedCheckerBlake3 = "fd403c3fb10ed4c2821704a6f8a7a977d2beb3add603643503816e538eefd43b";
  expectedReceiptBlake3 = "48ea004ea7e082d562f8189b48cc7600936b12761f675630eba8d3f9187d0709";
  expectedRunbookBlake3 = "9f4dac687763712ecf527707673bf1502b3a9ab53b77e365963f8dea7864998f";
  expectedReceiptBytes = 727;
  staleRunbookLine = 286;
  lengthPrefixBytes = 8;
  requestFrameBytes = 107588;
  responseFrameBytes = 99940;
  callTranscriptBytes =
    lengthPrefixBytes + requestFrameBytes + lengthPrefixBytes + responseFrameBytes;
  callCount = 24;
  continuityCount = 12;
  pueueTaskId = 25;
  ownerHealthStatus = 200;
  selectedTokenId = 2;
  responseConnectionCount = 1;
  firstSecondTokenCall = continuityCount;
  requestCallOffset = 44;
  requestPreStateOffset = 9284;
  responseRequestIdentityOffset = 68;
  responseHeaderBytes = 100;
  firstRequestMagicOffset = lengthPrefixBytes;
  firstRequestCallOffset = firstRequestMagicOffset + requestCallOffset;
  firstResponseMagicOffset = lengthPrefixBytes + requestFrameBytes + lengthPrefixBytes;
  firstResponseRequestIdentityOffset = firstResponseMagicOffset + responseRequestIdentityOffset;
  firstResponseRawOutputOffset = firstResponseMagicOffset + responseHeaderBytes;
  retainedStateOffset =
    firstSecondTokenCall * callTranscriptBytes + lengthPrefixBytes + requestPreStateOffset;
  genericFailureStatus = 1;
  unexpectedArgument = "unexpected";
in
# r[impl onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_persistent_metalium_device_4_evidence]
runCommand "rwkv-ttwkv7-persistent-device-4-passed-evidence"
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
    runbook_source=${lib.escapeShellArg runbookSource}

    validate_fixture_at() (
      set -e
      local root="$1"
      local manifest="$root/fixture-manifest.tsv"
      test "$(find "$root" -type f | wc -l)" -eq ${toString expectedFixtureFileCount}
      test "$(wc -l <"$manifest")" -eq ${toString expectedManifestLineCount}
      test "$(b3sum "$manifest" | cut -d' ' -f1)" = \
        ${lib.escapeShellArg expectedManifestBlake3}
      test "$(cut -f1 "$manifest" | LC_ALL=C sort -u | wc -l)" -eq \
        ${toString expectedManifestLineCount}
      while IFS=$'\t' read -r relative_path expected_bytes expected_blake3; do
        test -n "$relative_path"
        case "$relative_path" in
          /*|*../*)
            echo "manifest path escaped the fixture root: $relative_path" >&2
            return ${toString genericFailureStatus}
            ;;
        esac
        local artifact="$root/$relative_path"
        test -f "$artifact"
        test "$(wc -c <"$artifact")" -eq "$expected_bytes"
        test "$(b3sum "$artifact" | cut -d' ' -f1)" = "$expected_blake3"
      done <"$manifest"
    )

    expect_failure() {
      local name="$1"
      shift
      set +e
      "$@" >"$name.stdout" 2>"$name.stderr"
      local status="$?"
      set -e
      test "$status" -eq ${toString genericFailureStatus}
      echo "negative fixture rejected: $name"
    }

    validate_fixture_at "$fixture"
    call=0
    while IFS= read -r expected_request_hash &&
      IFS= read -r expected_response_hash <&4; do
      request_offset=$((call * ${toString callTranscriptBytes} + ${toString firstRequestMagicOffset}))
      response_offset=$((call * ${toString callTranscriptBytes} + ${toString firstResponseMagicOffset}))
      actual_request_hash="$(
        dd if="$fixture/artifact/transcript.bin" bs=1 skip="$request_offset" \
          count=${toString requestFrameBytes} status=none | b3sum | cut -d' ' -f1
      )"
      actual_response_hash="$(
        dd if="$fixture/artifact/transcript.bin" bs=1 skip="$response_offset" \
          count=${toString responseFrameBytes} status=none | b3sum | cut -d' ' -f1
      )"
      test "$actual_request_hash" = "$expected_request_hash"
      test "$actual_response_hash" = "$expected_response_hash"
      call=$((call + 1))
    done <"$fixture/request-frame-blake3.txt" \
      4<"$fixture/response-frame-blake3.txt"
    test "$call" -eq ${toString callCount}
    test "$(wc -l <"$fixture/response-frame-blake3.txt")" -eq ${toString callCount}
    test "$(b3sum "$checker_source" | cut -d' ' -f1)" = \
      ${lib.escapeShellArg expectedCheckerBlake3}
    test "$(b3sum "$runbook_source" | cut -d' ' -f1)" = \
      ${lib.escapeShellArg expectedRunbookBlake3}
    test "$(grep -nF '"session_call_count"' "$runbook_source" | head -n 1 | cut -d: -f1)" -eq \
      ${toString staleRunbookLine}
    if grep -Fq '"session_call_count"' "$fixture/artifact/receipt.json"; then
      echo 'accepted host receipt unexpectedly contains the stale flat call count' >&2
      exit ${toString genericFailureStatus}
    fi
    grep -Fq ${lib.escapeShellArg ''"call_count": ${toString callCount}''} \
      "$fixture/artifact/receipt.json"
    grep -Fq ${lib.escapeShellArg ''"same_layer_state_continuity_count": ${toString continuityCount}''} \
      "$fixture/artifact/receipt.json"
    rustc --edition=2024 -D warnings "$checker_source" -o checker
    ./checker "$fixture" >receipt-first.json
    ./checker "$fixture" >receipt-second.json
    cmp receipt-first.json receipt-second.json
    test "$(wc -c <receipt-first.json)" -eq ${toString expectedReceiptBytes}
    test "$(b3sum receipt-first.json | cut -d' ' -f1)" = \
      ${lib.escapeShellArg expectedReceiptBlake3}
    grep -F '"classification": "passed"' receipt-first.json
    grep -F '"physical_process_exit_status": 0' receipt-first.json
    grep -F '"artifact_validator_exit_status": 1' receipt-first.json
    grep -F '"orchestration_exit_status": 1' receipt-first.json
    grep -F ${lib.escapeShellArg ''"physical_wkv_call_count": ${toString callCount}''} receipt-first.json
    grep -F ${lib.escapeShellArg ''"accepted_physical_response_count": ${toString callCount}''} receipt-first.json
    grep -F ${lib.escapeShellArg ''"physical_workload_commit_count": ${toString callCount}''} receipt-first.json
    grep -F ${lib.escapeShellArg ''"same_layer_state_continuity_count": ${toString continuityCount}''} receipt-first.json
    grep -F '"response_channel": "unix_stream"' receipt-first.json
    grep -F ${lib.escapeShellArg ''"response_connection_count": ${toString responseConnectionCount}''} receipt-first.json
    grep -F ${lib.escapeShellArg ''"owner_health_status_after": ${toString ownerHealthStatus}''} receipt-first.json
    grep -F '"owner_restored": true' receipt-first.json
    grep -F ${lib.escapeShellArg ''"pueue_task_id": ${toString pueueTaskId}''} receipt-first.json
    grep -F '"retry_count": 0' receipt-first.json
    grep -F ${lib.escapeShellArg ''"selected_fourth_token_id": ${toString selectedTokenId}''} receipt-first.json

    expect_failure missing-argument ./checker
    expect_failure extra-argument ./checker "$fixture" ${lib.escapeShellArg unexpectedArgument}

    cp -R "$fixture" changed-request-magic
    chmod -R u+w changed-request-magic
    printf 'X' | dd of=changed-request-magic/artifact/transcript.bin bs=1 \
      seek=${toString firstRequestMagicOffset} conv=notrunc status=none
    expect_failure changed-request-magic-check ./checker changed-request-magic

    cp -R "$fixture" changed-response-magic
    chmod -R u+w changed-response-magic
    printf 'X' | dd of=changed-response-magic/artifact/transcript.bin bs=1 \
      seek=${toString firstResponseMagicOffset} conv=notrunc status=none
    expect_failure changed-response-magic-check ./checker changed-response-magic

    cp -R "$fixture" changed-call-order
    chmod -R u+w changed-call-order
    printf '\001' | dd of=changed-call-order/artifact/transcript.bin bs=1 \
      seek=${toString firstRequestCallOffset} conv=notrunc status=none
    expect_failure changed-call-order-check ./checker changed-call-order

    cp -R "$fixture" changed-request-identity
    chmod -R u+w changed-request-identity
    printf 'X' | dd of=changed-request-identity/artifact/transcript.bin bs=1 \
      seek=${toString firstResponseRequestIdentityOffset} conv=notrunc status=none
    expect_failure changed-request-identity-check ./checker changed-request-identity

    cp -R "$fixture" changed-continuity
    chmod -R u+w changed-continuity
    printf 'X' | dd of=changed-continuity/artifact/transcript.bin bs=1 \
      seek=${toString retainedStateOffset} conv=notrunc status=none
    expect_failure changed-continuity-check ./checker changed-continuity

    cp -R "$fixture" nonfinite-response
    chmod -R u+w nonfinite-response
    printf '\200\177' | dd of=nonfinite-response/artifact/transcript.bin bs=1 \
      seek=${toString firstResponseRawOutputOffset} conv=notrunc status=none
    expect_failure nonfinite-response-check ./checker nonfinite-response

    cp -R "$fixture" truncated-transcript
    chmod -R u+w truncated-transcript
    truncate -s -1 truncated-transcript/artifact/transcript.bin
    expect_failure truncated-transcript-check ./checker truncated-transcript

    cp -R "$fixture" changed-classification
    chmod -R u+w changed-classification
    substituteInPlace changed-classification/classification-receipt.json \
      --replace-fail '"outcome": "passed"' '"outcome": "failed"'
    expect_failure changed-classification-check ./checker changed-classification

    cp -R "$fixture" changed-process
    chmod -R u+w changed-process
    substituteInPlace changed-process/process-receipt.json \
      --replace-fail '"exit_status": 0' '"exit_status": 1'
    expect_failure changed-process-check ./checker changed-process

    cp -R "$fixture" changed-postprocess
    chmod -R u+w changed-postprocess
    substituteInPlace changed-postprocess/postprocess-diagnostic.json \
      --replace-fail '"first_failing_runbook_line": 286' '"first_failing_runbook_line": 287'
    expect_failure changed-postprocess-check ./checker changed-postprocess

    cp -R "$fixture" changed-health
    chmod -R u+w changed-health
    printf '503\n' >changed-health/health-after.status
    expect_failure changed-health-check ./checker changed-health

    cp -R "$fixture" changed-board
    chmod -R u+w changed-board
    substituteInPlace changed-board/board-after-second.txt \
      --replace-fail '"DDR_STATUS": "0x5555"' '"DDR_STATUS": "0x0000"'
    expect_failure changed-board-check ./checker changed-board

    cp -R "$fixture" changed-workload
    chmod -R u+w changed-workload
    substituteInPlace changed-workload/inspector/mesh_workloads_log.yaml \
      --replace-fail 'status: Committed' 'status: Rejected'
    expect_failure changed-workload-check ./checker changed-workload

    cp -R "$fixture" changed-pueue
    chmod -R u+w changed-pueue
    substituteInPlace changed-pueue/pueue-task.json \
      --replace-fail '"status": "failed"' '"status": "done"'
    expect_failure changed-pueue-check ./checker changed-pueue

    cp -R "$fixture" changed-unparsed-file
    chmod -R u+w changed-unparsed-file
    printf 'X' >>changed-unparsed-file/artifact/server-stdout.log
    expect_failure changed-unparsed-file-manifest validate_fixture_at changed-unparsed-file

    cp -R "$fixture" missing-file
    chmod -R u+w missing-file
    rm missing-file/inspector/startup.yaml
    expect_failure missing-file-manifest validate_fixture_at missing-file

    cp -R "$fixture" extra-file
    chmod -R u+w extra-file
    : >extra-file/unexpected
    expect_failure extra-file-manifest validate_fixture_at extra-file

    mkdir -p "$out"
    cp receipt-first.json "$out/receipt.json"
    cp "$fixture/fixture-manifest.tsv" "$out/fixture-manifest.tsv"
  ''
