# Check evaluated service values and generated files, not Nix source strings.
#
# Collie 1.x owns its user unit, its .env and its crew state: every crew verb
# rewrites and restarts ~/.config/systemd/user/collie.service, and `collie start`
# writes COLLIE_MUX into the .env. A Home Manager link at any of those paths
# makes the verb fail after it has stopped the bridge. NixOS keeps the desktop
# front door; the desktop-tailnet-proxy check covers that mapping.
{
  pkgs,
  lib,
  desktopConfig,
  desktopHome,
  aspen3Home,
  aspen1Home,
  collie,
}:
let
  homes = {
    britton-desktop = desktopHome;
    aspen3 = aspen3Home;
    aspen1 = aspen1Home;
  };
  crewHomes = {
    britton-desktop = desktopHome;
    aspen3 = aspen3Home;
  };
  retiredUnits = [
    "collie"
    "collie-aspen3"
    "collie-serve"
  ];
  retiredFiles = [
    "collie/.env"
    "herdr/plugins/config/herdr.collie/.env"
    "herdr/sessions/aspen3/herdr.sock"
  ];
  checks =
    lib.concatLists (
      lib.mapAttrsToList (host: home: [
        {
          name = "negative: ${host} Home Manager declares no Collie user unit";
          passed = lib.all (unit: !(home.systemd.user.services ? ${unit})) retiredUnits;
        }
        {
          name = "negative: ${host} Home Manager links no Collie .env or remote socket";
          passed = lib.all (file: !(home.xdg.configFile ? ${file})) retiredFiles;
        }
      ]) homes
    )
    ++ lib.mapAttrsToList (host: home: {
      name = "positive: ${host} starts Collie's own unit after sd-switch";
      passed =
        home.home.activation ? startCollie
        && builtins.elem "reloadSystemd" home.home.activation.startCollie.after;
    }) crewHomes
    ++ [
      {
        name = "negative: Collie cannot adopt the host-owned front door (no Tailscale operator role)";
        passed = !(builtins.elem "--operator=brittonr" desktopConfig.services.tailscale.extraUpFlags);
      }
    ];
in
pkgs.runCommand "collie-integration" { } ''
  set -eu
  ${lib.concatMapStringsSep "\n" (check: ''
    if [ "${lib.boolToString check.passed}" != true ]; then
      echo ${lib.escapeShellArg check.name} >&2
      exit 1
    fi
  '') checks}

  if ${pkgs.gnugrep}/bin/grep -Eq '^\[\[build\]\]|^id = "(update|uninstall)"' ${collie}/herdr-plugin.toml; then
    echo 'negative: the immutable plugin exposes installation mutations' >&2
    exit 1
  fi
  touch "$out"
''
