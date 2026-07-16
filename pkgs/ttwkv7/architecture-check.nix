{
  lib,
  runCommand,
  writeText,
  kernels,
  tt-metal,
}:
let
  metaliumRoot = "${tt-metal}/libexec/tt-metalium";
  compiler = "${metaliumRoot}/runtime/sfpi/compiler/bin/riscv-tt-elf-g++";
  trisckSource = "${metaliumRoot}/tt_metal/hw/firmware/src/tt-1xx/trisck.cc";
  architectureCheckDescriptors = writeText "ttwkv7-architecture-check-descriptors.h" (
    builtins.readFile ./architecture-check-descriptors.h
  );
  kernelRoot = "${kernels}/share/ttwkv7/kernels";
  kernelSources = [
    "wkv7_chunked_compute.cpp"
    "wkv7_decodeL_compute.cpp"
    "ttwkv7_constant_tile_compute.cpp"
  ];
  commonCompilerFlags = [
    "-O3"
    "-std=c++17"
    "-ftt-nttp"
    "-ftt-constinit"
    "-ftt-consteval"
    "-ftt-no-dyninit"
    "-flto=auto"
    "-ffast-math"
    "-fno-exceptions"
    "-fno-rtti"
    "-fno-use-cxa-atexit"
    "-g"
    "-MMD"
    "-Wall"
    "-Werror"
    "-Wno-error=deprecated-declarations"
    "-Wno-error=multistatement-macros"
    "-Wno-error=parentheses"
    "-Wno-error=unused-but-set-variable"
    "-Wno-unused-variable"
    "-Wno-unused-function"
  ];
  commonIncludeDirectories = [
    metaliumRoot
    "${metaliumRoot}/ttnn"
    "${metaliumRoot}/ttnn/cpp"
    "${metaliumRoot}/tt_metal"
    "${metaliumRoot}/tt_metal/hw/inc"
    "${metaliumRoot}/tt_metal/tt-llk/common"
    "${metaliumRoot}/tt_metal/hostdevcommon/api"
    "${metaliumRoot}/tt_metal/api"
    "${metaliumRoot}/runtime/sfpi/include"
    "${metaliumRoot}/tt_metal/hw/firmware/src/tt-1xx"
  ];
  compileOnlyPcieNocX = 0;
  compileOnlyPcieNocY = 3;
  compileOnlyDispatchMessageAddress = 4290184248;
  mathProcessorIndex = 3;
  commonDefinitions = [
    "TENSIX_FIRMWARE"
    "LOCAL_MEM_EN=0"
    "PROCESSOR_INDEX=${toString mathProcessorIndex}"
    "UCK_CHLKC_MATH"
    "COMPILE_FOR_TRISC=1"
    "KERNEL_BUILD"
    "NOC_INDEX=0"
    "PCIE_NOC_X=${toString compileOnlyPcieNocX}"
    "PCIE_NOC_Y=${toString compileOnlyPcieNocY}"
    "DISPATCH_MESSAGE_ADDR=${toString compileOnlyDispatchMessageAddress}"
    "FULL_KERNEL_NAME=\"ttwkv7-architecture-check/\""
    "KERNEL_COMPILE_TIME_ARGS=1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1"
  ];
  architectures = [
    {
      name = "blackhole";
      compilerCpu = "tt-bh-tensix";
      architectureDefinition = "ARCH_BLACKHOLE";
      numDramBanks = 8;
      numL1Banks = 130;
      extraDefinitions = [ "IS_NOT_POW2_NUM_L1_BANKS=1" ];
      includeDirectories = [
        "${metaliumRoot}/tt_metal/hw/ckernels/blackhole/metal/common"
        "${metaliumRoot}/tt_metal/hw/ckernels/blackhole/metal/llk_io"
        "${metaliumRoot}/tt_metal/hw/inc/internal/tt-1xx"
        "${metaliumRoot}/tt_metal/hw/inc/internal/tt-1xx/blackhole"
        "${metaliumRoot}/tt_metal/hw/inc/internal/tt-1xx/blackhole/blackhole_defines"
        "${metaliumRoot}/tt_metal/hw/inc/internal/tt-1xx/blackhole/noc"
        "${metaliumRoot}/tt_metal/tt-llk/tt_llk_blackhole/common/inc"
        "${metaliumRoot}/tt_metal/tt-llk/tt_llk_blackhole/llk_lib"
        "${metaliumRoot}/tt_metal/hw/ckernels/blackhole/metal/llk_api"
        "${metaliumRoot}/tt_metal/hw/ckernels/blackhole/metal/llk_api/llk_sfpu"
      ];
    }
    {
      name = "wormhole";
      compilerCpu = "tt-wh-tensix";
      architectureDefinition = "ARCH_WORMHOLE";
      numDramBanks = 12;
      numL1Banks = 64;
      extraDefinitions = [ ];
      includeDirectories = [
        "${metaliumRoot}/tt_metal/hw/ckernels/wormhole_b0/metal/common"
        "${metaliumRoot}/tt_metal/hw/ckernels/wormhole_b0/metal/llk_io"
        "${metaliumRoot}/tt_metal/hw/inc/internal/tt-1xx"
        "${metaliumRoot}/tt_metal/hw/inc/internal/tt-1xx/wormhole"
        "${metaliumRoot}/tt_metal/hw/inc/internal/tt-1xx/wormhole/wormhole_b0_defines"
        "${metaliumRoot}/tt_metal/hw/inc/internal/tt-1xx/wormhole/noc"
        "${metaliumRoot}/tt_metal/tt-llk/tt_llk_wormhole_b0/common/inc"
        "${metaliumRoot}/tt_metal/tt-llk/tt_llk_wormhole_b0/llk_lib"
        "${metaliumRoot}/tt_metal/hw/ckernels/wormhole_b0/metal/llk_api"
        "${metaliumRoot}/tt_metal/hw/ckernels/wormhole_b0/metal/llk_api/llk_sfpu"
      ];
    }
  ];
  mkIncludeFlag = directory: "-I${directory}";
  mkDefinitionFlag = definition: "-D${definition}";
  commonFlags =
    commonCompilerFlags
    ++ map mkIncludeFlag commonIncludeDirectories
    ++ map mkDefinitionFlag commonDefinitions;
  mkArchitectureFlags =
    architecture:
    [ "-mcpu=${architecture.compilerCpu}" ]
    ++ map mkIncludeFlag architecture.includeDirectories
    ++ map mkDefinitionFlag (
      architecture.extraDefinitions
      ++ [
        architecture.architectureDefinition
        "NUM_DRAM_BANKS=${toString architecture.numDramBanks}"
        "NUM_L1_BANKS=${toString architecture.numL1Banks}"
      ]
    );
  mkKernelScaffold =
    {
      buildDirectory,
      kernelSource,
    }:
    ''
      mkdir -p "${buildDirectory}/trisc1"
      cp ${lib.escapeShellArg architectureCheckDescriptors} "${buildDirectory}/chlkc_descriptors.h"
      printf '%s\n' '#define NOC_MODE 0' >"${buildDirectory}/defines_generated.h"
      printf '%s\n' \
        '#define TRISC_MATH' \
        '#include "defines_generated.h"' \
        '#include "${kernelRoot}/${kernelSource}"' \
        >"${buildDirectory}/chlkc_math.cpp"
    '';
  mkArchitectureCompile =
    architecture:
    let
      architectureFlags = mkArchitectureFlags architecture;
      compileKernel =
        kernelSource:
        let
          objectName = lib.removeSuffix ".cpp" kernelSource;
          buildDirectory = "$PWD/build/${architecture.name}/${objectName}";
        in
        ''
          echo "compiling ttWKV7 ${architecture.name} kernel: ${kernelSource}"
          ${mkKernelScaffold { inherit buildDirectory kernelSource; }}
          (
            cd "${buildDirectory}/trisc1"
            ${lib.escapeShellArgs ([ compiler ] ++ commonFlags ++ architectureFlags)} \
              -I. -I.. \
              -c ${lib.escapeShellArg trisckSource} \
              -o "$out/${architecture.name}/${objectName}.o"
          )
        '';
    in
    ''
      mkdir -p "$out/${architecture.name}"
      ${lib.concatMapStringsSep "\n" compileKernel kernelSources}
    '';
  positiveCompileCommands = lib.concatMapStringsSep "\n" mkArchitectureCompile architectures;
  expectedObjectCount = builtins.length kernelSources * builtins.length architectures;
  unsupportedArchitectureDiagnostic = "ttWKV7 constant generation requires a reviewed SFPU finalizer";
  negativeCompileSource = builtins.head kernelSources;
  negativeArchitecture = builtins.elemAt architectures 1;
  negativeBuildDirectory = "$PWD/build/unsupported-architecture";
  negativeArchitectureFlags = [
    "-mcpu=${negativeArchitecture.compilerCpu}"
  ]
  ++ map mkIncludeFlag negativeArchitecture.includeDirectories
  ++ map mkDefinitionFlag (
    negativeArchitecture.extraDefinitions
    ++ [
      "NUM_DRAM_BANKS=${toString negativeArchitecture.numDramBanks}"
      "NUM_L1_BANKS=${toString negativeArchitecture.numL1Banks}"
    ]
  );
in
# r[verify onix.tenstorrent.native_runtime.ttwkv7.fast_iteration]
runCommand "ttwkv7-architecture-check" { } ''
  set -euo pipefail

  test -x ${lib.escapeShellArg compiler}
  test -f ${lib.escapeShellArg trisckSource}
  test -f ${lib.escapeShellArg architectureCheckDescriptors}
  for kernel_source in ${lib.escapeShellArgs kernelSources}; do
    test -f ${lib.escapeShellArg kernelRoot}/"$kernel_source"
  done

  ${positiveCompileCommands}

  actual_object_count="$(find "$out" -type f -name '*.o' -print | wc -l)"
  test "$actual_object_count" -eq ${toString expectedObjectCount}

  ${mkKernelScaffold {
    buildDirectory = negativeBuildDirectory;
    kernelSource = negativeCompileSource;
  }}
  negative_log="$PWD/unsupported-architecture.log"
  if (
    cd "${negativeBuildDirectory}/trisc1"
    ${lib.escapeShellArgs ([ compiler ] ++ commonFlags ++ negativeArchitectureFlags)} \
      -I. -I.. \
      -c ${lib.escapeShellArg trisckSource} \
      -o "$PWD/unsupported-architecture.o"
  ) >"$negative_log" 2>&1; then
    echo "ttWKV7 architecture check unexpectedly accepted a compute kernel without an architecture define" >&2
    exit 1
  fi
  grep -Fq ${lib.escapeShellArg unsupportedArchitectureDiagnostic} "$negative_log"
  test ! -e "${negativeBuildDirectory}/trisc1/unsupported-architecture.o"
''
