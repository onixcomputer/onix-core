# Solarized Dark theme by Ethan Schoonover
{ pkgs }:
let
  mkTheme = import ./mk-theme.nix { inherit pkgs; };
in
mkTheme {
  name = "Solarized Dark";
  author = "Ethan Schoonover";
  variant = "dark";

  # Official Solarized Dark colors
  # Background tones (dark to light)
  base00 = "#002b36"; # base03 - darkest background
  base01 = "#073642"; # base02 - elevated background
  base02 = "#586e75"; # base01 - comments, secondary content
  base03 = "#657b83"; # base00 - body text, primary content
  base04 = "#839496"; # base0 - default foreground
  base05 = "#93a1a1"; # base1 - emphasized content
  base06 = "#eee8d5"; # base2 - light background highlights
  base07 = "#fdf6e3"; # base3 - light background

  # Semantic colors (8 accent colors) - Solarized accent colors
  red = "#dc322f";
  orange = "#cb4b16";
  yellow = "#b58900";
  green = "#859900";
  cyan = "#2aa198";
  blue = "#268bd2";
  purple = "#6c71c4"; # Violet
  magenta = "#d33682";

  # Terminal colors (official Solarized palette)
  term_black = "#073642"; # base02
  term_white = "#839496"; # base0
  term_bright_black = "#586e75"; # base01
  term_bright_red = "#cb4b16"; # orange (bright red = orange in Solarized)
  term_bright_yellow = "#b58900"; # same as normal
  term_bright_blue = "#268bd2"; # same as normal
  term_bright_magenta = "#6c71c4"; # violet
  term_bright_cyan = "#2aa198"; # same as normal
  term_bright_white = "#fdf6e3"; # base3

  # Special UI colors (Solarized-specific mappings)
  bg_highlight = "#073642"; # base02 instead of base02
  fg = "#839496"; # base0 - default foreground
  fg_dim = "#657b83"; # base00 - secondary text
  border = "#586e75"; # base01 - borders
  accent2 = "#2aa198"; # cyan - secondary accent

  # Hyprland-specific styling
  hypr = {
    active_border = "rgba(dc322fff)"; # Red border (Solarized red)
    inactive_border = "rgba(586e75aa)";
    border_size = 3;
    gaps_in = 3;
    gaps_out = 3;
    rounding = 0; # Sharp corners
  };

  # GTK theme integration
  gtk = {
    theme = {
      name = "NumixSolarizedDarkBlue";
      package = pkgs.numix-solarized-gtk-theme;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    preferDarkTheme = true;
  };

  # Matching wallpapers
  wallpapers = {
    main = "solarized-dark_jellyfish.jpg";
    collection = {
      "solarized-dark_jellyfish.jpg" = {
        url = "https://raw.githubusercontent.com/adeci/wallpapers/main/solarized-dark/solarized-dark_jellyfish.jpg";
        sha256 = "sha256-vNBIkJj4QLXYgHkWi3FoXhIh65kT7FmCUokhjcBl6WQ=";
      };
      "solarized-dark_city.png" = {
        url = "https://raw.githubusercontent.com/adeci/wallpapers/main/solarized-dark/solarized-dark_city.png";
        sha256 = "sha256-rMDiMc4eyut0dl8ihs7RWn8eMgPbboJ+x4nXDCJl7J0=";
      };
      "solarized-dark_street.jpeg" = {
        url = "https://raw.githubusercontent.com/adeci/wallpapers/main/solarized-dark/solarized-dark_street.jpeg";
        sha256 = "sha256-8VAZs9AUtuHYL6spS+ZinXTNiQuF9puwBmAD3Ze+z40=";
      };
    };
  };
}
