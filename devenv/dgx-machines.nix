{
  lib,
  inputs,
  projectRoot,
  inventory,
  clanMachineNames ? [ ],
  requireFiles ? true,
  enableFacter ? true,
}:
let
  inventoryCore = import ../lib/dgx-machine-inventory.nix { inherit lib; };
  pathFor = relativePath: projectRoot + "/${relativePath}";
  validation = inventoryCore.validateInventory {
    inherit
      clanMachineNames
      inventory
      requireFiles
      ;
    pathExists = relativePath: builtins.pathExists (pathFor relativePath);
  };
  systemStateVersion = "25.11";
  secretFileMode = "0400";
  secretFileOwner = "0:0";
  runtimeSecretDirectory = "/var/lib/onix-dgx-secrets";
  runtimeSecretFileNames = {
    tailscaleAuthKey = "tailscale-auth-key";
    meshJoinToken = "mesh-join-token";
    irohPrivateKey = "iroh-private-key";
    irohPublicKey = "iroh-public-key";
  };
  runtimeSecretFiles = lib.mapAttrs (
    _field: fileName: "${runtimeSecretDirectory}/${fileName}"
  ) runtimeSecretFileNames;

  mkMachine =
    name: machine:
    let
      backendUnit = machine.meshBackend.unit or null;
      knownHostsPath = pathFor machine.knownHostsFile;
      diskoModulePath = pathFor machine.diskoModule;
      secretBootstrapFiles = lib.mapAttrs' (
        field: secretName:
        lib.nameValuePair runtimeSecretFiles.${field} {
          secret = secretName;
          owner = secretFileOwner;
          mode = secretFileMode;
        }
      ) machine.runtimeSecrets;
    in
    {
      inherit (machine) system;
      target = {
        host = machine.targetHost;
        sshOpts = [
          "-o"
          "StrictHostKeyChecking=yes"
          "-o"
          "UserKnownHostsFile=${toString knownHostsPath}"
          "-o"
          "IdentitiesOnly=yes"
        ];
      };
      hardware.facter = if enableFacter then machine.facterReport else null;
      install = {
        copyHostKeys = true;
        secretspec.execution = "local";
        secrets = secretBootstrapFiles;
      };
      nixos =
        {
          config,
          ...
        }:
        {
          imports = [
            inputs.onix-core.nixosModules.dgxMachine
            diskoModulePath
          ];

          _module.args.dgxDiskById = machine.diskById;
          networking.hostName = name;
          system.stateVersion = systemStateVersion;

          onix.dgxMachine = {
            services = {
              enable = true;
              meshBackendUnit = backendUnit;
              meshBackendExternallyManaged = machine.meshBackend.externallyManaged;
              meshActivationModel = machine.meshBackend.modelAlias;
              localModel = machine.meshBackend.localModel or { };
            };
            inherit runtimeSecretFiles;
          };

          assertions = [
            {
              assertion = config.disko.devices.disk.main.device == machine.diskById;
              message = "${name}: Disko main device differs from typed diskById.";
            }
          ];
        };
    };
in
if validation.valid then
  lib.mapAttrs mkMachine validation.machines
else
  throw "Invalid DGX machine inventory:\n${lib.concatStringsSep "\n" validation.errors}"
