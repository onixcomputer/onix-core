{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  cfg = config.services.meshtop;
  package = self.packages.${pkgs.stdenv.hostPlatform.system}.meshtop;
in
{
  options.services.meshtop = {
    enable = lib.mkEnableOption "read-only meshtop agent and interactive viewer";

    viewerId = lib.mkOption {
      type = lib.types.strMatching "[0-9a-f]{64}";
      description = "Public Iroh endpoint ID of the only viewer authorized to read this agent's snapshots.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ package ];

    systemd.services.meshtop = {
      description = "Read-only meshtop monitoring agent";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      serviceConfig = {
        Type = "simple";
        DynamicUser = true;
        StateDirectory = "meshtop";
        StateDirectoryMode = "0700";
        UMask = "0077";
        ExecStart = "${lib.getExe package} agent --viewer ${cfg.viewerId} --key /var/lib/meshtop/agent.key";
        Restart = "on-failure";
        RestartSec = "5s";
        NoNewPrivileges = true;
        CapabilityBoundingSet = "";
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectControlGroups = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_NETLINK"
          "AF_UNIX"
        ];
      };
    };
  };
}
