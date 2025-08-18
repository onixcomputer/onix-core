# Everblush theme - dark, vibrant, and beautiful
{ pkgs }:
{
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
  red = "#e57474"; # Errors, urgent, failed
  orange = "#fcb163"; # Warnings (bright) - interpolated
  yellow = "#e5c76b"; # Warnings, caution
  green = "#8ccf7e"; # Success, connected, charged
  cyan = "#6cbfbf"; # Info, highlights
  blue = "#67b0e8"; # Primary accent, links, focused
  purple = "#c47fd5"; # Secondary accent (magenta in original)
  magenta = "#c47fd5"; # Tertiary accent, special

  # Terminal colors (16-color palette)
  # Normal colors (matching semantic colors)
  term_black = "#232a2d";
  term_red = "#e57474";
  term_green = "#8ccf7e";
  term_yellow = "#e5c76b";
  term_blue = "#67b0e8";
  term_magenta = "#c47fd5";
  term_cyan = "#6cbfbf";
  term_white = "#b3b9b8";

  # Bright colors (slightly brightened versions)
  term_bright_black = "#3b4244";
  term_bright_red = "#ef7d7d";
  term_bright_green = "#96d988";
  term_bright_yellow = "#f4d67a";
  term_bright_blue = "#71baf2";
  term_bright_magenta = "#ce89df";
  term_bright_cyan = "#67cbe7";
  term_bright_white = "#dadada";

  # Special UI colors (derived from base colors)
  bg = "#141b1e"; # Alias for base00
  bg_dark = "#0d1316"; # Even darker variant
  bg_highlight = "#2d3437"; # Alias for base02
  fg = "#dadada"; # Alias for base06
  fg_dim = "#b3b9b8"; # Alias for base05
  border = "#3b4244"; # Alias for base03
  accent = "#67b0e8"; # Alias for blue (primary accent)
  accent2 = "#8ccf7e"; # Green for secondary (matching Hyprland border gradient)

  # RGB values for colors that need transparency (derived from hex above)
  accent_rgb = "103, 176, 232"; # RGB of accent (#67b0e8)
  accent2_rgb = "140, 207, 126"; # RGB of accent2 (#8ccf7e)
  bg_dark_rgb = "13, 19, 22"; # RGB of bg_dark (#0d1316)

  # Opacity values (can be overridden per-theme)
  opacity = {
    terminal = "0.92";
    popups = "0.90";
    notifications = "0.90";
  };

  # Hyprland-specific styling
  hypr = {
    active_border = "rgba(67b0e8ff) rgba(8ccf7eff) 45deg"; # Gradient using accent (#67b0e8) to accent2 (#8ccf7e)
    inactive_border = "rgba(3b4244aa)"; # Using border color (#3b4244) with transparency
    border_size = 4; # Slightly thicker borders for Everblush
    gaps_in = 4; # Slightly larger gaps
    gaps_out = 4;
    rounding = 12; # More rounded corners for softer look
  };

  # Waybar-specific styling (colors derived from base theme)
  waybar = {
    # Just define the opacity values and styling here
    workspace_hover_opacity = "0.15";
    workspace_hover_border_opacity = "0.25";
    workspace_active_shadow_opacity = "0.3";
    workspace_active_hover_shadow_opacity = "0.4";

    # Module styling
    module_bg_opacity = "0.8";
    module_radius = "0.5em";
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
    # Main wallpaper that gets auto-set
    main = "everblush_mountain.png";

    # All wallpapers for this theme (including main)
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
