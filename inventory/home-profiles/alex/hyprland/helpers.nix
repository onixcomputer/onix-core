# custom helpers for our hyprland setup!
{ pkgs, ... }:
let
  # Terminal spawner that inherits working directory from focused window
  terminal-cwd = pkgs.writeShellScriptBin "terminal-cwd" ''
    PID=$(${pkgs.hyprland}/bin/hyprctl activewindow -j | ${pkgs.jq}/bin/jq -r '.pid')

    if [ -n "$PID" ] && [ "$PID" != "null" ]; then
      SHELL_PID=$(${pkgs.procps}/bin/pgrep -P "$PID" -x "fish|zsh|bash|sh" | head -1)

      if [ -n "$SHELL_PID" ]; then
        TARGET_PID="$SHELL_PID"
      else
        TARGET_PID="$PID"
      fi

      if [ -e "/proc/$TARGET_PID/cwd" ]; then
        DIR=$(readlink "/proc/$TARGET_PID/cwd" 2>/dev/null)
        if [ -n "$DIR" ] && [ -d "$DIR" ]; then
          exec ${pkgs.alacritty}/bin/alacritty --working-directory "$DIR" "$@"
        fi
      fi
    fi

    # Fallback to home directory
    exec ${pkgs.alacritty}/bin/alacritty "$@"
  '';

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
    terminal-cwd
    screenshot-wrapper
    networkmanager
    networkmanagerapplet # Provides nm-connection-editor binary only
    hyprlock # Screen locker for Hyprland
  ];

  # Explicitly disable nm-applet service (we use waybar + rofi instead)
  services.network-manager-applet.enable = false;
}
