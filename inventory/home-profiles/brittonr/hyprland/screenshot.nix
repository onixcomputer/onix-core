{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Screenshot tools
    hyprshot
    hyprpicker
    slurp
    satty
    grim
  ];
}
