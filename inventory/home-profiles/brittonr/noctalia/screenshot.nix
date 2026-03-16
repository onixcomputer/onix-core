{ pkgs, config, ... }:
let
  screenshotDir = config.paths.screenshots;

  # Screenshot wrapper for region selection with annotation support
  # Uses grim + slurp + satty for niri (compositor-agnostic tools)
  screenshot-region = pkgs.writeShellScriptBin "screenshot-region" ''
    set -e
    SCREENSHOT_DIR="${screenshotDir}"
    mkdir -p "$SCREENSHOT_DIR"

    # Kill any lingering satty from a previous screenshot instead of
    # silently failing. The old flock approach caused a "cooldown" where
    # re-triggering right after closing satty would silently exit.
    ${pkgs.procps}/bin/pkill -x satty 2>/dev/null || true

    # Capture region with slurp, pipe through satty for annotation
    ${pkgs.grim}/bin/grim -t ppm -g "$(${pkgs.slurp}/bin/slurp -d)" - | \
      ${pkgs.satty}/bin/satty --filename - \
        --copy-command="${pkgs.wl-clipboard}/bin/wl-copy" \
        --annotation-size-factor ${toString config.screenshot.annotationSizeFactor} \
        --output-filename="$SCREENSHOT_DIR/screenshot_%Y-%m-%d_%H-%M-%S.png" \
        --actions-on-enter="save-to-clipboard,exit" \
        --actions-on-escape="save-to-clipboard,exit" \
        --brush-smooth-history-size=${toString config.screenshot.brushSmoothHistorySize} \
        --disable-notifications
  '';

  # Full screen screenshot (no annotation)
  # Uses niri's built-in screenshot to avoid wlr-screencopy compositor stall.
  # niri renders directly into its own buffer (~27ms vs ~45ms for grim's
  # Wayland client round-trip). At 3840x2160@240Hz on NVIDIA, this cuts
  # dropped frames from ~10 to ~6.
  screenshot-screen = pkgs.writeShellScriptBin "screenshot-screen" ''
    niri msg action screenshot-screen
  '';

  # Full screen screenshot with satty annotation
  screenshot-screen-edit = pkgs.writeShellScriptBin "screenshot-screen-edit" ''
    set -e
    SCREENSHOT_DIR="${screenshotDir}"
    mkdir -p "$SCREENSHOT_DIR"

    # Kill any lingering satty from a previous screenshot
    ${pkgs.procps}/bin/pkill -x satty 2>/dev/null || true

    ${pkgs.grim}/bin/grim -t ppm - | \
      ${pkgs.satty}/bin/satty --filename - \
        --copy-command="${pkgs.wl-clipboard}/bin/wl-copy" \
        --annotation-size-factor ${toString config.screenshot.annotationSizeFactor} \
        --output-filename="$SCREENSHOT_DIR/screenshot_%Y-%m-%d_%H-%M-%S.png" \
        --actions-on-enter="save-to-clipboard,exit" \
        --actions-on-escape="save-to-clipboard,exit" \
        --brush-smooth-history-size=${toString config.screenshot.brushSmoothHistorySize} \
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
    pkgs.grim # still needed for region/edit (slurp selection)
    pkgs.slurp
    pkgs.satty
    pkgs.hyprpicker
    pkgs.wl-clipboard
    pkgs.libnotify
    pkgs.procps # for pkill in screenshot scripts
    # Custom wrappers
    screenshot-region
    screenshot-screen
    screenshot-screen-edit
    color-picker
  ];

  # Ensure Screenshots directory exists
  home.file."Pictures/Screenshots/.keep".text = "";
}
