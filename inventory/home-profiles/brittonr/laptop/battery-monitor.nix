{ pkgs, config, ... }:
{
  home.packages = [ pkgs.batsignal ];

  systemd.user.services.batsignal = {
    Unit = {
      Description = "Battery signal - battery monitor and notification";
      After = [ "graphical-session.target" ];
    };

    Service = {
      Type = "simple";
      ExecStart = "${pkgs.batsignal}/bin/batsignal -w ${toString config.power.battery.warning} -c ${toString config.power.battery.critical} -d ${toString config.power.battery.danger} -f ${toString config.power.battery.full}";
      Restart = "on-failure";
      RestartSec = config.serviceTiming.restartSec.normal;
    };

    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
