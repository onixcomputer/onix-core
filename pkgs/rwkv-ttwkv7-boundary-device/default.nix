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
  commandName = "wkv7-rwkv-boundary";
  fixtureFilename = "ttwkv7-boundary.json";
  recoveryAttemptOrdinal = "2";
  recoverySessionId = "rwkv-ttwkv7-boundary-device-${recoveryAttemptOrdinal}";
  recoveryRunRoot = "/var/tmp/${recoverySessionId}";
  runtimeExecutable = "${ttwkv7}/bin/wkv7";
  expectedFixtureByteCount = 420072;
  expectedFixtureBlake3 = "731f44866c869300ca330f703f1adad4c3ae7ee62b832fa881a6bf4ea90211cd";
  expectedOrderedArtifactBlake3 = "44d91ad223079fa9ae5f6f0dc9943fc6d13cc25cb09262111ad433c7e6288494";
  expectedVisibleDevice = "1";
  wrongVisibleDevice = "0";
  testInspectorAddress = "127.0.0.1:43147";
  invalidInspectorAddress = "0.0.0.0:43147";
  invalidMode = "invalid-mode";
  unexpectedSuffix = "unexpected-suffix";
  invalidModeStatus = 2;
  failureStatus = 1;
  truncatedFixtureByteCount = expectedFixtureByteCount - 1;
  fixtureSource = "${rwkvLayerHarness}/share/rwkv-layer-harness/${fixtureFilename}";
  ownerControlExecutable = "${ttwkv7OwnerControl}/bin/ttwkv7-owner-control";
in
# r[impl onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_boundary_device_harness]
stdenvNoCC.mkDerivation {
  pname = "rwkv-ttwkv7-boundary-device";
  version = "0.2.0";

  dontUnpack = true;
  nativeBuildInputs = [
    b3sum
    nickel
    rwkvLab
  ];

  installPhase = ''
    runHook preInstall
    set -euo pipefail

    fixture_path="$out/share/rwkv-ttwkv7-boundary-device/${fixtureFilename}"
    wrapper_path="$out/bin/${commandName}"
    session_root="$out/share/rwkv-ttwkv7-boundary-device/session"
    mkdir -p "$out/bin" "$out/share/rwkv-ttwkv7-boundary-device" "$session_root"
    cp ${fixtureSource} "$fixture_path"
    test "$(wc -c <"$fixture_path")" -eq ${toString expectedFixtureByteCount}
    test "$(b3sum "$fixture_path" | cut -d' ' -f1)" = ${lib.escapeShellArg expectedFixtureBlake3}

    substitute ${./boundary-wrapper.sh} "$wrapper_path" \
      --replace-fail '@fixturePath@' "$fixture_path" \
      --replace-fail '@runtimeExecutable@' ${lib.escapeShellArg runtimeExecutable}
    chmod +x "$wrapper_path"

    cp ${rwkvLab}/share/rwkv-lab/session-contract.ncl "$session_root/session-contract.ncl"
    substitute ${./session-plan.ncl} "$session_root/session-plan.ncl" \
      --replace-fail '@packagePath@' "$out" \
      --replace-fail '@kernelPath@' ${lib.escapeShellArg "${ttwkv7}/share/ttwkv7/kernels"} \
      --replace-fail '@executablePath@' "$wrapper_path" \
      --replace-fail '@ownerControlPath@' ${lib.escapeShellArg ownerControlExecutable} \
      --replace-fail '@sessionId@' ${lib.escapeShellArg recoverySessionId} \
      --replace-fail '@runRoot@' ${lib.escapeShellArg recoveryRunRoot}
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

    fixture="$out/share/rwkv-ttwkv7-boundary-device/${fixtureFilename}"
    wrapper="$out/bin/${commandName}"
    session_root="$out/share/rwkv-ttwkv7-boundary-device/session"
    fixture_root="$(mktemp -d)"
    first_receipt="$fixture_root/self-test-first.json"
    second_receipt="$fixture_root/self-test-second.json"

    "$wrapper" self-test >"$first_receipt"
    "$wrapper" self-test >"$second_receipt"
    cmp "$first_receipt" "$second_receipt"
    grep -F ${lib.escapeShellArg "\"device_initialized\":false"} "$first_receipt"
    grep -F ${lib.escapeShellArg "\"fixture_blake3\":\"${expectedFixtureBlake3}\""} "$first_receipt"
    grep -F ${lib.escapeShellArg "\"ordered_artifact_blake3\":\"${expectedOrderedArtifactBlake3}\""} "$first_receipt"
    grep -F ${lib.escapeShellArg "\"self_test_passed\":true"} "$first_receipt"
    grep -F ${lib.escapeShellArg "\"workload_enqueue_count\":0"} "$first_receipt"

    runtime_root="$fixture_root/runtime"
    runtime_cache="$runtime_root/cache"
    runtime_logs="$runtime_root/logs"
    TT_VISIBLE_DEVICES=${lib.escapeShellArg expectedVisibleDevice} \
      TT_METAL_CACHE="$runtime_cache" \
      TT_METAL_LOGS_PATH="$runtime_logs" \
      TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS=${lib.escapeShellArg testInspectorAddress} \
      "$wrapper" validate-runtime >"$fixture_root/preflight.log"
    grep -F 'rwkv ttWKV7 boundary runtime state preflight: PASS' "$fixture_root/preflight.log"
    test -d "$runtime_cache"
    test -d "$runtime_logs"
    test ! -e "$runtime_logs/rwkv-boundary-device"

    fake_runtime="$fixture_root/fake-runtime"
    printf '%s\n' \
      '#!${stdenvNoCC.shell}' \
      'printf "%s\\n" "$@"' \
      >"$fake_runtime"
    chmod +x "$fake_runtime"
    fake_wrapper="$fixture_root/fake-wrapper"
    substitute ${./boundary-wrapper.sh} "$fake_wrapper" \
      --replace-fail '@fixturePath@' "$fixture" \
      --replace-fail '@runtimeExecutable@' "$fake_runtime"
    chmod +x "$fake_wrapper"
    patchShebangs "$fake_wrapper"

    "$fake_wrapper" self-test >"$fixture_root/self-test-vector.log"
    test "$(cat "$fixture_root/self-test-vector.log")" = "$(
      printf '%s\n%s' boundary-self-test "$fixture"
    )"
    TT_VISIBLE_DEVICES=${lib.escapeShellArg expectedVisibleDevice} \
      TT_METAL_CACHE="$runtime_cache" \
      TT_METAL_LOGS_PATH="$runtime_logs" \
      TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS=${lib.escapeShellArg testInspectorAddress} \
      "$fake_wrapper" probe >"$fixture_root/probe-vector.log"
    test "$(cat "$fixture_root/probe-vector.log")" = "$(
      printf '%s\n%s\n%s' boundary-run "$fixture" "$runtime_logs/rwkv-boundary-device"
    )"

    expect_status() {
      expected_status="$1"
      expected_diagnostic="$2"
      output_path="$3"
      shift 3
      if "$@" >"$output_path" 2>&1; then
        echo "boundary negative command unexpectedly passed: $*" >&2
        exit 1
      else
        actual_status="$?"
      fi
      test "$actual_status" -eq "$expected_status"
      grep -F "$expected_diagnostic" "$output_path"
    }

    expect_status ${toString failureStatus} 'self-test does not accept additional arguments' \
      "$fixture_root/self-test-suffix.log" "$wrapper" self-test ${lib.escapeShellArg unexpectedSuffix}
    expect_status ${toString failureStatus} 'probe does not accept additional arguments' \
      "$fixture_root/probe-suffix.log" "$wrapper" probe ${lib.escapeShellArg unexpectedSuffix}
    expect_status ${toString invalidModeStatus} 'usage:' \
      "$fixture_root/invalid-mode.log" "$wrapper" ${lib.escapeShellArg invalidMode}
    expect_status ${toString failureStatus} 'TT_VISIBLE_DEVICES must select physical device 1 exactly' \
      "$fixture_root/wrong-device.log" env \
      TT_VISIBLE_DEVICES=${lib.escapeShellArg wrongVisibleDevice} \
      TT_METAL_CACHE="$runtime_cache" \
      TT_METAL_LOGS_PATH="$runtime_logs" \
      TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS=${lib.escapeShellArg testInspectorAddress} \
      "$wrapper" validate-runtime
    expect_status ${toString failureStatus} 'TT_METAL_CACHE must be an absolute writable path outside /nix/store' \
      "$fixture_root/missing-cache.log" env \
      TT_VISIBLE_DEVICES=${lib.escapeShellArg expectedVisibleDevice} \
      TT_METAL_LOGS_PATH="$runtime_logs" \
      TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS=${lib.escapeShellArg testInspectorAddress} \
      "$wrapper" validate-runtime
    expect_status ${toString failureStatus} 'TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS must be' \
      "$fixture_root/invalid-inspector.log" env \
      TT_VISIBLE_DEVICES=${lib.escapeShellArg expectedVisibleDevice} \
      TT_METAL_CACHE="$runtime_cache" \
      TT_METAL_LOGS_PATH="$runtime_logs" \
      TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS=${lib.escapeShellArg invalidInspectorAddress} \
      "$wrapper" validate-runtime

    changed_fixture="$fixture_root/changed-fixture.json"
    cp "$fixture" "$changed_fixture"
    chmod u+w "$changed_fixture"
    printf 'x' | dd of="$changed_fixture" bs=1 seek=0 conv=notrunc status=none
    expect_status ${toString failureStatus} 'whole fixture BLAKE3 mismatch' \
      "$fixture_root/changed-fixture.log" ${lib.escapeShellArg runtimeExecutable} \
      boundary-self-test "$changed_fixture"
    rejected_artifact_root="$fixture_root/rejected-device-artifacts"
    expect_status ${toString failureStatus} 'whole fixture BLAKE3 mismatch' \
      "$fixture_root/changed-fixture-device.log" ${lib.escapeShellArg runtimeExecutable} \
      boundary-run "$changed_fixture" "$rejected_artifact_root"
    test ! -e "$rejected_artifact_root"
    expect_status ${toString failureStatus} 'boundary artifact root must be absolute and outside /nix/store' \
      "$fixture_root/store-artifact-root.log" ${lib.escapeShellArg runtimeExecutable} \
      boundary-run "$fixture" /nix/store/unsafe-boundary-artifacts

    truncated_fixture="$fixture_root/truncated-fixture.json"
    head -c ${toString truncatedFixtureByteCount} "$fixture" >"$truncated_fixture"
    expect_status ${toString failureStatus} 'fixture byte count does not match the authority' \
      "$fixture_root/truncated-fixture.log" ${lib.escapeShellArg runtimeExecutable} \
      boundary-self-test "$truncated_fixture"

    rwkv-lab check "$session_root/manifest.json" >"$fixture_root/plan-replay.json"
    cmp "$session_root/plan-receipt.json" "$fixture_root/plan-replay.json"
    rwkv-lab classify \
      "$session_root/manifest.json" \
      "$session_root/not-run-evidence.json" \
      >"$fixture_root/not-run-replay.json"
    cmp "$session_root/not-run-receipt.json" "$fixture_root/not-run-replay.json"
    grep -F '"outcome": "not_run"' "$session_root/not-run-receipt.json"
    grep -F '"process_budget_exhausted": false' "$session_root/not-run-receipt.json"
    grep -F '"success_claim": null' "$session_root/not-run-receipt.json"
    grep -F ${lib.escapeShellArg "\"session_id\": \"${recoverySessionId}\""} "$session_root/plan-receipt.json"
    grep -F ${lib.escapeShellArg "\"run_root\": \"${recoveryRunRoot}\""} "$session_root/plan-receipt.json"
    grep -F '"stage": "operator"' "$session_root/plan-receipt.json"
    grep -F '"max_processes": 1' "$session_root/plan-receipt.json"
    grep -F '"physical_device": 1' "$session_root/plan-receipt.json"
    grep -F '"arguments": [' "$session_root/plan-receipt.json"
    grep -F '"probe"' "$session_root/plan-receipt.json"
    grep -F 'No hardware execution is authorized by this plan artifact.' \
      "$session_root/plan-receipt.json"

    runner_source=${lib.escapeShellArg "${ttwkv7}/share/ttwkv7/source/wkv7_runner.cpp"}
    boundary_header=${lib.escapeShellArg "${ttwkv7}/share/ttwkv7/source/ttwkv7-boundary-device.h"}
    test -f "$boundary_header"
    test "$(grep -Fc '#include "ttwkv7-boundary-device.h"' "$runner_source")" -eq 1
    test "$(grep -Fc 'MeshDevice::create_unit_mesh' "$runner_source")" -eq 2
    test "$(grep -Fc 'boundary-self-test' "$runner_source")" -ge 1
    test "$(grep -Fc 'boundary-run' "$runner_source")" -ge 1
    test "$(grep -Fc 'kBoundaryOneShotExecutionPolicy' "$runner_source")" -eq 2
    grep -F 'if (!one_shot)' "$runner_source"
    grep -F 'boundary_capture->writer_raw = bf16_bits(raw);' "$runner_source"
    grep -F 'workload_enqueue_count' "$runner_source"
    grep -F 'kBoundaryNmseCeiling = 6.0e-2' "$boundary_header"
    grep -F 'metrics.nmse < kBoundaryNmseCeiling' "$boundary_header"
    if grep -E 'getenv|std::env|std::filesystem|fstream|MeshDevice|CommandQueue|EnqueueMeshWorkload|CreateKernel|CreateCircularBuffer' \
      "$boundary_header"; then
      echo "boundary pure core contains an imperative or device surface" >&2
      exit 1
    fi

    wrapper_source=${./boundary-wrapper.sh}
    test "$(grep -Fxc '  exec "$runtime_executable" boundary-self-test "$fixture_path"' "$wrapper_source")" -eq 1
    test "$(grep -Fxc '  exec "$runtime_executable" boundary-run "$fixture_path" \' "$wrapper_source")" -eq 1
    test "$(grep -Fc 'boundary-run' "$wrapper_source")" -eq 1
    test "$(grep -Fc 'boundary-self-test' "$wrapper_source")" -eq 2

    runHook postInstallCheck
  '';

  meta = {
    description = "Prepared exact-fixture ttWKV7 boundary device harness and session plan";
    license = lib.licenses.mit;
    mainProgram = commandName;
    platforms = [ "x86_64-linux" ];
  };
}
