_: {
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
    interface =
      { lib, ... }:
      {
        freeformType = lib.types.attrsOf lib.types.anything;

        options = {
          retentionDays = lib.mkOption {
            type = lib.types.int;
            default = 30;
            description = "Delete generations older than this many days";
          };
          schedule = lib.mkOption {
            type = lib.types.str;
            default = "weekly";
            description = "When to run GC (systemd calendar format)";
          };
          optimizeStore = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable automatic store optimization (hard-link deduplication)";
          };
          autoOptimise = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Optimize during each build (slight overhead, continuous benefit)";
          };
          optimizeSchedule = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ "04:00" ];
            description = "When to run full store optimization";
          };
        };
      };

    perInstance =
      { extendSettings, ... }:
      {
        nixosModule =
          { lib, ... }:
          let
            cfg = extendSettings {
              retentionDays = lib.mkDefault 30;
              schedule = lib.mkDefault "weekly";
              optimizeStore = lib.mkDefault true;
              autoOptimise = lib.mkDefault true;
              optimizeSchedule = lib.mkDefault [ "04:00" ];
            };
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
              CPUSchedulingPolicy = "idle";
              IOSchedulingClass = "idle";
              Nice = 19;
            };
          };
      };
  };
}
