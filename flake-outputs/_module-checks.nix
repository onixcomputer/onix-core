# Verify that the module registry in services/contracts.ncl stays in
# sync with the actual module directories in modules/.
#
# Catches two kinds of drift:
#   - Module registered in contracts.ncl but no directory exists
#   - Module directory exists (and is in modules/default.nix) but not
#     registered in contracts.ncl
#
# Note: borgbackup-extras and matrix-synapse-cf are plain NixOS modules
# loaded via extraModules, not clan perInstance service definitions.
# They are intentionally absent from the registry.
{
  self,
  pkgs,
  lib,
  ...
}:
let
  plugins = self.packages.x86_64-linux.wasm-plugins;
  wasm = import ../lib/wasm.nix { inherit plugins; };

  moduleLists = wasm.evalNickelFile ../inventory/services/module-lists.ncl;
  llamacppServerValidation = wasm.evalNickelFile ../inventory/services/fixtures/llamacpp-server-validation.ncl;
  sglangDiffusionValidation = wasm.evalNickelFile ../inventory/services/fixtures/sglang-diffusion-validation.ncl;
  ttInferenceServerValidation = wasm.evalNickelFile ../inventory/services/fixtures/tt-inference-server-validation.ncl;
  rustfsValidation = wasm.evalNickelFile ../inventory/services/fixtures/rustfs-validation.ncl;
  rustfsTopologyTests = import ../modules/rustfs/topology-tests.nix { inherit lib; };
  celldValidation = wasm.evalNickelFile ../inventory/services/fixtures/celld-validation.ncl;
  celldSettingsTests = import ../modules/celld/settings-tests.nix { inherit lib; };

  # Modules registered in contracts.ncl (clan perInstance services only)
  registeredModules = lib.sort lib.lessThan moduleLists.selfModules;

  # Module directories on disk that are clan perInstance services
  # (i.e., listed in modules/default.nix).
  moduleDefs = import ../modules { inherit (self) inputs; };
  diskModules = lib.sort lib.lessThan (lib.attrNames moduleDefs);

  inRegistryNoDisk = lib.subtractLists diskModules registeredModules;
  onDiskNoRegistry = lib.subtractLists registeredModules diskModules;

  # Modules missing schema.ncl files
  modulesWithoutSchema = builtins.filter (
    name: !builtins.pathExists (self + "/modules/${name}/schema.ncl")
  ) diskModules;

  llamacppPositiveErrors = llamacppServerValidation.positive;
  llamacppNegativeErrors = llamacppServerValidation.negative;
  expectedLlamacppNegativeFields = [
    "backend"
    "modelSha256"
    "metaliumDeviceId"
    "metaliumInspectorPort"
    "metaliumTrace"
    "generationThreads"
    "batchThreads"
    "flashAttention"
  ];
  missingLlamacppNegativeFields = builtins.filter (
    field: !(lib.any (error: lib.hasInfix field error) llamacppNegativeErrors)
  ) expectedLlamacppNegativeFields;

  sglangPositiveErrors = sglangDiffusionValidation.positive;
  sglangNegativeErrors = sglangDiffusionValidation.negative;
  expectedSglangNegativeFields = [
    "port"
    "numGpus"
    "gpuPassthrough"
    "environmentFiles"
  ];
  missingSglangNegativeFields = builtins.filter (
    field: !(lib.any (error: lib.hasInfix field error) sglangNegativeErrors)
  ) expectedSglangNegativeFields;

  ttInferenceServerPositiveErrors = ttInferenceServerValidation.positive;
  ttInferenceServerNegativeErrors = ttInferenceServerValidation.negative;
  expectedTtInferenceServerNegativeFields = [
    "image"
    "model"
    "device"
    "physicalDeviceId"
    "host"
    "port"
    "cacheUid"
    "cacheGid"
    "enableTraceCapture"
    "autoStart"
    "extraArgs"
  ];
  missingTtInferenceServerNegativeFields = builtins.filter (
    field: !(lib.any (error: lib.hasInfix field error) ttInferenceServerNegativeErrors)
  ) expectedTtInferenceServerNegativeFields;

  rustfsPositiveErrors = rustfsValidation.positive;
  rustfsNegativeErrors = rustfsValidation.negative;
  expectedRustfsNegativeFields = [
    "mode"
    "dataDir"
    "bindAddress"
    "apiPort"
    "consolePort"
    "enableConsole"
    "openFirewall"
    "firewallInterface"
    "clusterEndpoints"
    "topologyWaitMode"
    "topologyWaitTimeoutSeconds"
  ];
  missingRustfsNegativeFields = builtins.filter (
    field: !(lib.any (error: lib.hasInfix field error) rustfsNegativeErrors)
  ) expectedRustfsNegativeFields;
  rustfsTopologyPositiveErrors = rustfsTopologyTests.positiveErrors;
  rustfsTopologyMissingNegativeCases = rustfsTopologyTests.missingNegativeCases;
  rustfsTopologyNegativeErrors = rustfsTopologyTests.negativeErrors;
  rustfsClusterMachines = [
    "aspen1"
    "aspen3"
    "britton-desktop"
  ];
  rustfsMissingNetlinkMachines = builtins.filter (
    machine:
    !(builtins.elem "AF_NETLINK"
      self.nixosConfigurations.${machine}.config.systemd.services.rustfs.serviceConfig.RestrictAddressFamilies
    )
  ) rustfsClusterMachines;

  celldPositiveErrors = celldValidation.positive;
  celldNegativeErrors = celldValidation.negative;
  expectedCelldNegativeFields = [
    "stateDir"
    "bindAddress"
    "storageEndpoint"
    "bucketName"
    "region"
    "accessKeyId"
    "publicPort"
    "internalPort"
    "openFirewall"
    "firewallInterface"
    "provisionStorage"
    "rustfsAdminGenerator"
    "deployCounter"
    "leaseTtlMilliseconds"
    "restartDelaySeconds"
    "shutdownDrainMilliseconds"
  ];
  missingCelldNegativeFields = builtins.filter (
    field: !(lib.any (error: lib.hasInfix field error) celldNegativeErrors)
  ) expectedCelldNegativeFields;
  celldSettingsPositiveErrors = celldSettingsTests.positiveErrors;
  celldSettingsMissingNegativeCases = celldSettingsTests.missingNegativeCases;
  celldSettingsNegativeErrors = celldSettingsTests.negativeErrors;
  celldPublicPort = 39200;
  celldInternalPort = 39201;
  celldClusterMachines = [
    "aspen1"
    "aspen3"
    "britton-desktop"
  ];
  celldProvisionerMachines = builtins.filter (
    machine:
    builtins.hasAttr "celld-storage-provision"
      self.nixosConfigurations.${machine}.config.systemd.services
  ) celldClusterMachines;
  celldMissingServices = builtins.filter (
    machine: !(builtins.hasAttr "celld" self.nixosConfigurations.${machine}.config.systemd.services)
  ) celldClusterMachines;
  celldExpectedStorageEndpoints = {
    aspen1 = "http://100.100.103.95:39000";
    aspen3 = "http://100.108.13.4:39000";
    britton-desktop = "http://100.110.43.11:39000";
  };
  celldStorageEndpointMismatches = builtins.filter (
    machine:
    self.nixosConfigurations.${machine}.config.systemd.services.celld.environment.S3_ENDPOINT
    != celldExpectedStorageEndpoints.${machine}
  ) celldClusterMachines;
  celldTailnetFirewallMismatches = builtins.filter (
    machine:
    let
      firewall = self.nixosConfigurations.${machine}.config.networking.firewall;
      tailnetPorts = firewall.interfaces.tailscale0.allowedTCPPorts;
      globalPorts = firewall.allowedTCPPorts;
      requiredPorts = [
        celldPublicPort
        celldInternalPort
      ];
    in
    !(lib.all (port: builtins.elem port tailnetPorts) requiredPorts)
    || lib.any (port: builtins.elem port globalPorts) requiredPorts
  ) celldClusterMachines;
  celldDesktopClockProviderValid =
    self.nixosConfigurations.britton-desktop.config.services.chrony.enable
    && !self.nixosConfigurations.britton-desktop.config.services.timesyncd.enable;
in
{
  checks = {
    module-registry-sync = pkgs.runCommand "module-registry-sync" { } ''
      ${lib.optionalString (inRegistryNoDisk != [ ]) ''
        echo "Modules in contracts.ncl selfModules but missing from modules/default.nix:"
        echo "  ${lib.concatStringsSep " " inRegistryNoDisk}"
        echo ""
      ''}
      ${lib.optionalString (onDiskNoRegistry != [ ]) ''
        echo "Modules in modules/default.nix but not registered in contracts.ncl:"
        echo "  ${lib.concatStringsSep " " onDiskNoRegistry}"
        echo ""
      ''}
      ${lib.optionalString (modulesWithoutSchema != [ ]) ''
        echo "Modules missing schema.ncl (needed for settings contract validation):"
        echo "  ${lib.concatStringsSep " " modulesWithoutSchema}"
        echo ""
      ''}
      ${lib.optionalString
        (inRegistryNoDisk != [ ] || onDiskNoRegistry != [ ] || modulesWithoutSchema != [ ])
        ''
          echo "Fix: update contracts.ncl and/or add schema.ncl to each module"
          exit 1
        ''
      }
      touch $out
    '';

    # Positive and negative settings coverage for
    # r[verify onix.tenstorrent.model_process_isolation.devices] and
    # r[verify onix.tenstorrent.model_performance.trace_replay].
    llamacpp-server-settings = pkgs.runCommand "llamacpp-server-settings" { } ''
      ${lib.optionalString (llamacppPositiveErrors != [ ]) ''
        echo "Valid llamacpp-server settings produced unexpected errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" llamacppPositiveErrors)}
        exit 1
      ''}
      ${lib.optionalString (missingLlamacppNegativeFields != [ ]) ''
        echo "Invalid llamacpp-server settings did not report expected fields:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" missingLlamacppNegativeFields)}
        echo "Actual errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" llamacppNegativeErrors)}
        exit 1
      ''}
      touch $out
    '';

    sglang-diffusion-settings = pkgs.runCommand "sglang-diffusion-settings" { } ''
      ${lib.optionalString (sglangPositiveErrors != [ ]) ''
        echo "Valid sglang-diffusion settings produced unexpected errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" sglangPositiveErrors)}
        exit 1
      ''}
      ${lib.optionalString (missingSglangNegativeFields != [ ]) ''
        echo "Invalid sglang-diffusion settings did not report expected fields:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" missingSglangNegativeFields)}
        echo "Actual errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" sglangNegativeErrors)}
        exit 1
      ''}
      touch $out
    '';

    # Positive and negative settings coverage for
    # r[verify onix.tenstorrent.vllm.p150_llama] and
    # r[verify onix.tenstorrent.vllm.secrets].
    tt-inference-server-settings = pkgs.runCommand "tt-inference-server-settings" { } ''
      ${lib.optionalString (ttInferenceServerPositiveErrors != [ ]) ''
        echo "Valid tt-inference-server settings produced unexpected errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" ttInferenceServerPositiveErrors)}
        exit 1
      ''}
      ${lib.optionalString (missingTtInferenceServerNegativeFields != [ ]) ''
        echo "Invalid tt-inference-server settings did not report expected fields:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" missingTtInferenceServerNegativeFields)}
        echo "Actual errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" ttInferenceServerNegativeErrors)}
        exit 1
      ''}
      touch $out
    '';

    rustfs-settings = pkgs.runCommand "rustfs-settings" { } ''
      ${lib.optionalString (rustfsPositiveErrors != [ ]) ''
        echo "Valid rustfs settings produced unexpected errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" rustfsPositiveErrors)}
        exit 1
      ''}
      ${lib.optionalString (missingRustfsNegativeFields != [ ]) ''
        echo "Invalid rustfs settings did not report expected fields:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" missingRustfsNegativeFields)}
        echo "Actual errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" rustfsNegativeErrors)}
        exit 1
      ''}
      touch $out
    '';

    # r[verify onix.rustfs_cluster.validation]
    rustfs-topology = pkgs.runCommand "rustfs-topology" { } ''
      ${lib.optionalString (rustfsTopologyPositiveErrors != [ ]) ''
        echo "Valid RustFS topologies produced unexpected errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" rustfsTopologyPositiveErrors)}
        exit 1
      ''}
      ${lib.optionalString (rustfsTopologyMissingNegativeCases != [ ]) ''
        echo "Invalid RustFS topologies did not report expected errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" rustfsTopologyMissingNegativeCases)}
        echo "Actual errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" rustfsTopologyNegativeErrors)}
        exit 1
      ''}
      ${lib.optionalString (rustfsMissingNetlinkMachines != [ ]) ''
        echo "RustFS cannot enumerate local interfaces without AF_NETLINK:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" rustfsMissingNetlinkMachines)}
        exit 1
      ''}
      touch $out
    '';

    # r[verify onix.celld_rustfs.package]
    celld-package = pkgs.runCommand "celld-package" { } ''
      actual="$(${lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.celld} --version)"
      test "$actual" = "celld 0.3.0"
      touch $out
    '';

    # r[verify onix.celld_rustfs.validation]
    celld-settings = pkgs.runCommand "celld-settings" { } ''
      ${lib.optionalString (celldPositiveErrors != [ ]) ''
        echo "Valid Celld settings produced unexpected type errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" celldPositiveErrors)}
        exit 1
      ''}
      ${lib.optionalString (missingCelldNegativeFields != [ ]) ''
        echo "Invalid Celld settings did not report expected fields:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" missingCelldNegativeFields)}
        exit 1
      ''}
      ${lib.optionalString (celldSettingsPositiveErrors != [ ]) ''
        echo "Valid Celld settings produced semantic errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" celldSettingsPositiveErrors)}
        exit 1
      ''}
      ${lib.optionalString (celldSettingsMissingNegativeCases != [ ]) ''
        echo "Invalid Celld settings did not report expected semantic errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" celldSettingsMissingNegativeCases)}
        echo "Actual errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" celldSettingsNegativeErrors)}
        exit 1
      ''}
      touch $out
    '';

    # r[verify onix.celld_rustfs.composition]
    # r[verify onix.celld_rustfs.security]
    celld-generated = pkgs.runCommand "celld-generated" { } ''
      ${lib.optionalString (builtins.length celldProvisionerMachines != 1) ''
        echo "Celld requires exactly one storage provisioner; found:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" celldProvisionerMachines)}
        exit 1
      ''}
      ${lib.optionalString (celldMissingServices != [ ]) ''
        echo "Celld service is missing from fleet machines:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" celldMissingServices)}
        exit 1
      ''}
      ${lib.optionalString (celldStorageEndpointMismatches != [ ]) ''
        echo "Celld nodes are not aligned with local RustFS endpoints:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" celldStorageEndpointMismatches)}
        exit 1
      ''}
      ${lib.optionalString (celldTailnetFirewallMismatches != [ ]) ''
        echo "Celld firewall ports are not Tailnet-only on:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" celldTailnetFirewallMismatches)}
        exit 1
      ''}
      ${lib.optionalString (!celldDesktopClockProviderValid) ''
        echo "Celld requires Chrony on the NetworkManager-managed desktop"
        exit 1
      ''}
      touch $out
    '';
  };
}
