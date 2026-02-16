_: {
  _class = "clan.service";

  manifest = {
    name = "iroh-ssh";
    description = "P2P SSH via Iroh - SSH to machines without public IPs, port forwarding, or VPN";
    readme = "Iroh-based peer-to-peer SSH using QUIC/UDP hole-punching for NAT traversal";
    categories = [
      "Networking"
      "SSH"
    ];
  };

  roles.peer = {
    description = "Iroh SSH peer that runs the iroh-ssh server for incoming connections";
    interface =
      { lib, ... }:
      {
        freeformType = lib.types.attrsOf lib.types.anything;

        options = {
          persist = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Persist iroh node identity across restarts";
          };
        };
      };

    perInstance =
      { instanceName, settings, ... }:
      {
        nixosModule =
          {
            pkgs,
            lib,
            ...
          }:
          let
            iroh-ssh = pkgs.callPackage ../../pkgs/iroh-ssh { };
            persist = settings.persist or true;
          in
          {
            systemd.services."iroh-ssh-${instanceName}" = {
              description = "Iroh SSH Server (${instanceName})";
              wantedBy = [ "multi-user.target" ];
              wants = [ "network-online.target" ];
              after = [
                "network-online.target"
                "sshd.service"
              ];

              serviceConfig = {
                ExecStart = "${iroh-ssh}/bin/iroh-ssh server${lib.optionalString persist " --persist"}";
                StateDirectory = "iroh-ssh-${instanceName}";
                WorkingDirectory = "/var/lib/iroh-ssh-${instanceName}";
                Restart = "on-failure";
                RestartSec = "10s";

                # Hardening
                DynamicUser = true;
                ProtectSystem = "strict";
                ProtectHome = true;
                PrivateTmp = true;
                NoNewPrivileges = true;
              };
            };

            # Allow UDP for QUIC (iroh uses UDP hole-punching for NAT traversal)
            networking.firewall.allowedUDPPortRanges = [
              {
                from = 1024;
                to = 65535;
              }
            ];

            # Install iroh-ssh CLI system-wide
            environment.systemPackages = [ iroh-ssh ];
          };
      };
  };
}
