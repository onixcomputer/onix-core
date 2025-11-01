{ inputs, ... }:
{
  networking = {
    hostName = "sequoia";
  };

  time.timeZone = "America/New_York";

  # adeci's dev blog
  systemd.services.devblog = {
    description = "adeci's dev blog";
    after = [ "network.target" ];

    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "10";
      User = "alex";
      Group = "users";
      ExecStart = "${inputs.devblog.packages.x86_64-linux.default}/bin/devblog";
    };
  };

  # Start the service but don't wait for it during deployment
  systemd.targets.multi-user.wants = [ "devblog.service" ];
}
