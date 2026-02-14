{ lib, ... }:
let
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
    hexDigits.${builtins.substring 0 1 (lib.toLower hex)} * 16
    + hexDigits.${builtins.substring 1 1 (lib.toLower hex)};
in
{
  options.colors = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      red = "#ff4444";
      orange = "#ff6600";
      yellow = "#ffaa00";
      green = "#44ff44";
      cyan = "#00ffff";
      blue = "#4488ff";
      purple = "#aa44ff";
      magenta = "#ff44ff";

      bg = "#1a1a1a";
      bg_dark = "#0d0d0d";
      bg_highlight = "#262626";
      fg = "#e6e6e6";
      fg_dim = "#b3b3b3";
      border = "#404040";
      comment = "#595959";

      accent = "#ff6600";
      accent2 = "#ffaa00";

      # Terminal palette (16-color) - Tokyo Night
      term_black = "#32344a";
      term_red = "#f7768e";
      term_green = "#9ece6a";
      term_yellow = "#e0af68";
      term_blue = "#7aa2f7";
      term_magenta = "#ad8ee6";
      term_cyan = "#449dab";
      term_white = "#787c99";

      term_bright_black = "#444b6a";
      term_bright_red = "#ff7a93";
      term_bright_green = "#b9f27c";
      term_bright_yellow = "#ff9e64";
      term_bright_blue = "#7da6ff";
      term_bright_magenta = "#bb9af7";
      term_bright_cyan = "#0db9d7";
      term_bright_white = "#acb0d0";

      # Terminal-specific overrides (may differ from UI bg/fg)
      term_bg = "#1a1b26";
      term_fg = "#a9b1d6";
      term_selection = "#7aa2f7";

      # Screencasting indicator colors
      screencast_active = "#f38ba8";
      screencast_inactive = "#7d0d2d";

      # RGB variants for transparency (R, G, B as string)
      accent_rgb = "255, 102, 0";
      accent2_rgb = "255, 170, 0";
      bg_dark_rgb = "13, 13, 13";

      # Strip leading # from hex color
      noHash = hex: builtins.substring 1 6 hex;

      # Convert "#rrggbb" to "R, G, B" string
      hexToRgb =
        hex:
        let
          r = toString (hexByteToDec (builtins.substring 1 2 hex));
          g = toString (hexByteToDec (builtins.substring 3 2 hex));
          b = toString (hexByteToDec (builtins.substring 5 2 hex));
        in
        "${r}, ${g}, ${b}";

      # Convert "#rrggbb" to "38;2;R;G;B" for ANSI 256-color sequences
      hexToAnsi =
        hex:
        let
          r = toString (hexByteToDec (builtins.substring 1 2 hex));
          g = toString (hexByteToDec (builtins.substring 3 2 hex));
          b = toString (hexByteToDec (builtins.substring 5 2 hex));
        in
        "38;2;${r};${g};${b}";
    };
    description = "User color palette for CLI tools and non-graphical configs";
  };
}
