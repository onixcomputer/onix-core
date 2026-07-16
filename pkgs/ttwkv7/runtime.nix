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
  primaryCommand = "wkv7";
  aliasCommand = "ttwkv7";
  probeCommand = "wkv7-constant-probe";
  diagnosticCommand = "wkv7-diagnose";
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
    substitute ${./probe-wrapper.sh} "$out/bin/${probeCommand}" \
      --replace-fail '@probeExecutable@' "$out/libexec/ttwkv7/wkv7-constant-probe-runtime"
    substitute ${./diagnostic-wrapper.sh} "$out/bin/${diagnosticCommand}" \
      --replace-fail '@diagnosticExecutable@' "$out/libexec/ttwkv7/wkv7-diagnostic-runtime"
    chmod +x "$out/bin/${probeCommand}" "$out/bin/${diagnosticCommand}"
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
    test -x ${packageExecutable}
    test -x ${probeExecutable}
    test -x ${wrappedProbeExecutable}
    test -x ${diagnosticRuntimeExecutable}

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

    for kernel_source in ${lib.escapeShellArgs requiredKernelSources}; do
      test -f "${packageKernelDirectory}/$kernel_source"
    done

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

    # Positive and negative wrapper topology coverage for
    # r[verify onix.tenstorrent.native_runtime.ttwkv7.single_device_topology].
    for wrapped_command in \
      "$out/bin/${primaryCommand}" \
      ${wrappedProbeExecutable} \
      ${diagnosticRuntimeExecutable}; do
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
