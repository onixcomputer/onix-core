{ lib, ... }:
let
  # Hex conversion utilities
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

  # Import all sub-palette files
  core = import ./colors/core.nix;
  terminal = import ./colors/terminal.nix;
  editor = import ./colors/editor.nix;
  bar = import ./colors/bar.nix;
  btop = import ./colors/btop.nix;
  zen = import ./colors/zen.nix;
  rainbow = import ./colors/rainbow.nix;
  misc = import ./colors/misc.nix;
in
{
  options.colors = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default =
      core
      // terminal
      // editor
      // bar
      // btop
      // zen
      // rainbow
      // misc
      // {
        # RGB variants for transparency (R, G, B as string)
        accent_rgb = "255, 102, 0";
        accent2_rgb = "255, 170, 0";
        bg_dark_rgb = "13, 13, 13";

        # Utility functions
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
