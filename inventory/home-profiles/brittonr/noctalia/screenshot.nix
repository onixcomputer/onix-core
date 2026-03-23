{ pkgs, config, ... }:
let
  screenshotDir = config.paths.screenshots;

  screenshot-region = pkgs.writeShellApplication {
    name = "screenshot-region";
    runtimeInputs = [
      pkgs.grim
      pkgs.slurp
      pkgs.satty
      pkgs.wl-clipboard
      pkgs.procps
    ];
    # SC2088: tilde in Nix-interpolated string is expanded at runtime below
    excludeShellChecks = [ "SC2088" ];
    text = ''
      SCREENSHOT_DIR="${screenshotDir}"
      SCREENSHOT_DIR="''${SCREENSHOT_DIR/#\~/$HOME}"
      mkdir -p "$SCREENSHOT_DIR"

      # Kill any lingering satty from a previous screenshot instead of
      # silently failing. The old flock approach caused a "cooldown" where
      # re-triggering right after closing satty would silently exit.
      pkill -x satty 2>/dev/null || true

      # Capture region with slurp, pipe through satty for annotation
      grim -t ppm -g "$(slurp -d)" - | \
        satty --filename - \
          --copy-command="wl-copy" \
          --annotation-size-factor ${toString config.screenshot.annotationSizeFactor} \
          --output-filename="$SCREENSHOT_DIR/screenshot_%Y-%m-%d_%H-%M-%S.png" \
          --actions-on-enter="save-to-clipboard,exit" \
          --actions-on-escape="save-to-clipboard,exit" \
          --brush-smooth-history-size=${toString config.screenshot.brushSmoothHistorySize} \
          --disable-notifications
    '';
  };

  # Full screen screenshot (no annotation)
  # Uses niri's built-in screenshot to avoid wlr-screencopy compositor stall.
  # niri renders directly into its own buffer (~27ms vs ~45ms for grim's
  # Wayland client round-trip). At 3840x2160@240Hz on NVIDIA, this cuts
  # dropped frames from ~10 to ~6.
  screenshot-screen = pkgs.writeShellApplication {
    name = "screenshot-screen";
    text = ''
      niri msg action screenshot-screen
    '';
  };

  # Full screen screenshot with satty annotation
  screenshot-screen-edit = pkgs.writeShellApplication {
    name = "screenshot-screen-edit";
    runtimeInputs = [
      pkgs.grim
      pkgs.satty
      pkgs.wl-clipboard
      pkgs.procps
    ];
    # SC2088: tilde in Nix-interpolated string is expanded at runtime below
    excludeShellChecks = [ "SC2088" ];
    text = ''
      SCREENSHOT_DIR="${screenshotDir}"
      SCREENSHOT_DIR="''${SCREENSHOT_DIR/#\~/$HOME}"
      mkdir -p "$SCREENSHOT_DIR"

      # Kill any lingering satty from a previous screenshot
      pkill -x satty 2>/dev/null || true

      grim -t ppm - | \
        satty --filename - \
          --copy-command="wl-copy" \
          --annotation-size-factor ${toString config.screenshot.annotationSizeFactor} \
          --output-filename="$SCREENSHOT_DIR/screenshot_%Y-%m-%d_%H-%M-%S.png" \
          --actions-on-enter="save-to-clipboard,exit" \
          --actions-on-escape="save-to-clipboard,exit" \
          --brush-smooth-history-size=${toString config.screenshot.brushSmoothHistorySize} \
          --disable-notifications
    '';
  };

  # Color picker
  color-picker = pkgs.writeShellApplication {
    name = "color-picker";
    runtimeInputs = [
      pkgs.hyprpicker
      pkgs.libnotify
    ];
    text = ''
      color=$(hyprpicker -a) || true
      if [ -n "''${color:-}" ]; then
        notify-send "Color Picked" "$color copied to clipboard" -i color-picker
      fi
    '';
  };
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
