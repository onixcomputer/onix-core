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

    # Archive tools
    unzip

    # Network tools
    wget

    # Parser and formatter tools
    tree-sitter
    stylua
  ];
}
