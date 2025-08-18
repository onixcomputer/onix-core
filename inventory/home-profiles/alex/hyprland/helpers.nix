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
          exec ${pkgs.kitty}/bin/kitty --directory="$DIR" "$@"
        fi
      fi
    fi

    # Fallback to home directory
    exec ${pkgs.kitty}/bin/kitty "$@"
  '';
in
{
  home.packages = [ terminal-cwd ];
}
