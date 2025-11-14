# Onix Dark theme - professional dark theme with orange accents
{ pkgs }:
{
  name = "Onix Dark";
  author = "Onix Computer";
  variant = "dark";

  # Surface colors (8 levels from darkest to lightest)
  base00 = "#0d0d0d"; # Default background (darker than #1a1a1a)
  base01 = "#1a1a1a"; # Lighter bg (elevated surfaces)
  base02 = "#262626"; # Selection/highlight bg
  base03 = "#404040"; # Comments/borders/inactive
  base04 = "#595959"; # Dark foreground (status bars)
  base05 = "#b3b3b3"; # Default foreground (secondary text)
  base06 = "#e6e6e6"; # Light foreground (primary text)
  base07 = "#ffffff"; # Lightest (rarely used)

  # Semantic colors (8 accent colors)
  red = "#ff4444"; # Errors, urgent, failed
  orange = "#ff6600"; # Primary accent (Onix orange)
  yellow = "#ffaa00"; # Warnings, caution
  green = "#44ff44"; # Success, connected, charged
  cyan = "#00ffff"; # Info, highlights
  blue = "#4488ff"; # Links, focused
  purple = "#aa44ff"; # Secondary accent
  magenta = "#ff44ff"; # Tertiary accent, special

  # Terminal colors (16-color palette)
  # Normal colors
  term_black = "#1a1a1a";
  term_red = "#ff4444";
  term_green = "#44ff44";
  term_yellow = "#ffaa00";
  term_blue = "#4488ff";
  term_magenta = "#ff44ff";
  term_cyan = "#00ffff";
  term_white = "#b3b3b3";

  # Bright colors
  term_bright_black = "#404040";
  term_bright_red = "#ff6666";
  term_bright_green = "#66ff66";
  term_bright_yellow = "#ffcc00";
  term_bright_blue = "#66aaff";
  term_bright_magenta = "#cc66ff";
  term_bright_cyan = "#66ffff";
  term_bright_white = "#e6e6e6";

  # Special UI colors (derived from base colors)
  bg = "#1a1a1a"; # Alias for base01
  bg_dark = "#0d0d0d"; # Alias for base00
  bg_highlight = "#262626"; # Alias for base02
  fg = "#e6e6e6"; # Alias for base06
  fg_dim = "#b3b3b3"; # Alias for base05
  border = "#404040"; # Alias for base03
  accent = "#ff6600"; # Onix orange (primary accent)
  accent2 = "#ffaa00"; # Yellow for secondary

  # RGB values for colors that need transparency
  accent_rgb = "255, 102, 0"; # RGB of accent (#ff6600)
  accent2_rgb = "255, 170, 0"; # RGB of accent2 (#ffaa00)
  bg_dark_rgb = "13, 13, 13"; # RGB of bg_dark (#0d0d0d)

  # Opacity values
  opacity = {
    terminal = "0.95";
    popups = "0.95";
    notifications = "0.95";
  };

  # Hyprland-specific styling
  hypr = {
    active_border = "rgba(ff6600ff) rgba(ffaa00ff) 45deg"; # Orange gradient
    inactive_border = "rgba(404040aa)";
    border_size = 2;
    gaps_in = 8;
    gaps_out = 8;
    rounding = 0; # Sharp corners for professional look
  };

  # Waybar-specific styling
  waybar = {
    workspace_hover_opacity = "0.15";
    workspace_hover_border_opacity = "0.25";
    workspace_active_shadow_opacity = "0.3";
    workspace_active_hover_shadow_opacity = "0.4";
    module_bg_opacity = "0.8";
    module_radius = "0";
  };

  # GTK theme integration
  gtk = {
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    preferDarkTheme = true;
  };

  # Matching wallpapers - for onix themes, wallpapers are symlinked manually
  # The main wallpaper should exist in ~/Pictures/Wallpapers/
  wallpapers = {
    # Main wallpaper that gets auto-set
    main = "1-matte-black.jpg";

    # No collection - we'll use manually symlinked wallpapers from ~/git/wallpapers
    collection = { };
  };
}
