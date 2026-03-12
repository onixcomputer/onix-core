# Theme builder function - reduces duplication across theme files
{ pkgs }:
let
  # Hex to decimal conversion utilities
  hexDigits = {
    "0" = 0;
    "1" = 1;
    "2" = 2;
    "3" = 3;
    "4" = 4;
    "5" = 5;
    "6" = 6;
    "7" = 7;
    "8" = 8;
    "9" = 9;
    "a" = 10;
    "b" = 11;
    "c" = 12;
    "d" = 13;
    "e" = 14;
    "f" = 15;
  };

  hexByteToDec =
    hex:
    hexDigits.${builtins.substring 0 1 (pkgs.lib.toLower hex)} * 16
    + hexDigits.${builtins.substring 1 1 (pkgs.lib.toLower hex)};

  # Convert "#rrggbb" to "R, G, B" string
  hexToRgb =
    hex:
    let
      r = toString (hexByteToDec (builtins.substring 1 2 hex));
      g = toString (hexByteToDec (builtins.substring 3 2 hex));
      b = toString (hexByteToDec (builtins.substring 5 2 hex));
    in
    "${r}, ${g}, ${b}";

  # Default waybar configuration (identical across most themes)
  defaultWaybar = {
    workspace_hover_opacity = "0.15";
    workspace_hover_border_opacity = "0.25";
    workspace_active_shadow_opacity = "0.3";
    workspace_active_hover_shadow_opacity = "0.4";
    module_bg_opacity = "0.8";
    module_radius = "0.5em";
  };

  # Default opacity values
  defaultOpacity = {
    terminal = "0.92";
    popups = "0.90";
    notifications = "0.90";
  };

in
# The actual theme builder function
themeSpec:
let
  # Extract required fields
  inherit (themeSpec) name author variant;
  inherit (themeSpec)
    base00
    base01
    base02
    base03
    base04
    base05
    base06
    base07
    ;
  inherit (themeSpec)
    red
    orange
    yellow
    green
    cyan
    blue
    purple
    magenta
    ;

  # Build the theme attrset with all the common structure
  theme = rec {
    # Basic metadata
    inherit name author variant;

    # Surface colors (passed through)
    inherit
      base00
      base01
      base02
      base03
      base04
      base05
      base06
      base07
      ;

    # Semantic colors (passed through)
    inherit
      red
      orange
      yellow
      green
      cyan
      blue
      purple
      magenta
      ;

    # Terminal colors (use provided or fallback to semantic)
    term_black = themeSpec.term_black or base01;
    term_red = themeSpec.term_red or red;
    term_green = themeSpec.term_green or green;
    term_yellow = themeSpec.term_yellow or yellow;
    term_blue = themeSpec.term_blue or blue;
    term_magenta = themeSpec.term_magenta or magenta;
    term_cyan = themeSpec.term_cyan or cyan;
    term_white = themeSpec.term_white or base05;

    term_bright_black = themeSpec.term_bright_black or base03;
    term_bright_red = themeSpec.term_bright_red or red;
    term_bright_green = themeSpec.term_bright_green or green;
    term_bright_yellow = themeSpec.term_bright_yellow or orange;
    term_bright_blue = themeSpec.term_bright_blue or blue;
    term_bright_magenta = themeSpec.term_bright_magenta or purple;
    term_bright_cyan = themeSpec.term_bright_cyan or cyan;
    term_bright_white = themeSpec.term_bright_white or base06;

    # Special UI colors (use provided or sensible defaults)
    bg = themeSpec.bg or base00;
    bg_dark = themeSpec.bg_dark or base00;
    bg_highlight = themeSpec.bg_highlight or base02;
    fg = themeSpec.fg or base06;
    fg_dim = themeSpec.fg_dim or base05;
    border = themeSpec.border or base03;
    accent = themeSpec.accent or blue;
    accent2 = themeSpec.accent2 or purple;

    # Automatically compute RGB values from hex colors
    accent_rgb = hexToRgb accent;
    accent2_rgb = hexToRgb accent2;
    bg_dark_rgb = hexToRgb bg_dark;

    # Opacity values (use provided or defaults)
    opacity = defaultOpacity // (themeSpec.opacity or { });

    # Waybar styling (merge with defaults)
    waybar = defaultWaybar // (themeSpec.waybar or { });

    # Direct passthroughs from themeSpec
    inherit (themeSpec) hypr gtk wallpapers;
  };
in
theme
