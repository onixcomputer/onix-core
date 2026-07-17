{
  lib,
  runCommand,
  b3sum,
  rwkvLayerHarness,
  ttwkv7,
}:
let
  validator = "${ttwkv7}/libexec/ttwkv7/wkv7-rwkv-host-layout-validator";
  fixture = "${rwkvLayerHarness}/share/rwkv-layer-harness/ttwkv7-boundary.json";
  runnerSource = "${ttwkv7}/share/ttwkv7/source/wkv7_runner.cpp";
  validatorSource = "${ttwkv7}/share/ttwkv7/source/rwkv-host-layout-validator.cpp";
  hostLayoutHeader = "${ttwkv7}/share/ttwkv7/source/ttwkv7-host-layout.h";
  expectedFixtureByteCount = 420072;
  expectedReceiptByteCount = 1783;
  expectedFixtureBlake3 = "731f44866c869300ca330f703f1adad4c3ae7ee62b832fa881a6bf4ea90211cd";
  expectedOrderedArtifactBlake3 = "44d91ad223079fa9ae5f6f0dc9943fc6d13cc25cb09262111ad433c7e6288494";
  expectedInputUploadBlake3 = [
    "12038a499897e2a403b179f31a54e7201ffdf6f80402c91d24e0b4c86e5ed849"
    "3e00c954d55ad0f5ab0f9f8b869d81dcb19c5bc572e9637ef6836fc76f8264cc"
    "8ef11709d3f136a17ca7f5a3cf2fb91b52424eeda51d28797be429a12e5f8fa7"
    "e9bea640d3c09a80143dc04be45e77935e7639e1e0f064c0009b8cbfdaba154c"
    "9e64a0be9c6b753dae7ab5300f2fff33a660ef025be6e5893f13f56eaceec534"
    "c7a95d4671b51545417c5bcb930321325d1bfe431746879971bd2335500b6858"
  ];
  expectedStateUploadBlake3 = "a2966fb56eb97345c35c7710f222eac752d7d2f8f84eb0bf2a8e11e85ae466f7";
  expectedWriterBlake3 = "a4e8062724fae1002b2d7c812725caf1268466813743f3097efdc7ad25254e21";
  expectedCombinedLayoutBlake3 = "caee8424524e33f54c85145a248794d4776713a78d2bbb6dbd5f03401a4835d6";
  expectedReceiptBlake3 = "777d156d5b3ab459cd622d0cd99f62cd31c918be9ebc25292aeea7d254b0059e";
  validationFailureStatus = 1;
  invalidArgumentStatus = 2;
  truncatedFixtureByteCount = expectedFixtureByteCount - 1;
  expectedRunnerNativeInputCallCount = 1;
  expectedRunnerStateUploadCallCount = 2;
  expectedRunnerWriterLayoutCallCount = 2;
  expectedRunnerWriterIndexCallCount = 3;
in
# r[verify onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_host_layout]
runCommand "rwkv-ttwkv7-host-layout-check"
  {
    nativeBuildInputs = [ b3sum ];
  }
  ''
    set -euo pipefail

    test -x ${lib.escapeShellArg validator}
    test -f ${lib.escapeShellArg fixture}
    test -f ${lib.escapeShellArg runnerSource}
    test -f ${lib.escapeShellArg validatorSource}
    test -f ${lib.escapeShellArg hostLayoutHeader}
    test "$(wc -c < ${lib.escapeShellArg fixture})" -eq ${toString expectedFixtureByteCount}
    test "$(b3sum ${lib.escapeShellArg fixture} | cut -d' ' -f1)" = \
      ${lib.escapeShellArg expectedFixtureBlake3}

    fixture_root="$(mktemp -d)"
    first_receipt="$fixture_root/first-receipt.json"
    second_receipt="$fixture_root/second-receipt.json"
    ${lib.escapeShellArg validator} ${lib.escapeShellArg fixture} >"$first_receipt"
    ${lib.escapeShellArg validator} ${lib.escapeShellArg fixture} >"$second_receipt"
    cmp "$first_receipt" "$second_receipt"
    test "$(wc -c < "$first_receipt")" -eq ${toString expectedReceiptByteCount}
    test "$(b3sum "$first_receipt" | cut -d' ' -f1)" = \
      ${lib.escapeShellArg expectedReceiptBlake3}
    grep -Fq ${lib.escapeShellArg "\"fixture_blake3\":\"${expectedFixtureBlake3}\""} "$first_receipt"
    grep -Fq ${lib.escapeShellArg "\"fixture_ordered_artifact_blake3\":\"${expectedOrderedArtifactBlake3}\""} "$first_receipt"
    grep -Fq ${lib.escapeShellArg "\"state_upload_blake3\":\"${expectedStateUploadBlake3}\""} "$first_receipt"
    grep -Fq ${lib.escapeShellArg "\"writer_tiled_blake3\":\"${expectedWriterBlake3}\""} "$first_receipt"
    grep -Fq ${lib.escapeShellArg "\"combined_layout_blake3\":\"${expectedCombinedLayoutBlake3}\""} "$first_receipt"
    grep -Fq ${lib.escapeShellArg "\"tile_counts\":{\"input_uploads\":12,\"state_upload\":1536,\"writer\":72}"} "$first_receipt"
    grep -Fq ${lib.escapeShellArg "\"device_initialized\":false"} "$first_receipt"
    grep -Fq ${lib.escapeShellArg "No ttWKV7 recurrence or compute-kernel execution is established."} "$first_receipt"
    for expected_hash in ${lib.escapeShellArgs expectedInputUploadBlake3}; do
      grep -Fq "\"$expected_hash\"" "$first_receipt"
    done

    mutable_copy() {
      local name="$1"
      local destination="$fixture_root/$name.json"
      cp ${lib.escapeShellArg fixture} "$destination"
      chmod u+w "$destination"
      printf '%s\n' "$destination"
    }

    expect_fixture_rejected() {
      local name="$1"
      local expected_diagnostic="$2"
      local candidate="$3"
      local log="$fixture_root/$name.log"
      if ${lib.escapeShellArg validator} "$candidate" >"$log" 2>&1; then
        echo "host-layout validator accepted negative fixture: $name" >&2
        exit 1
      else
        local status="$?"
      fi
      test "$status" -eq ${toString validationFailureStatus}
      grep -Fq "$expected_diagnostic" "$log"
    }

    changed_target="$(mutable_copy changed-target)"
    substituteInPlace "$changed_target" \
      --replace-fail '"target":"ttwkv7_logical_wkv_boundary"' \
      '"target":"xtwkv7_logical_wkv_boundary"'
    expect_fixture_rejected changed-target 'target authority mismatch' "$changed_target"

    changed_order="$(mutable_copy changed-order)"
    substituteInPlace "$changed_order" \
      --replace-fail '"input_order":["a","w","k","v","r","b"]' \
      '"input_order":["w","a","k","v","r","b"]'
    expect_fixture_rejected changed-order 'fixture prefix or input order mismatch' "$changed_order"

    changed_orientation="$(mutable_copy changed-orientation)"
    substituteInPlace "$changed_orientation" \
      --replace-fail '"state_order":"head_row_column"' \
      '"state_order":"row_head_column"'
    expect_fixture_rejected changed-orientation 'state_order authority mismatch' "$changed_orientation"

    changed_shape="$(mutable_copy changed-shape)"
    substituteInPlace "$changed_shape" \
      --replace-fail '"logical_shape":[12,64]' \
      '"logical_shape":[64,12]'
    expect_fixture_rejected changed-shape 'unexpected logical shape' "$changed_shape"

    changed_name="$(mutable_copy changed-name)"
    substituteInPlace "$changed_name" \
      --replace-fail '"name":"a"' '"name":"x"'
    expect_fixture_rejected changed-name 'artifact order expected a, found x' "$changed_name"

    changed_count="$(mutable_copy changed-count)"
    substituteInPlace "$changed_count" \
      --replace-fail '"element_count":768' '"element_count":769'
    expect_fixture_rejected changed-count 'inconsistent element or byte count' "$changed_count"

    changed_byte="$(mutable_copy changed-byte)"
    substituteInPlace "$changed_byte" \
      --replace-fail '"bytes_hex":"b33c2dbc' '"bytes_hex":"b23c2dbc'
    expect_fixture_rejected changed-byte 'a BLAKE3 mismatch' "$changed_byte"

    uppercase_hex="$(mutable_copy uppercase-hex)"
    substituteInPlace "$uppercase_hex" \
      --replace-fail '"bytes_hex":"b33c2dbc' '"bytes_hex":"B33c2dbc'
    expect_fixture_rejected uppercase-hex 'bytes must be lowercase hexadecimal' "$uppercase_hex"

    changed_ordered_hash="$(mutable_copy changed-ordered-hash)"
    substituteInPlace "$changed_ordered_hash" \
      --replace-fail ${lib.escapeShellArg expectedOrderedArtifactBlake3} \
      ${lib.escapeShellArg "54d91ad223079fa9ae5f6f0dc9943fc6d13cc25cb09262111ad433c7e6288494"}
    expect_fixture_rejected changed-ordered-hash 'ordered fixture artifact BLAKE3 mismatch' "$changed_ordered_hash"

    malformed_json="$(mutable_copy malformed-json)"
    substituteInPlace "$malformed_json" \
      --replace-fail '{"schema_version"' '["schema_version"'
    expect_fixture_rejected malformed-json 'host-layout validation failed:' "$malformed_json"

    truncated="$(mutable_copy truncated)"
    truncate -s ${toString truncatedFixtureByteCount} "$truncated"
    expect_fixture_rejected truncated 'fixture byte count does not match the authority' "$truncated"

    duplicated="$(mutable_copy duplicated)"
    printf 'x' >>"$duplicated"
    expect_fixture_rejected duplicated 'fixture byte count does not match the authority' "$duplicated"

    unreadable="$(mutable_copy unreadable)"
    chmod 000 "$unreadable"
    expect_fixture_rejected unreadable 'fixture file could not be opened' "$unreadable"

    expect_fixture_rejected directory-path 'fixture path must be a readable regular file' "$fixture_root"

    missing_argument_log="$fixture_root/missing-argument.log"
    if ${lib.escapeShellArg validator} >"$missing_argument_log" 2>&1; then
      echo "host-layout validator accepted a missing fixture argument" >&2
      exit 1
    else
      missing_argument_status="$?"
    fi
    test "$missing_argument_status" -eq ${toString invalidArgumentStatus}
    grep -Fq 'usage:' "$missing_argument_log"

    suffix_log="$fixture_root/suffix.log"
    if ${lib.escapeShellArg validator} ${lib.escapeShellArg fixture} unexpected-suffix \
      >"$suffix_log" 2>&1; then
      echo "host-layout validator accepted an argument suffix" >&2
      exit 1
    else
      suffix_status="$?"
    fi
    test "$suffix_status" -eq ${toString invalidArgumentStatus}
    grep -Fq 'usage:' "$suffix_log"

    test "$(grep -Fc '#include "ttwkv7-host-layout.h"' ${lib.escapeShellArg runnerSource})" -eq 1
    test "$(grep -Fc 'ttwkv7::host_layout::build_native_input(' ${lib.escapeShellArg runnerSource})" -eq \
      ${toString expectedRunnerNativeInputCallCount}
    test "$(grep -Fc 'ttwkv7::host_layout::build_state_upload_matrix(' ${lib.escapeShellArg runnerSource})" -eq \
      ${toString expectedRunnerStateUploadCallCount}
    test "$(grep -Fc 'ttwkv7::host_layout::derive_writer_layout(' ${lib.escapeShellArg runnerSource})" -eq \
      ${toString expectedRunnerWriterLayoutCallCount}
    grep -Fq 'writer_layout->padded_rows / TH' ${lib.escapeShellArg runnerSource}
    test "$(grep -Fc 'ttwkv7::host_layout::writer_output_index(' ${lib.escapeShellArg runnerSource})" -eq \
      ${toString expectedRunnerWriterIndexCallCount}
    test "$(grep -Fc 'ttwkv7::host_layout::writer_state_index(' ${lib.escapeShellArg runnerSource})" -eq \
      ${toString expectedRunnerWriterIndexCallCount}
    if grep -F 'std::vector<float> mat((uint64_t)Gpad * cols' ${lib.escapeShellArg runnerSource}; then
      echo "production runner retained a duplicate state-upload formula" >&2
      exit 1
    fi
    if grep -F '(T + S * G + 31) / 32' ${lib.escapeShellArg runnerSource}; then
      echo "production runner retained a duplicate writer-row formula" >&2
      exit 1
    fi
    for forbidden in \
      '<filesystem>' '<fstream>' 'std::filesystem' 'std::getenv' \
      'std::process' 'std::chrono' 'printf(' 'fprintf(' 'MeshDevice' 'CreateKernel('; do
      if grep -F "$forbidden" ${lib.escapeShellArg hostLayoutHeader}; then
        echo "shared host-layout core contains forbidden side-effect surface: $forbidden" >&2
        exit 1
      fi
    done
    for forbidden in 'mesh_device.hpp' 'MeshDevice' 'CreateKernel(' 'EnqueueMeshWorkload' \
      'EnqueueWriteMeshBuffer' 'EnqueueReadMeshBuffer'; do
      if grep -F "$forbidden" ${lib.escapeShellArg validatorSource}; then
        echo "host-layout validator contains a device execution surface: $forbidden" >&2
        exit 1
      fi
    done

    mkdir -p "$out"
    cp "$first_receipt" "$out/receipt.json"
  ''
