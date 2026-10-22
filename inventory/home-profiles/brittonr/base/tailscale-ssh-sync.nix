{
  lib,
  osConfig ? { },
  pkgs,
  ...
}:
let
  sync = pkgs.writeShellApplication {
    name = "tailscale-ssh-sync";
    text = ''
      exec ${pkgs.python3}/bin/python3 ${./tailscale-ssh-sync.py} \
        --tailscale ${pkgs.tailscale}/bin/tailscale "$@"
    '';
  };
in
{
  config =
    lib.mkIf (pkgs.stdenv.hostPlatform.isLinux && (osConfig.services.tailscale.enable or false))
      {
        home.packages = [ sync ];

        systemd.user = {
          services.tailscale-ssh-sync = {
            Unit.Description = "Refresh SSH aliases from the local Tailscale inventory";

            Service = {
              Type = "oneshot";
              ExecStart = "${sync}/bin/tailscale-ssh-sync --output %h/.ssh/tailscale_hosts";
              UMask = "0077";
              TimeoutStartSec = "30s";
            };
          };

          timers.tailscale-ssh-sync = {
            Unit.Description = "Refresh Tailscale SSH aliases every minute";

            Timer = {
              OnStartupSec = "5s";
              OnUnitActiveSec = "1min";
              AccuracySec = "1s";
            };

            Install.WantedBy = [ "timers.target" ];
          };
        };
      };
}
