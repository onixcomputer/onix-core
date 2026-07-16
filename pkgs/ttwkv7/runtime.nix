{
  lib,
  stdenvNoCC,
  makeWrapper,
  architectureCheck,
  binaries,
  kernels,
  tt-metal,
  source,
}:
let
  metaliumRuntimeRoot = "${tt-metal}/libexec/tt-metalium";
  packageKernelDirectory = "$out/share/ttwkv7/kernels";
  packageExecutable = "$out/libexec/ttwkv7/wkv7";
  probeExecutable = "$out/libexec/ttwkv7/wkv7-constant-probe";
  wrappedProbeExecutable = "$out/libexec/ttwkv7/wkv7-constant-probe-runtime";
  diagnosticRuntimeExecutable = "$out/libexec/ttwkv7/wkv7-diagnostic-runtime";
  dataMovementExecutable = "$out/libexec/ttwkv7/wkv7-data-movement-probe";
  dataMovementRuntimeExecutable = "$out/libexec/ttwkv7/wkv7-data-movement-runtime";
  primaryCommand = "wkv7";
  aliasCommand = "ttwkv7";
  probeCommand = "wkv7-constant-probe";
  diagnosticCommand = "wkv7-diagnose";
  dataMovementCommand = "wkv7-data-movement";
  probeSelfTestMode = "self-test";
  probePreflightMode = "validate-runtime";
  probeDeviceMode = "probe";
  probeForwardedArgument = "no-device-probe-argument";
  diagnosticPreflightMode = "validate-runtime";
  diagnosticDeviceMode = "diagnose";
  diagnosticProgramMode = "test";
  diagnosticKernelSelector = "all";
  diagnosticGroupCount = "1";
  diagnosticSequenceLength = "1";
  diagnosticVisibleDevice = "1";
  diagnosticChangedKernelSelector = "chunked";
  diagnosticChangedGroupCount = "2";
  diagnosticChangedSequenceLength = "2";
  diagnosticWrongVisibleDevice = "0";
  diagnosticUnexpectedSuffix = "unexpected-diagnostic-suffix";
  dataMovementSelfTestMode = "self-test";
  dataMovementArtifactSelfTestMode = "artifact-self-test";
  dataMovementPreflightMode = "validate-runtime";
  dataMovementDeviceMode = "probe";
  dataMovementVisibleDevice = "1";
  dataMovementWrongVisibleDevice = "0";
  dataMovementUnexpectedSuffix = "unexpected-data-movement-suffix";
  hostileOutputPath = "/nonexistent-ttwkv7-output";
  invalidMode = "invalid-mode";
  invalidModeExitStatus = 2;
  wrapperFailureStatus = 1;
  usageDiagnostic = "usage:";
  preflightPassDiagnostic = "ttWKV7 runtime state preflight: PASS";
  diagnosticPreflightPassDiagnostic = "ttWKV7 diagnostic runtime state preflight: PASS";
  diagnosticSuffixDiagnostic = "diagnose does not accept additional arguments";
  diagnosticUsageDiagnostic = "usage: wkv7-diagnose validate-runtime|diagnose";
  diagnosticDeviceSelectionDiagnostic = "TT_VISIBLE_DEVICES must select physical device 1 exactly";
  dataMovementPreflightPassDiagnostic = "ttWKV7 data-movement runtime state preflight: PASS";
  dataMovementSelfTestPassDiagnostic = "data-movement oracle self-test: PASS";
  dataMovementArtifactSelfTestPassDiagnostic = "data-movement artifact self-test: PASS";
  dataMovementArtifactRootDiagnostic = "data-movement artifact root could not be prepared";
  dataMovementSuffixDiagnostic = "probe does not accept additional arguments";
  dataMovementUsageDiagnostic = "usage: wkv7-data-movement self-test|validate-runtime|probe";
  selfTestPassDiagnostic = "constant-tile oracle self-test: PASS";
  cachePathDiagnostic = "TT_METAL_CACHE must be an absolute writable path outside /nix/store";
  logsPathDiagnostic = "TT_METAL_LOGS_PATH must be an absolute writable path outside /nix/store";
  inspectorAddressDiagnostic = "TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS must be";
  cacheCreationDiagnostic = "TT_METAL_CACHE could not be created";
  logsCreationDiagnostic = "TT_METAL_LOGS_PATH could not be created";
  meshGraphDescriptorVariable = "TT_MESH_GRAPH_DESC_PATH";
  architectureSfpuStart = "_llk_math_eltwise_sfpu_start_(";
  blackholeSfpuDone = "_llk_math_eltwise_sfpu_done_with_addrmod_reset_();";
  wormholeSfpuDone = "_llk_math_eltwise_sfpu_done_();";
  blackholeBranch = "#if defined(ARCH_BLACKHOLE)";
  wormholeBranch = "#elif defined(ARCH_WORMHOLE)";
  wormholeOnlyAddrModCall = "math::set_addr_mod_base();";
  testInspectorHost = "127.0.0.1";
  testInspectorPort = 43127;
  invalidLowInspectorPort = 0;
  invalidHighInspectorPort = 65536;
  expectedDataMovementCreateKernelCount = 6;
  expectedReaderHelperCallCount = 4;
  expectedReaderCbCadenceSiteCount = 2;
  alignedReaderHelperSource = "ttwkv7_aligned_dram_face_read.h";
  alignedReaderHelperInclude = "#include \"${alignedReaderHelperSource}\"";
  alignedReaderHelperCall = "ttwkv7::read_dram_face_row(";
  alignedReaderBlackholeBranch = "#ifdef ARCH_BLACKHOLE";
  alignedReaderNocCall = "noc_async_read(";
  alignedReaderCbReserveCall = "cb_reserve_back(c_natstage";
  alignedReaderCbPushCall = "cb_push_back(c_natstage";
  invalidDirectReaderGather = "noc_async_read(source, destination, kFaceRowBytes);";
  invalidReaderCadence = "cb_push_back(c_natstage, 1);";
  constantGeneratorSources = [
    "wkv7_chunked_compute.cpp"
    "wkv7_decodeL_compute.cpp"
    "ttwkv7_constant_tile_compute.cpp"
  ];
  requiredKernelSources = [
    "wkv7_chunked_compute.cpp"
    "wkv7_decodeL_compute.cpp"
    "wkv7_decodeL_reader.cpp"
    "wkv7_reader.cpp"
    "wkv7_writer.cpp"
    "ttwkv7_constant_tile_compute.cpp"
    "ttwkv7_constant_tile_writer.cpp"
    "ttwkv7_data_movement_capture_writer.cpp"
    "ttwkv7_data_movement_capture_source_reader.cpp"
    "ttwkv7_data_movement_source_reader.cpp"
    alignedReaderHelperSource
  ];
  productionReaderSources = [
    "wkv7_reader.cpp"
    "wkv7_decodeL_reader.cpp"
  ];
in
stdenvNoCC.mkDerivation {
  pname = "ttwkv7";
  inherit (source) version;

  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/libexec/ttwkv7" "$out/share/ttwkv7"
    ln -s ${binaries}/libexec/ttwkv7/wkv7 ${packageExecutable}
    ln -s ${binaries}/libexec/ttwkv7/wkv7-constant-probe ${probeExecutable}
    ln -s ${binaries}/libexec/ttwkv7/wkv7-data-movement-probe ${dataMovementExecutable}
    ln -s ${kernels}/share/ttwkv7/kernels ${packageKernelDirectory}

    makeWrapper ${packageExecutable} "$out/bin/${primaryCommand}" \
      --set TT_METAL_HOME ${lib.escapeShellArg metaliumRuntimeRoot} \
      --set TT_METAL_RUNTIME_ROOT ${lib.escapeShellArg metaliumRuntimeRoot} \
      --unset ${meshGraphDescriptorVariable} \
      --chdir "$out/share/ttwkv7"
    makeWrapper ${probeExecutable} ${wrappedProbeExecutable} \
      --set TT_METAL_HOME ${lib.escapeShellArg metaliumRuntimeRoot} \
      --set TT_METAL_RUNTIME_ROOT ${lib.escapeShellArg metaliumRuntimeRoot} \
      --unset ${meshGraphDescriptorVariable} \
      --chdir "$out/share/ttwkv7"
    makeWrapper ${packageExecutable} ${diagnosticRuntimeExecutable} \
      --set TT_METAL_HOME ${lib.escapeShellArg metaliumRuntimeRoot} \
      --set TT_METAL_RUNTIME_ROOT ${lib.escapeShellArg metaliumRuntimeRoot} \
      --unset ${meshGraphDescriptorVariable} \
      --chdir "$out/share/ttwkv7"
    makeWrapper ${dataMovementExecutable} ${dataMovementRuntimeExecutable} \
      --set TT_METAL_HOME ${lib.escapeShellArg metaliumRuntimeRoot} \
      --set TT_METAL_RUNTIME_ROOT ${lib.escapeShellArg metaliumRuntimeRoot} \
      --unset ${meshGraphDescriptorVariable} \
      --chdir "$out/share/ttwkv7"
    substitute ${./probe-wrapper.sh} "$out/bin/${probeCommand}" \
      --replace-fail '@probeExecutable@' "$out/libexec/ttwkv7/wkv7-constant-probe-runtime"
    substitute ${./diagnostic-wrapper.sh} "$out/bin/${diagnosticCommand}" \
      --replace-fail '@diagnosticExecutable@' "$out/libexec/ttwkv7/wkv7-diagnostic-runtime"
    substitute ${./data-movement-wrapper.sh} "$out/bin/${dataMovementCommand}" \
      --replace-fail '@dataMovementExecutable@' "$out/libexec/ttwkv7/wkv7-data-movement-runtime"
    chmod +x "$out/bin/${probeCommand}" "$out/bin/${diagnosticCommand}" "$out/bin/${dataMovementCommand}"
    ln -s ${primaryCommand} "$out/bin/${aliasCommand}"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    # Positive package-layout coverage for
    # r[verify onix.tenstorrent.native_runtime.ttwkv7.fast_iteration].
    test -x "$out/bin/${primaryCommand}"
    test -x "$out/bin/${aliasCommand}"
    test -x "$out/bin/${probeCommand}"
    test -x "$out/bin/${diagnosticCommand}"
    test -x "$out/bin/${dataMovementCommand}"
    test -x ${packageExecutable}
    test -x ${probeExecutable}
    test -x ${wrappedProbeExecutable}
    test -x ${diagnosticRuntimeExecutable}
    test -x ${dataMovementExecutable}
    test -x ${dataMovementRuntimeExecutable}

    # Positive and negative production-dispatch coverage for
    # r[verify onix.tenstorrent.native_runtime.ttwkv7.production_probe_wrapper].
    production_probe_wrapper="$out/bin/${probeCommand}"
    production_probe_target="$out/libexec/ttwkv7/wkv7-constant-probe-runtime"
    test -x "$production_probe_target"
    grep -F \
      "exec \"$production_probe_target\" ${lib.escapeShellArg probeDeviceMode} \"\$@\"" \
      "$production_probe_wrapper"
    if grep -F 'exec "$out/' "$production_probe_wrapper"; then
      echo "ttWKV7 production probe wrapper must not expand out at runtime" >&2
      exit 1
    fi
    if grep -F '@probeExecutable@' "$production_probe_wrapper"; then
      echo "ttWKV7 production probe wrapper retained its executable placeholder" >&2
      exit 1
    fi
    missing_out_log="$(mktemp)"
    env -u out "$production_probe_wrapper" ${lib.escapeShellArg probeSelfTestMode} \
      >"$missing_out_log"
    grep -F ${lib.escapeShellArg selfTestPassDiagnostic} "$missing_out_log"
    hostile_out_log="$(mktemp)"
    env out=${lib.escapeShellArg hostileOutputPath} \
      "$production_probe_wrapper" ${lib.escapeShellArg probeSelfTestMode} \
      >"$hostile_out_log"
    grep -F ${lib.escapeShellArg selfTestPassDiagnostic} "$hostile_out_log"

    # Positive and negative exact cross-kernel diagnostic coverage for
    # r[verify onix.tenstorrent.native_runtime.ttwkv7.cross_kernel_diagnostic].
    production_diagnostic_wrapper="$out/bin/${diagnosticCommand}"
    production_diagnostic_target="$out/libexec/ttwkv7/wkv7-diagnostic-runtime"
    test -x "$production_diagnostic_target"
    production_diagnostic_exec_line="  exec \"$production_diagnostic_target\" ${lib.escapeShellArg diagnosticProgramMode} ${lib.escapeShellArg diagnosticKernelSelector} ${lib.escapeShellArg diagnosticGroupCount} ${lib.escapeShellArg diagnosticSequenceLength}"
    test "$(grep -Fxc "$production_diagnostic_exec_line" "$production_diagnostic_wrapper")" -eq 1
    test "$(grep -Ec '^[[:space:]]*exec ' "$production_diagnostic_wrapper")" -eq 1
    if grep -F 'exec "$out/' "$production_diagnostic_wrapper"; then
      echo "ttWKV7 diagnostic wrapper must not expand out at runtime" >&2
      exit 1
    fi
    if grep -F '@diagnosticExecutable@' "$production_diagnostic_wrapper"; then
      echo "ttWKV7 diagnostic wrapper retained its executable placeholder" >&2
      exit 1
    fi

    diagnostic_state_root="$(mktemp -d)"
    diagnostic_cache="$diagnostic_state_root/cache"
    diagnostic_logs="$diagnostic_state_root/logs"
    diagnostic_inspector=${lib.escapeShellArg "${testInspectorHost}:${toString testInspectorPort}"}
    TT_VISIBLE_DEVICES=${lib.escapeShellArg diagnosticVisibleDevice} \
      TT_METAL_CACHE="$diagnostic_cache" \
      TT_METAL_LOGS_PATH="$diagnostic_logs" \
      TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$diagnostic_inspector" \
      "$production_diagnostic_wrapper" ${lib.escapeShellArg diagnosticPreflightMode} \
      >"$diagnostic_state_root/production-preflight.log"
    grep -F ${lib.escapeShellArg diagnosticPreflightPassDiagnostic} \
      "$diagnostic_state_root/production-preflight.log"

    fake_diagnostic="$diagnostic_state_root/fake-diagnostic"
    printf '%s\n' \
      '#!${stdenvNoCC.shell}' \
      'printf "%s\n" "$@"' \
      >"$fake_diagnostic"
    chmod +x "$fake_diagnostic"
    fake_diagnostic_wrapper="$diagnostic_state_root/fake-diagnostic-wrapper"
    substitute ${./diagnostic-wrapper.sh} "$fake_diagnostic_wrapper" \
      --replace-fail '@diagnosticExecutable@' "$fake_diagnostic"
    chmod +x "$fake_diagnostic_wrapper"

    TT_VISIBLE_DEVICES=${lib.escapeShellArg diagnosticVisibleDevice} \
      TT_METAL_CACHE="$diagnostic_cache" \
      TT_METAL_LOGS_PATH="$diagnostic_logs" \
      TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$diagnostic_inspector" \
      ${stdenvNoCC.shell} "$fake_diagnostic_wrapper" ${lib.escapeShellArg diagnosticDeviceMode} \
      >"$diagnostic_state_root/exact-vector.log"
    diagnostic_vector_expected="$(
      printf '%s\n' \
        ${lib.escapeShellArgs [
          diagnosticProgramMode
          diagnosticKernelSelector
          diagnosticGroupCount
          diagnosticSequenceLength
        ]}
    )"

    assert_exact_diagnostic_vector() {
      vector_log="$1"
      test "$(cat "$vector_log")" = "$diagnostic_vector_expected"
    }
    assert_exact_diagnostic_vector "$diagnostic_state_root/exact-vector.log"

    expect_diagnostic_vector_rejection() {
      fixture_name="$1"
      shift
      fixture_log="$diagnostic_state_root/$fixture_name.log"
      printf '%s\n' "$@" >"$fixture_log"
      if assert_exact_diagnostic_vector "$fixture_log"; then
        echo "ttWKV7 diagnostic vector comparator accepted mutation: $fixture_name" >&2
        exit 1
      fi
    }
    expect_diagnostic_vector_rejection dropped-mode \
      ${lib.escapeShellArgs [
        diagnosticKernelSelector
        diagnosticGroupCount
        diagnosticSequenceLength
      ]}
    expect_diagnostic_vector_rejection dropped-length \
      ${lib.escapeShellArgs [
        diagnosticProgramMode
        diagnosticKernelSelector
        diagnosticGroupCount
      ]}
    expect_diagnostic_vector_rejection duplicated-mode \
      ${lib.escapeShellArgs [
        diagnosticProgramMode
        diagnosticProgramMode
        diagnosticKernelSelector
        diagnosticGroupCount
        diagnosticSequenceLength
      ]}
    expect_diagnostic_vector_rejection duplicated-kernel \
      ${lib.escapeShellArgs [
        diagnosticProgramMode
        diagnosticKernelSelector
        diagnosticKernelSelector
        diagnosticGroupCount
        diagnosticSequenceLength
      ]}
    expect_diagnostic_vector_rejection reordered-kernel-group \
      ${lib.escapeShellArgs [
        diagnosticProgramMode
        diagnosticGroupCount
        diagnosticKernelSelector
        diagnosticSequenceLength
      ]}
    expect_diagnostic_vector_rejection changed-kernel \
      ${lib.escapeShellArgs [
        diagnosticProgramMode
        diagnosticChangedKernelSelector
        diagnosticGroupCount
        diagnosticSequenceLength
      ]}
    expect_diagnostic_vector_rejection changed-group \
      ${lib.escapeShellArgs [
        diagnosticProgramMode
        diagnosticKernelSelector
        diagnosticChangedGroupCount
        diagnosticSequenceLength
      ]}
    expect_diagnostic_vector_rejection changed-length \
      ${lib.escapeShellArgs [
        diagnosticProgramMode
        diagnosticKernelSelector
        diagnosticGroupCount
        diagnosticChangedSequenceLength
      ]}
    expect_diagnostic_vector_rejection suffixed-vector \
      ${lib.escapeShellArgs [
        diagnosticProgramMode
        diagnosticKernelSelector
        diagnosticGroupCount
        diagnosticSequenceLength
        diagnosticUnexpectedSuffix
      ]}

    diagnostic_suffix_log="$diagnostic_state_root/suffix-rejection.log"
    if ${stdenvNoCC.shell} "$fake_diagnostic_wrapper" \
      ${lib.escapeShellArg diagnosticDeviceMode} ${lib.escapeShellArg diagnosticUnexpectedSuffix} \
      >"$diagnostic_suffix_log" 2>&1; then
      echo "ttWKV7 diagnostic wrapper accepted a caller-controlled suffix" >&2
      exit 1
    else
      diagnostic_suffix_status="$?"
    fi
    test "$diagnostic_suffix_status" -eq ${toString wrapperFailureStatus}
    grep -F ${lib.escapeShellArg diagnosticSuffixDiagnostic} "$diagnostic_suffix_log"

    diagnostic_invalid_log="$diagnostic_state_root/invalid-mode.log"
    if "$production_diagnostic_wrapper" ${lib.escapeShellArg invalidMode} \
      >"$diagnostic_invalid_log" 2>&1; then
      echo "ttWKV7 diagnostic wrapper accepted an invalid mode" >&2
      exit 1
    else
      diagnostic_invalid_status="$?"
    fi
    test "$diagnostic_invalid_status" -eq ${toString invalidModeExitStatus}
    grep -F ${lib.escapeShellArg diagnosticUsageDiagnostic} "$diagnostic_invalid_log"

    # Positive and negative exact data-movement diagnostic coverage for
    # r[verify onix.tenstorrent.native_runtime.ttwkv7.data_movement_diagnostic].
    production_data_movement_wrapper="$out/bin/${dataMovementCommand}"
    production_data_movement_target="$out/libexec/ttwkv7/wkv7-data-movement-runtime"
    test -x "$production_data_movement_target"
    data_movement_self_test_exec_line="  exec \"$production_data_movement_target\" ${lib.escapeShellArg dataMovementSelfTestMode}"
    data_movement_probe_exec_line="  exec \"$production_data_movement_target\" ${lib.escapeShellArg dataMovementDeviceMode}"
    test "$(grep -Fxc "$data_movement_self_test_exec_line" "$production_data_movement_wrapper")" -eq 1
    test "$(grep -Fxc "$data_movement_probe_exec_line" "$production_data_movement_wrapper")" -eq 1
    test "$(grep -Ec '^[[:space:]]*exec ' "$production_data_movement_wrapper")" -eq 2
    if grep -F 'exec "$out/' "$production_data_movement_wrapper"; then
      echo "ttWKV7 data-movement wrapper must not expand out at runtime" >&2
      exit 1
    fi
    if grep -F '@dataMovementExecutable@' "$production_data_movement_wrapper"; then
      echo "ttWKV7 data-movement wrapper retained its executable placeholder" >&2
      exit 1
    fi

    data_movement_missing_out_log="$(mktemp)"
    env -u out "$production_data_movement_wrapper" ${lib.escapeShellArg dataMovementSelfTestMode} \
      >"$data_movement_missing_out_log"
    grep -F ${lib.escapeShellArg dataMovementSelfTestPassDiagnostic} "$data_movement_missing_out_log"
    data_movement_hostile_out_log="$(mktemp)"
    env out=${lib.escapeShellArg hostileOutputPath} \
      "$production_data_movement_wrapper" ${lib.escapeShellArg dataMovementSelfTestMode} \
      >"$data_movement_hostile_out_log"
    grep -F ${lib.escapeShellArg dataMovementSelfTestPassDiagnostic} "$data_movement_hostile_out_log"

    data_movement_state_root="$(mktemp -d)"
    data_movement_artifact_root="$data_movement_state_root/artifact-root"
    mkdir -p "$data_movement_artifact_root"
    "$production_data_movement_target" \
      ${lib.escapeShellArg dataMovementArtifactSelfTestMode} \
      "$data_movement_artifact_root" \
      >"$data_movement_state_root/artifact-self-test.log"
    grep -F ${lib.escapeShellArg dataMovementArtifactSelfTestPassDiagnostic} \
      "$data_movement_state_root/artifact-self-test.log"
    test -s "$data_movement_artifact_root/ttwkv7-data-movement/sample.bf16"
    test -s "$data_movement_artifact_root/ttwkv7-data-movement/sample-producer.args"
    grep -F ${lib.escapeShellArg "sample.bf16"} \
      "$data_movement_artifact_root/ttwkv7-data-movement/manifest.tsv"
    data_movement_artifact_file="$data_movement_state_root/artifact-file"
    touch "$data_movement_artifact_file"
    if "$production_data_movement_target" \
      ${lib.escapeShellArg dataMovementArtifactSelfTestMode} \
      "$data_movement_artifact_file" \
      >"$data_movement_state_root/artifact-self-test-negative.log" 2>&1; then
      echo "ttWKV7 data-movement artifact self-test accepted a file root" >&2
      exit 1
    else
      data_movement_artifact_negative_status="$?"
    fi
    test "$data_movement_artifact_negative_status" -eq ${toString wrapperFailureStatus}
    if env -u TT_METAL_LOGS_PATH \
      "$production_data_movement_target" ${lib.escapeShellArg dataMovementDeviceMode} \
      >"$data_movement_state_root/missing-artifact-root.log" 2>&1; then
      echo "ttWKV7 data-movement probe accepted a missing artifact root" >&2
      exit 1
    else
      data_movement_missing_artifact_status="$?"
    fi
    test "$data_movement_missing_artifact_status" -eq ${toString wrapperFailureStatus}
    grep -F ${lib.escapeShellArg dataMovementArtifactRootDiagnostic} \
      "$data_movement_state_root/missing-artifact-root.log"

    data_movement_cache="$data_movement_state_root/cache"
    data_movement_logs="$data_movement_state_root/logs"
    data_movement_inspector=${lib.escapeShellArg "${testInspectorHost}:${toString testInspectorPort}"}
    TT_VISIBLE_DEVICES=${lib.escapeShellArg dataMovementVisibleDevice} \
      TT_METAL_CACHE="$data_movement_cache" \
      TT_METAL_LOGS_PATH="$data_movement_logs" \
      TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$data_movement_inspector" \
      "$production_data_movement_wrapper" ${lib.escapeShellArg dataMovementPreflightMode} \
      >"$data_movement_state_root/production-preflight.log"
    grep -F ${lib.escapeShellArg dataMovementPreflightPassDiagnostic} \
      "$data_movement_state_root/production-preflight.log"

    fake_data_movement="$data_movement_state_root/fake-data-movement"
    printf '%s\n' \
      '#!${stdenvNoCC.shell}' \
      'printf "%s\n" "$@"' \
      >"$fake_data_movement"
    chmod +x "$fake_data_movement"
    fake_data_movement_wrapper="$data_movement_state_root/fake-data-movement-wrapper"
    substitute ${./data-movement-wrapper.sh} "$fake_data_movement_wrapper" \
      --replace-fail '@dataMovementExecutable@' "$fake_data_movement"
    chmod +x "$fake_data_movement_wrapper"

    ${stdenvNoCC.shell} "$fake_data_movement_wrapper" ${lib.escapeShellArg dataMovementSelfTestMode} \
      >"$data_movement_state_root/exact-self-test-vector.log"
    test "$(cat "$data_movement_state_root/exact-self-test-vector.log")" = \
      ${lib.escapeShellArg dataMovementSelfTestMode}
    TT_VISIBLE_DEVICES=${lib.escapeShellArg dataMovementVisibleDevice} \
      TT_METAL_CACHE="$data_movement_cache" \
      TT_METAL_LOGS_PATH="$data_movement_logs" \
      TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$data_movement_inspector" \
      ${stdenvNoCC.shell} "$fake_data_movement_wrapper" ${lib.escapeShellArg dataMovementDeviceMode} \
      >"$data_movement_state_root/exact-probe-vector.log"
    test "$(cat "$data_movement_state_root/exact-probe-vector.log")" = \
      ${lib.escapeShellArg dataMovementDeviceMode}

    data_movement_suffix_log="$data_movement_state_root/suffix-rejection.log"
    if ${stdenvNoCC.shell} "$fake_data_movement_wrapper" \
      ${lib.escapeShellArg dataMovementDeviceMode} ${lib.escapeShellArg dataMovementUnexpectedSuffix} \
      >"$data_movement_suffix_log" 2>&1; then
      echo "ttWKV7 data-movement wrapper accepted a caller-controlled suffix" >&2
      exit 1
    else
      data_movement_suffix_status="$?"
    fi
    test "$data_movement_suffix_status" -eq ${toString wrapperFailureStatus}
    grep -F ${lib.escapeShellArg dataMovementSuffixDiagnostic} "$data_movement_suffix_log"

    data_movement_invalid_log="$data_movement_state_root/invalid-mode.log"
    if "$production_data_movement_wrapper" ${lib.escapeShellArg invalidMode} \
      >"$data_movement_invalid_log" 2>&1; then
      echo "ttWKV7 data-movement wrapper accepted an invalid mode" >&2
      exit 1
    else
      data_movement_invalid_status="$?"
    fi
    test "$data_movement_invalid_status" -eq ${toString invalidModeExitStatus}
    grep -F ${lib.escapeShellArg dataMovementUsageDiagnostic} "$data_movement_invalid_log"
    test "$(grep -Fc 'CreateKernel(' ${./data-movement-probe.cpp})" -eq \
      ${toString expectedDataMovementCreateKernelCount}
    if grep -F 'ComputeConfig' ${./data-movement-probe.cpp}; then
      echo "ttWKV7 data-movement probe must not create a compute kernel" >&2
      exit 1
    fi
    grep -F ${lib.escapeShellArg "kernels/wkv7_reader.cpp"} ${./data-movement-probe.cpp}
    grep -F ${lib.escapeShellArg "kernels/wkv7_decodeL_reader.cpp"} ${./data-movement-probe.cpp}
    grep -F ${lib.escapeShellArg "kernels/wkv7_writer.cpp"} ${./data-movement-probe.cpp}
    grep -F ${lib.escapeShellArg "kernels/ttwkv7_data_movement_capture_source_reader.cpp"} ${./data-movement-probe.cpp}
    grep -F ${lib.escapeShellArg "tt::CBIndex::c_21"} ${./data-movement-probe.cpp}
    grep -F ${lib.escapeShellArg "tt::CBIndex::c_16"} ${./data-movement-probe.cpp}
    grep -F ${lib.escapeShellArg "chunked-partial-L1"} ${./data-movement-probe.cpp}
    grep -F ${lib.escapeShellArg "chunked-full-L32"} ${./data-movement-probe.cpp}
    grep -F ${lib.escapeShellArg "exhausted-L1-Lreal1-chunked-vector"} ${./data-movement-probe.cpp}
    grep -F ${lib.escapeShellArg "TT_METAL_LOGS_PATH"} ${./data-movement-probe.cpp}
    grep -F ${lib.escapeShellArg "manifest.tsv"} ${./data-movement-probe.cpp}

    for kernel_source in ${lib.escapeShellArgs requiredKernelSources}; do
      test -f "${packageKernelDirectory}/$kernel_source"
    done

    # r[verify onix.tenstorrent.native_runtime.ttwkv7.reader_gather_alignment]
    aligned_reader_helper="${packageKernelDirectory}/${alignedReaderHelperSource}"
    grep -F ${lib.escapeShellArg alignedReaderBlackholeBranch} "$aligned_reader_helper"
    test "$(grep -Fc ${lib.escapeShellArg alignedReaderNocCall} "$aligned_reader_helper")" -eq 2
    grep -F ${lib.escapeShellArg "alignas(ttwkv7::kDramReadAlignmentBytes)"} \
      "${packageKernelDirectory}/wkv7_reader.cpp"
    grep -F ${lib.escapeShellArg "alignas(ttwkv7::kDramReadAlignmentBytes)"} \
      "${packageKernelDirectory}/wkv7_decodeL_reader.cpp"
    check_aligned_reader_source() {
      local reader_source="$1"
      test "$(grep -Fc ${lib.escapeShellArg alignedReaderHelperInclude} "$reader_source")" -eq 1 || return 1
      test "$(grep -Fc ${lib.escapeShellArg alignedReaderHelperCall} "$reader_source")" -eq \
        ${toString expectedReaderHelperCallCount} || return 1
      test "$(grep -Fc ${lib.escapeShellArg alignedReaderCbReserveCall} "$reader_source")" -eq \
        ${toString expectedReaderCbCadenceSiteCount} || return 1
      test "$(grep -Fc ${lib.escapeShellArg alignedReaderCbPushCall} "$reader_source")" -eq \
        ${toString expectedReaderCbCadenceSiteCount} || return 1
      if grep -F ${lib.escapeShellArg alignedReaderNocCall} "$reader_source"; then
        return 1
      fi
    }
    for reader_name in ${lib.escapeShellArgs productionReaderSources}; do
      check_aligned_reader_source "${packageKernelDirectory}/$reader_name"
    done
    invalid_reader="$data_movement_state_root/invalid-direct-reader.cpp"
    cp "${packageKernelDirectory}/wkv7_reader.cpp" "$invalid_reader"
    chmod u+w "$invalid_reader"
    printf '%s\n' ${lib.escapeShellArg invalidDirectReaderGather} >>"$invalid_reader"
    if check_aligned_reader_source "$invalid_reader"; then
      echo "ttWKV7 aligned-reader source checker accepted a direct DRAM gather" >&2
      exit 1
    fi
    invalid_cadence_reader="$data_movement_state_root/invalid-reader-cadence.cpp"
    cp "${packageKernelDirectory}/wkv7_decodeL_reader.cpp" "$invalid_cadence_reader"
    chmod u+w "$invalid_cadence_reader"
    printf '%s\n' ${lib.escapeShellArg invalidReaderCadence} >>"$invalid_cadence_reader"
    if check_aligned_reader_source "$invalid_cadence_reader"; then
      echo "ttWKV7 aligned-reader source checker accepted CB cadence drift" >&2
      exit 1
    fi

    # Positive and negative architecture portability coverage for
    # r[verify onix.tenstorrent.native_runtime.ttwkv7.architecture_sfpu].
    for generator_name in ${lib.escapeShellArgs constantGeneratorSources}; do
      generator_source="${packageKernelDirectory}/$generator_name"
      grep -F ${lib.escapeShellArg architectureSfpuStart} "$generator_source"
      grep -F ${lib.escapeShellArg blackholeBranch} "$generator_source"
      grep -F ${lib.escapeShellArg blackholeSfpuDone} "$generator_source"
      grep -F ${lib.escapeShellArg wormholeBranch} "$generator_source"
      grep -F ${lib.escapeShellArg wormholeSfpuDone} "$generator_source"
      if grep -F ${lib.escapeShellArg wormholeOnlyAddrModCall} "$generator_source"; then
        echo "ttWKV7 constant generators must not call the Wormhole-only address-modifier primitive directly" >&2
        exit 1
      fi
    done

    # Positive and negative pure-oracle coverage for
    # r[verify onix.tenstorrent.native_runtime.ttwkv7.constant_tile_probe].
    "$out/bin/${probeCommand}" ${lib.escapeShellArg probeSelfTestMode}
    probe_invalid_log="$(mktemp)"
    if "$out/bin/${probeCommand}" ${lib.escapeShellArg invalidMode} >"$probe_invalid_log" 2>&1; then
      echo "ttWKV7 constant probe unexpectedly accepted invalid mode '${invalidMode}'" >&2
      exit 1
    else
      probe_invalid_status="$?"
    fi
    test "$probe_invalid_status" -eq ${toString invalidModeExitStatus}
    grep -F ${lib.escapeShellArg usageDiagnostic} "$probe_invalid_log"

    # Positive and negative runtime-state coverage for
    # r[verify onix.tenstorrent.native_runtime.ttwkv7.explicit_runtime_state].
    runtime_state_root="$(mktemp -d)"
    runtime_cache="$runtime_state_root/cache"
    runtime_logs="$runtime_state_root/logs"
    runtime_inspector=${lib.escapeShellArg "${testInspectorHost}:${toString testInspectorPort}"}
    TT_METAL_CACHE="$runtime_cache" \
      TT_METAL_LOGS_PATH="$runtime_logs" \
      TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$runtime_inspector" \
      "$out/bin/${probeCommand}" ${lib.escapeShellArg probePreflightMode} \
      >"$runtime_state_root/preflight.log"
    grep -F ${lib.escapeShellArg preflightPassDiagnostic} "$runtime_state_root/preflight.log"
    test -d "$runtime_cache"
    test -d "$runtime_logs"

    fake_probe="$runtime_state_root/fake-probe"
    printf '%s\n' \
      '#!${stdenvNoCC.shell}' \
      'printf "%s\n" "$@"' \
      >"$fake_probe"
    chmod +x "$fake_probe"
    fake_probe_wrapper="$runtime_state_root/fake-probe-wrapper"
    substitute ${./probe-wrapper.sh} "$fake_probe_wrapper" \
      --replace-fail '@probeExecutable@' "$fake_probe"
    chmod +x "$fake_probe_wrapper"
    TT_METAL_CACHE="$runtime_cache" \
      TT_METAL_LOGS_PATH="$runtime_logs" \
      TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$runtime_inspector" \
      ${stdenvNoCC.shell} "$fake_probe_wrapper" ${lib.escapeShellArg probeDeviceMode} \
      >"$runtime_state_root/fake-probe-mode.log"
    test "$(cat "$runtime_state_root/fake-probe-mode.log")" = \
      ${lib.escapeShellArg probeDeviceMode}

    TT_METAL_CACHE="$runtime_cache" \
      TT_METAL_LOGS_PATH="$runtime_logs" \
      TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$runtime_inspector" \
      ${stdenvNoCC.shell} "$fake_probe_wrapper" ${lib.escapeShellArg probeDeviceMode} \
        ${lib.escapeShellArg probeForwardedArgument} \
      >"$runtime_state_root/fake-probe-forwarded.log"
    fake_probe_forwarded_expected="$(
      printf '%s\n%s' \
        ${lib.escapeShellArg probeDeviceMode} \
        ${lib.escapeShellArg probeForwardedArgument}
    )"
    test "$(cat "$runtime_state_root/fake-probe-forwarded.log")" = \
      "$fake_probe_forwarded_expected"

    expect_wrapper_failure() {
      failure_name="$1"
      expected_diagnostic="$2"
      shift 2
      failure_log="$runtime_state_root/$failure_name.log"
      if "$@" >"$failure_log" 2>&1; then
        echo "ttWKV7 wrapper unexpectedly accepted negative case: $failure_name" >&2
        exit 1
      else
        failure_status="$?"
      fi
      test "$failure_status" -eq ${toString wrapperFailureStatus}
      grep -F "$expected_diagnostic" "$failure_log"
    }

    expect_wrapper_failure missing-cache ${lib.escapeShellArg cachePathDiagnostic} \
      env -u TT_METAL_CACHE \
        TT_METAL_LOGS_PATH="$runtime_logs" \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$runtime_inspector" \
        "$out/bin/${probeCommand}" ${lib.escapeShellArg probePreflightMode}
    expect_wrapper_failure relative-cache ${lib.escapeShellArg cachePathDiagnostic} \
      env TT_METAL_CACHE=relative-cache \
        TT_METAL_LOGS_PATH="$runtime_logs" \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$runtime_inspector" \
        "$out/bin/${probeCommand}" ${lib.escapeShellArg probePreflightMode}
    expect_wrapper_failure store-cache ${lib.escapeShellArg cachePathDiagnostic} \
      env TT_METAL_CACHE=/nix/store/unsafe-cache \
        TT_METAL_LOGS_PATH="$runtime_logs" \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$runtime_inspector" \
        "$out/bin/${probeCommand}" ${lib.escapeShellArg probePreflightMode}
    expect_wrapper_failure missing-logs ${lib.escapeShellArg logsPathDiagnostic} \
      env -u TT_METAL_LOGS_PATH \
        TT_METAL_CACHE="$runtime_cache" \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$runtime_inspector" \
        "$out/bin/${probeCommand}" ${lib.escapeShellArg probePreflightMode}
    expect_wrapper_failure relative-logs ${lib.escapeShellArg logsPathDiagnostic} \
      env TT_METAL_CACHE="$runtime_cache" \
        TT_METAL_LOGS_PATH=relative-logs \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$runtime_inspector" \
        "$out/bin/${probeCommand}" ${lib.escapeShellArg probePreflightMode}
    expect_wrapper_failure store-logs ${lib.escapeShellArg logsPathDiagnostic} \
      env TT_METAL_CACHE="$runtime_cache" \
        TT_METAL_LOGS_PATH=/nix/store/unsafe-logs \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$runtime_inspector" \
        "$out/bin/${probeCommand}" ${lib.escapeShellArg probePreflightMode}

    cache_file="$runtime_state_root/cache-file"
    touch "$cache_file"
    expect_wrapper_failure cache-file ${lib.escapeShellArg cacheCreationDiagnostic} \
      env TT_METAL_CACHE="$cache_file" \
        TT_METAL_LOGS_PATH="$runtime_logs" \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$runtime_inspector" \
        "$out/bin/${probeCommand}" ${lib.escapeShellArg probePreflightMode}
    logs_file="$runtime_state_root/logs-file"
    touch "$logs_file"
    expect_wrapper_failure logs-file ${lib.escapeShellArg logsCreationDiagnostic} \
      env TT_METAL_CACHE="$runtime_cache" \
        TT_METAL_LOGS_PATH="$logs_file" \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$runtime_inspector" \
        "$out/bin/${probeCommand}" ${lib.escapeShellArg probePreflightMode}
    expect_wrapper_failure non-loopback-inspector ${lib.escapeShellArg inspectorAddressDiagnostic} \
      env TT_METAL_CACHE="$runtime_cache" \
        TT_METAL_LOGS_PATH="$runtime_logs" \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="0.0.0.0:${toString testInspectorPort}" \
        "$out/bin/${probeCommand}" ${lib.escapeShellArg probePreflightMode}
    expect_wrapper_failure low-inspector-port ${lib.escapeShellArg inspectorAddressDiagnostic} \
      env TT_METAL_CACHE="$runtime_cache" \
        TT_METAL_LOGS_PATH="$runtime_logs" \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="${testInspectorHost}:${toString invalidLowInspectorPort}" \
        "$out/bin/${probeCommand}" ${lib.escapeShellArg probePreflightMode}
    expect_wrapper_failure high-inspector-port ${lib.escapeShellArg inspectorAddressDiagnostic} \
      env TT_METAL_CACHE="$runtime_cache" \
        TT_METAL_LOGS_PATH="$runtime_logs" \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="${testInspectorHost}:${toString invalidHighInspectorPort}" \
        "$out/bin/${probeCommand}" ${lib.escapeShellArg probePreflightMode}
    expect_wrapper_failure diagnostic-missing-visible-device ${lib.escapeShellArg diagnosticDeviceSelectionDiagnostic} \
      env -u TT_VISIBLE_DEVICES \
        TT_METAL_CACHE="$runtime_cache" \
        TT_METAL_LOGS_PATH="$runtime_logs" \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$runtime_inspector" \
        "$production_diagnostic_wrapper" ${lib.escapeShellArg diagnosticPreflightMode}
    expect_wrapper_failure diagnostic-wrong-visible-device ${lib.escapeShellArg diagnosticDeviceSelectionDiagnostic} \
      env TT_VISIBLE_DEVICES=${lib.escapeShellArg diagnosticWrongVisibleDevice} \
        TT_METAL_CACHE="$runtime_cache" \
        TT_METAL_LOGS_PATH="$runtime_logs" \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$runtime_inspector" \
        "$production_diagnostic_wrapper" ${lib.escapeShellArg diagnosticPreflightMode}
    expect_wrapper_failure diagnostic-missing-cache ${lib.escapeShellArg cachePathDiagnostic} \
      env -u TT_METAL_CACHE \
        TT_VISIBLE_DEVICES=${lib.escapeShellArg diagnosticVisibleDevice} \
        TT_METAL_LOGS_PATH="$runtime_logs" \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$runtime_inspector" \
        "$production_diagnostic_wrapper" ${lib.escapeShellArg diagnosticPreflightMode}
    expect_wrapper_failure diagnostic-relative-cache ${lib.escapeShellArg cachePathDiagnostic} \
      env TT_VISIBLE_DEVICES=${lib.escapeShellArg diagnosticVisibleDevice} \
        TT_METAL_CACHE=relative-cache \
        TT_METAL_LOGS_PATH="$runtime_logs" \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$runtime_inspector" \
        "$production_diagnostic_wrapper" ${lib.escapeShellArg diagnosticPreflightMode}
    expect_wrapper_failure diagnostic-store-cache ${lib.escapeShellArg cachePathDiagnostic} \
      env TT_VISIBLE_DEVICES=${lib.escapeShellArg diagnosticVisibleDevice} \
        TT_METAL_CACHE=/nix/store/unsafe-cache \
        TT_METAL_LOGS_PATH="$runtime_logs" \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$runtime_inspector" \
        "$production_diagnostic_wrapper" ${lib.escapeShellArg diagnosticPreflightMode}
    expect_wrapper_failure diagnostic-missing-logs ${lib.escapeShellArg logsPathDiagnostic} \
      env -u TT_METAL_LOGS_PATH \
        TT_VISIBLE_DEVICES=${lib.escapeShellArg diagnosticVisibleDevice} \
        TT_METAL_CACHE="$runtime_cache" \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$runtime_inspector" \
        "$production_diagnostic_wrapper" ${lib.escapeShellArg diagnosticPreflightMode}
    expect_wrapper_failure diagnostic-relative-logs ${lib.escapeShellArg logsPathDiagnostic} \
      env TT_VISIBLE_DEVICES=${lib.escapeShellArg diagnosticVisibleDevice} \
        TT_METAL_CACHE="$runtime_cache" \
        TT_METAL_LOGS_PATH=relative-logs \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$runtime_inspector" \
        "$production_diagnostic_wrapper" ${lib.escapeShellArg diagnosticPreflightMode}
    expect_wrapper_failure diagnostic-store-logs ${lib.escapeShellArg logsPathDiagnostic} \
      env TT_VISIBLE_DEVICES=${lib.escapeShellArg diagnosticVisibleDevice} \
        TT_METAL_CACHE="$runtime_cache" \
        TT_METAL_LOGS_PATH=/nix/store/unsafe-logs \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$runtime_inspector" \
        "$production_diagnostic_wrapper" ${lib.escapeShellArg diagnosticPreflightMode}
    expect_wrapper_failure diagnostic-cache-file ${lib.escapeShellArg cacheCreationDiagnostic} \
      env TT_VISIBLE_DEVICES=${lib.escapeShellArg diagnosticVisibleDevice} \
        TT_METAL_CACHE="$cache_file" \
        TT_METAL_LOGS_PATH="$runtime_logs" \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$runtime_inspector" \
        "$production_diagnostic_wrapper" ${lib.escapeShellArg diagnosticPreflightMode}
    expect_wrapper_failure diagnostic-logs-file ${lib.escapeShellArg logsCreationDiagnostic} \
      env TT_VISIBLE_DEVICES=${lib.escapeShellArg diagnosticVisibleDevice} \
        TT_METAL_CACHE="$runtime_cache" \
        TT_METAL_LOGS_PATH="$logs_file" \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$runtime_inspector" \
        "$production_diagnostic_wrapper" ${lib.escapeShellArg diagnosticPreflightMode}
    expect_wrapper_failure diagnostic-non-loopback-inspector ${lib.escapeShellArg inspectorAddressDiagnostic} \
      env TT_VISIBLE_DEVICES=${lib.escapeShellArg diagnosticVisibleDevice} \
        TT_METAL_CACHE="$runtime_cache" \
        TT_METAL_LOGS_PATH="$runtime_logs" \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="0.0.0.0:${toString testInspectorPort}" \
        "$production_diagnostic_wrapper" ${lib.escapeShellArg diagnosticPreflightMode}
    expect_wrapper_failure diagnostic-low-inspector-port ${lib.escapeShellArg inspectorAddressDiagnostic} \
      env TT_VISIBLE_DEVICES=${lib.escapeShellArg diagnosticVisibleDevice} \
        TT_METAL_CACHE="$runtime_cache" \
        TT_METAL_LOGS_PATH="$runtime_logs" \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="${testInspectorHost}:${toString invalidLowInspectorPort}" \
        "$production_diagnostic_wrapper" ${lib.escapeShellArg diagnosticPreflightMode}
    expect_wrapper_failure diagnostic-high-inspector-port ${lib.escapeShellArg inspectorAddressDiagnostic} \
      env TT_VISIBLE_DEVICES=${lib.escapeShellArg diagnosticVisibleDevice} \
        TT_METAL_CACHE="$runtime_cache" \
        TT_METAL_LOGS_PATH="$runtime_logs" \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="${testInspectorHost}:${toString invalidHighInspectorPort}" \
        "$production_diagnostic_wrapper" ${lib.escapeShellArg diagnosticPreflightMode}
    expect_wrapper_failure data-movement-missing-visible-device ${lib.escapeShellArg diagnosticDeviceSelectionDiagnostic} \
      env -u TT_VISIBLE_DEVICES \
        TT_METAL_CACHE="$runtime_cache" \
        TT_METAL_LOGS_PATH="$runtime_logs" \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$runtime_inspector" \
        "$production_data_movement_wrapper" ${lib.escapeShellArg dataMovementPreflightMode}
    expect_wrapper_failure data-movement-wrong-visible-device ${lib.escapeShellArg diagnosticDeviceSelectionDiagnostic} \
      env TT_VISIBLE_DEVICES=${lib.escapeShellArg dataMovementWrongVisibleDevice} \
        TT_METAL_CACHE="$runtime_cache" \
        TT_METAL_LOGS_PATH="$runtime_logs" \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$runtime_inspector" \
        "$production_data_movement_wrapper" ${lib.escapeShellArg dataMovementPreflightMode}
    expect_wrapper_failure data-movement-missing-cache ${lib.escapeShellArg cachePathDiagnostic} \
      env -u TT_METAL_CACHE \
        TT_VISIBLE_DEVICES=${lib.escapeShellArg dataMovementVisibleDevice} \
        TT_METAL_LOGS_PATH="$runtime_logs" \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$runtime_inspector" \
        "$production_data_movement_wrapper" ${lib.escapeShellArg dataMovementPreflightMode}
    expect_wrapper_failure data-movement-relative-cache ${lib.escapeShellArg cachePathDiagnostic} \
      env TT_VISIBLE_DEVICES=${lib.escapeShellArg dataMovementVisibleDevice} \
        TT_METAL_CACHE=relative-cache \
        TT_METAL_LOGS_PATH="$runtime_logs" \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$runtime_inspector" \
        "$production_data_movement_wrapper" ${lib.escapeShellArg dataMovementPreflightMode}
    expect_wrapper_failure data-movement-store-cache ${lib.escapeShellArg cachePathDiagnostic} \
      env TT_VISIBLE_DEVICES=${lib.escapeShellArg dataMovementVisibleDevice} \
        TT_METAL_CACHE=/nix/store/unsafe-cache \
        TT_METAL_LOGS_PATH="$runtime_logs" \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$runtime_inspector" \
        "$production_data_movement_wrapper" ${lib.escapeShellArg dataMovementPreflightMode}
    expect_wrapper_failure data-movement-missing-logs ${lib.escapeShellArg logsPathDiagnostic} \
      env -u TT_METAL_LOGS_PATH \
        TT_VISIBLE_DEVICES=${lib.escapeShellArg dataMovementVisibleDevice} \
        TT_METAL_CACHE="$runtime_cache" \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$runtime_inspector" \
        "$production_data_movement_wrapper" ${lib.escapeShellArg dataMovementPreflightMode}
    expect_wrapper_failure data-movement-relative-logs ${lib.escapeShellArg logsPathDiagnostic} \
      env TT_VISIBLE_DEVICES=${lib.escapeShellArg dataMovementVisibleDevice} \
        TT_METAL_CACHE="$runtime_cache" \
        TT_METAL_LOGS_PATH=relative-logs \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$runtime_inspector" \
        "$production_data_movement_wrapper" ${lib.escapeShellArg dataMovementPreflightMode}
    expect_wrapper_failure data-movement-store-logs ${lib.escapeShellArg logsPathDiagnostic} \
      env TT_VISIBLE_DEVICES=${lib.escapeShellArg dataMovementVisibleDevice} \
        TT_METAL_CACHE="$runtime_cache" \
        TT_METAL_LOGS_PATH=/nix/store/unsafe-logs \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$runtime_inspector" \
        "$production_data_movement_wrapper" ${lib.escapeShellArg dataMovementPreflightMode}
    expect_wrapper_failure data-movement-cache-file ${lib.escapeShellArg cacheCreationDiagnostic} \
      env TT_VISIBLE_DEVICES=${lib.escapeShellArg dataMovementVisibleDevice} \
        TT_METAL_CACHE="$cache_file" \
        TT_METAL_LOGS_PATH="$runtime_logs" \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$runtime_inspector" \
        "$production_data_movement_wrapper" ${lib.escapeShellArg dataMovementPreflightMode}
    expect_wrapper_failure data-movement-logs-file ${lib.escapeShellArg logsCreationDiagnostic} \
      env TT_VISIBLE_DEVICES=${lib.escapeShellArg dataMovementVisibleDevice} \
        TT_METAL_CACHE="$runtime_cache" \
        TT_METAL_LOGS_PATH="$logs_file" \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$runtime_inspector" \
        "$production_data_movement_wrapper" ${lib.escapeShellArg dataMovementPreflightMode}
    expect_wrapper_failure data-movement-non-loopback-inspector ${lib.escapeShellArg inspectorAddressDiagnostic} \
      env TT_VISIBLE_DEVICES=${lib.escapeShellArg dataMovementVisibleDevice} \
        TT_METAL_CACHE="$runtime_cache" \
        TT_METAL_LOGS_PATH="$runtime_logs" \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="0.0.0.0:${toString testInspectorPort}" \
        "$production_data_movement_wrapper" ${lib.escapeShellArg dataMovementPreflightMode}
    expect_wrapper_failure data-movement-low-inspector-port ${lib.escapeShellArg inspectorAddressDiagnostic} \
      env TT_VISIBLE_DEVICES=${lib.escapeShellArg dataMovementVisibleDevice} \
        TT_METAL_CACHE="$runtime_cache" \
        TT_METAL_LOGS_PATH="$runtime_logs" \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="${testInspectorHost}:${toString invalidLowInspectorPort}" \
        "$production_data_movement_wrapper" ${lib.escapeShellArg dataMovementPreflightMode}
    expect_wrapper_failure data-movement-high-inspector-port ${lib.escapeShellArg inspectorAddressDiagnostic} \
      env TT_VISIBLE_DEVICES=${lib.escapeShellArg dataMovementVisibleDevice} \
        TT_METAL_CACHE="$runtime_cache" \
        TT_METAL_LOGS_PATH="$runtime_logs" \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="${testInspectorHost}:${toString invalidHighInspectorPort}" \
        "$production_data_movement_wrapper" ${lib.escapeShellArg dataMovementPreflightMode}
    expect_wrapper_failure unsafe-probe ${lib.escapeShellArg cachePathDiagnostic} \
      env -u TT_METAL_CACHE \
        TT_METAL_LOGS_PATH="$runtime_logs" \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$runtime_inspector" \
        "$out/bin/${probeCommand}" ${lib.escapeShellArg probeDeviceMode}
    expect_wrapper_failure unsafe-diagnostic ${lib.escapeShellArg cachePathDiagnostic} \
      env -u TT_METAL_CACHE \
        TT_VISIBLE_DEVICES=${lib.escapeShellArg diagnosticVisibleDevice} \
        TT_METAL_LOGS_PATH="$runtime_logs" \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$runtime_inspector" \
        "$production_diagnostic_wrapper" ${lib.escapeShellArg diagnosticDeviceMode}
    expect_wrapper_failure unsafe-data-movement ${lib.escapeShellArg cachePathDiagnostic} \
      env -u TT_METAL_CACHE \
        TT_VISIBLE_DEVICES=${lib.escapeShellArg dataMovementVisibleDevice} \
        TT_METAL_LOGS_PATH="$runtime_logs" \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$runtime_inspector" \
        "$production_data_movement_wrapper" ${lib.escapeShellArg dataMovementDeviceMode}

    # Positive and negative wrapper topology coverage for
    # r[verify onix.tenstorrent.native_runtime.ttwkv7.single_device_topology].
    for wrapped_command in \
      "$out/bin/${primaryCommand}" \
      ${wrappedProbeExecutable} \
      ${diagnosticRuntimeExecutable} \
      ${dataMovementRuntimeExecutable}; do
      grep -F "export TT_METAL_HOME='${metaliumRuntimeRoot}'" "$wrapped_command"
      grep -F "export TT_METAL_RUNTIME_ROOT='${metaliumRuntimeRoot}'" "$wrapped_command"
      grep -F ${lib.escapeShellArg "unset ${meshGraphDescriptorVariable}"} "$wrapped_command"
      if grep -F ${lib.escapeShellArg "export ${meshGraphDescriptorVariable}"} "$wrapped_command"; then
        echo "ttWKV7 wrapper must not export a mesh graph descriptor" >&2
        exit 1
      fi
    done

    # Negative no-device CLI coverage for
    # r[verify onix.tenstorrent.native_runtime.ttwkv7.package].
    invalid_mode_log="$(mktemp)"
    if "$out/bin/${primaryCommand}" ${lib.escapeShellArg invalidMode} >"$invalid_mode_log" 2>&1; then
      echo "ttWKV7 unexpectedly accepted invalid mode '${invalidMode}'" >&2
      exit 1
    else
      invalid_mode_status="$?"
    fi
    test "$invalid_mode_status" -eq ${toString invalidModeExitStatus}
    grep -F ${lib.escapeShellArg usageDiagnostic} "$invalid_mode_log"

    runHook postInstallCheck
  '';

  passthru = {
    inherit architectureCheck binaries kernels;
  };

  meta = {
    description = "Standalone RWKV-7 WKV7 operator demo and test bench for TT-Metalium";
    homepage = "https://github.com/marty1885/ttWKV7";
    # Upstream has no declared license at the pinned revision.
    license = lib.licenses.unfree;
    mainProgram = primaryCommand;
    platforms = [ "x86_64-linux" ];
  };
}
