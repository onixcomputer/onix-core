{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  ninja,
  makeWrapper,
  fmt,
  nlohmann_json,
  spdlog,
  enchantum,
  tt-logger,
  tt-metal,
}:
let
  upstreamRevision = "84d8b6a44729cc358f163e7ab9614b0a1b8ddc09";
  upstreamSourceHash = "sha256-zhGN99BPbVES7jVK/tKWeNeNbsDaU2yw/7XUg7YzEyw=";
  metaliumRuntimeRoot = "${tt-metal}/libexec/tt-metalium";
  packageKernelDirectory = "$out/share/ttwkv7/kernels";
  packageExecutable = "$out/libexec/ttwkv7/wkv7";
  probeExecutable = "$out/libexec/ttwkv7/wkv7-constant-probe";
  primaryCommand = "wkv7";
  aliasCommand = "ttwkv7";
  probeCommand = "wkv7-constant-probe";
  probeSelfTestMode = "self-test";
  invalidMode = "invalid-mode";
  invalidModeExitStatus = 2;
  usageDiagnostic = "usage:";
  meshGraphDescriptorVariable = "TT_MESH_GRAPH_DESC_PATH";
  architectureSfpuStart = "_llk_math_eltwise_sfpu_start_(";
  blackholeSfpuDone = "_llk_math_eltwise_sfpu_done_with_addrmod_reset_();";
  wormholeSfpuDone = "_llk_math_eltwise_sfpu_done_();";
  blackholeBranch = "#if defined(ARCH_BLACKHOLE)";
  wormholeBranch = "#elif defined(ARCH_WORMHOLE)";
  wormholeOnlyAddrModCall = "math::set_addr_mod_base();";
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
stdenv.mkDerivation {
  pname = "ttwkv7";
  version = "unstable-2026-06-22";

  # r[impl onix.tenstorrent.native_runtime.ttwkv7.package]
  src = fetchFromGitHub {
    owner = "marty1885";
    repo = "ttWKV7";
    rev = upstreamRevision;
    hash = upstreamSourceHash;
  };

  patches = [
    ./use-installed-metalium.patch
    ./use-architecture-sfpu-helpers.patch
  ];

  postPatch = ''
    cp ${./constant-tile-probe.cpp} constant-tile-probe.cpp
    cp ${./constant-tile-probe-compute.cpp} kernels/ttwkv7_constant_tile_compute.cpp
    cp ${./constant-tile-probe-writer.cpp} kernels/ttwkv7_constant_tile_writer.cpp
  '';

  strictDeps = true;
  nativeBuildInputs = [
    cmake
    ninja
    makeWrapper
  ];
  buildInputs = [
    enchantum
    fmt
    nlohmann_json
    spdlog
    tt-logger
    tt-metal
  ];

  postInstall = ''
    makeWrapper ${packageExecutable} "$out/bin/${primaryCommand}" \
      --set TT_METAL_HOME ${lib.escapeShellArg metaliumRuntimeRoot} \
      --set TT_METAL_RUNTIME_ROOT ${lib.escapeShellArg metaliumRuntimeRoot} \
      --unset ${meshGraphDescriptorVariable} \
      --chdir "$out/share/ttwkv7"
    makeWrapper ${probeExecutable} "$out/bin/${probeCommand}" \
      --set TT_METAL_HOME ${lib.escapeShellArg metaliumRuntimeRoot} \
      --set TT_METAL_RUNTIME_ROOT ${lib.escapeShellArg metaliumRuntimeRoot} \
      --unset ${meshGraphDescriptorVariable} \
      --chdir "$out/share/ttwkv7"
    ln -s ${primaryCommand} "$out/bin/${aliasCommand}"
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    # Positive package-layout coverage for
    # r[verify onix.tenstorrent.native_runtime.ttwkv7.package].
    test -x "$out/bin/${primaryCommand}"
    test -x "$out/bin/${aliasCommand}"
    test -x "$out/bin/${probeCommand}"
    test -x ${packageExecutable}
    test -x ${probeExecutable}
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

    # Positive and negative wrapper topology coverage for
    # r[verify onix.tenstorrent.native_runtime.ttwkv7.single_device_topology].
    for wrapped_command in ${
      lib.escapeShellArgs [
        primaryCommand
        probeCommand
      ]
    }; do
      grep -F ${lib.escapeShellArg "unset ${meshGraphDescriptorVariable}"} "$out/bin/$wrapped_command"
      if grep -F ${lib.escapeShellArg "export ${meshGraphDescriptorVariable}"} "$out/bin/$wrapped_command"; then
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

  meta = {
    description = "Standalone RWKV-7 WKV7 operator demo and test bench for TT-Metalium";
    homepage = "https://github.com/marty1885/ttWKV7";
    # Upstream has no declared license at the pinned revision.
    license = lib.licenses.unfree;
    mainProgram = primaryCommand;
    platforms = [ "x86_64-linux" ];
  };
}
