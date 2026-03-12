# Solarized Dark theme by Ethan Schoonover
{ pkgs }:
{
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
  red = "#dc322f"; # Red
  orange = "#cb4b16"; # Orange
  yellow = "#b58900"; # Yellow
  green = "#859900"; # Green
  cyan = "#2aa198"; # Cyan
  blue = "#268bd2"; # Blue
  purple = "#6c71c4"; # Violet
  magenta = "#d33682"; # Magenta

  # Terminal colors (official Solarized palette)
  # Normal colors (ANSI 0-7)
  term_black = "#073642"; # base02
  term_red = "#dc322f"; # red
  term_green = "#859900"; # green
  term_yellow = "#b58900"; # yellow
  term_blue = "#268bd2"; # blue
  term_magenta = "#d33682"; # magenta
  term_cyan = "#2aa198"; # cyan
  term_white = "#839496"; # base0

  # Bright colors (Solarized approach)
  term_bright_black = "#586e75"; # base01
  term_bright_red = "#cb4b16"; # orange (bright red = orange in Solarized)
  term_bright_green = "#859900"; # green (same as normal)
  term_bright_yellow = "#b58900"; # yellow (same as normal)
  term_bright_blue = "#268bd2"; # blue (same as normal)
  term_bright_magenta = "#6c71c4"; # violet
  term_bright_cyan = "#2aa198"; # cyan (same as normal)
  term_bright_white = "#fdf6e3"; # base3

  # Special UI colors (derived from base colors)
  bg = "#002b36"; # base03 - background
  bg_dark = "#002b36"; # base03 - darkest available
  bg_highlight = "#073642"; # base02 - highlighted background
  fg = "#839496"; # base0 - default foreground
  fg_dim = "#657b83"; # base00 - secondary text
  border = "#586e75"; # base01 - borders
  accent = "#268bd2"; # blue - primary accent
  accent2 = "#2aa198"; # cyan - secondary accent

  # RGB values for colors that need transparency (derived from hex above)
  accent_rgb = "38, 139, 210"; # RGB of accent (#268bd2)
  accent2_rgb = "42, 161, 152"; # RGB of accent2 (#2aa198)
  bg_dark_rgb = "0, 43, 54"; # RGB of bg_dark (#002b36)

  # Opacity values (can be overridden per-theme)
  opacity = {
    terminal = "0.92";
    popups = "0.90";
    notifications = "0.90";
  };

  # Hyprland-specific styling
  hypr = {
    active_border = "rgba(dc322fff)"; # Red border (Solarized red)
    inactive_border = "rgba(586e75aa)"; # Using border color with transparency
    border_size = 3; # Slightly thicker borders
    gaps_in = 3;
    gaps_out = 3;
    rounding = 0; # Sharp corners like Tokyo Night
  };

  # Waybar-specific styling (colors derived from base theme)
  waybar = {
    # Just define opacity values - colors come from theme
    workspace_hover_opacity = "0.15";
    workspace_hover_border_opacity = "0.25";
    workspace_active_shadow_opacity = "0.3";
    workspace_active_hover_shadow_opacity = "0.4";

    # Module styling
    module_bg_opacity = "0.8";
    module_radius = "0.5em";
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
    # Main wallpaper that gets auto-set
    main = "solarized-dark_jellyfish.jpg";

    # All wallpapers for this theme (including main)
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
