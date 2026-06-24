# Shared development tools for NixOS and Darwin.
# Platform-aware: uses _class for packages that differ or don't exist
# on one platform.
#
# Adapted from clan-infra modules/dev.nix.
{
  _class,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  agentPkgs = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  nixfmt-rs = inputs.nixfmt-rs.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
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
      # nixpkgs-review depends on nix-eval-jobs, which currently fails to
      # compile against Onix's Nix C++ API. Re-enable after that package is fixed.
      nix-output-monitor
      nixfmt-rs
      ripgrep
      tree
    ]
    ++ lib.optionals (_class == "nixos") [
      agentPkgs.claude-code
      uutils-coreutils-noprefix
      kitty.terminfo
      wezterm.terminfo
      pstree
      systemctl-tui
      dua
    ]
    ++ lib.optionals (_class == "darwin") [
      agentPkgs.claude-code
    ];
}
