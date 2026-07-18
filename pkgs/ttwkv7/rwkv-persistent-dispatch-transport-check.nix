{
  lib,
  runCommand,
  b3sum,
  rwkvLayerHarness,
  ttwkv7,
}:
let
  host = "${rwkvLayerHarness}/bin/rwkv-ttwkv7-persistent-physical-core";
  server = "${ttwkv7}/bin/wkv7";
  evidence = ../rwkv-layer-harness/fixtures/ttwkv7-device-2;
  runnerSource = "${ttwkv7}/share/ttwkv7/source/wkv7_runner.cpp";
  transportHeader = "${ttwkv7}/share/ttwkv7/source/ttwkv7-dispatch-transport.h";
  requestByteCount = 107588;
  responseByteCount = 99940;
  expectedRequestBlake3 = "90189e44d52b7835eae5bff0d8a993859b1fc04282b58880a4b9b322a740d247";
  expectedResponseBlake3 = "401dcccd689aacf994c51db5ff746f8ed863179cbea386047e2e9012e2652bd2";
in
runCommand "rwkv-ttwkv7-persistent-dispatch-transport-check"
  {
    nativeBuildInputs = [ b3sum ];
  }
  ''
    set -euo pipefail
    mkdir -p "$out"

    ${host} --emit-first-request ${evidence} >request.bin
    test "$(wc -c <request.bin)" -eq ${toString requestByteCount}
    test "$(b3sum request.bin | cut -d' ' -f1)" = \
      ${lib.escapeShellArg expectedRequestBlake3}

    ${server} dispatch-frame-self-test <request.bin >response-first.bin
    ${server} dispatch-frame-self-test <request.bin >response-second.bin
    cmp response-first.bin response-second.bin
    test "$(wc -c <response-first.bin)" -eq ${toString responseByteCount}
    test "$(b3sum response-first.bin | cut -d' ' -f1)" = \
      ${lib.escapeShellArg expectedResponseBlake3}
    ${host} --validate-response request.bin response-first.bin >validation.log
    grep -F 'persistent physical core response validation: PASS' validation.log

    self_test_first="$(${server} dispatch-server-self-test)"
    self_test_second="$(${server} dispatch-server-self-test)"
    test "$self_test_first" = "$self_test_second"
    test "$self_test_first" = 'persistent ttWKV7 dispatch server self-test: PASS'

    expect_failure() {
      expected_diagnostic="$1"
      output_path="$2"
      shift 2
      if "$@" >"$output_path" 2>&1; then
        echo "persistent dispatch transport mutation unexpectedly passed: $*" >&2
        exit 1
      fi
      grep -F "$expected_diagnostic" "$output_path"
    }

    cp request.bin changed-magic.bin
    chmod u+w changed-magic.bin
    printf 'X' | dd of=changed-magic.bin bs=1 seek=0 conv=notrunc status=none
    expect_failure 'dispatch request magic mismatch' changed-magic.log \
      ${server} dispatch-frame-self-test <changed-magic.bin

    head -c ${toString (requestByteCount - 1)} request.bin >truncated-request.bin
    expect_failure 'ended before a complete frame' truncated-request.log \
      ${server} dispatch-frame-self-test <truncated-request.bin

    cp request.bin trailing-request.bin
    printf 'x' >>trailing-request.bin
    expect_failure 'contains trailing data' trailing-request.log \
      ${server} dispatch-frame-self-test <trailing-request.bin

    cp response-first.bin changed-response.bin
    chmod u+w changed-response.bin
    printf 'X' | dd of=changed-response.bin bs=1 seek=0 conv=notrunc status=none
    expect_failure 'response magic mismatch' changed-response.log \
      ${host} --validate-response request.bin changed-response.bin

    head -c ${toString (responseByteCount - 1)} response-first.bin >truncated-response.bin
    expect_failure 'response post-state is truncated' truncated-response.log \
      ${host} --validate-response request.bin truncated-response.bin

    expect_failure 'dispatch-frame-self-test does not accept additional arguments' \
      frame-suffix.log ${server} dispatch-frame-self-test unexpected
    expect_failure 'dispatch-server-self-test does not accept additional arguments' \
      self-test-suffix.log ${server} dispatch-server-self-test unexpected

    test -f ${transportHeader}
    grep -F 'class DispatchSessionCore' ${transportHeader}
    grep -F 'kExpectedCallCount = kLayerCount * kTokenCount' ${transportHeader}
    grep -F 'dispatch same-layer physical state continuity mismatch' ${transportHeader}
    grep -F 'dispatch session contains duplicate frames' ${transportHeader}
    if grep -E 'MeshDevice|EnqueueMeshWorkload|std::filesystem|getenv|fread|fwrite|Command::new' \
      ${transportHeader}; then
      echo 'persistent dispatch frame core contains an imperative surface' >&2
      exit 1
    fi

    grep -F 'int run_dispatch_server()' ${runnerSource}
    grep -F 'auto device = distributed::MeshDevice::create_unit_mesh(0);' ${runnerSource}
    test "$(grep -Fc 'auto device = distributed::MeshDevice::create_unit_mesh(0);' \
      ${runnerSource})" -eq 2
    grep -F 'call < ttwkv7::dispatch_transport::kExpectedCallCount' ${runnerSource}
    grep -F 'session.record_response(request, request_bytes, payload)' ${runnerSource}
    grep -F 'const int trailing = std::fgetc(stdin);' ${runnerSource}
    grep -F 'write_text(summary_path, receipt.dump() + "\n")' ${runnerSource}
    if grep -E 'retry|reconnect|backoff' ${runnerSource}; then
      echo 'persistent dispatch server contains a retry or reconnect surface' >&2
      exit 1
    fi

    request_blake3="$(b3sum request.bin | cut -d' ' -f1)"
    response_blake3="$(b3sum response-first.bin | cut -d' ' -f1)"
    cat >"$out/receipt.json" <<EOF
    {"device_initialized":false,"request_blake3":"$request_blake3","request_bytes":${toString requestByteCount},"response_blake3":"$response_blake3","response_bytes":${toString responseByteCount},"self_test_passed":true,"target":"rwkv_ttwkv7_persistent_dispatch_transport"}
    EOF
  ''
