{ pkgs, ... }:
let
  # Screenshot wrapper with lock mechanism to prevent multiple instances
  screenshot-wrapper = pkgs.writeShellScriptBin "screenshot-wrapper" ''
    # Use a lock file to prevent multiple instances
    LOCKFILE="/tmp/hyprshot-$USER.lock"
    exec 9>"$LOCKFILE"
    if ! ${pkgs.util-linux}/bin/flock -n 9; then
      # Screenshot already in progress, exit silently
      exit 0
    fi
    # Run hyprshot with the provided arguments
    ${pkgs.hyprshot}/bin/hyprshot "$@"
    # Lock is automatically released when script exits
  '';
in
{
  home.packages = with pkgs; [
    # Screenshot tools
    hyprshot
    hyprpicker
    slurp
    satty
    grim
    screenshot-wrapper
  ];

  # Override the screenshot keybindings in hyprland config
  wayland.windowManager.hyprland.settings.bind = [
    # Region selection screenshot
    "$mod SHIFT, S, exec, screenshot-wrapper -m region -o ~/Screenshots"

    # Window selection screenshot
    "$mod SHIFT, W, exec, screenshot-wrapper -m window -o ~/Screenshots"
  ];
}
