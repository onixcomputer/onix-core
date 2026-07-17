{
  lib,
  runCommand,
  b3sum,
  rwkvLayerHarness,
  ttwkv7,
}:
let
  validator = "${ttwkv7}/libexec/ttwkv7/wkv7-rwkv-decode-reader-validator";
  fixture = "${rwkvLayerHarness}/share/rwkv-layer-harness/ttwkv7-boundary.json";
  runnerSource = "${ttwkv7}/share/ttwkv7/source/wkv7_runner.cpp";
  validatorSource = "${ttwkv7}/share/ttwkv7/source/rwkv-decode-reader-validator.cpp";
  decodeAbiHeader = "${ttwkv7}/share/ttwkv7/source/ttwkv7-decode-abi.h";
  decodeReaderSource = "${ttwkv7}/share/ttwkv7/kernels/wkv7_decodeL_reader.cpp";
  decodeComputeSource = "${ttwkv7}/share/ttwkv7/kernels/wkv7_decodeL_compute.cpp";
  writerSource = "${ttwkv7}/share/ttwkv7/kernels/wkv7_writer.cpp";
  expectedFixtureByteCount = 420072;
  expectedReceiptByteCount = 2716;
  expectedFixtureBlake3 = "731f44866c869300ca330f703f1adad4c3ae7ee62b832fa881a6bf4ea90211cd";
  expectedReceiptBlake3 = "1b5a682b68999e9160f832920c1952218496afb5452456277ce48eb551b0f902";
  expectedStateUploadBlake3 = "a2966fb56eb97345c35c7710f222eac752d7d2f8f84eb0bf2a8e11e85ae466f7";
  expectedReaderArgumentsBlake3 = "e1eb29d5f7771c31453b84dfc8976d2655fa3a22d9c4162b187692204a18d17b";
  expectedComputeArgumentsBlake3 = "d40aade7cd0925462819a1a219de53ca415495ba184569db139b9be019056ae8";
  expectedWriterArgumentsBlake3 = "387b7f3c5b39372ff8ff97e1decb786f0981e55497ed8a5e3b1e49494ca65ecd";
  expectedSourceTraceBlake3 = "dcc74e1be512087c818aaed55c3a4847e5c366a0973ee85ab7ba998199fd7101";
  expectedStatePayloadBlake3 = "ab70bffef8633ac1740b71e0f09610d61fd20161458d9a65e0d4cb57892f12b5";
  expectedInputPayloadBlake3 = "e21a26e0ad74e9f1a9e8a18c7cc22c2376d92548f17d961d8ff7309e12547122";
  expectedCombinedBlake3 = "ced0aac7159bfe1d7416796d7ca205353384900120c9b4916ae4e8ca210ccad1";
  expectedReaderArguments = ''"reader":[12,1,2,1,1,4096,8192,12288,16384,20480,24576,28672,1,0,0,1,0,12]'';
  expectedComputeArguments = ''"compute":[2,12,1,1,1,0,12,4]'';
  expectedWriterArguments = ''"writer":[32768,0,12,12,1,12,2,24,1,1,1,1]'';
  expectedDecodeReaderSourceBlake3 = "221a9e9cb987902e99e4e50bfe5dce2d9f44a5252720b5d3dcbd13fbadb85fca";
  expectedDecodeComputeSourceBlake3 = "bbda1f84aa2fcef7a946de76e0a0a03202e068c822f54b80c9cab5f4e13e35d0";
  expectedWriterSourceBlake3 = "80ecf2f848144aa1a693f6b3b854542d2fd752bed8c83d9cbce31bd16e261b74";
  expectedStateSourcePages = 1536;
  expectedInputPageRows = 144;
  expectedFaceReads = 3360;
  expectedPairedRowGathers = 1680;
  expectedStateValues = 49152;
  expectedInputValues = 4608;
  validationFailureStatus = 1;
  invalidArgumentStatus = 2;
  truncatedFixtureByteCount = expectedFixtureByteCount - 1;
in
# r[verify onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_decode_reader_abi]
runCommand "rwkv-ttwkv7-decode-reader-check"
  {
    nativeBuildInputs = [ b3sum ];
  }
  ''
    set -euo pipefail

    for required in \
      ${lib.escapeShellArg validator} \
      ${lib.escapeShellArg fixture} \
      ${lib.escapeShellArg runnerSource} \
      ${lib.escapeShellArg validatorSource} \
      ${lib.escapeShellArg decodeAbiHeader} \
      ${lib.escapeShellArg decodeReaderSource} \
      ${lib.escapeShellArg decodeComputeSource} \
      ${lib.escapeShellArg writerSource}; do
      test -e "$required"
    done
    test -x ${lib.escapeShellArg validator}
    test "$(wc -c < ${lib.escapeShellArg fixture})" -eq ${toString expectedFixtureByteCount}
    test "$(b3sum ${lib.escapeShellArg fixture} | cut -d' ' -f1)" = \
      ${lib.escapeShellArg expectedFixtureBlake3}
    test "$(b3sum ${lib.escapeShellArg decodeReaderSource} | cut -d' ' -f1)" = \
      ${lib.escapeShellArg expectedDecodeReaderSourceBlake3}
    test "$(b3sum ${lib.escapeShellArg decodeComputeSource} | cut -d' ' -f1)" = \
      ${lib.escapeShellArg expectedDecodeComputeSourceBlake3}
    test "$(b3sum ${lib.escapeShellArg writerSource} | cut -d' ' -f1)" = \
      ${lib.escapeShellArg expectedWriterSourceBlake3}

    fixture_root="$(mktemp -d)"
    first_receipt="$fixture_root/first-receipt.json"
    second_receipt="$fixture_root/second-receipt.json"
    ${lib.escapeShellArg validator} ${lib.escapeShellArg fixture} >"$first_receipt"
    ${lib.escapeShellArg validator} ${lib.escapeShellArg fixture} >"$second_receipt"
    cmp "$first_receipt" "$second_receipt"
    test "$(wc -c < "$first_receipt")" -eq ${toString expectedReceiptByteCount}
    test "$(b3sum "$first_receipt" | cut -d' ' -f1)" = \
      ${lib.escapeShellArg expectedReceiptBlake3}

    for expected in \
      ${lib.escapeShellArg expectedFixtureBlake3} \
      ${lib.escapeShellArg expectedStateUploadBlake3} \
      ${lib.escapeShellArg expectedReaderArgumentsBlake3} \
      ${lib.escapeShellArg expectedComputeArgumentsBlake3} \
      ${lib.escapeShellArg expectedWriterArgumentsBlake3} \
      ${lib.escapeShellArg expectedSourceTraceBlake3} \
      ${lib.escapeShellArg expectedStatePayloadBlake3} \
      ${lib.escapeShellArg expectedInputPayloadBlake3} \
      ${lib.escapeShellArg expectedCombinedBlake3} \
      ${lib.escapeShellArg expectedDecodeReaderSourceBlake3} \
      ${lib.escapeShellArg expectedDecodeComputeSourceBlake3} \
      ${lib.escapeShellArg expectedWriterSourceBlake3}; do
      grep -Fq "$expected" "$first_receipt"
    done
    grep -Fq ${lib.escapeShellArg expectedReaderArguments} "$first_receipt"
    grep -Fq ${lib.escapeShellArg expectedComputeArguments} "$first_receipt"
    grep -Fq ${lib.escapeShellArg expectedWriterArguments} "$first_receipt"
    grep -Fq ${lib.escapeShellArg "\"state_source_pages\":${toString expectedStateSourcePages}"} "$first_receipt"
    grep -Fq ${lib.escapeShellArg "\"input_page_row_selections\":${toString expectedInputPageRows}"} "$first_receipt"
    grep -Fq ${lib.escapeShellArg "\"face_reads\":${toString expectedFaceReads}"} "$first_receipt"
    grep -Fq ${lib.escapeShellArg "\"paired_row_gathers\":${toString expectedPairedRowGathers}"} "$first_receipt"
    grep -Fq ${lib.escapeShellArg "\"state_values\":${toString expectedStateValues}"} "$first_receipt"
    grep -Fq ${lib.escapeShellArg "\"input_values\":${toString expectedInputValues}"} "$first_receipt"
    grep -Fq ${lib.escapeShellArg "\"unwritten_input_rows_included\":false"} "$first_receipt"
    grep -Fq ${lib.escapeShellArg "\"device_initialized\":false"} "$first_receipt"
    grep -Fq 'No unwritten decode input-tile row is assigned a value.' "$first_receipt"

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
        echo "decode-reader validator accepted negative fixture: $name" >&2
        exit 1
      else
        local status="$?"
      fi
      test "$status" -eq ${toString validationFailureStatus}
      grep -Fq "$expected_diagnostic" "$log"
    }

    changed_byte="$(mutable_copy changed-byte)"
    substituteInPlace "$changed_byte" \
      --replace-fail '"bytes_hex":"b33c2dbc' '"bytes_hex":"b23c2dbc'
    expect_fixture_rejected changed-byte 'whole fixture authority mismatch' "$changed_byte"

    changed_order="$(mutable_copy changed-order)"
    substituteInPlace "$changed_order" \
      --replace-fail '"input_order":["a","w","k","v","r","b"]' \
      '"input_order":["w","a","k","v","r","b"]'
    expect_fixture_rejected changed-order 'whole fixture authority mismatch' "$changed_order"

    truncated="$(mutable_copy truncated)"
    truncate -s ${toString truncatedFixtureByteCount} "$truncated"
    expect_fixture_rejected truncated 'whole fixture authority mismatch' "$truncated"

    duplicated="$(mutable_copy duplicated)"
    printf 'x' >>"$duplicated"
    expect_fixture_rejected duplicated 'whole fixture authority mismatch' "$duplicated"

    unreadable="$(mutable_copy unreadable)"
    chmod 000 "$unreadable"
    expect_fixture_rejected unreadable 'fixture file could not be opened' "$unreadable"
    expect_fixture_rejected directory-path 'fixture path must be a readable regular file' "$fixture_root"

    missing_log="$fixture_root/missing.log"
    if ${lib.escapeShellArg validator} >"$missing_log" 2>&1; then
      echo "decode-reader validator accepted a missing fixture argument" >&2
      exit 1
    else
      missing_status="$?"
    fi
    test "$missing_status" -eq ${toString invalidArgumentStatus}
    grep -Fq 'usage:' "$missing_log"

    suffix_log="$fixture_root/suffix.log"
    if ${lib.escapeShellArg validator} ${lib.escapeShellArg fixture} unexpected-suffix \
      >"$suffix_log" 2>&1; then
      echo "decode-reader validator accepted an argument suffix" >&2
      exit 1
    else
      suffix_status="$?"
    fi
    test "$suffix_status" -eq ${toString invalidArgumentStatus}
    grep -Fq 'usage:' "$suffix_log"

    test "$(grep -Fc '#include "ttwkv7-decode-abi.h"' ${lib.escapeShellArg runnerSource})" -eq 1
    test "$(grep -Fc 'ttwkv7::decode_abi::make_decode_runtime_arguments(' ${lib.escapeShellArg runnerSource})" -eq 1
    grep -Fq 'std::vector<uint32_t>(arguments->reader.begin(), arguments->reader.end())' ${lib.escapeShellArg runnerSource}
    grep -Fq 'std::vector<uint32_t>(arguments->compute.begin(), arguments->compute.end())' ${lib.escapeShellArg runnerSource}
    grep -Fq 'std::vector<uint32_t>(arguments->writer.begin(), arguments->writer.end())' ${lib.escapeShellArg runnerSource}
    if grep -Fq 'std::vector<uint32_t>{St, IC, (uint32_t)cl, Ht, nc, inst_start, inst_end, P}' ${lib.escapeShellArg runnerSource}; then
      echo "production runner retained the ad hoc decode compute vector" >&2
      exit 1
    fi
    grep -Fq 'uint32_t src_page = (sq / 32) * tpr + h * (NS * 32) + i * St + jt;' ${lib.escapeShellArg decodeReaderSource}
    grep -Fq 'uint32_t base = (sq * L + t) * Ht * St + ht * St;' ${lib.escapeShellArg decodeReaderSource}
    grep -Fq 'uint32_t src_page = base + st;' ${lib.escapeShellArg decodeReaderSource}
    grep -Fq 'const uint32_t soff0 = (lh / 16) * 1024 + (lh % 16) * 32;' ${lib.escapeShellArg decodeReaderSource}
    grep -Fq 'const uint32_t ssoff0 = (srow / 16) * 1024 + (srow % 16) * 32;' ${lib.escapeShellArg decodeReaderSource}

    for forbidden in \
      '<filesystem>' '<fstream>' 'std::filesystem' 'std::getenv' \
      'std::process' 'std::chrono' 'printf(' 'fprintf(' 'MeshDevice' \
      'CreateKernel('; do
      if grep -F "$forbidden" ${lib.escapeShellArg decodeAbiHeader}; then
        echo "decode ABI core contains forbidden side-effect surface: $forbidden" >&2
        exit 1
      fi
    done
    for forbidden in \
      'mesh_device.hpp' 'MeshDevice' 'CreateKernel(' 'EnqueueMeshWorkload' \
      'EnqueueWriteMeshBuffer' 'EnqueueReadMeshBuffer'; do
      if grep -F "$forbidden" ${lib.escapeShellArg validatorSource}; then
        echo "decode-reader validator contains a device execution surface: $forbidden" >&2
        exit 1
      fi
    done

    mkdir -p "$out"
    cp "$first_receipt" "$out/receipt.json"
  ''
