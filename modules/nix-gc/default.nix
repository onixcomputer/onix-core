{ schema, inputs }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
in
{
  _class = "clan.service";

  manifest = {
    name = "nix-gc";
    description = "Automatic Nix store garbage collection and optimization";
    readme = "Configures automatic cleanup of old Nix generations and store optimization";
    categories = [
      "System"
      "Maintenance"
    ];
  };

  roles.default = {
    description = "Machine with automatic Nix garbage collection enabled";
    interface = mkSettings.mkInterface schema.default;

    perInstance =
      { extendSettings, ... }:
      {
        nixosModule =
          { lib, ... }:
          let
            # Re-import with the NixOS module's lib for correct mkDefault wiring.
            ms = import ../../lib/mk-settings.nix { inherit lib; };
            cfg = extendSettings (ms.mkDefaults schema.default);

            deleteOlderThan = "${toString cfg.retentionDays}d";
            stockGcOptions = "--delete-older-than ${deleteOlderThan}";
            idleNiceLevel = 19;
            lowPriorityServiceConfig = {
              CPUSchedulingPolicy = lib.mkForce "idle";
              IOSchedulingClass = "idle";
              Nice = idleNiceLevel;
            };
          in
          {
            imports = [ inputs.fast-nix-gc.nixosModules.default ];

            config = lib.mkMerge [
              {
                nix.settings.auto-optimise-store = cfg.autoOptimise;
              }

              (lib.mkIf cfg.useFastGc {
                services.fast-nix-gc = {
                  enable = true;
                  automatic = true;
                  dates = cfg.schedule;
                  inherit deleteOlderThan;
                  inherit (cfg) ensureFree;
                  inherit (cfg) keepRecent;
                  inherit (cfg) noVacuum;
                  inherit (cfg) gcRootsDirs;
                  inherit (cfg) extraArgs;
                };

                services.fast-nix-optimise = {
                  enable = cfg.optimizeStore;
                  automatic = cfg.optimizeStore;
                  dates = cfg.optimizeSchedule;
                };

                nix = {
                  gc.automatic = lib.mkForce false;
                  optimise.automatic = lib.mkForce false;
                };

                # Run maintenance at lowest priority — never steal resources from builds or interactive work.
                systemd.services.fast-nix-gc.serviceConfig = lowPriorityServiceConfig;
                systemd.services.fast-nix-optimise.serviceConfig = lib.mkIf cfg.optimizeStore lowPriorityServiceConfig;
              })

              (lib.mkIf (!cfg.useFastGc) {
                nix = {
                  gc = {
                    automatic = true;
                    dates = cfg.schedule;
                    options = stockGcOptions;
                  };

                  optimise = lib.mkIf cfg.optimizeStore {
                    automatic = true;
                    dates = cfg.optimizeSchedule;
                  };
                };

                # Run GC at lowest priority — never steal resources from builds or interactive work.
                systemd.services.nix-gc.serviceConfig = lowPriorityServiceConfig;
              })
            ];
          };
      };
  };
}
