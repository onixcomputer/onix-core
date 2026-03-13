# Shared development tools for NixOS and Darwin.
# Platform-aware: uses _class for packages that differ or don't exist
# on one platform.
#
# Adapted from clan-infra modules/dev.nix.
{
  _class,
  lib,
  pkgs,
  ...
}:
{
  environment.systemPackages =
    with pkgs;
    [
      bat
      btop
      fd
      gh
      git
      jujutsu
      nixpkgs-review
      nix-output-monitor
      ripgrep
      tree
    ]
    ++ lib.optionals (_class == "nixos") [
      claude-code-bin
      uutils-coreutils-noprefix
      kitty.terminfo
      pstree
      systemctl-tui
      dua
    ]
    ++ lib.optionals (_class == "darwin") [
      claude-code
    ];
}
