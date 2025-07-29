{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Audio control utilities
    pavucontrol
    pamixer
    playerctl
  ];
}
