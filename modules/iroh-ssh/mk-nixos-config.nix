{
  config,
  lib,
  pkgs,
  settings,
  privateKeyPath,
  publicKeyPath,
}:
let
  serviceName = "iroh-ssh";
  serviceUser = serviceName;
  serviceGroup = serviceName;
  stateDirectoryName = serviceName;
  stateHome = "/var/lib/${stateDirectoryName}";
  sshDirectory = "${stateHome}/.ssh";
  privateKeyFileName = "irohssh_ed25519";
  publicKeyFileName = "${privateKeyFileName}.pub";
  privateKeyMode = "0600";
  publicKeyMode = "0644";
  restartDelay = "10s";

  irohSsh = pkgs.callPackage ../../pkgs/iroh-ssh { };
  setupKeys = pkgs.writeShellApplication {
    name = "${serviceName}-setup-keys";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      mkdir -p ${sshDirectory}
      install -o ${serviceUser} -g ${serviceGroup} -m ${privateKeyMode} \
        ${lib.escapeShellArg privateKeyPath} \
        ${sshDirectory}/${privateKeyFileName}
      install -o ${serviceUser} -g ${serviceGroup} -m ${publicKeyMode} \
        ${lib.escapeShellArg publicKeyPath} \
        ${sshDirectory}/${publicKeyFileName}
    '';
  };
in
{
  assertions = [
    {
      assertion = config.services.openssh.enable or false;
      message = "${serviceName}: requires openssh to be enabled (services.openssh.enable = true) — iroh-ssh forwards incoming connections to local sshd on port ${toString settings.sshPort}";
    }
  ];

  systemd.services.${serviceName} = {
    description = "iroh-ssh server";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [
      "network-online.target"
      "sshd.service"
    ];

    serviceConfig = {
      Type = "simple";
      User = serviceUser;
      Group = serviceGroup;
      StateDirectory = stateDirectoryName;
      ExecStartPre = "+${lib.getExe setupKeys}";
      ExecStart = "${lib.getExe irohSsh} server --persist --ssh-port ${toString settings.sshPort}";
      Environment = "HOME=${stateHome}";
      Restart = "on-failure";
      RestartSec = restartDelay;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      NoNewPrivileges = true;
    };
  };

  users.users.${serviceUser} = {
    isSystemUser = true;
    group = serviceGroup;
    home = stateHome;
  };
  users.groups.${serviceGroup} = { };

  environment.systemPackages = [ irohSsh ];
}
