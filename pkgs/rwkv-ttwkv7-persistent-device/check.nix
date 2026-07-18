{
  lib,
  runCommand,
  closureInfo,
  b3sum,
  persistentDevice,
  rwkvLayerHarness,
  ttwkv7,
}:
let
  packageClosure = closureInfo { rootPaths = [ persistentDevice ]; };
  expectedClosurePathCount = 127;
  expectedMetaliumPythonPath = "/nix/store/l9k0anq0z7zz81zcwy035jfwap9ga6rl-python3-3.13.13";
  wrapper = "${persistentDevice}/bin/rwkv-ttwkv7-persistent-device";
  sessionRoot = "${persistentDevice}/share/rwkv-ttwkv7-persistent-device/session";
  planManifest = "${sessionRoot}/manifest.json";
  planReceipt = "${sessionRoot}/plan-receipt.json";
  notRunReceipt = "${sessionRoot}/not-run-receipt.json";
  evidenceRoot = "${persistentDevice}/share/rwkv-ttwkv7-persistent-device/evidence";
  runnerSource = "${ttwkv7}/share/ttwkv7/source/wkv7_runner.cpp";
  transportHeader = "${ttwkv7}/share/ttwkv7/source/ttwkv7-dispatch-transport.h";
  hostExecutable = "${rwkvLayerHarness}/bin/rwkv-ttwkv7-persistent-physical-dispatch";
  coreExecutable = "${rwkvLayerHarness}/bin/rwkv-ttwkv7-persistent-physical-core";
  metaliumExecutable = "${ttwkv7}/bin/wkv7";
  expectedManifestBlake3 = "8261cc89daafa3118ae8da1ea7b46228978f4a1422443ae2c875d83d63791d4d";
  expectedPlanReceiptBlake3 = "4cfb670fd9c9bc92b9e5d06c5a4adf4439d96b67b44b6de450cb93bf003464fc";
  expectedNotRunReceiptBlake3 = "f1628fb83aac17fe3c39345f45239b8a5116a9434e6dfe4aa95a3f7eec28b6c7";
  expectedWrapperBlake3 = "7339ef2d8b0f607a2b1577a4c1c9859f043a6b5c31755557594682ab1115eb9e";
  expectedSelfTestBlake3 = "8e8e17fe7b81fe74afd69ff109199655aac438a0dc9ab580ff53a651cea9ae8d";
  expectedRunnerBlake3 = "58c01b487e5cd419ff6185290919a40db2e550071c83143f0a9d7eaf2c27eecf";
  expectedTransportHeaderBlake3 = "a30c2f099a06e48635d06ea5af55f71c7c43cf5cf985dcf9635d3640dfcd1f2f";
  expectedHostExecutableBlake3 = "68c327c40a776de2df98800b54e9efb6d45725ff8e5e362b955195a13d6efa47";
  expectedCoreExecutableBlake3 = "0f042500558aeda86ae0444b8673065d3774eac40e86cfdb228e03d412ac5fc0";
  expectedMetaliumExecutableBlake3 = "7706e92ff8125360a1470d1d14b6eff0a20f9f2b66988baa4a387e51a9fa9512";
  expectedDecodeReaderBlake3 = "221a9e9cb987902e99e4e50bfe5dce2d9f44a5252720b5d3dcbd13fbadb85fca";
  expectedDecodeComputeBlake3 = "bbda1f84aa2fcef7a946de76e0a0a03202e068c822f54b80c9cab5f4e13e35d0";
  expectedWriterBlake3 = "80ecf2f848144aa1a693f6b3b854542d2fd752bed8c83d9cbce31bd16e261b74";
  expectedPlanId = "7c1d1dbc06ba73e5d54f52f929f80aacac52084ad0610a3cce5da60b325df427";
  inspectorAddress = "127.0.0.1:43158";
in
runCommand "rwkv-ttwkv7-persistent-device-check"
  {
    nativeBuildInputs = [ b3sum ];
  }
  ''
    set -euo pipefail

    closure=${packageClosure}/store-paths
    test "$(wc -l <"$closure")" -eq ${toString expectedClosurePathCount}
    test "$(grep -Fxc ${lib.escapeShellArg expectedMetaliumPythonPath} "$closure")" -eq 1
    test "$(grep -Fc 'python' "$closure")" -eq 1
    if grep -Ei 'pytorch|torch-equation' "$closure"; then
      echo 'persistent device closure contains a forbidden framework dependency' >&2
      exit 1
    fi

    for path in ${
      lib.escapeShellArgs [
        wrapper
        planManifest
        planReceipt
        notRunReceipt
        runnerSource
        transportHeader
        hostExecutable
        coreExecutable
        metaliumExecutable
      ]
    }; do
      test -f "$path"
    done
    test -x ${lib.escapeShellArg wrapper}
    test -f ${lib.escapeShellArg "${evidenceRoot}/diagnostic.log"}
    test "$(b3sum ${lib.escapeShellArg planManifest} | cut -d' ' -f1)" = \
      ${lib.escapeShellArg expectedManifestBlake3}
    test "$(b3sum ${lib.escapeShellArg planReceipt} | cut -d' ' -f1)" = \
      ${lib.escapeShellArg expectedPlanReceiptBlake3}
    test "$(b3sum ${lib.escapeShellArg notRunReceipt} | cut -d' ' -f1)" = \
      ${lib.escapeShellArg expectedNotRunReceiptBlake3}
    test "$(b3sum ${lib.escapeShellArg wrapper} | cut -d' ' -f1)" = \
      ${lib.escapeShellArg expectedWrapperBlake3}
    test "$(b3sum ${lib.escapeShellArg runnerSource} | cut -d' ' -f1)" = \
      ${lib.escapeShellArg expectedRunnerBlake3}
    test "$(b3sum ${lib.escapeShellArg transportHeader} | cut -d' ' -f1)" = \
      ${lib.escapeShellArg expectedTransportHeaderBlake3}
    test "$(b3sum ${lib.escapeShellArg hostExecutable} | cut -d' ' -f1)" = \
      ${lib.escapeShellArg expectedHostExecutableBlake3}
    test "$(b3sum ${lib.escapeShellArg coreExecutable} | cut -d' ' -f1)" = \
      ${lib.escapeShellArg expectedCoreExecutableBlake3}
    test "$(b3sum ${lib.escapeShellArg metaliumExecutable} | cut -d' ' -f1)" = \
      ${lib.escapeShellArg expectedMetaliumExecutableBlake3}
    test "$(b3sum ${ttwkv7}/share/ttwkv7/kernels/wkv7_decodeL_reader.cpp | cut -d' ' -f1)" = \
      ${lib.escapeShellArg expectedDecodeReaderBlake3}
    test "$(b3sum ${ttwkv7}/share/ttwkv7/kernels/wkv7_decodeL_compute.cpp | cut -d' ' -f1)" = \
      ${lib.escapeShellArg expectedDecodeComputeBlake3}
    test "$(b3sum ${ttwkv7}/share/ttwkv7/kernels/wkv7_writer.cpp | cut -d' ' -f1)" = \
      ${lib.escapeShellArg expectedWriterBlake3}

    ${lib.escapeShellArg wrapper} self-test >self-test-first.log
    ${lib.escapeShellArg wrapper} self-test >self-test-second.log
    cmp self-test-first.log self-test-second.log
    test "$(b3sum self-test-first.log | cut -d' ' -f1)" = \
      ${lib.escapeShellArg expectedSelfTestBlake3}
    runtime_root="$PWD/runtime"
    TT_VISIBLE_DEVICES=1 \
      TT_METAL_CACHE="$runtime_root/cache" \
      TT_METAL_LOGS_PATH="$runtime_root/logs" \
      TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS=${lib.escapeShellArg inspectorAddress} \
      ${lib.escapeShellArg wrapper} validate-runtime >preflight.log
    grep -F 'rwkv persistent physical dispatch runtime state preflight: PASS' preflight.log
    test ! -e "$runtime_root/logs/rwkv-persistent-physical-dispatch"

    grep -F ${lib.escapeShellArg "\"plan_id\": \"${expectedPlanId}\""} ${lib.escapeShellArg planReceipt}
    grep -F '"session_id": "rwkv-ttwkv7-persistent-device-4"' ${lib.escapeShellArg planReceipt}
    grep -F '"run_root": "/var/tmp/rwkv-ttwkv7-persistent-device-4"' ${lib.escapeShellArg planReceipt}
    grep -F '"child_stdout"' ${lib.escapeShellArg planReceipt}
    grep -F '"max_processes": 1' ${lib.escapeShellArg planReceipt}
    grep -F '"timeout_seconds": 1800' ${lib.escapeShellArg planReceipt}
    grep -F '"rollback_delay_seconds": 2100' ${lib.escapeShellArg planReceipt}
    grep -F '"outcome": "not_run"' ${lib.escapeShellArg notRunReceipt}
    grep -F '"process_budget_exhausted": false' ${lib.escapeShellArg notRunReceipt}
    grep -F '"success_claim": null' ${lib.escapeShellArg notRunReceipt}

    grep -F '::prctl(PR_SET_PDEATHSIG, kParentDeathSignal)' ${lib.escapeShellArg runnerSource}
    grep -F '::getppid() != expected_parent' ${lib.escapeShellArg runnerSource}
    grep -F 'DispatchResponseChannel response_channel(dispatch_response_socket_path())' \
      ${lib.escapeShellArg runnerSource}
    grep -F 'response_channel.write_response(response);' ${lib.escapeShellArg runnerSource}

    mkdir -p "$out"
    cp self-test-first.log "$out/self-test.log"
    cp ${lib.escapeShellArg planReceipt} "$out/plan-receipt.json"
    cp ${lib.escapeShellArg notRunReceipt} "$out/not-run-receipt.json"
    printf '%s\n' \
      '{' \
      '  "closure_path_count": ${toString expectedClosurePathCount},' \
      '  "device_initialized": false,' \
      '  "hardware_process_started": false,' \
      '  "not_run_receipt_blake3": "${expectedNotRunReceiptBlake3}",' \
      '  "package_path": "${persistentDevice}",' \
      '  "plan_id": "${expectedPlanId}",' \
      '  "plan_receipt_blake3": "${expectedPlanReceiptBlake3}",' \
      '  "self_test_blake3": "${expectedSelfTestBlake3}",' \
      '  "target": "rwkv_ttwkv7_persistent_device_readiness"' \
      '}' \
      >"$out/receipt.json"
  ''
