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
  expectedManifestBlake3 = "b39ce7ff9ee4d52cd3d574c4cb91550f27a6e6558175fd6b338ab0473f5aa809";
  expectedPlanReceiptBlake3 = "aac7aabc0d1d1fe1ab7c26c1864889307913e4b45237b325522239562bb86ebb";
  expectedNotRunReceiptBlake3 = "86ac1e63a4ec96ff3cd02c4592192a5b682ac1c51c4d1c6b2f919ec8cc090ce5";
  expectedWrapperBlake3 = "64376bd99c31aa1106b06372bf8433e68bc91df90c5cd4cc8128e9cf9e4d611a";
  expectedSelfTestBlake3 = "8e8e17fe7b81fe74afd69ff109199655aac438a0dc9ab580ff53a651cea9ae8d";
  expectedRunnerBlake3 = "f5272a3fdc24249979e6033b23deb5d0a0e415b8e11aa60b595cf8430345f0ce";
  expectedTransportHeaderBlake3 = "a30c2f099a06e48635d06ea5af55f71c7c43cf5cf985dcf9635d3640dfcd1f2f";
  expectedHostExecutableBlake3 = "dd3641da315320a2e6d9d05f41bf0fb53b22053bc5d5dec8122a97ef9969eeb7";
  expectedCoreExecutableBlake3 = "0f042500558aeda86ae0444b8673065d3774eac40e86cfdb228e03d412ac5fc0";
  expectedDecodeReaderBlake3 = "221a9e9cb987902e99e4e50bfe5dce2d9f44a5252720b5d3dcbd13fbadb85fca";
  expectedDecodeComputeBlake3 = "bbda1f84aa2fcef7a946de76e0a0a03202e068c822f54b80c9cab5f4e13e35d0";
  expectedWriterBlake3 = "80ecf2f848144aa1a693f6b3b854542d2fd752bed8c83d9cbce31bd16e261b74";
  expectedPlanId = "9736c1b59a87d0af30a4b34087cdc56446cce69f6236accf6011b8eb5f165bf4";
  inspectorAddress = "127.0.0.1:43157";
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
    grep -F '"session_id": "rwkv-ttwkv7-persistent-device-3"' ${lib.escapeShellArg planReceipt}
    grep -F '"run_root": "/var/tmp/rwkv-ttwkv7-persistent-device-3"' ${lib.escapeShellArg planReceipt}
    grep -F '"max_processes": 1' ${lib.escapeShellArg planReceipt}
    grep -F '"timeout_seconds": 1800' ${lib.escapeShellArg planReceipt}
    grep -F '"rollback_delay_seconds": 2100' ${lib.escapeShellArg planReceipt}
    grep -F '"outcome": "not_run"' ${lib.escapeShellArg notRunReceipt}
    grep -F '"process_budget_exhausted": false' ${lib.escapeShellArg notRunReceipt}
    grep -F '"success_claim": null' ${lib.escapeShellArg notRunReceipt}

    grep -F '::prctl(PR_SET_PDEATHSIG, kParentDeathSignal)' ${lib.escapeShellArg runnerSource}
    grep -F '::getppid() != expected_parent' ${lib.escapeShellArg runnerSource}

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
