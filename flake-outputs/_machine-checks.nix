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
  llamaUnitName = "${llamaServiceName}.service";
  ttWkv7OwnerControlUser = "brittonr";
  ttWkv7OwnerControlCommandName = "ttwkv7-owner-control";
  ttWkv7OwnerControlSystemctl = "${brittonDesktopConfig.systemd.package}/bin/systemctl";
  ttWkv7OwnerControlLsof = "${pkgs.lsof}/bin/lsof";
  requiredTtWkv7OwnerControlCommands = [
    "${ttWkv7OwnerControlSystemctl} stop ${llamaUnitName}"
    "${ttWkv7OwnerControlSystemctl} start ${llamaUnitName}"
    "${ttWkv7OwnerControlLsof} ${llamaDevicePath}"
  ];
  llamaApiPort = 8000;
  llamaLoopbackHost = "127.0.0.1";
  llamaImage = "ghcr.io/tenstorrent/tt-inference-server/vllm-tt-metal-src-release-ubuntu-22.04-amd64:0.18.0-c49bb76-6b4a3a7@sha256:6aee48978be401c0a86cb1761c4d64af818df8380bc7b27c1018d704518545ff";
  ttMetaliumToolsUrl = "https://docs.tenstorrent.com/tt-metal/latest/tt-metalium/tools/index.html";
  ttWkv7PackageNameFragment = "ttwkv7";
  ttWkv7CommandName = "wkv7";
  ttWkv7UpstreamTarget = "Wormhole";
  ttWkv7ManagedTarget = "Blackhole P150";
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
  brittonDesktopSudoers = brittonDesktopConfig.environment.etc.sudoers.source;
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
  ttWkv7CommandPackage = lib.findFirst (
    package: lib.hasInfix ttWkv7PackageNameFragment (toString package)
  ) null brittonDesktopConfig.environment.systemPackages;
  hasTtWkv7CommandPackage = ttWkv7CommandPackage != null;
  ttWkv7OwnerControlGroups =
    brittonDesktopConfig.users.users.${ttWkv7OwnerControlUser}.extraGroups or [ ];
  sudoGrants = lib.concatMap (
    rule:
    map (command: {
      commandText = command.command;
      groups = rule.groups or [ ];
      options = command.options or [ ];
      users = rule.users or [ ];
    }) (rule.commands or [ ])
  ) brittonDesktopConfig.security.sudo.extraRules;
  ownerControlPasswordlessGrants = builtins.filter (
    grant:
    (
      lib.elem ttWkv7OwnerControlUser grant.users
      || builtins.any (group: lib.elem group ttWkv7OwnerControlGroups) grant.groups
    )
    && lib.elem "NOPASSWD" grant.options
  ) sudoGrants;
  ownerControlPasswordlessCommands = map (grant: grant.commandText) ownerControlPasswordlessGrants;
  hasRequiredOwnerControlCommands = lib.all (
    requiredCommand:
    builtins.any (
      grant:
      grant.commandText == requiredCommand
      && grant.users == [ ttWkv7OwnerControlUser ]
      && grant.options == [ "NOPASSWD" ]
    ) sudoGrants
  ) requiredTtWkv7OwnerControlCommands;
  isBroadOwnerControlCommand =
    commandText:
    commandText == "ALL"
    || commandText == ttWkv7OwnerControlSystemctl
    || commandText == ttWkv7OwnerControlLsof
    || (
      lib.hasPrefix "${ttWkv7OwnerControlSystemctl} " commandText
      && !(lib.elem commandText requiredTtWkv7OwnerControlCommands)
    )
    || (
      lib.hasPrefix "${ttWkv7OwnerControlLsof} " commandText
      && !(lib.elem commandText requiredTtWkv7OwnerControlCommands)
    );
  hasBroadOwnerControlCommand = builtins.any isBroadOwnerControlCommand ownerControlPasswordlessCommands;
  ttWkv7OwnerControlPackage = lib.findFirst (
    package: lib.hasInfix ttWkv7OwnerControlCommandName (toString package)
  ) null brittonDesktopConfig.environment.systemPackages;
  hasTtWkv7OwnerControlPackage = ttWkv7OwnerControlPackage != null;
  ttWkv7OwnerControlExecutable =
    if hasTtWkv7OwnerControlPackage then lib.getExe ttWkv7OwnerControlPackage else null;
  hasToolsReference = lib.hasInfix ttMetaliumToolsUrl tenstorrentHostGuide;
  documentsTtWkv7Boundary =
    lib.hasInfix "${ttWkv7CommandName} test" tenstorrentHostGuide
    && lib.hasInfix ttWkv7UpstreamTarget tenstorrentHostGuide
    && lib.hasInfix ttWkv7ManagedTarget tenstorrentHostGuide
    && lib.hasInfix "classifies this package as unfree" tenstorrentHostGuide;
  documentsManagedTtBenchmark =
    lib.hasInfix "sudo ${ttBenchmarkCommandName}" tenstorrentHostGuide
    && lib.hasInfix "${ttBenchmarkStateDir}/latest-summary.json" tenstorrentHostGuide;
  documentsTtWkv7OwnerControl =
    lib.hasInfix "${ttWkv7OwnerControlCommandName} validate" tenstorrentHostGuide
    && lib.hasInfix llamaUnitName tenstorrentHostGuide
    && lib.hasInfix llamaDevicePath tenstorrentHostGuide
    && lib.hasInfix "does not authorize a hardware" tenstorrentHostGuide
    && lib.hasInfix "probe, select a device" tenstorrentHostGuide;

  # Positive and negative coverage for
  # r[verify onix.britton_desktop.accelerators.inventory],
  # r[verify onix.britton_desktop.accelerators.services],
  # r[verify onix.tenstorrent.model_performance.trace_replay],
  # r[verify onix.tenstorrent.model_performance.concurrent_serving],
  # r[verify onix.tenstorrent.model_performance.managed_benchmark],
  # r[verify onix.tenstorrent.native_runtime.ttwkv7.host],
  # r[verify onix.tenstorrent.native_runtime.ttwkv7.compatibility_boundary],
  # r[verify onix.tenstorrent.native_runtime.ttwkv7.owner_control],
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
    ${lib.optionalString (!hasTtWkv7CommandPackage) ''
      echo "${brittonDesktopName} must include the ${ttWkv7PackageNameFragment} package"
      exit 1
    ''}
    ${lib.optionalString (!hasRequiredOwnerControlCommands) ''
      echo "${brittonDesktopName} must grant only the exact ttWKV7 owner-control commands"
      exit 1
    ''}
    ${lib.optionalString hasBroadOwnerControlCommand ''
      echo "${brittonDesktopName} must not grant wildcard or unrelated ttWKV7 owner-control commands"
      exit 1
    ''}
    ${lib.optionalString (!hasTtWkv7OwnerControlPackage) ''
      echo "${brittonDesktopName} must install ${ttWkv7OwnerControlCommandName}"
      exit 1
    ''}
    ${lib.optionalString (!hasToolsReference) ''
      echo "${brittonDesktopName} Tenstorrent guide must reference ${ttMetaliumToolsUrl}"
      exit 1
    ''}
    ${lib.optionalString (!documentsTtWkv7Boundary) ''
      echo "${brittonDesktopName} Tenstorrent guide must document ttWKV7 invocation, licensing, and hardware boundaries"
      exit 1
    ''}
    ${lib.optionalString (!documentsManagedTtBenchmark) ''
      echo "${brittonDesktopName} Tenstorrent guide must document the managed benchmark command and summary"
      exit 1
    ''}
    ${lib.optionalString (!documentsTtWkv7OwnerControl) ''
      echo "${brittonDesktopName} Tenstorrent guide must document least-privilege ttWKV7 owner control"
      exit 1
    ''}
    ${lib.optionalString (ttBenchmarkExecStart != null) ''
      test -x ${lib.escapeShellArg ttBenchmarkExecStart}
      grep -F -- "trap restore_displaced_services EXIT HUP INT TERM" ${lib.escapeShellArg ttBenchmarkExecStart} >/dev/null
      grep -F -- "systemctl is-active --quiet" ${lib.escapeShellArg ttBenchmarkExecStart} >/dev/null
      grep -F -- "${vibeThinkerServiceName}.service" ${lib.escapeShellArg ttBenchmarkExecStart} >/dev/null
      grep -F -- "${llamaServiceName}.service" ${lib.escapeShellArg ttBenchmarkExecStart} >/dev/null
      grep -F -- "last-run-succeeded" ${lib.escapeShellArg ttBenchmarkExecStart} >/dev/null
      grep -F -- "--cache-root ${ttBenchmarkCacheDir}" ${lib.escapeShellArg ttBenchmarkExecStart} >/dev/null
      grep -F -- "--logs-root ${ttBenchmarkLogsDir}" ${lib.escapeShellArg ttBenchmarkExecStart} >/dev/null
    ''}
    ${lib.optionalString (ttBenchmarkCommandExecutable != null) ''
      test -x ${lib.escapeShellArg ttBenchmarkCommandExecutable}
      grep -F -- "rm -f /run/${ttBenchmarkServiceName}-last-run-succeeded" ${lib.escapeShellArg ttBenchmarkCommandExecutable} >/dev/null
      grep -F -- "did not complete a new validated run" ${lib.escapeShellArg ttBenchmarkCommandExecutable} >/dev/null
    ''}
    test -f ${lib.escapeShellArg brittonDesktopSudoers}
    for required_command in ${lib.escapeShellArgs requiredTtWkv7OwnerControlCommands}; do
      grep -F -- "NOPASSWD: $required_command" ${lib.escapeShellArg brittonDesktopSudoers} >/dev/null
    done
    ${lib.optionalString (ttWkv7OwnerControlExecutable != null) ''
      test -x ${lib.escapeShellArg ttWkv7OwnerControlExecutable}
      ${lib.escapeShellArg ttWkv7OwnerControlExecutable} --help >owner-control-help.log 2>&1
      grep -F -- "usage: ${ttWkv7OwnerControlCommandName} --help|validate|isolate|restore" owner-control-help.log >/dev/null

      if ${lib.escapeShellArg ttWkv7OwnerControlExecutable} invalid-mode >owner-control-invalid.log 2>&1; then
        echo "${ttWkv7OwnerControlCommandName} unexpectedly accepted an invalid mode" >&2
        exit 1
      else
        invalid_status="$?"
      fi
      test "$invalid_status" -eq 2
      grep -F -- "usage:" owner-control-invalid.log >/dev/null

      if ${lib.escapeShellArg ttWkv7OwnerControlExecutable} --help extra-argument >owner-control-extra.log 2>&1; then
        echo "${ttWkv7OwnerControlCommandName} unexpectedly accepted an extra argument" >&2
        exit 1
      else
        extra_status="$?"
      fi
      test "$extra_status" -eq 2
      grep -F -- "usage:" owner-control-extra.log >/dev/null

      grep -F -- ${lib.escapeShellArg llamaUnitName} ${lib.escapeShellArg ttWkv7OwnerControlExecutable} >/dev/null
      grep -F -- ${lib.escapeShellArg llamaDevicePath} ${lib.escapeShellArg ttWkv7OwnerControlExecutable} >/dev/null
      grep -F -- ${lib.escapeShellArg ttWkv7OwnerControlSystemctl} ${lib.escapeShellArg ttWkv7OwnerControlExecutable} >/dev/null
      grep -F -- ${lib.escapeShellArg ttWkv7OwnerControlLsof} ${lib.escapeShellArg ttWkv7OwnerControlExecutable} >/dev/null
      if grep -F -- "TT_VISIBLE_DEVICES" ${lib.escapeShellArg ttWkv7OwnerControlExecutable}; then
        echo "${ttWkv7OwnerControlCommandName} must not select a device" >&2
        exit 1
      fi
      if grep -F -- "wkv7-constant-probe" ${lib.escapeShellArg ttWkv7OwnerControlExecutable}; then
        echo "${ttWkv7OwnerControlCommandName} must not invoke a probe" >&2
        exit 1
      fi
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
