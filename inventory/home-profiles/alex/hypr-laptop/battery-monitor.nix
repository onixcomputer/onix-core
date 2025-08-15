{ pkgs, ... }:
{
  home.packages = [ pkgs.batsignal ];

  systemd.user.services.batsignal = {
    Unit = {
      Description = "Battery signal - battery monitor and notification";
      After = [ "graphical-session.target" ];
    };

    Service = {
      Type = "simple";
      # -w: warning level (20%)
      # -c: critical level (10%)
      # -d: danger level (5%)
      # -e: make notifications expire (auto-dismiss)
      # -m: check interval in seconds
      ExecStart = "${pkgs.batsignal}/bin/batsignal -w 20 -c 10 -d 5 -e -m 120";
      Restart = "on-failure";
      RestartSec = "10s";
    };

    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
