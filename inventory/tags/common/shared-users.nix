# Shared user management for NixOS and Darwin.
# Defines admin users with platform-aware defaults.
# Uses _class to handle differences:
#   - Darwin: isNormalUser polyfill, home=/Users/<name>, gid=80 for admin
#   - NixOS: standard user config, wheel group for sudo
#
# SSH keys, UID, and shell are shared. Platform-specific group/home
# assignments are handled by conditionals.
#
# Adapted from clan-infra modules/admins.nix.
{
  _class,
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  # Collect nix-builder SSH public keys from all machines that have generated one.
  # These keys let the nix daemon (root) on builder-consumers authenticate to
  # builder hosts. Same auto-discovery pattern as nix-signing.nix.
  varsDir = "${self}/vars/per-machine";
  machines = lib.attrNames (builtins.readDir varsDir);
  builderPubKeys = lib.flatten (
    map (
      machine:
      let
        keyPath = "${varsDir}/${machine}/nix-builder-ssh/id_ed25519.pub/value";
      in
      lib.optional (builtins.pathExists keyPath) (lib.fileContents keyPath)
    ) machines
  );
in
{
  # Darwin needs users.knownUsers to manage users declaratively.
  # List users we define here so nix-darwin knows to manage them.
  imports = lib.optional (_class == "darwin") {
    users.knownUsers = [ "brittonr" ];
  };

  config = {
    users.users =
      let
        baseUid = if _class == "darwin" then 555 else 1555;

        sshKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILYzh3yIsSTOYXkJMFHBKzkakoDfonm3/RED5rqMqhIO britton@framework"
        ]
        ++ builderPubKeys;
      in
      {
        brittonr = {
          uid = baseUid;
          openssh.authorizedKeys.keys = sshKeys;
        }
        // lib.optionalAttrs (_class == "nixos") {
          isNormalUser = true;
          group = "brittonr";
          shell = pkgs.fish;
          extraGroups = [ "wheel" ];
        }
        // lib.optionalAttrs (_class == "darwin") {
          home = "/Users/brittonr";
          createHome = true;
          shell = "/run/current-system/sw/bin/fish";
          gid = 80; # admin group = sudo on darwin
        };
      }
      // lib.optionalAttrs (_class == "nixos") {
        # Auto-propagate SSH keys from all wheel users to root.
        root.openssh.authorizedKeys.keys = builtins.concatMap (user: user.openssh.authorizedKeys.keys) (
          builtins.attrValues (
            lib.filterAttrs (
              _: user: (user.isNormalUser or false) && builtins.elem "wheel" (user.extraGroups or [ ])
            ) config.users.users
          )
        );
      }
      // lib.optionalAttrs (_class == "darwin") {
        # Authorize root for SSH deploys (same pattern as NixOS).
        # macOS root home is /var/root.
        root.openssh.authorizedKeys.keys = sshKeys;
      };

    # brittonr group only on NixOS (darwin uses gid=80 admin group)
    users.groups = lib.optionalAttrs (_class == "nixos") {
      brittonr = { };
    };

    programs.fish.enable = true;

    # sudo authentication: password, YubiKey, or fprintd — no NOPASSWD.
    # NixOS deploys SSH as root (no sudo needed).
    # Darwin deploys need interactive auth or local rebuild.
  };
}
