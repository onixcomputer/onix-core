# Build all machine configurations as nix flake checks.
# Catches eval/build failures in CI without deploying.
#
# machinesPerSystem is derived from the `system` field in
# inventory/core/machines.ncl — no manual list to maintain.
{
  self,
  lib,
  pkgs,
  system,
  ...
}:
let
  plugins = self.packages.x86_64-linux.wasm-plugins;
  wasm = import ../lib/wasm.nix { inherit plugins; };
  machinesDef = (wasm.evalNickelFile ../inventory/core/machines.ncl).machines;

  brittonDesktopName = "britton-desktop";
  requiredAcceleratorTag = "tenstorrent";
  forbiddenAcceleratorTag = "nvidia";
  tenstorrentVendorId = "1e52";
  nvidiaVendorId = "10de";
  expectedTenstorrentDeviceCount = 2;
  requiredGraphicsDriver = "amdgpu";
  forbiddenInitrdModule = "nvidia";
  removedNvidiaServiceName = "docker-sglang-diffusion-krea2-britton-desktop";
  vibeThinkerServiceName = "llamacpp-server-vibethinker-britton-desktop";
  ttBenchmarkServiceName = "tt-vibethinker-benchmark";
  ttBenchmarkCommandName = "tt-vibethinker-bench";
  ttBenchmarkStateDirectory = ttBenchmarkServiceName;
  ttBenchmarkStateDir = "/var/lib/${ttBenchmarkStateDirectory}";
  ttBenchmarkCacheDir = "/var/cache/${ttBenchmarkServiceName}";
  ttBenchmarkLogsDir = "/var/log/${ttBenchmarkServiceName}";
  supraRouterServiceName = "llamacpp-server-supra-router";
  llamaContainerName = "tt-inference-server-llama-3-1-8b-instruct-p150";
  llamaServiceName = "docker-${llamaContainerName}";
  llamaGeneratorName = llamaContainerName;
  requiredEndpointServices = [
    vibeThinkerServiceName
    supraRouterServiceName
    llamaServiceName
  ];
  requiredMetaliumServices = [ vibeThinkerServiceName ];
  metaliumTraceEnvironmentVariable = "GGML_METALIUM_TRACE";
  metaliumTraceDisabledEnvironmentValue = "0";
  validatedMetaliumWorkerThreads = 8;
  metaliumGenerationThreadsArgument = "--threads ${toString validatedMetaliumWorkerThreads}";
  metaliumBatchThreadsArgument = "--threads-batch ${toString validatedMetaliumWorkerThreads}";
  validatedSupraCpuThreads = 4;
  supraCpuGenerationThreadsArgument = "--threads ${toString validatedSupraCpuThreads}";
  supraCpuBatchThreadsArgument = "--threads-batch ${toString validatedSupraCpuThreads}";
  cpuOnlyGpuLayersArgument = "--gpu-layers 0";
  metaliumPackageNameFragment = "llama-cpp-metalium";
  llamaModel = "meta-llama/Llama-3.1-8B-Instruct";
  llamaDevice = "p150";
  llamaPhysicalDeviceId = 1;
  llamaDevicePath = "/dev/tenstorrent/${toString llamaPhysicalDeviceId}";
  llamaApiPort = 8000;
  llamaLoopbackHost = "127.0.0.1";
  llamaImage = "ghcr.io/tenstorrent/tt-inference-server/vllm-tt-metal-src-release-ubuntu-22.04-amd64:0.18.0-c49bb76-6b4a3a7@sha256:6aee48978be401c0a86cb1761c4d64af818df8380bc7b27c1018d704518545ff";
  ttMetaliumToolsUrl = "https://docs.tenstorrent.com/tt-metal/latest/tt-metalium/tools/index.html";
  brittonDesktopTags = machinesDef.${brittonDesktopName}.tags;
  brittonDesktopFacter = builtins.fromJSON (
    builtins.readFile ../machines/britton-desktop/facter.json
  );
  brittonDesktopPciDevices = brittonDesktopFacter.hardware.pci;
  brittonDesktopGraphicsDrivers = map (
    device: device.driver_module
  ) brittonDesktopFacter.hardware.graphics_card;
  countPciVendor =
    vendorId:
    builtins.length (builtins.filter (device: device.vendor.hex == vendorId) brittonDesktopPciDevices);
  tenstorrentDeviceCount = countPciVendor tenstorrentVendorId;
  nvidiaDeviceCount = countPciVendor nvidiaVendorId;
  brittonDesktopConfig = self.nixosConfigurations.${brittonDesktopName}.config;
  brittonDesktopServices = brittonDesktopConfig.systemd.services;
  tenstorrentHostGuide = brittonDesktopConfig.environment.etc."tenstorrent/README.md".text;
  hasRequiredAccelerator = lib.elem requiredAcceleratorTag brittonDesktopTags;
  hasForbiddenAccelerator = lib.elem forbiddenAcceleratorTag brittonDesktopTags;
  hasRequiredGraphicsDriver = lib.elem requiredGraphicsDriver brittonDesktopGraphicsDrivers;
  hasForbiddenInitrdModule = lib.elem forbiddenInitrdModule brittonDesktopConfig.boot.initrd.kernelModules;
  hasRemovedNvidiaService = builtins.hasAttr removedNvidiaServiceName brittonDesktopServices;
  missingEndpointServices = builtins.filter (
    serviceName: !(builtins.hasAttr serviceName brittonDesktopServices)
  ) requiredEndpointServices;
  missingMetaliumServices = builtins.filter (
    serviceName: !(builtins.hasAttr serviceName brittonDesktopServices)
  ) requiredMetaliumServices;
  serviceEnvironmentValue =
    serviceName: variableName:
    brittonDesktopServices.${serviceName}.environment.${variableName} or null;
  vibeThinkerTraceEnvironmentValue = serviceEnvironmentValue vibeThinkerServiceName metaliumTraceEnvironmentVariable;
  keepsRegressedVibeThinkerTraceDisabled =
    vibeThinkerTraceEnvironmentValue == metaliumTraceDisabledEnvironmentValue;
  vibeThinkerWarmupCommand = brittonDesktopServices.${vibeThinkerServiceName}.postStart or null;
  keepsVibeThinkerWarmupDisabled = vibeThinkerWarmupCommand == null || vibeThinkerWarmupCommand == "";
  keepsVibeThinkerRunningAcrossSwitch =
    !(brittonDesktopServices.${vibeThinkerServiceName}.restartIfChanged or true);
  vibeThinkerMeshEnvironmentValue = serviceEnvironmentValue vibeThinkerServiceName "GGML_METALIUM_MESH_SHAPE";
  keepsVibeThinkerOnSingleDevice = vibeThinkerMeshEnvironmentValue == null;
  hasManagedTtBenchmark = builtins.hasAttr ttBenchmarkServiceName brittonDesktopServices;
  ttBenchmarkService = brittonDesktopServices.${ttBenchmarkServiceName} or { };
  ttBenchmarkServiceConfig = ttBenchmarkService.serviceConfig or { };
  ttBenchmarkExecStart = ttBenchmarkServiceConfig.ExecStart or null;
  ttBenchmarkWorkingDirectory = ttBenchmarkServiceConfig.WorkingDirectory or null;
  ttBenchmarkWantedBy = ttBenchmarkService.wantedBy or [ ];
  ttBenchmarkEnvironment = ttBenchmarkService.environment or { };
  hasIsolatedTtBenchmarkState =
    (ttBenchmarkServiceConfig.StateDirectory or null) == ttBenchmarkStateDirectory
    && (ttBenchmarkServiceConfig.CacheDirectory or null) == ttBenchmarkServiceName
    && (ttBenchmarkServiceConfig.LogsDirectory or null) == ttBenchmarkServiceName
    && ttBenchmarkWorkingDirectory == ttBenchmarkStateDir
    && (ttBenchmarkEnvironment.HOME or null) == ttBenchmarkStateDir
    && lib.hasPrefix "/var/lib/" ttBenchmarkWorkingDirectory;
  ttBenchmarkIsManual = ttBenchmarkWantedBy == [ ];
  ttBenchmarkCommandPackage = lib.findFirst (
    package: lib.hasInfix ttBenchmarkCommandName (toString package)
  ) null brittonDesktopConfig.environment.systemPackages;
  hasTtBenchmarkCommand = ttBenchmarkCommandPackage != null;
  ttBenchmarkCommandExecutable =
    if hasTtBenchmarkCommand then lib.getExe ttBenchmarkCommandPackage else null;
  serviceExecStart = serviceName: brittonDesktopServices.${serviceName}.serviceConfig.ExecStart;
  hasValidatedMetaliumWorkerBudget =
    serviceName:
    let
      execStart = serviceExecStart serviceName;
    in
    lib.hasInfix metaliumGenerationThreadsArgument execStart
    && lib.hasInfix metaliumBatchThreadsArgument execStart;
  missingValidatedWorkerBudgets = builtins.filter (
    serviceName: !(hasValidatedMetaliumWorkerBudget serviceName)
  ) requiredMetaliumServices;
  serviceCpuAffinity =
    serviceName: brittonDesktopServices.${serviceName}.serviceConfig.CPUAffinity or null;
  servicesWithRejectedCpuAffinity = builtins.filter (
    serviceName: serviceCpuAffinity serviceName != null
  ) requiredMetaliumServices;

  supraExecStart = serviceExecStart supraRouterServiceName;
  supraMetaliumEnvironmentVariables = [
    "GGML_METALIUM_DEVICE_ID"
    "GGML_METALIUM_TRACE"
    "TT_METAL_CACHE"
    "TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS"
    "TT_METAL_LOGS_PATH"
    "TT_VISIBLE_DEVICES"
  ];
  keepsSupraOnCpu =
    lib.hasInfix cpuOnlyGpuLayersArgument supraExecStart
    && lib.hasInfix supraCpuGenerationThreadsArgument supraExecStart
    && lib.hasInfix supraCpuBatchThreadsArgument supraExecStart
    && !(lib.hasInfix metaliumPackageNameFragment supraExecStart)
    && lib.all (
      variableName: serviceEnvironmentValue supraRouterServiceName variableName == null
    ) supraMetaliumEnvironmentVariables;

  brittonDesktopContainers = brittonDesktopConfig.virtualisation.oci-containers.containers;
  llamaContainer = brittonDesktopContainers.${llamaContainerName} or { };
  llamaCommand = llamaContainer.cmd or [ ];
  llamaExtraOptions = llamaContainer.extraOptions or [ ];
  hasIsolatedLlamaContainer =
    builtins.hasAttr llamaContainerName brittonDesktopContainers
    && (llamaContainer.image or null) == llamaImage
    &&
      (llamaContainer.ports or [ ]) == [
        "${llamaLoopbackHost}:${toString llamaApiPort}:${toString llamaApiPort}"
      ]
    && lib.elem "--model" llamaCommand
    && lib.elem llamaModel llamaCommand
    && lib.elem "--tt-device" llamaCommand
    && lib.elem llamaDevice llamaCommand
    && lib.elem "--device=${llamaDevicePath}:${llamaDevicePath}" llamaExtraOptions
    && !(builtins.hasAttr "TT_VISIBLE_DEVICES" (llamaContainer.environment or { }))
    && builtins.length (llamaContainer.environmentFiles or [ ]) == 1;
  llamaGenerators = brittonDesktopConfig.clan.core.vars.generators;
  hasSecretLlamaCredential =
    builtins.hasAttr llamaGeneratorName llamaGenerators
    && (llamaGenerators.${llamaGeneratorName}.files."env-file".secret or false)
    && (llamaGenerators.${llamaGeneratorName}.files."env-file".deploy or false)
    && (llamaGenerators.${llamaGeneratorName}.files."env-file".mode or null) == "0400";
  llamaExecCondition = brittonDesktopServices.${llamaServiceName}.serviceConfig.ExecCondition or null;
  hasGatedLlamaStartup =
    llamaExecCondition != null && lib.hasInfix "credential-check" llamaExecCondition;
  llamaPreStart = brittonDesktopServices.${llamaServiceName}.preStart or "";
  repairsIncompleteLlamaWeights = lib.hasInfix "model-cache-repair" llamaPreStart;
  hasToolsReference = lib.hasInfix ttMetaliumToolsUrl tenstorrentHostGuide;
  documentsManagedTtBenchmark =
    lib.hasInfix "sudo ${ttBenchmarkCommandName}" tenstorrentHostGuide
    && lib.hasInfix "${ttBenchmarkStateDir}/latest-summary.json" tenstorrentHostGuide;

  # Positive and negative coverage for
  # r[verify onix.britton_desktop.accelerators.inventory],
  # r[verify onix.britton_desktop.accelerators.services],
  # r[verify onix.tenstorrent.model_performance.trace_replay],
  # r[verify onix.tenstorrent.model_performance.concurrent_serving],
  # r[verify onix.tenstorrent.model_performance.managed_benchmark],
  # r[verify onix.tenstorrent.vllm.p150_llama], and
  # r[verify onix.tenstorrent.vllm.secrets].
  brittonDesktopAcceleratorInventory = pkgs.runCommand "britton-desktop-accelerator-inventory" { } ''
    ${lib.optionalString (!hasRequiredAccelerator) ''
      echo "${brittonDesktopName} must retain the ${requiredAcceleratorTag} tag"
      exit 1
    ''}
    ${lib.optionalString hasForbiddenAccelerator ''
      echo "${brittonDesktopName} must not carry the absent ${forbiddenAcceleratorTag} tag"
      exit 1
    ''}
    ${lib.optionalString (tenstorrentDeviceCount != expectedTenstorrentDeviceCount) ''
      echo "${brittonDesktopName} facter report must contain ${toString expectedTenstorrentDeviceCount} Tenstorrent PCI devices"
      exit 1
    ''}
    ${lib.optionalString (nvidiaDeviceCount != 0) ''
      echo "${brittonDesktopName} facter report must not contain NVIDIA PCI devices"
      exit 1
    ''}
    ${lib.optionalString (!hasRequiredGraphicsDriver) ''
      echo "${brittonDesktopName} facter report must retain the ${requiredGraphicsDriver} graphics driver"
      exit 1
    ''}
    ${lib.optionalString hasForbiddenInitrdModule ''
      echo "${brittonDesktopName} initrd must not require the absent ${forbiddenInitrdModule} module"
      exit 1
    ''}
    ${lib.optionalString hasRemovedNvidiaService ''
      echo "${brittonDesktopName} must not generate the NVIDIA-only ${removedNvidiaServiceName} service"
      exit 1
    ''}
    ${lib.optionalString (missingEndpointServices != [ ]) ''
      echo "${brittonDesktopName} is missing required model endpoint services: ${lib.concatStringsSep " " missingEndpointServices}"
      exit 1
    ''}
    ${lib.optionalString (missingMetaliumServices != [ ]) ''
      echo "${brittonDesktopName} is missing required Metalium services: ${lib.concatStringsSep " " missingMetaliumServices}"
      exit 1
    ''}
    ${lib.optionalString (!keepsRegressedVibeThinkerTraceDisabled) ''
      echo "${vibeThinkerServiceName} must keep trace replay disabled after its measured regression"
      exit 1
    ''}
    ${lib.optionalString (!keepsVibeThinkerWarmupDisabled) ''
      echo "${vibeThinkerServiceName} must not run trace warmup while trace replay is disabled"
      exit 1
    ''}
    ${lib.optionalString (!keepsVibeThinkerRunningAcrossSwitch) ''
      echo "${vibeThinkerServiceName} must not be interrupted by the supplementary Llama activation"
      exit 1
    ''}
    ${lib.optionalString (!keepsVibeThinkerOnSingleDevice) ''
      echo "${vibeThinkerServiceName} must remain on the accepted single-device serving path"
      exit 1
    ''}
    ${lib.optionalString (!hasManagedTtBenchmark) ''
      echo "${brittonDesktopName} must expose the managed TT benchmark service"
      exit 1
    ''}
    ${lib.optionalString (hasManagedTtBenchmark && !hasIsolatedTtBenchmarkState) ''
      echo "${ttBenchmarkServiceName} must isolate state, cache, logs, and working directory outside the source tree"
      exit 1
    ''}
    ${lib.optionalString (hasManagedTtBenchmark && !ttBenchmarkIsManual) ''
      echo "${ttBenchmarkServiceName} must remain a manually invoked benchmark"
      exit 1
    ''}
    ${lib.optionalString (!hasTtBenchmarkCommand) ''
      echo "${brittonDesktopName} must install the ${ttBenchmarkCommandName} operator command"
      exit 1
    ''}
    ${lib.optionalString (!keepsSupraOnCpu) ''
      echo "${supraRouterServiceName} must retain the validated CPU-only four-thread runtime"
      exit 1
    ''}
    ${lib.optionalString (!hasIsolatedLlamaContainer) ''
      echo "${llamaContainerName} must retain its digest, loopback API, p150 profile, and exclusive ${llamaDevicePath} mapping"
      exit 1
    ''}
    ${lib.optionalString (!hasSecretLlamaCredential) ''
      echo "${llamaGeneratorName} must deploy HF_TOKEN through a root-only Clan secret file"
      exit 1
    ''}
    ${lib.optionalString (!hasGatedLlamaStartup) ''
      echo "${llamaServiceName} must preflight gated-model access before launching Docker"
      exit 1
    ''}
    ${lib.optionalString (!repairsIncompleteLlamaWeights) ''
      echo "${llamaServiceName} must discard incomplete model caches before startup"
      exit 1
    ''}
    ${lib.optionalString (missingValidatedWorkerBudgets != [ ]) ''
      echo "Metalium services are missing the validated ${toString validatedMetaliumWorkerThreads}-thread worker budget: ${lib.concatStringsSep " " missingValidatedWorkerBudgets}"
      exit 1
    ''}
    ${lib.optionalString (servicesWithRejectedCpuAffinity != [ ]) ''
      echo "Metalium services must not retain the rejected CCD affinity trial: ${lib.concatStringsSep " " servicesWithRejectedCpuAffinity}"
      exit 1
    ''}
    ${lib.optionalString (!hasToolsReference) ''
      echo "${brittonDesktopName} Tenstorrent guide must reference ${ttMetaliumToolsUrl}"
      exit 1
    ''}
    ${lib.optionalString (!documentsManagedTtBenchmark) ''
      echo "${brittonDesktopName} Tenstorrent guide must document the managed benchmark command and summary"
      exit 1
    ''}
    ${lib.optionalString (ttBenchmarkExecStart != null) ''
      test -x ${lib.escapeShellArg ttBenchmarkExecStart}
      grep -F -- "trap restore_vibethinker EXIT HUP INT TERM" ${lib.escapeShellArg ttBenchmarkExecStart} >/dev/null
      grep -F -- "systemctl is-active --quiet" ${lib.escapeShellArg ttBenchmarkExecStart} >/dev/null
      grep -F -- "last-run-succeeded" ${lib.escapeShellArg ttBenchmarkExecStart} >/dev/null
      grep -F -- "--cache-root ${ttBenchmarkCacheDir}" ${lib.escapeShellArg ttBenchmarkExecStart} >/dev/null
      grep -F -- "--logs-root ${ttBenchmarkLogsDir}" ${lib.escapeShellArg ttBenchmarkExecStart} >/dev/null
    ''}
    ${lib.optionalString (ttBenchmarkCommandExecutable != null) ''
      test -x ${lib.escapeShellArg ttBenchmarkCommandExecutable}
      grep -F -- "rm -f /run/${ttBenchmarkServiceName}-last-run-succeeded" ${lib.escapeShellArg ttBenchmarkCommandExecutable} >/dev/null
      grep -F -- "did not complete a new validated run" ${lib.escapeShellArg ttBenchmarkCommandExecutable} >/dev/null
    ''}
    touch "$out"
  '';

  # Group machine names by their `system` field from machines.ncl
  machinesPerSystem = builtins.groupBy (name: machinesDef.${name}.system) (lib.attrNames machinesDef);

  nixosMachines = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux (
    lib.mapAttrs' (n: lib.nameValuePair "nixos-${n}") (
      lib.genAttrs (machinesPerSystem.${system} or [ ]) (
        name: self.nixosConfigurations.${name}.config.system.build.toplevel
      )
    )
  );

  darwinMachines = lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin (
    lib.mapAttrs' (n: lib.nameValuePair "darwin-${n}") (
      lib.genAttrs (machinesPerSystem.${system} or [ ]) (
        name: self.darwinConfigurations.${name}.config.system.build.toplevel
      )
    )
  );
in
{
  checks =
    nixosMachines
    // darwinMachines
    //
      lib.optionalAttrs
        (pkgs.stdenv.hostPlatform.isLinux && system == machinesDef.${brittonDesktopName}.system)
        {
          britton-desktop-accelerator-inventory = brittonDesktopAcceleratorInventory;
        };
}
