# Supervise the personal desktop Radicle node without sharing machine replica authority.
# r[impl onix.radicle_replica.personal_supervision]
# r[impl onix.radicle_replica.personal_signer]
{
  config,
  lib,
  pkgs,
  ...
}:
let
  radicleHome = "${config.home.homeDirectory}/.radicle";
  radicleSocket = "${radicleHome}/node/control.sock";
  nodeListenAddress = "127.0.0.1:0";
  restartDelay = "10s";
  yubikeyAgentUnit = "yubikey-agent.service";
  radicleDesktopPackage =
    import ../../../../modules/radicle-desktop/package.nix
      {
        inherit pkgs lib;
      }
      {
        desktopHome = radicleHome;
        desktopSocket = radicleSocket;
        inherit nodeListenAddress;
      };
  yubikeyAgentSocket = "%t/yubikey-agent/yubikey-agent.sock";
in
{
  assertions = [
    {
      assertion = config.services.yubikey-agent.enable;
      message = "The personal Radicle node requires services.yubikey-agent.enable";
    }
  ];

  home = {
    packages = [ radicleDesktopPackage ];
    sessionVariables = {
      RAD_HOME = radicleHome;
      RAD_SOCKET = radicleSocket;
    };
  };

  systemd.user.services.radicle-personal-node = {
    Unit = {
      Description = "Supervise the personal Radicle node";
      After = [ yubikeyAgentUnit ];
      Wants = [ yubikeyAgentUnit ];
      StartLimitIntervalSec = 0;
    };

    Service = {
      Type = "simple";
      ExecStart = "${radicleDesktopPackage}/bin/radicle-node --force";
      Environment = [ "SSH_AUTH_SOCK=${yubikeyAgentSocket}" ];
      Restart = "always";
      RestartSec = restartDelay;
      UMask = "0077";
    };

    Install.WantedBy = [ "default.target" ];
  };
}
