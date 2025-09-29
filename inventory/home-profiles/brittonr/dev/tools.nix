{ pkgs, ... }:
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
    terranix
    nix-index
    nix-prefetch
    android-tools

    # Archive tools
    unzip

    # Network tools
    wget

    # Parser and formatter tools
    tree-sitter
    stylua
  ];
}
