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
  primaryCommand = "wkv7";
  aliasCommand = "ttwkv7";
  probeCommand = "wkv7-constant-probe";
  probeSelfTestMode = "self-test";
  probePreflightMode = "validate-runtime";
  probeDeviceMode = "probe";
  probeForwardedArgument = "no-device-probe-argument";
  invalidMode = "invalid-mode";
  invalidModeExitStatus = 2;
  wrapperFailureStatus = 1;
  usageDiagnostic = "usage:";
  preflightPassDiagnostic = "ttWKV7 runtime state preflight: PASS";
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
    substitute ${./probe-wrapper.sh} "$out/bin/${probeCommand}" \
      --replace-fail '@probeExecutable@' ${lib.escapeShellArg wrappedProbeExecutable}
    chmod +x "$out/bin/${probeCommand}"
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
    test -x ${packageExecutable}
    test -x ${probeExecutable}
    test -x ${wrappedProbeExecutable}
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
        ${lib.escapeShellArg probeForwardedArgument} \
      >"$runtime_state_root/fake-probe.log"
    test "$(cat "$runtime_state_root/fake-probe.log")" = ${lib.escapeShellArg probeForwardedArgument}

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
    expect_wrapper_failure unsafe-probe ${lib.escapeShellArg cachePathDiagnostic} \
      env -u TT_METAL_CACHE \
        TT_METAL_LOGS_PATH="$runtime_logs" \
        TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS="$runtime_inspector" \
        "$out/bin/${probeCommand}" ${lib.escapeShellArg probeDeviceMode}

    # Positive and negative wrapper topology coverage for
    # r[verify onix.tenstorrent.native_runtime.ttwkv7.single_device_topology].
    for wrapped_command in "$out/bin/${primaryCommand}" ${wrappedProbeExecutable}; do
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
