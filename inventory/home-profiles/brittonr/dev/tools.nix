{ pkgs, ... }:
let
  tuicr = pkgs.callPackage ../../../../pkgs/tuicr { };
in
{
  home.packages = with pkgs; [
    # Search and file tools
    ripgrep
    fd
    bat
    nixos-generators
    glow
    comma
    warp-terminal
    nh
    nix-search-tv
    deadnix
    statix
    dix
    flake-edit
    terranix
    nix-index
    nix-prefetch
    android-tools

    # Archive tools
    unzip

    # Network tools
    wget

    # Debug and system tools
    lsof
    gdb
    ast-grep
    graphicsmagick
    tea
    sysdig

    # Code quality tools
    shellcheck
    ruff
    mypy

    # Parser and formatter tools
    tree-sitter
    stylua

    # TUI tools
    tuicr
  ];
}
