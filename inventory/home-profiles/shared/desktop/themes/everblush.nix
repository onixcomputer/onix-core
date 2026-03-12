# Everblush theme - dark, vibrant, and beautiful
{ pkgs }:
let
  mkTheme = import ./mk-theme.nix { inherit pkgs; };
in
mkTheme {
  name = "Everblush";
  author = "Everblush";
  variant = "dark";

  # Surface colors (8 levels from darkest to lightest)
  base00 = "#141b1e"; # Default background
  base01 = "#232a2d"; # Lighter bg (elevated surfaces)
  base02 = "#2d3437"; # Selection/highlight bg
  base03 = "#3b4244"; # Comments/borders/inactive
  base04 = "#575e61"; # Dark foreground (status bars)
  base05 = "#b3b9b8"; # Default foreground (secondary text)
  base06 = "#dadada"; # Light foreground (primary text)
  base07 = "#ffffff"; # Lightest (rarely used)

  # Semantic colors (8 accent colors)
  red = "#e57474";
  orange = "#fcb163";
  yellow = "#e5c76b";
  green = "#8ccf7e";
  cyan = "#6cbfbf";
  blue = "#67b0e8";
  purple = "#c47fd5";
  magenta = "#c47fd5";

  # Terminal colors (bright versions are slightly brightened)
  term_black = "#232a2d";
  term_white = "#b3b9b8";
  term_bright_black = "#3b4244";
  term_bright_red = "#ef7d7d";
  term_bright_green = "#96d988";
  term_bright_yellow = "#f4d67a";
  term_bright_blue = "#71baf2";
  term_bright_magenta = "#ce89df";
  term_bright_cyan = "#67cbe7";
  term_bright_white = "#dadada";

  # Special UI colors
  bg_dark = "#0d1316"; # Even darker variant
  accent2 = "#8ccf7e"; # Green for secondary (matching Hyprland gradient)

  # Hyprland-specific styling
  hypr = {
    active_border = "rgba(67b0e8ff) rgba(8ccf7eff) 45deg";
    inactive_border = "rgba(3b4244aa)";
    border_size = 4;
    gaps_in = 4;
    gaps_out = 4;
    rounding = 12; # Rounded corners for softer look
  };

  # GTK theme integration - using Adwaita light for testing theme swap
  gtk = {
    theme = {
      name = "Adwaita";
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Papirus-Light";
      package = pkgs.papirus-icon-theme;
    };
    preferDarkTheme = false;
  };

  # Matching wallpapers
  wallpapers = {
    main = "everblush_mountain.png";
    collection = {
      "everblush_mountain.png" = {
        url = "https://raw.githubusercontent.com/adeci/wallpapers/main/everblush/everblush_mountain.png";
        sha256 = "sha256-zaQu4syTlxwLnTwfkhz2yXSyYSkUJnozpVqJYbJHZdU=";
      };
      "everblush_circles.png" = {
        url = "https://raw.githubusercontent.com/adeci/wallpapers/main/everblush/everblush_circles.png";
        sha256 = "sha256-8VrcK4WWsc6hZQBga/FbjQlmLujskneoe3oIs8BZYZk=";
      };
      "everblush_anger.png" = {
        url = "https://raw.githubusercontent.com/adeci/wallpapers/main/everblush/everblush_anger.png";
        sha256 = "sha256-39LolpURE+b4PEbuyZM/upmwU+RwtoogvDrSpHyMhL0=";
      };
      "everblush_pacman.png" = {
        url = "https://raw.githubusercontent.com/adeci/wallpapers/main/everblush/everblush_pacman.png";
        sha256 = "sha256-kaYs0m3qYQU9G3HEBJV5gmGpYL9SnD6eqwNV0nlqHIM=";
      };
      "swampcat.mp4" = {
        url = "https://raw.githubusercontent.com/adeci/wallpapers/main/everblush/swampcat.mp4";
        sha256 = "sha256-+uCCPUYVRFkpt13eMjwITftcaPZLtGpC2g+dWor5Prk=";
      };
    };
  };
}
