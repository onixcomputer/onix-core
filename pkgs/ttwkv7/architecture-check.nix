{
  lib,
  runCommand,
  writeText,
  kernels,
  source,
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
  runnerSource = "${source.upstream}/wkv7_runner.cpp";
  scratchCbIndex = 22;
  decodeScratchPageCount = 2;
  minimumChunkedScratchPageCount = 32;
  tileEdgeElements = 32;
  scratchCbName = "c_dram_read_scratch";
  scratchCbDeclaration = "${scratchCbName} = ${toString scratchCbIndex};";
  scratchReserve = "cb_reserve_back(${scratchCbName}, 1);";
  scratchWritePointer = "get_write_ptr(${scratchCbName})";
  stackScratchDeclaration = "uint32_t dram_read_scratch[";
  stackScratchCast = "reinterpret_cast<uint32_t>(dram_read_scratch)";
  productionReaderSources = [
    "wkv7_reader.cpp"
    "wkv7_decodeL_reader.cpp"
  ];
  hostScratchAllocationPatterns = [
    "MakeCB(prog, core, CB::c_${toString scratchCbIndex}, std::max((uint32_t)cl, ${toString minimumChunkedScratchPageCount}u));"
    "MakeCB(prog, core, CB::c_${toString scratchCbIndex}, ${toString decodeScratchPageCount}u);"
  ];
  kernelSources = [
    "wkv7_chunked_compute.cpp"
    "wkv7_decodeL_compute.cpp"
    "ttwkv7_constant_tile_compute.cpp"
  ];
  # r[verify onix.tenstorrent.native_runtime.ttwkv7.reader_gather_alignment]
  dataMovementKernelSpecs = [
    {
      source = "wkv7_reader.cpp";
      processorName = "brisc";
      firmwareSource = "${metaliumRoot}/tt_metal/hw/firmware/src/tt-1xx/brisck.cc";
      processorIndex = 0;
      nocIndex = 0;
      processorDefinition = "COMPILE_FOR_BRISC";
    }
    {
      source = "wkv7_decodeL_reader.cpp";
      processorName = "brisc";
      firmwareSource = "${metaliumRoot}/tt_metal/hw/firmware/src/tt-1xx/brisck.cc";
      processorIndex = 0;
      nocIndex = 0;
      processorDefinition = "COMPILE_FOR_BRISC";
    }
    {
      source = "ttwkv7_data_movement_capture_source_reader.cpp";
      processorName = "brisc";
      firmwareSource = "${metaliumRoot}/tt_metal/hw/firmware/src/tt-1xx/brisck.cc";
      processorIndex = 0;
      nocIndex = 0;
      processorDefinition = "COMPILE_FOR_BRISC";
    }
    {
      source = "ttwkv7_data_movement_source_reader.cpp";
      processorName = "brisc";
      firmwareSource = "${metaliumRoot}/tt_metal/hw/firmware/src/tt-1xx/brisck.cc";
      processorIndex = 0;
      nocIndex = 0;
      processorDefinition = "COMPILE_FOR_BRISC";
    }
    {
      source = "ttwkv7_data_movement_capture_writer.cpp";
      processorName = "ncrisc";
      firmwareSource = "${metaliumRoot}/tt_metal/hw/firmware/src/tt-1xx/ncrisck.cc";
      processorIndex = 1;
      nocIndex = 1;
      processorDefinition = "COMPILE_FOR_NCRISC";
    }
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
      dataMovementBankDefinitions = [ "LOG_BASE_2_OF_NUM_DRAM_BANKS=3" ];
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
      dataMovementBankDefinitions = [
        "IS_NOT_POW2_NUM_DRAM_BANKS=1"
        "LOG_BASE_2_OF_NUM_L1_BANKS=6"
      ];
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
  baseFlags = commonCompilerFlags ++ map mkIncludeFlag commonIncludeDirectories;
  commonFlags = baseFlags ++ map mkDefinitionFlag commonDefinitions;
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
  mkDataMovementScaffold =
    {
      buildDirectory,
      kernelSource,
    }:
    ''
      mkdir -p "${buildDirectory}"
      cp ${lib.escapeShellArg architectureCheckDescriptors} "${buildDirectory}/chlkc_descriptors.h"
      printf '%s\n' \
        '#include "${kernelRoot}/${kernelSource}"' \
        >"${buildDirectory}/kernel_includes.hpp"
    '';
  mkDataMovementCompile =
    architecture:
    let
      architectureFlags = mkArchitectureFlags architecture;
      compileKernel =
        kernelSpec:
        let
          objectName = lib.removeSuffix ".cpp" kernelSpec.source;
          buildDirectory = "$PWD/build/${architecture.name}/${objectName}-${kernelSpec.processorName}";
          processorDefinitions = [
            "TENSIX_FIRMWARE"
            "LOCAL_MEM_EN=0"
            "PCIE_NOC_X=${toString compileOnlyPcieNocX}"
            "PCIE_NOC_Y=${toString compileOnlyPcieNocY}"
            "DISPATCH_MESSAGE_ADDR=${toString compileOnlyDispatchMessageAddress}"
            "PROCESSOR_INDEX=${toString kernelSpec.processorIndex}"
            kernelSpec.processorDefinition
            "NOC_INDEX=${toString kernelSpec.nocIndex}"
            "NOC_MODE=0"
            "KERNEL_BUILD"
            "FULL_KERNEL_NAME=\"ttwkv7-data-movement-check/\""
            "KERNEL_COMPILE_TIME_ARGS=1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1"
          ];
          dataMovementFlags =
            baseFlags
            ++ architectureFlags
            ++ map mkDefinitionFlag architecture.dataMovementBankDefinitions
            ++ map mkDefinitionFlag processorDefinitions;
        in
        ''
          echo "compiling ttWKV7 ${architecture.name} data-movement kernel: ${kernelSpec.source} (${kernelSpec.processorName})"
          ${mkDataMovementScaffold {
            inherit buildDirectory;
            kernelSource = kernelSpec.source;
          }}
          (
            cd "${buildDirectory}"
            ${lib.escapeShellArgs ([ compiler ] ++ dataMovementFlags)} \
              -I. \
              -c ${lib.escapeShellArg kernelSpec.firmwareSource} \
              -o "$out/${architecture.name}/${objectName}-${kernelSpec.processorName}.o"
          )
        '';
    in
    lib.concatMapStringsSep "\n" compileKernel dataMovementKernelSpecs;
  positiveCompileCommands = lib.concatStringsSep "\n" (
    map mkArchitectureCompile architectures ++ map mkDataMovementCompile architectures
  );
  expectedObjectCount =
    (builtins.length kernelSources + builtins.length dataMovementKernelSpecs)
    * builtins.length architectures;
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
  for kernel_source in ${
    lib.escapeShellArgs (map (kernelSpec: kernelSpec.source) dataMovementKernelSpecs)
  }; do
    test -f ${lib.escapeShellArg kernelRoot}/"$kernel_source"
  done
  for firmware_source in ${
    lib.escapeShellArgs (map (kernelSpec: kernelSpec.firmwareSource) dataMovementKernelSpecs)
  }; do
    test -f "$firmware_source"
  done
  test -f ${lib.escapeShellArg runnerSource}

  validate_reader_l1_scratch() {
    local reader_source="$1"

    grep -Fq ${lib.escapeShellArg scratchCbDeclaration} "$reader_source" || return 1
    grep -Fq '#if defined(ARCH_BLACKHOLE)' "$reader_source" || return 1
    grep -Fq ${lib.escapeShellArg scratchReserve} "$reader_source" || return 1
    grep -Fq ${lib.escapeShellArg scratchWritePointer} "$reader_source" || return 1
    grep -Fq 'ttwkv7::aligned_l1_scratch_address' "$reader_source" || return 1
    grep -Fq 'constexpr uint32_t dram_read_scratch_l1_address = 0;' "$reader_source" || return 1
    ! grep -Fq ${lib.escapeShellArg stackScratchDeclaration} "$reader_source" || return 1
    ! grep -Fq ${lib.escapeShellArg stackScratchCast} "$reader_source" || return 1
  }

  for reader_source in ${lib.escapeShellArgs productionReaderSources}; do
    validate_reader_l1_scratch ${lib.escapeShellArg kernelRoot}/"$reader_source"
  done

  grep -Fq 'constexpr uint32_t TW = ${toString tileEdgeElements}, TH = ${toString tileEdgeElements};' ${lib.escapeShellArg runnerSource}
  grep -Fq 'const uint32_t ts = sizeof(bfloat16) * TW * TH;' ${lib.escapeShellArg runnerSource}
  grep -Fq '.set_page_size(cb, ts);' ${lib.escapeShellArg runnerSource}
  for allocation_pattern in ${lib.escapeShellArgs hostScratchAllocationPatterns}; do
    test "$(grep -Fc "$allocation_pattern" ${lib.escapeShellArg runnerSource})" -eq 1
  done

  for forbidden_alias_operation in \
    'cb_reserve_back(c_selstage' \
    'cb_wait_front(c_selstage' \
    'cb_push_back(c_selstage' \
    'cb_pop_front(c_selstage' \
    'get_write_ptr(c_selstage'; do
    if grep -RFq "$forbidden_alias_operation" ${lib.escapeShellArg kernelRoot}; then
      echo "CB${toString scratchCbIndex} selection-stage alias unexpectedly participates in kernel flow: $forbidden_alias_operation" >&2
      exit 1
    fi
  done

  invalid_stack_reader="$PWD/invalid-stack-reader.cpp"
  cp ${lib.escapeShellArg kernelRoot}/${builtins.head productionReaderSources} "$invalid_stack_reader"
  chmod u+w "$invalid_stack_reader"
  printf '%s\n' ${lib.escapeShellArg stackScratchDeclaration} >>"$invalid_stack_reader"
  if validate_reader_l1_scratch "$invalid_stack_reader" >/dev/null 2>&1; then
    echo "ttWKV7 reader scratch check unexpectedly accepted process-local stack scratch" >&2
    exit 1
  fi

  missing_reserve_reader="$PWD/missing-reserve-reader.cpp"
  cp ${lib.escapeShellArg kernelRoot}/${builtins.head productionReaderSources} "$missing_reserve_reader"
  chmod u+w "$missing_reserve_reader"
  substituteInPlace "$missing_reserve_reader" \
    --replace-fail ${lib.escapeShellArg scratchReserve} '// invalid fixture removed the scratch reservation'
  if validate_reader_l1_scratch "$missing_reserve_reader" >/dev/null 2>&1; then
    echo "ttWKV7 reader scratch check unexpectedly accepted a missing CB reservation" >&2
    exit 1
  fi

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
