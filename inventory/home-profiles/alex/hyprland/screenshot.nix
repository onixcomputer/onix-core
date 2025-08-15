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

  # Override the screenshot keybindings in hyprland config
  wayland.windowManager.hyprland.settings.bind = [
    # Region selection screenshot
    "$mod SHIFT, S, exec, screenshot-wrapper -m region -o ~/Screenshots"

    # Window selection screenshot
    "$mod SHIFT, W, exec, screenshot-wrapper -m window -o ~/Screenshots"
  ];
}
