_: {
  _class = "clan.service";

  manifest = {
    name = "clan-var-echo";
    description = "Demo service that generates a clan var and echoes it to systemd journal";
    categories = [
      "Development"
      "Testing"
    ];
  };

  roles.server = {
    interface =
      { lib, ... }:
      {
        freeformType = lib.types.attrsOf lib.types.anything;

        options = {
          message = lib.mkOption {
            type = lib.types.str;
            default = "Generated clan var token";
            description = ''
              Custom message to include with the echoed token in the journal.
            '';
          };

          interval = lib.mkOption {
            type = lib.types.str;
            default = "1h";
            description = ''
              How often to echo the token to the journal. Set to empty string for one-shot.
            '';
          };
        };
      };

    perInstance =
      { instanceName, settings, ... }:
      {
        nixosModule =
          { pkgs, lib, ... }:
          let
            message = settings.message or "Simple echo service test";
            interval = settings.interval or "1h";

            serviceName = "clan-var-echo-${instanceName}";
          in
          {
            # No clan vars needed for this simplified test

            # Create systemd service to echo the token to journal
            systemd.services.${serviceName} = {
              description = "Echo clan var token to journal (${instanceName})";
              wants = [ "multi-user.target" ];
              after = [ "multi-user.target" ];

              serviceConfig = {
                Type = "oneshot";
                User = "root";
                Group = "systemd-journal";
                RemainAfterExit = lib.mkIf (interval == "") true;
              };

              script = ''
                # Simple service to test tag-based deployment in microvm
                echo "=== Clan Echo Service Test (${instanceName}) ===" | ${pkgs.systemd}/bin/systemd-cat -t ${serviceName} -p info
                echo "Service started at $(date)" | ${pkgs.systemd}/bin/systemd-cat -t ${serviceName} -p info
                echo "Running on hostname: $(hostname)" | ${pkgs.systemd}/bin/systemd-cat -t ${serviceName} -p info
                echo "${message}" | ${pkgs.systemd}/bin/systemd-cat -t ${serviceName} -p info
                echo "Service completed successfully!" | ${pkgs.systemd}/bin/systemd-cat -t ${serviceName} -p info
              '';
            }
            // lib.optionalAttrs (interval != "") {
              # If interval is set, make it a timer-based service
              wantedBy = [ ]; # Don't start automatically, let timer handle it
            }
            // lib.optionalAttrs (interval == "") {
              # If no interval, run once at boot
              wantedBy = [ "multi-user.target" ];
            };

            # Create timer if interval is specified
            systemd.timers = lib.optionalAttrs (interval != "") {
              ${serviceName} = {
                description = "Timer for clan var echo service (${instanceName})";
                wantedBy = [ "timers.target" ];
                timerConfig = {
                  OnBootSec = "1m"; # First run 1 minute after boot
                  OnUnitActiveSec = interval; # Repeat every interval
                  Persistent = true;
                };
              };
            };
          };
      };
  };
}
