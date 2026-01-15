{ pkgs, ... }:
let
  # Screenshot wrapper for region selection with annotation support
  # Uses grim + slurp + satty for niri (compositor-agnostic tools)
  screenshot-region = pkgs.writeShellScriptBin "screenshot-region" ''
    set -e
    SCREENSHOT_DIR="$HOME/Screenshots"
    mkdir -p "$SCREENSHOT_DIR"

    # Use a lock file to prevent multiple instances
    LOCKFILE="/tmp/screenshot-$USER.lock"
    exec 9>"$LOCKFILE"
    if ! ${pkgs.util-linux}/bin/flock -n 9; then
      # Screenshot already in progress, exit silently
      exit 0
    fi

    # Capture region with slurp, pipe through satty for annotation
    ${pkgs.grim}/bin/grim -t ppm -g "$(${pkgs.slurp}/bin/slurp -d)" - | \
      ${pkgs.satty}/bin/satty --filename - \
        --copy-command="${pkgs.wl-clipboard}/bin/wl-copy" \
        --annotation-size-factor 2.0 \
        --output-filename="$SCREENSHOT_DIR/screenshot_%Y-%m-%d_%H-%M-%S.png" \
        --actions-on-enter="save-to-clipboard,exit" \
        --actions-on-escape="save-to-clipboard,exit" \
        --brush-smooth-history-size=5 \
        --disable-notifications
  '';

  # Full screen screenshot (no annotation)
  screenshot-screen = pkgs.writeShellScriptBin "screenshot-screen" ''
    set -e
    SCREENSHOT_DIR="$HOME/Screenshots"
    mkdir -p "$SCREENSHOT_DIR"
    FILENAME="$SCREENSHOT_DIR/screenshot_$(date +'%Y-%m-%d_%H-%M-%S').png"

    ${pkgs.grim}/bin/grim "$FILENAME"
    ${pkgs.wl-clipboard}/bin/wl-copy < "$FILENAME"
    ${pkgs.libnotify}/bin/notify-send "Screenshot" "Saved to $FILENAME" -i camera-photo
  '';

  # Full screen screenshot with satty annotation
  screenshot-screen-edit = pkgs.writeShellScriptBin "screenshot-screen-edit" ''
    set -e
    SCREENSHOT_DIR="$HOME/Screenshots"
    mkdir -p "$SCREENSHOT_DIR"

    # Use a lock file to prevent multiple instances
    LOCKFILE="/tmp/screenshot-$USER.lock"
    exec 9>"$LOCKFILE"
    if ! ${pkgs.util-linux}/bin/flock -n 9; then
      exit 0
    fi

    ${pkgs.grim}/bin/grim -t ppm - | \
      ${pkgs.satty}/bin/satty --filename - \
        --copy-command="${pkgs.wl-clipboard}/bin/wl-copy" \
        --annotation-size-factor 2.0 \
        --output-filename="$SCREENSHOT_DIR/screenshot_%Y-%m-%d_%H-%M-%S.png" \
        --actions-on-enter="save-to-clipboard,exit" \
        --actions-on-escape="save-to-clipboard,exit" \
        --brush-smooth-history-size=5 \
        --disable-notifications
  '';

  # Color picker
  color-picker = pkgs.writeShellScriptBin "color-picker" ''
    color=$(${pkgs.hyprpicker}/bin/hyprpicker -a)
    if [ -n "$color" ]; then
      ${pkgs.libnotify}/bin/notify-send "Color Picked" "$color copied to clipboard" -i color-picker
    fi
  '';
in
{
  home.packages = [
    # Screenshot tools
    pkgs.grim
    pkgs.slurp
    pkgs.satty
    pkgs.hyprpicker
    pkgs.wl-clipboard
    pkgs.libnotify
    # Custom wrappers
    screenshot-region
    screenshot-screen
    screenshot-screen-edit
    color-picker
  ];

  # Ensure Screenshots directory exists
  home.file."Screenshots/.keep".text = "";
}
