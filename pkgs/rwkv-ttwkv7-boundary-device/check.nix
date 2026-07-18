{
  lib,
  runCommand,
  closureInfo,
  b3sum,
  nickel,
  boundaryDevice,
  ttwkv7,
}:
let
  ordinaryClosure = closureInfo { rootPaths = [ ttwkv7 ]; };
  boundaryClosure = closureInfo { rootPaths = [ boundaryDevice ]; };
  ordinaryClosurePathCount = 68;
  boundaryClosurePathCount = 118;
  expectedMetaliumPythonPath = "/nix/store/l9k0anq0z7zz81zcwy035jfwap9ga6rl-python3-3.13.13";
  fixturePath = "${boundaryDevice}/share/rwkv-ttwkv7-boundary-device/ttwkv7-boundary.json";
  wrapper = "${boundaryDevice}/bin/wkv7-rwkv-boundary";
  planReceipt = "${boundaryDevice}/share/rwkv-ttwkv7-boundary-device/session/plan-receipt.json";
  notRunReceipt = "${boundaryDevice}/share/rwkv-ttwkv7-boundary-device/session/not-run-receipt.json";
  preflightReceiptSource = ./preflight-attempt-1.ncl;
  expectedFixtureByteCount = 420072;
  expectedFixtureBlake3 = "731f44866c869300ca330f703f1adad4c3ae7ee62b832fa881a6bf4ea90211cd";
  expectedSelfTestBlake3 = "c1b6b14a04acb3aca238a2ae77854a22701d70da1ffcc2e9efee9f852048d6e8";
  expectedPlanReceiptBlake3 = "2ec6e28974a96bd13c716b5c4adcbbff78d9fca1c3bed6cd7009111098d3c191";
  expectedNotRunReceiptBlake3 = "1d5e7d25fbb58d2ff685e542abca6c4b7ea55c9bcfd4a10be0664e9d7ef8eab1";
  expectedPreflightReceiptBlake3 = "ff37d0a0f54d9c99c373d2815613acb9d02f1c6d230146755e2f6cbe34ec5e69";
  expectedRunnerBlake3 = "29ecf61ab7333b4fabcf3ea2d13855bd0280a6dad5d695d749c2a1f3430dc370";
  expectedBoundaryCoreBlake3 = "e644934c561be74c852e6e223f8a25e2564e1cdeda165c2a7570efa378de8b20";
  expectedDecodeReaderBlake3 = "221a9e9cb987902e99e4e50bfe5dce2d9f44a5252720b5d3dcbd13fbadb85fca";
  expectedDecodeComputeBlake3 = "bbda1f84aa2fcef7a946de76e0a0a03202e068c822f54b80c9cab5f4e13e35d0";
  expectedWriterBlake3 = "80ecf2f848144aa1a693f6b3b854542d2fd752bed8c83d9cbce31bd16e261b74";
  runnerSource = "${ttwkv7}/share/ttwkv7/source/wkv7_runner.cpp";
  boundaryCore = "${ttwkv7}/share/ttwkv7/source/ttwkv7-boundary-device.h";
  decodeReader = "${ttwkv7}/share/ttwkv7/kernels/wkv7_decodeL_reader.cpp";
  decodeCompute = "${ttwkv7}/share/ttwkv7/kernels/wkv7_decodeL_compute.cpp";
  writer = "${ttwkv7}/share/ttwkv7/kernels/wkv7_writer.cpp";
  forbiddenClosurePatterns = "rwkv-layer-harness|goose-world|safetensor|pytorch|torch-equation";
  noDeviceReceiptField = "\"device_initialized\":false";
  zeroEnqueueReceiptField = "\"workload_enqueue_count\":0";
in
# r[verify onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_boundary_device_harness]
runCommand "rwkv-ttwkv7-boundary-device-check"
  {
    nativeBuildInputs = [
      b3sum
      nickel
    ];
  }
  ''
    set -euo pipefail

    ordinary_closure=${ordinaryClosure}/store-paths
    boundary_closure=${boundaryClosure}/store-paths
    test "$(wc -l <"$ordinary_closure")" -eq ${toString ordinaryClosurePathCount}
    test "$(wc -l <"$boundary_closure")" -eq ${toString boundaryClosurePathCount}
    test "$(grep -Fxc ${lib.escapeShellArg expectedMetaliumPythonPath} "$ordinary_closure")" -eq 1
    test "$(grep -Fc 'python' "$ordinary_closure")" -eq 1
    test "$(grep -Fxc ${lib.escapeShellArg expectedMetaliumPythonPath} "$boundary_closure")" -eq 1
    test "$(grep -Fc 'python' "$boundary_closure")" -eq 1
    if grep -Ei ${lib.escapeShellArg forbiddenClosurePatterns} "$ordinary_closure"; then
      echo "ordinary ttWKV7 closure contains a forbidden RWKV boundary dependency" >&2
      exit 1
    fi
    if grep -Ei ${lib.escapeShellArg forbiddenClosurePatterns} "$boundary_closure"; then
      echo "boundary harness closure retained a build-time checkpoint or layer harness" >&2
      exit 1
    fi

    test -x ${lib.escapeShellArg wrapper}
    test -f ${lib.escapeShellArg fixturePath}
    test -f ${lib.escapeShellArg planReceipt}
    test -f ${lib.escapeShellArg notRunReceipt}
    test "$(wc -c <${lib.escapeShellArg fixturePath})" -eq ${toString expectedFixtureByteCount}
    test "$(b3sum ${lib.escapeShellArg fixturePath} | cut -d' ' -f1)" = \
      ${lib.escapeShellArg expectedFixtureBlake3}
    test "$(b3sum ${lib.escapeShellArg runnerSource} | cut -d' ' -f1)" = \
      ${lib.escapeShellArg expectedRunnerBlake3}
    test "$(b3sum ${lib.escapeShellArg boundaryCore} | cut -d' ' -f1)" = \
      ${lib.escapeShellArg expectedBoundaryCoreBlake3}
    test "$(b3sum ${lib.escapeShellArg decodeReader} | cut -d' ' -f1)" = \
      ${lib.escapeShellArg expectedDecodeReaderBlake3}
    test "$(b3sum ${lib.escapeShellArg decodeCompute} | cut -d' ' -f1)" = \
      ${lib.escapeShellArg expectedDecodeComputeBlake3}
    test "$(b3sum ${lib.escapeShellArg writer} | cut -d' ' -f1)" = \
      ${lib.escapeShellArg expectedWriterBlake3}
    test "$(b3sum ${lib.escapeShellArg planReceipt} | cut -d' ' -f1)" = \
      ${lib.escapeShellArg expectedPlanReceiptBlake3}
    test "$(b3sum ${lib.escapeShellArg notRunReceipt} | cut -d' ' -f1)" = \
      ${lib.escapeShellArg expectedNotRunReceiptBlake3}

    nickel export --format json ${preflightReceiptSource} >preflight-attempt-1.json
    test "$(b3sum preflight-attempt-1.json | cut -d' ' -f1)" = \
      ${lib.escapeShellArg expectedPreflightReceiptBlake3}
    grep -F '"outcome": "not_run"' preflight-attempt-1.json
    grep -F '"process_attempts": 0' preflight-attempt-1.json
    grep -F '"owner_isolation_attempts": 0' preflight-attempt-1.json
    grep -F '"device_path_metadata_checked": true' preflight-attempt-1.json
    grep -F '"board_queried": false' preflight-attempt-1.json
    grep -F '"device_opened": false' preflight-attempt-1.json
    grep -F '"metalium_initialized": false' preflight-attempt-1.json
    grep -F '"kernel_executed": false' preflight-attempt-1.json
    grep -F '"device_process_started": false' preflight-attempt-1.json
    grep -F ${lib.escapeShellArg "\"observed_fingerprint\": \"SHA256:DOOddCNRRRqCVbueQZovbR8Q//NwYeeMCaznz+GqxQE\""} \
      preflight-attempt-1.json

    ${lib.escapeShellArg wrapper} self-test >self-test.json
    test "$(b3sum self-test.json | cut -d' ' -f1)" = \
      ${lib.escapeShellArg expectedSelfTestBlake3}
    test "$(grep -Fc ${lib.escapeShellArg noDeviceReceiptField} self-test.json)" -eq 1
    test "$(grep -Fc ${lib.escapeShellArg zeroEnqueueReceiptField} self-test.json)" -eq 1
    self_test_blake3="$(b3sum self-test.json | cut -d' ' -f1)"
    plan_receipt_blake3="$(b3sum ${lib.escapeShellArg planReceipt} | cut -d' ' -f1)"
    not_run_receipt_blake3="$(b3sum ${lib.escapeShellArg notRunReceipt} | cut -d' ' -f1)"

    mkdir -p "$out"
    cp self-test.json "$out/self-test.json"
    cp ${lib.escapeShellArg planReceipt} "$out/plan-receipt.json"
    cp ${lib.escapeShellArg notRunReceipt} "$out/not-run-receipt.json"
    cp preflight-attempt-1.json "$out/preflight-attempt-1.json"
    printf '%s\n' \
      "{" \
      "  \"boundary_closure_path_count\": ${toString boundaryClosurePathCount}," \
      "  \"device_initialized\": false," \
      "  \"fixture_blake3\": \"${expectedFixtureBlake3}\"," \
      "  \"not_run_receipt_blake3\": \"$not_run_receipt_blake3\"," \
      "  \"ordinary_closure_path_count\": ${toString ordinaryClosurePathCount}," \
      "  \"preflight_attempt_1_blake3\": \"${expectedPreflightReceiptBlake3}\"," \
      "  \"plan_receipt_blake3\": \"$plan_receipt_blake3\"," \
      "  \"self_test_blake3\": \"$self_test_blake3\"," \
      "  \"target\": \"rwkv_ttwkv7_boundary_device_readiness\"" \
      "}" \
      >"$out/receipt.json"
  ''
