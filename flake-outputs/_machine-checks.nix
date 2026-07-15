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
  supraRouterServiceName = "llamacpp-server-supra-router";
  requiredMetaliumServices = [
    vibeThinkerServiceName
    supraRouterServiceName
  ];
  metaliumTraceEnvironmentVariable = "GGML_METALIUM_TRACE";
  metaliumTraceEnabledEnvironmentValue = "1";
  metaliumTraceDisabledEnvironmentValue = "0";
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
  missingMetaliumServices = builtins.filter (
    serviceName: !(builtins.hasAttr serviceName brittonDesktopServices)
  ) requiredMetaliumServices;
  serviceEnvironmentValue =
    serviceName: variableName:
    brittonDesktopServices.${serviceName}.environment.${variableName} or null;
  supraTraceEnvironmentValue = serviceEnvironmentValue supraRouterServiceName metaliumTraceEnvironmentVariable;
  vibeThinkerTraceEnvironmentValue = serviceEnvironmentValue vibeThinkerServiceName metaliumTraceEnvironmentVariable;
  hasExpectedSupraTraceRollout = supraTraceEnvironmentValue == metaliumTraceEnabledEnvironmentValue;
  keepsRegressedVibeThinkerTraceDisabled =
    vibeThinkerTraceEnvironmentValue == metaliumTraceDisabledEnvironmentValue;
  hasToolsReference = lib.hasInfix ttMetaliumToolsUrl tenstorrentHostGuide;

  # Positive and negative coverage for
  # r[verify onix.britton_desktop.accelerators.inventory],
  # r[verify onix.britton_desktop.accelerators.services], and
  # r[verify onix.tenstorrent.model_performance.trace_replay].
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
    ${lib.optionalString (missingMetaliumServices != [ ]) ''
      echo "${brittonDesktopName} is missing required Metalium services: ${lib.concatStringsSep " " missingMetaliumServices}"
      exit 1
    ''}
    ${lib.optionalString (!hasExpectedSupraTraceRollout) ''
      echo "${supraRouterServiceName} must retain the validated Metalium trace rollout"
      exit 1
    ''}
    ${lib.optionalString (!keepsRegressedVibeThinkerTraceDisabled) ''
      echo "${vibeThinkerServiceName} must keep trace replay disabled after its measured regression"
      exit 1
    ''}
    ${lib.optionalString (!hasToolsReference) ''
      echo "${brittonDesktopName} Tenstorrent guide must reference ${ttMetaliumToolsUrl}"
      exit 1
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
