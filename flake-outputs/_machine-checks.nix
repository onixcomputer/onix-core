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
  expectedTenstorrentDriverVersion = "2.10.0";
  incompatibleTenstorrentDriverVersion = "0.0.0-incompatible-fixture";
  requiredGraphicsDriver = "amdgpu";
  forbiddenInitrdModule = "nvidia";
  removedNvidiaServiceName = "docker-sglang-diffusion-krea2-britton-desktop";
  retiredVibeThinkerServiceName = "llamacpp-server-vibethinker-britton-desktop";
  retiredVibeThinkerUnitName = "${retiredVibeThinkerServiceName}.service";
  retiredLlamaContainerName = "tt-inference-server-llama-3-1-8b-instruct-p150";
  retiredLlamaServiceName = "docker-${retiredLlamaContainerName}";
  retiredLlamaUnitName = "${retiredLlamaServiceName}.service";
  qwenServiceName = "qwen38-p150x2";
  qwenUnitName = "${qwenServiceName}.service";
  qwenModelRevision = "1d4bf0f2ff6012fd82039f2fa52739d0dd7c60c0";
  qwenModelPath = "/home/brittonr/.cache/huggingface/hub/models--Qwen--Qwen3.8-27B/snapshots/${qwenModelRevision}";
  qwenListenAddress = "127.0.0.1";
  qwenApiPort = 8000;
  qwenMaximumSequenceLength = 2048;
  qwenMaximumGenerationTokens = 64;
  qwenExpectedConflicts = [
    retiredVibeThinkerUnitName
    retiredLlamaUnitName
  ];
  qwenDevicePaths = [
    "/dev/tenstorrent/0"
    "/dev/tenstorrent/1"
  ];
  ttBenchmarkServiceName = "tt-vibethinker-benchmark";
  ttBenchmarkCommandName = "tt-vibethinker-bench";
  ttBenchmarkStateDirectory = ttBenchmarkServiceName;
  ttBenchmarkStateDir = "/var/lib/${ttBenchmarkStateDirectory}";
  ttBenchmarkCacheDir = "/var/cache/${ttBenchmarkServiceName}";
  ttBenchmarkLogsDir = "/var/log/${ttBenchmarkServiceName}";
  supraRouterServiceName = "llamacpp-server-supra-router";
  requiredEndpointServices = [
    qwenServiceName
    supraRouterServiceName
  ];
  validatedSupraCpuThreads = 4;
  supraCpuGenerationThreadsArgument = "--threads ${toString validatedSupraCpuThreads}";
  supraCpuBatchThreadsArgument = "--threads-batch ${toString validatedSupraCpuThreads}";
  cpuOnlyGpuLayersArgument = "--gpu-layers 0";
  metaliumPackageNameFragment = "llama-cpp-metalium";
  ttWkv7DiagnosticDevicePath = "/dev/tenstorrent/1";
  ttWkv7OwnerControlUser = "brittonr";
  ttWkv7OwnerControlCommandName = "ttwkv7-owner-control";
  ttWkv7OwnerControlSystemctl = "${brittonDesktopConfig.systemd.package}/bin/systemctl";
  ttWkv7OwnerControlLsof = "${pkgs.lsof}/bin/lsof";
  ttWkv7OwnerControlSudoWrapper = "/run/wrappers/bin/sudo";
  forbiddenTtWkv7OwnerControlStoreSudo = "${pkgs.sudo}/bin/sudo";
  requiredTtWkv7OwnerControlCommands = [
    "${ttWkv7OwnerControlSystemctl} stop ${qwenUnitName}"
    "${ttWkv7OwnerControlSystemctl} start ${qwenUnitName}"
    "${ttWkv7OwnerControlLsof} ${ttWkv7DiagnosticDevicePath}"
  ];
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
  tenstorrentKernelModule = brittonDesktopConfig.boot.kernelPackages.tt-kmd;
  tenstorrentKernelVersion = brittonDesktopConfig.boot.kernelPackages.kernel.modDirVersion;
  tenstorrentKernelModuleFile = "${tenstorrentKernelModule}/lib/modules/${tenstorrentKernelVersion}/misc/tenstorrent.ko.xz";
  hasRequiredAccelerator = lib.elem requiredAcceleratorTag brittonDesktopTags;
  hasForbiddenAccelerator = lib.elem forbiddenAcceleratorTag brittonDesktopTags;
  hasRequiredGraphicsDriver = lib.elem requiredGraphicsDriver brittonDesktopGraphicsDrivers;
  hasForbiddenInitrdModule = lib.elem forbiddenInitrdModule brittonDesktopConfig.boot.initrd.kernelModules;
  hasRemovedNvidiaService = builtins.hasAttr removedNvidiaServiceName brittonDesktopServices;
  hasRetiredVibeThinkerService = builtins.hasAttr retiredVibeThinkerServiceName brittonDesktopServices;
  hasRetiredLlamaService = builtins.hasAttr retiredLlamaServiceName brittonDesktopServices;
  brittonDesktopContainers = brittonDesktopConfig.virtualisation.oci-containers.containers;
  hasRetiredLlamaContainer = builtins.hasAttr retiredLlamaContainerName brittonDesktopContainers;
  missingEndpointServices = builtins.filter (
    serviceName: !(builtins.hasAttr serviceName brittonDesktopServices)
  ) requiredEndpointServices;
  serviceEnvironmentValue =
    serviceName: variableName:
    brittonDesktopServices.${serviceName}.environment.${variableName} or null;
  serviceExecStart = serviceName: brittonDesktopServices.${serviceName}.serviceConfig.ExecStart;

  qwenService = brittonDesktopServices.${qwenServiceName} or { };
  qwenServiceConfig = qwenService.serviceConfig or { };
  qwenExecStart = qwenServiceConfig.ExecStart or "";
  qwenConditionPaths = qwenService.unitConfig.ConditionPathExists or [ ];
  qwenUnsetEnvironment = qwenServiceConfig.UnsetEnvironment or [ ];
  qwenHasExpectedCommand =
    lib.hasInfix "/bin/qwen36-p150x2-serve" qwenExecStart
    && lib.hasInfix "--host ${qwenListenAddress}" qwenExecStart
    && lib.hasInfix "--port ${toString qwenApiPort}" qwenExecStart
    && lib.hasInfix "--model-path ${qwenModelPath}" qwenExecStart
    && lib.hasInfix "--model-alias Qwen3.8-27B" qwenExecStart
    && lib.hasInfix "--max-sequence-length ${toString qwenMaximumSequenceLength}" qwenExecStart
    && lib.hasInfix "--max-generation-tokens ${toString qwenMaximumGenerationTokens}" qwenExecStart;
  qwenHasExpectedEnvironment =
    serviceEnvironmentValue qwenServiceName "HF_HUB_OFFLINE" == "1"
    && serviceEnvironmentValue qwenServiceName "HF_MODEL" == qwenModelPath
    && serviceEnvironmentValue qwenServiceName "MESH_DEVICE" == "P150x2"
    && serviceEnvironmentValue qwenServiceName "QWEN35_TEMP" == "0"
    && serviceEnvironmentValue qwenServiceName "TT_CACHE_PATH" == qwenModelPath;
  qwenOwnsBothDevices = lib.all (devicePath: lib.elem devicePath qwenConditionPaths) qwenDevicePaths;
  qwenHasExpectedConflicts = (qwenService.conflicts or [ ]) == qwenExpectedConflicts;
  qwenStartsAtBoot = lib.elem "multi-user.target" (qwenService.wantedBy or [ ]);
  qwenUsesDeviceGroup = (qwenServiceConfig.Group or null) == "tenstorrent";
  qwenClearsAmbientMesh =
    lib.elem "TT_MESH_GRAPH_DESC_PATH" qwenUnsetEnvironment
    && lib.elem "TT_METAL_SIMULATOR" qwenUnsetEnvironment;

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
  documentsQwenDeployment =
    lib.hasInfix qwenUnitName tenstorrentHostGuide
    && lib.hasInfix qwenModelRevision tenstorrentHostGuide
    && lib.hasInfix "http://${qwenListenAddress}:${toString qwenApiPort}" tenstorrentHostGuide
    && lib.hasInfix "only managed service that owns both P150 devices" tenstorrentHostGuide;
  documentsTtWkv7OwnerControl =
    lib.hasInfix "${ttWkv7OwnerControlCommandName} validate" tenstorrentHostGuide
    && lib.hasInfix qwenUnitName tenstorrentHostGuide
    && lib.hasInfix ttWkv7DiagnosticDevicePath tenstorrentHostGuide
    && lib.hasInfix "does not authorize a" tenstorrentHostGuide
    && lib.hasInfix "hardware probe, select a device" tenstorrentHostGuide;

  # Positive and negative coverage for
  # r[verify onix.britton_desktop.accelerators.inventory],
  # r[verify onix.britton_desktop.accelerators.services],
  # r[verify onix.tenstorrent.p150x2_qwen.deployment],
  # r[verify onix.tenstorrent.p150x2_qwen.contract],
  # r[verify onix.tenstorrent.p150x2_qwen.exclusivity],
  # r[verify onix.tenstorrent.model_performance.managed_benchmark],
  # r[verify onix.tenstorrent.native_runtime.ttwkv7.host],
  # r[verify onix.tenstorrent.native_runtime.ttwkv7.compatibility_boundary],
  # r[verify onix.tenstorrent.native_runtime.ttwkv7.owner_control], and
  # r[verify onix.tenstorrent.native_runtime.ttwkv7.owner_control.sudo_wrapper].
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
    ${lib.optionalString hasRetiredVibeThinkerService ''
      echo "${brittonDesktopName} must not generate retired service ${retiredVibeThinkerServiceName}"
      exit 1
    ''}
    ${lib.optionalString hasRetiredLlamaService ''
      echo "${brittonDesktopName} must not generate retired service ${retiredLlamaServiceName}"
      exit 1
    ''}
    ${lib.optionalString hasRetiredLlamaContainer ''
      echo "${brittonDesktopName} must not generate retired container ${retiredLlamaContainerName}"
      exit 1
    ''}
    ${lib.optionalString (!qwenHasExpectedCommand) ''
      echo "${qwenServiceName} must use the pinned serialized Qwen command and limits"
      exit 1
    ''}
    ${lib.optionalString (!qwenHasExpectedEnvironment) ''
      echo "${qwenServiceName} must select the pinned model and P150x2 runtime"
      exit 1
    ''}
    ${lib.optionalString (!qwenOwnsBothDevices) ''
      echo "${qwenServiceName} must require both physical P150 device nodes"
      exit 1
    ''}
    ${lib.optionalString (!qwenHasExpectedConflicts) ''
      echo "${qwenServiceName} must conflict with both retired accelerator services"
      exit 1
    ''}
    ${lib.optionalString (!qwenStartsAtBoot) ''
      echo "${qwenServiceName} must start through multi-user.target"
      exit 1
    ''}
    ${lib.optionalString (!qwenUsesDeviceGroup) ''
      echo "${qwenServiceName} must use the Tenstorrent device group"
      exit 1
    ''}
    ${lib.optionalString (!qwenClearsAmbientMesh) ''
      echo "${qwenServiceName} must clear ambient simulator and mesh settings"
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
    ${lib.optionalString (!documentsQwenDeployment) ''
      echo "${brittonDesktopName} Tenstorrent guide must document the admitted Qwen deployment"
      exit 1
    ''}
    ${lib.optionalString (!documentsTtWkv7OwnerControl) ''
      echo "${brittonDesktopName} Tenstorrent guide must document least-privilege ttWKV7 owner control"
      exit 1
    ''}
    ${lib.optionalString (ttBenchmarkExecStart != null) ''
      test -x ${lib.escapeShellArg ttBenchmarkExecStart}
      grep -F -- "trap restore_qwen EXIT HUP INT TERM" ${lib.escapeShellArg ttBenchmarkExecStart} >/dev/null
      grep -F -- "systemctl is-active --quiet" ${lib.escapeShellArg ttBenchmarkExecStart} >/dev/null
      grep -F -- ${lib.escapeShellArg qwenUnitName} ${lib.escapeShellArg ttBenchmarkExecStart} >/dev/null
      if grep -F -- ${lib.escapeShellArg retiredVibeThinkerUnitName} ${lib.escapeShellArg ttBenchmarkExecStart}; then
        echo "${ttBenchmarkServiceName} must not restore the retired VibeThinker service" >&2
        exit 1
      fi
      if grep -F -- ${lib.escapeShellArg retiredLlamaUnitName} ${lib.escapeShellArg ttBenchmarkExecStart}; then
        echo "${ttBenchmarkServiceName} must not restore the retired Llama service" >&2
        exit 1
      fi
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

      grep -F -- ${lib.escapeShellArg qwenUnitName} ${lib.escapeShellArg ttWkv7OwnerControlExecutable} >/dev/null
      grep -F -- ${lib.escapeShellArg ttWkv7DiagnosticDevicePath} ${lib.escapeShellArg ttWkv7OwnerControlExecutable} >/dev/null
      grep -F -- ${lib.escapeShellArg ttWkv7OwnerControlSystemctl} ${lib.escapeShellArg ttWkv7OwnerControlExecutable} >/dev/null
      grep -F -- ${lib.escapeShellArg ttWkv7OwnerControlLsof} ${lib.escapeShellArg ttWkv7OwnerControlExecutable} >/dev/null
      grep -F -- ${lib.escapeShellArg ttWkv7OwnerControlSudoWrapper} ${lib.escapeShellArg ttWkv7OwnerControlExecutable} >/dev/null
      if grep -F -- ${lib.escapeShellArg forbiddenTtWkv7OwnerControlStoreSudo} ${lib.escapeShellArg ttWkv7OwnerControlExecutable}; then
        echo "${ttWkv7OwnerControlCommandName} must not invoke the non-setuid store sudo executable" >&2
        exit 1
      fi
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

  # Positive and negative coverage for the pinned TT-KMD module version.
  brittonDesktopTenstorrentDriver = pkgs.runCommand "britton-desktop-tenstorrent-driver" { } ''
    assert_driver_version() {
      actual_version="$1"
      expected_version="$2"
      test "$actual_version" = "$expected_version"
    }

    test -f ${lib.escapeShellArg tenstorrentKernelModuleFile}
    actual_tenstorrent_driver_version="$(${pkgs.kmod}/bin/modinfo -F version ${lib.escapeShellArg tenstorrentKernelModuleFile})"

    if ! assert_driver_version "$actual_tenstorrent_driver_version" ${lib.escapeShellArg expectedTenstorrentDriverVersion}; then
      echo "${brittonDesktopName} must use TT-KMD ${expectedTenstorrentDriverVersion}; built module reports $actual_tenstorrent_driver_version"
      exit 1
    fi

    if assert_driver_version ${lib.escapeShellArg incompatibleTenstorrentDriverVersion} ${lib.escapeShellArg expectedTenstorrentDriverVersion}; then
      echo "The TT-KMD version guard accepted an incompatible fixture"
      exit 1
    fi

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
          britton-desktop-tenstorrent-driver = brittonDesktopTenstorrentDriver;
        };
}
