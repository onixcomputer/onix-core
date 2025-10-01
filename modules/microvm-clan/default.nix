_: {
  _class = "clan.service";

  manifest = {
    name = "microvm-clan";
    description = "Clan-native MicroVMs using complete clan machine configurations";
    categories = [
      "Virtualization"
      "Infrastructure"
      "Clan"
    ];
  };

  roles.server = {
    interface =
      { lib, ... }:
      {
        freeformType = lib.types.attrsOf lib.types.anything;

        options = {
          clanMachine = lib.mkOption {
            type = lib.types.str;
            description = ''
              Name of the clan machine to run as a microvm.
              Must correspond to a machine defined in the clan inventory.
            '';
            example = "test-vm";
          };

          restartIfChanged = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              Whether to restart the microvm when the host configuration changes.
              Set to false for production VMs requiring explicit updates.
            '';
          };

          microvm = lib.mkOption {
            type = lib.types.attrsOf lib.types.anything;
            default = { };
            description = ''
              MicroVM-specific configuration (hypervisor, resources, etc.).
              These options are passed directly to microvm.nix.
            '';
          };
        };
      };

    perInstance =
      { instanceName, settings, ... }:
      {
        nixosModule =
          {
            inputs,
            lib,
            clan-core,
            ...
          }:
          let
            clanMachine = settings.clanMachine;
            restartIfChanged = settings.restartIfChanged or false;
            microvmConfig = settings.microvm or { };

            # Get machine imports from the clan configuration (with access to inputs.self)
            machineImports =
              inputs.self.clan.clanInternals.inventoryClass.machines.${clanMachine}.machineImports or [ ];

            # Set sensible defaults for microvm
            defaultMicrovmSettings = {
              hypervisor = "cloud-hypervisor";
              vcpu = 2;
              mem = 1024;
              shares = [
                {
                  tag = "ro-store";
                  source = "/nix/store";
                  mountPoint = "/nix/.ro-store";
                  proto = "virtiofs";
                }
              ];
              interfaces = [
                {
                  type = "tap";
                  id = "cl-${lib.substring 0 10 instanceName}";
                  mac = "02:00:00:00:00:${toString (lib.strings.stringLength instanceName + 10)}";
                }
              ];
            };

            finalMicrovmSettings = defaultMicrovmSettings // microvmConfig;

            # Build complete machine configuration including clan services
            # Filter out problematic nixpkgs config from imports for microvm compatibility
            filteredMachineImports = map (
              importPath:
              { ... }:
              {
                imports = [ importPath ];
                # Disable nixpkgs config from tags/services to avoid conflict with microvm
                nixpkgs.config = lib.mkForce { };
              }
            ) machineImports;

            machineConfigModule =
              { ... }:
              {
                imports =
                  # Base machine files
                  builtins.filter builtins.pathExists [
                    "${inputs.self}/machines/${clanMachine}/configuration.nix"
                    "${inputs.self}/machines/${clanMachine}/hardware-configuration.nix"
                    "${inputs.self}/machines/${clanMachine}/disko.nix"
                  ]
                  # Add filtered machine-specific service imports (includes tag-based services)
                  ++ filteredMachineImports;

                # Set clan core settings to match the machine
                clan.core.settings = {
                  machine.name = clanMachine;
                  directory = inputs.self;
                };

                # Set nixpkgs config at the top level for microvm
                nixpkgs.config.allowUnfree = true;
              };
          in
          {
            imports = [
              inputs.microvm.nixosModules.host
            ];

            microvm.vms."${instanceName}" = {
              inherit restartIfChanged;

              config =
                { clanMachineConfig, ... }:
                {
                  imports = [
                    inputs.microvm.nixosModules.microvm
                    clan-core.nixosModules.clanCore
                    clanMachineConfig
                  ];

                  # Basic guest configuration - use default so machine config can override
                  system.stateVersion = lib.mkDefault "25.05";
                  networking.hostName = lib.mkDefault clanMachine;

                  microvm = finalMicrovmSettings;
                };

              # Pass machine config through specialArgs to avoid circular dependency
              specialArgs = {
                inherit inputs clan-core;
                clanMachineConfig = machineConfigModule;
              };
            };

            # Ensure firewall allows microvm traffic
            networking.firewall.trustedInterfaces = [ "cl-${lib.substring 0 10 instanceName}" ];
          };
      };
  };
}
