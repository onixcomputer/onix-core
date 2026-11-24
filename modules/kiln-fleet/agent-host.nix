# A Kiln fleet agent host: a headless herdr session named `kiln` for the
# agents the coordinator dispatches. Kiln reaches it locally on the
# coordinator and through a saved herdr machine elsewhere; it never uses the
# operator's default session, so dispatched agents stay out of his layout.
# Attach to watch them with `herdr --session kiln`.
#
# Kiln fetches each agent's commit from its worktree over ssh with Kiln's own
# key, which this host accepts only for git-upload-pack under the Kiln
# worktree root.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  fleet = import ./lib.nix {
    inherit lib;
    inherit (inputs) self;
  };
  account = config.users.users.${fleet.user};
  uid = toString account.uid;
  worktreeRoot = fleet.worktreeRoot config.networking.hostName;

  uploadPackOnly = pkgs.writeShellScript "kiln-fleet-upload-pack" ''
    set -eu
    request=''${SSH_ORIGINAL_COMMAND:-}
    case "$request" in
      "git-upload-pack '"*"'") ;;
      *)
        echo "kiln-fleet: only git-upload-pack is allowed" >&2
        exit 1
        ;;
    esac
    path=''${request#git-upload-pack \'}
    path=''${path%\'}
    case "$path" in
      *..* | *\'*)
        echo "kiln-fleet: refused path" >&2
        exit 1
        ;;
      ${worktreeRoot}/*) ;;
      *)
        echo "kiln-fleet: only Kiln worktrees can be fetched" >&2
        exit 1
        ;;
    esac
    exec ${pkgs.git}/bin/git-upload-pack "$path"
  '';
in
{
  users.users.${fleet.user}.openssh.authorizedKeys.keys = lib.optional (
    fleet.sshPublicKey != null
  ) ''restrict,command="${uploadPackOnly}" ${fleet.sshPublicKey}'';

  systemd.tmpfiles.rules = [
    "d ${builtins.dirOf worktreeRoot} 0700 ${fleet.user} ${account.group} -"
    "d ${worktreeRoot} 0700 ${fleet.user} ${account.group} -"
  ];

  systemd.services.herdr-kiln = {
    description = "Headless herdr session for Kiln-dispatched agents";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    # A restart stops every pane, so a switch must not kill dispatched agents;
    # restart it by hand after a herdr update.
    restartIfChanged = false;
    # Panes start the user's login shell, which sets the agents' PATH; ssh
    # and the agents need the runtime directory that lingering keeps.
    environment = {
      HOME = account.home;
      SHELL = "/run/current-system/sw/bin/fish";
      XDG_RUNTIME_DIR = "/run/user/${uid}";
    };
    path = [
      "/etc/profiles/per-user/${fleet.user}"
      "/run/current-system/sw"
    ];
    serviceConfig = {
      User = fleet.user;
      ExecStart = "${lib.getExe pkgs.herdr} --session ${fleet.herdrSession} server";
      ExecStop = "${lib.getExe pkgs.herdr} --session ${fleet.herdrSession} server stop";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}
