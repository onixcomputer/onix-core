{
  config,
  inputs,
  pkgs,
  ...
}:
let
  package = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.meshtop;
  viewerId = "e4595bca7f97787646d6da8b3eab21f02e88d56759b9ac73d3a2f05c3932af51";
  agentKey = "${config.home.homeDirectory}/.local/state/meshtop/agent.key";
in
{
  home.packages = [ package ];

  home.file.".config/meshtop/hosts.toml".text = ''
    [[hosts]]
    name = "aspen3"
    id = "1513e39997fc37845f7af6421fdf1ebc47c3920123d66bd3849b934204c40339"

    [[hosts]]
    name = "britton-desktop"
    id = "6751880624ae32a6dddb262599be7a867fa20994ebcebb1d0e84c4b2aa0cfc77"

    [[hosts]]
    name = "bonsai"
    id = "9c71e0f64c3d068d9f6997a978d9575ca99486332ebec799b566a086b6520d66"

    [[hosts]]
    name = "leviathan"
    id = "0cc38af96ba5edcac062ed2f0f90dcf2581915154a36b37a1b41677d87a304ac"
  '';

  systemd.user.services.meshtop = {
    Unit.Description = "Read-only meshtop monitoring agent";

    Service = {
      Type = "simple";
      ExecStart = "${package}/bin/meshtop agent --viewer ${viewerId} --key ${agentKey}";
      StateDirectory = "meshtop";
      StateDirectoryMode = "0700";
      UMask = "0077";
      Restart = "on-failure";
      RestartSec = "5s";
      NoNewPrivileges = true;
    };

    Install.WantedBy = [ "default.target" ];
  };
}
