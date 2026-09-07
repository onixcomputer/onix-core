# Forward only Aspen3's user-owned JSON API socket, not Herdr's client protocol.
{
  config,
  lib,
  osConfig ? { },
  pkgs,
  ...
}:
let
  enabled = (osConfig.networking.hostName or null) == "britton-desktop";
  remoteUser = "brittonr";
  remoteHost = "aspen3.local";
  hostKeyAlias = "aspen3.clan";
  runtimeDirectory = "collie-aspen3";
  userId = osConfig.users.users.${config.home.username}.uid;
  runtimeRoot = "/run/user/${toString userId}";
  remoteSocket = "/home/${remoteUser}/.config/herdr/herdr.sock";
  localSocket = "${runtimeRoot}/${runtimeDirectory}/herdr.sock";
  connectTimeoutSeconds = 10;
  keepaliveSeconds = 15;
  keepaliveFailures = 3;
  restartDelay = "5s";
  privateDirectoryMode = "0700";
  privateSocketMask = "0177";
  sshArgs = [
    "${pkgs.openssh}/bin/ssh"
    "-F"
    "/dev/null"
    "-NT"
    "-o"
    "BatchMode=yes"
    "-o"
    "StrictHostKeyChecking=yes"
    "-o"
    "HostKeyAlias=${hostKeyAlias}"
    "-o"
    "IdentitiesOnly=yes"
    "-i"
    "%h/.ssh/framework"
    "-o"
    "IdentityAgent=%t/yubikey-agent/yubikey-agent.sock"
    "-o"
    "ForwardAgent=no"
    "-o"
    "ExitOnForwardFailure=yes"
    "-o"
    "ConnectTimeout=${toString connectTimeoutSeconds}"
    "-o"
    "ServerAliveInterval=${toString keepaliveSeconds}"
    "-o"
    "ServerAliveCountMax=${toString keepaliveFailures}"
    "-o"
    "StreamLocalBindMask=${privateSocketMask}"
    "-o"
    "StreamLocalBindUnlink=yes"
    "-L"
    "%t/${runtimeDirectory}/herdr.sock:${remoteSocket}"
    "${remoteUser}@${remoteHost}"
  ];
in
{
  config = lib.mkIf enabled {
    assertions = [
      {
        assertion = builtins.isInt userId && userId > 0;
        message = "The Collie remote socket requires a fixed user UID.";
      }
    ];

    # Keep a real session directory for Collie's Dirent.isDirectory discovery.
    # Only the socket file links to the private runtime directory.
    xdg.configFile."herdr/sessions/aspen3/herdr.sock".source =
      config.lib.file.mkOutOfStoreSymlink localSocket;

    systemd.user.services.collie-aspen3 = {
      Unit = {
        Description = "Aspen3 Herdr API socket for Collie";
        After = [ "yubikey-agent.service" ];
        # A missing network or locked agent must not exhaust a startup budget.
        StartLimitIntervalSec = 0;
      };
      Service = {
        Type = "exec";
        ExecStart = lib.escapeShellArgs sshArgs;
        Restart = "always";
        RestartSec = restartDelay;
        RuntimeDirectory = runtimeDirectory;
        RuntimeDirectoryMode = privateDirectoryMode;
        NoNewPrivileges = true;
        PrivateTmp = true;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
