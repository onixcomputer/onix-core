{ pkgs, ... }:
{
  home.packages = with pkgs; [
    jujutsu
    bat
    fzf
    ripgrep
  ];
}
