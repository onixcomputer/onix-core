{ schema }:
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
          in
          {
            nix = {
              gc = {
                automatic = true;
                dates = cfg.schedule;
                options = "--delete-older-than ${toString cfg.retentionDays}d";
              };

              settings.auto-optimise-store = cfg.autoOptimise;

              optimise = lib.mkIf cfg.optimizeStore {
                automatic = true;
                dates = cfg.optimizeSchedule;
              };
            };

            # Run GC at lowest priority — never steal resources from builds or interactive work
            systemd.services.nix-gc.serviceConfig = {
              CPUSchedulingPolicy = lib.mkForce "idle";
              IOSchedulingClass = "idle";
              Nice = 19;
            };
          };
      };
  };
}
