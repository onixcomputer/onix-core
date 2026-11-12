{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  user = "brittonr";
  home = "/Users/${user}";
  stateDirectory = "${home}/.local/state/herdr-iroh";
  socketPath = "${home}/.config/herdr/herdr.sock";
  herdrIrohPackage = inputs.herdr-iroh.packages.${pkgs.stdenv.hostPlatform.system}.default;
  allowedPeers = {
    britton-grok.endpointId = "8f9a3e1c7b464c60cce5bccf653b043ff444c2fa524828a2f7a66d0495153311";
  };

  # herdr-iroh ships a NixOS module only. On the laptop run the same relay and
  # saved-machine gateway as a per-user LaunchAgent: macOS launchd refused to
  # posix_spawn the store binary from a system LaunchDaemon with UserName.
  peerBlocks = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: peer: ''
      [peers.${builtins.toJSON name}]
      endpoint_id = ${builtins.toJSON peer.endpointId}
      methods = "full"
    '') allowedPeers
  );
  configFile = pkgs.writeText "herdr-iroh-server.toml" ''
    relays = true
    relay_timeout_ms = 900000
    gateway = true
    socket_path = ${builtins.toJSON socketPath}
    herdr_bin = ${builtins.toJSON "${pkgs.herdr}/bin/herdr"}

    ${peerBlocks}
  '';
in
{
  home.activation.herdrIrohStateDirectory = lib.hm.dag.entryBefore [ "setupLaunchAgents" ] ''
    run install -d -m 700 ${stateDirectory}
  '';

  launchd.agents.herdr-iroh = {
    enable = true;
    config = {
      ProgramArguments = [
        "${herdrIrohPackage}/bin/herdr-iroh"
        "serve"
        "--config"
        (toString configFile)
        "--state-dir"
        stateDirectory
      ];
      RunAtLoad = true;
      KeepAlive = true;
      WorkingDirectory = home;
      EnvironmentVariables = {
        HOME = home;
        PATH = "/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      };
      StandardOutPath = "${home}/Library/Logs/herdr-iroh.log";
      StandardErrorPath = "${home}/Library/Logs/herdr-iroh.err.log";
    };
  };
}
