# Tokyo Night theme by enkia
{ pkgs }:
rec {
  name = "Tokyo Night";
  author = "enkia";
  variant = "dark";

  # Surface colors (8 levels from darkest to lightest)
  base00 = "#1a1b26"; # Default background
  base01 = "#24283b"; # Lighter bg (elevated surfaces)
  base02 = "#414868"; # Selection/highlight bg
  base03 = "#565f89"; # Comments/borders/inactive
  base04 = "#787c99"; # Dark foreground (status bars)
  base05 = "#a9b1d6"; # Default foreground (secondary text)
  base06 = "#c0caf5"; # Light foreground (primary text)
  base07 = "#ffffff"; # Lightest (rarely used)

  # Semantic colors (8 accent colors)
  red = "#f7768e"; # Errors, urgent, failed
  orange = "#ff9e64"; # Warnings (bright)
  yellow = "#e0af68"; # Warnings, caution
  green = "#9ece6a"; # Success, connected, charged
  cyan = "#7dcfff"; # Info, highlights
  blue = "#7aa2f7"; # Primary accent, links, focused
  purple = "#bb9af7"; # Secondary accent
  magenta = "#ad8ee6"; # Tertiary accent, special

  # Terminal colors (16-color palette)
  # Normal colors
  term_black = "#32344a";
  term_red = "#f7768e";
  term_green = "#9ece6a";
  term_yellow = "#e0af68";
  term_blue = "#7aa2f7";
  term_magenta = "#ad8ee6";
  term_cyan = "#449dab";
  term_white = "#787c99";

  # Bright colors
  term_bright_black = "#444b6a";
  term_bright_red = "#ff7a93";
  term_bright_green = "#b9f27c";
  term_bright_yellow = "#ff9e64";
  term_bright_blue = "#7da6ff";
  term_bright_magenta = "#bb9af7";
  term_bright_cyan = "#0db9d7";
  term_bright_white = "#acb0d0";

  # Special UI colors (derived from base colors)
  bg = "#1a1b26"; # Alias for base00
  bg_dark = "#16161e"; # Even darker variant
  bg_highlight = "#414868"; # Alias for base02
  fg = "#c0caf5"; # Alias for base06
  fg_dim = "#a9b1d6"; # Alias for base05
  border = "#565f89"; # Alias for base03
  accent = "#7aa2f7"; # Alias for blue (primary accent)
  accent2 = "#bb9af7"; # Alias for purple (secondary accent)

  # RGB values for colors that need transparency (derived from hex above)
  accent_rgb = "122, 162, 247"; # RGB of accent (#7aa2f7)
  accent2_rgb = "187, 154, 247"; # RGB of accent2 (#bb9af7)
  bg_dark_rgb = "22, 22, 30"; # RGB of bg_dark (#16161e)

  # Opacity values (can be overridden per-theme)
  opacity = {
    terminal = "0.92";
    popups = "0.90";
    notifications = "0.90";
  };

  # Hyprland-specific styling
  hypr = {
    active_border = "rgba(7aa2f7ff) rgba(bb9af7ff) 45deg"; # Gradient using accent (#7aa2f7) to accent2 (#bb9af7)
    inactive_border = "rgba(565f89aa)"; # Using border color (#565f89) with transparency
    border_size = 3; # Slightly thicker borders for Tokyo Night
    gaps_in = 3;
    gaps_out = 3;
    rounding = 0; # Sharp corners for Tokyo Night
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
      name = "Tokyonight-Dark";
      package = pkgs.tokyo-night-gtk;
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
    main = "tokyo-night_nix.png";

    # All wallpapers for this theme (including main)
    collection = {
      "tokyo-night_nix.png" = {
        url = "https://raw.githubusercontent.com/adeci/wallpapers/main/tokyo-night/tokyo-night_nix.png";
        sha256 = "sha256-W5GaKCOiV2S3NuORGrRaoOE2x9X6gUS+wYf7cQkw9CY=";
      };
      "tokyo-night_street.jpg" = {
        url = "https://raw.githubusercontent.com/adeci/wallpapers/main/tokyo-night/tokyo-night_street.jpg";
        sha256 = "sha256-XlSm8RzGwowJMT/DQBNwfsU4V6QuvP4kvwVm1pzw6SM=";
      };
      "tokyo-night_forest.jxl" = {
        url = "https://raw.githubusercontent.com/adeci/wallpapers/main/tokyo-night/tokyo-night_forest.jxl";
        sha256 = "sha256-jbY5p0vKLdearaZh1kuQytVsPia6h2AsEbOAqGpxEWw=";
      };
    };
  };
}
