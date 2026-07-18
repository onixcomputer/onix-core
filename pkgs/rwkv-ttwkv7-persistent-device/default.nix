{
  lib,
  stdenvNoCC,
  b3sum,
  nickel,
  rwkvLab,
  rwkvLayerHarness,
  ttwkv7,
  ttwkv7OwnerControl,
}:
let
  commandName = "rwkv-ttwkv7-persistent-device";
  sessionId = "rwkv-ttwkv7-persistent-device-3";
  runRoot = "/var/tmp/${sessionId}";
  evidenceSource = ../rwkv-layer-harness/fixtures/ttwkv7-device-2;
  hostExecutable = "${rwkvLayerHarness}/bin/rwkv-ttwkv7-persistent-physical-dispatch";
  coreExecutable = "${rwkvLayerHarness}/bin/rwkv-ttwkv7-persistent-physical-core";
  cpuServerExecutable = "${rwkvLayerHarness}/bin/rwkv-ttwkv7-cpu-dispatch-server";
  metaliumServerExecutable = "${ttwkv7}/bin/wkv7";
  ownerControlExecutable = "${ttwkv7OwnerControl}/bin/ttwkv7-owner-control";
  expectedVisibleDevice = "1";
  wrongVisibleDevice = "0";
  testInspectorAddress = "127.0.0.1:43157";
  invalidInspectorAddress = "0.0.0.0:43157";
  expectedCoreReceiptBlake3 = "de05540f46e16803d999432792e5586760c9625de44a36aab105a255c4f4a9d5";
  expectedCoreReceiptByteCount = 53208;
  expectedTranscriptByteCount = 4981056;
  invalidModeStatus = 2;
  failureStatus = 1;
  unexpectedSuffix = "unexpected-suffix";
in
stdenvNoCC.mkDerivation {
  pname = "rwkv-ttwkv7-persistent-device";
  version = "0.1.0";

  dontUnpack = true;
  nativeBuildInputs = [
    b3sum
    nickel
    rwkvLab
  ];

  installPhase = ''
    runHook preInstall
    set -euo pipefail

    wrapper="$out/bin/${commandName}"
    evidence_root="$out/share/${commandName}/evidence"
    session_root="$out/share/${commandName}/session"
    mkdir -p "$out/bin" "$evidence_root" "$session_root"
    cp -R ${evidenceSource}/. "$evidence_root/"

    substitute ${./wrapper.sh} "$wrapper" \
      --replace-fail '@evidenceRoot@' "$evidence_root" \
      --replace-fail '@hostExecutable@' ${lib.escapeShellArg hostExecutable} \
      --replace-fail '@coreExecutable@' ${lib.escapeShellArg coreExecutable} \
      --replace-fail '@cpuServerExecutable@' ${lib.escapeShellArg cpuServerExecutable} \
      --replace-fail '@metaliumServerExecutable@' ${lib.escapeShellArg metaliumServerExecutable}
    chmod +x "$wrapper"

    cp ${rwkvLab}/share/rwkv-lab/session-contract.ncl "$session_root/session-contract.ncl"
    substitute ${./session-plan.ncl} "$session_root/session-plan.ncl" \
      --replace-fail '@packagePath@' "$out" \
      --replace-fail '@kernelPath@' ${lib.escapeShellArg "${ttwkv7}/share/ttwkv7/kernels"} \
      --replace-fail '@executablePath@' "$wrapper" \
      --replace-fail '@ownerControlPath@' ${lib.escapeShellArg ownerControlExecutable}
    nickel export --format json "$session_root/session-plan.ncl" >"$session_root/manifest.json"
    rwkv-lab check "$session_root/manifest.json" >"$session_root/plan-receipt.json"
    plan_id="$(rwkv-lab plan-id "$session_root/manifest.json")"
    substitute ${./not-run-evidence.json.in} "$session_root/not-run-evidence.json" \
      --replace-fail '@planId@' "$plan_id"
    rwkv-lab classify \
      "$session_root/manifest.json" \
      "$session_root/not-run-evidence.json" \
      >"$session_root/not-run-receipt.json"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    set -euo pipefail

    wrapper="$out/bin/${commandName}"
    evidence_root="$out/share/${commandName}/evidence"
    session_root="$out/share/${commandName}/session"
    fixture_root="$(mktemp -d)"

    "$wrapper" self-test >"$fixture_root/self-test-first.log"
    "$wrapper" self-test >"$fixture_root/self-test-second.log"
    cmp "$fixture_root/self-test-first.log" "$fixture_root/self-test-second.log"
    grep -F 'rwkv persistent dispatch process shell self-test: PASS' \
      "$fixture_root/self-test-first.log"

    runtime_cache="$fixture_root/runtime/cache"
    runtime_logs="$fixture_root/runtime/logs"
    TT_VISIBLE_DEVICES=${lib.escapeShellArg expectedVisibleDevice} \
      TT_METAL_CACHE="$runtime_cache" \
      TT_METAL_LOGS_PATH="$runtime_logs" \
      TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS=${lib.escapeShellArg testInspectorAddress} \
      "$wrapper" validate-runtime >"$fixture_root/preflight.log"
    grep -F 'rwkv persistent physical dispatch runtime state preflight: PASS' \
      "$fixture_root/preflight.log"
    test -d "$runtime_cache"
    test -d "$runtime_logs"
    test ! -e "$runtime_logs/rwkv-persistent-physical-dispatch"

    expect_failure() {
      expected_status="$1"
      expected_diagnostic="$2"
      output_path="$3"
      shift 3
      if "$@" >"$output_path" 2>&1; then
        echo "persistent device package mutation unexpectedly passed: $*" >&2
        exit 1
      else
        actual_status="$?"
      fi
      test "$actual_status" -eq "$expected_status"
      grep -F "$expected_diagnostic" "$output_path"
    }

    expect_failure ${toString failureStatus} 'self-test does not accept additional arguments' \
      "$fixture_root/self-test-suffix.log" "$wrapper" self-test ${lib.escapeShellArg unexpectedSuffix}
    expect_failure ${toString failureStatus} 'probe does not accept additional arguments' \
      "$fixture_root/probe-suffix.log" "$wrapper" probe ${lib.escapeShellArg unexpectedSuffix}
    expect_failure ${toString invalidModeStatus} 'usage:' \
      "$fixture_root/invalid-mode.log" "$wrapper" invalid-mode
    expect_failure ${toString failureStatus} 'TT_VISIBLE_DEVICES must select physical device 1 exactly' \
      "$fixture_root/wrong-device.log" env \
      TT_VISIBLE_DEVICES=${lib.escapeShellArg wrongVisibleDevice} \
      TT_METAL_CACHE="$runtime_cache" \
      TT_METAL_LOGS_PATH="$runtime_logs" \
      TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS=${lib.escapeShellArg testInspectorAddress} \
      "$wrapper" validate-runtime
    expect_failure ${toString failureStatus} 'TT_METAL_CACHE must be an absolute writable path outside /nix/store' \
      "$fixture_root/missing-cache.log" env \
      TT_VISIBLE_DEVICES=${lib.escapeShellArg expectedVisibleDevice} \
      TT_METAL_LOGS_PATH="$runtime_logs" \
      TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS=${lib.escapeShellArg testInspectorAddress} \
      "$wrapper" validate-runtime
    expect_failure ${toString failureStatus} 'TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS must be' \
      "$fixture_root/invalid-inspector.log" env \
      TT_VISIBLE_DEVICES=${lib.escapeShellArg expectedVisibleDevice} \
      TT_METAL_CACHE="$runtime_cache" \
      TT_METAL_LOGS_PATH="$runtime_logs" \
      TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS=${lib.escapeShellArg invalidInspectorAddress} \
      "$wrapper" validate-runtime

    fake_host="$fixture_root/fake-host"
    printf '%s\n' \
      '#!${stdenvNoCC.shell}' \
      'printf "%s\\n" "$@"' \
      >"$fake_host"
    chmod +x "$fake_host"
    fake_server="$fixture_root/fake-server"
    printf '#!${stdenvNoCC.shell}\nexit 1\n' >"$fake_server"
    chmod +x "$fake_server"
    fake_wrapper="$fixture_root/fake-wrapper"
    substitute ${./wrapper.sh} "$fake_wrapper" \
      --replace-fail '@evidenceRoot@' "$evidence_root" \
      --replace-fail '@hostExecutable@' "$fake_host" \
      --replace-fail '@coreExecutable@' "$fake_host" \
      --replace-fail '@cpuServerExecutable@' "$fake_server" \
      --replace-fail '@metaliumServerExecutable@' "$fake_server"
    chmod +x "$fake_wrapper"
    patchShebangs "$fake_wrapper"
    TT_VISIBLE_DEVICES=${lib.escapeShellArg expectedVisibleDevice} \
      TT_METAL_CACHE="$runtime_cache" \
      TT_METAL_LOGS_PATH="$runtime_logs" \
      TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS=${lib.escapeShellArg testInspectorAddress} \
      "$fake_wrapper" probe >"$fixture_root/probe-vector.log"
    test "$(cat "$fixture_root/probe-vector.log")" = "$(
      printf '%s\n%s\n%s\n%s\n%s\n%s' \
        --server "$fake_server" --evidence-root "$evidence_root" \
        --artifact-root "$runtime_logs/rwkv-persistent-physical-dispatch"
    )"

    test -f "$evidence_root/diagnostic.log"
    test "$(b3sum "$evidence_root/observed-output.bf16" | cut -d' ' -f1)" = \
      '417a583d87e901c5488266e84f3f9cfba98e2bbe45fc8da952c8cb4b06afc66a'
    test "$(b3sum "$evidence_root/observed-post-state.bf16" | cut -d' ' -f1)" = \
      'b3321aeb38963fb96a720ae33d9477e8fbfb83b3750213abc64786885d3771a9'

    rwkv-lab check "$session_root/manifest.json" >"$fixture_root/plan-replay.json"
    cmp "$session_root/plan-receipt.json" "$fixture_root/plan-replay.json"
    rwkv-lab classify \
      "$session_root/manifest.json" \
      "$session_root/not-run-evidence.json" \
      >"$fixture_root/not-run-replay.json"
    cmp "$session_root/not-run-receipt.json" "$fixture_root/not-run-replay.json"
    grep -F '"session_id": "${sessionId}"' "$session_root/plan-receipt.json"
    grep -F '"run_root": "${runRoot}"' "$session_root/plan-receipt.json"
    grep -F '"max_processes": 1' "$session_root/plan-receipt.json"
    grep -F '"timeout_seconds": 1800' "$session_root/plan-receipt.json"
    grep -F '"rollback_delay_seconds": 2100' "$session_root/plan-receipt.json"
    grep -F '"physical_device": 1' "$session_root/plan-receipt.json"
    grep -F '"outcome": "not_run"' "$session_root/not-run-receipt.json"
    grep -F '"process_budget_exhausted": false' "$session_root/not-run-receipt.json"
    grep -F '"success_claim": null' "$session_root/not-run-receipt.json"

    wrapper_source=${./wrapper.sh}
    test "$(grep -Fc 'exec "$host_executable"' "$wrapper_source")" -eq 1
    grep -F -- '--server "$metalium_server_executable"' "$wrapper_source"
    grep -F 'unset RWKV_TTWKV7_CPU_SERVER_FAULT' "$wrapper_source"
    test "$(grep -Fc -- '--test-server' "$wrapper_source")" -eq 1
    test "$(grep -Fc -- '--server' "$wrapper_source")" -eq 1
    if grep -E 'retry|reconnect|backoff' "$wrapper_source"; then
      echo 'persistent device wrapper contains a retry or reconnect surface' >&2
      exit 1
    fi

    test -x ${hostExecutable}
    test -x ${coreExecutable}
    test -x ${cpuServerExecutable}
    test -x ${metaliumServerExecutable}
    test -x ${ownerControlExecutable}
    test ${toString expectedCoreReceiptByteCount} -eq 53208
    test ${toString expectedTranscriptByteCount} -eq 4981056
    test ${lib.escapeShellArg expectedCoreReceiptBlake3} = \
      'de05540f46e16803d999432792e5586760c9625de44a36aab105a255c4f4a9d5'

    runHook postInstallCheck
  '';

  meta = {
    description = "Prepared single-attempt persistent physical RWKV ttWKV7 dispatch session";
    license = lib.licenses.mit;
    mainProgram = commandName;
    platforms = [ "x86_64-linux" ];
  };
}
