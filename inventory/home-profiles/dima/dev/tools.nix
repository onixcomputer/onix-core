{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Search and file tools
    ripgrep
    fd

    # Archive tools
    unzip

    # Network tools
    wget

    # Parser and formatter tools
    tree-sitter
    stylua
  ];
}
