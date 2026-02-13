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

      # Strip leading # from hex color
      noHash = hex: builtins.substring 1 6 hex;

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
