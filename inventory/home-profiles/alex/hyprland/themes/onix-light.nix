# Onix Light theme - professional light theme with orange accents
{ pkgs }:
{
  name = "Onix Light";
  author = "Onix Computer";
  variant = "light";

  # Surface colors (8 levels from darkest to lightest)
  base00 = "#ffffff"; # Default background (pure white)
  base01 = "#f5f5f5"; # Slightly darker bg (elevated surfaces)
  base02 = "#e0e0e0"; # Selection/highlight bg
  base03 = "#cccccc"; # Comments/borders/inactive
  base04 = "#999999"; # Light foreground (status bars)
  base05 = "#666666"; # Default foreground (secondary text)
  base06 = "#333333"; # Dark foreground (primary text)
  base07 = "#000000"; # Darkest (rarely used)

  # Semantic colors (8 accent colors) - adjusted for light background
  red = "#cc0000"; # Errors, urgent, failed
  orange = "#ff6600"; # Primary accent (Onix orange)
  yellow = "#cc8800"; # Warnings, caution
  green = "#00aa00"; # Success, connected, charged
  cyan = "#0088aa"; # Info, highlights
  blue = "#0066cc"; # Links, focused
  purple = "#8800cc"; # Secondary accent
  magenta = "#cc00aa"; # Tertiary accent, special

  # Terminal colors (16-color palette)
  # Normal colors
  term_black = "#333333";
  term_red = "#cc0000";
  term_green = "#00aa00";
  term_yellow = "#cc8800";
  term_blue = "#0066cc";
  term_magenta = "#cc00aa";
  term_cyan = "#0088aa";
  term_white = "#e0e0e0";

  # Bright colors
  term_bright_black = "#666666";
  term_bright_red = "#ff0000";
  term_bright_green = "#00ff00";
  term_bright_yellow = "#ffaa00";
  term_bright_blue = "#0088ff";
  term_bright_magenta = "#ff00dd";
  term_bright_cyan = "#00ddff";
  term_bright_white = "#ffffff";

  # Special UI colors (derived from base colors)
  bg = "#ffffff"; # Alias for base00
  bg_dark = "#f5f5f5"; # Alias for base01
  bg_highlight = "#e0e0e0"; # Alias for base02
  fg = "#333333"; # Alias for base06
  fg_dim = "#666666"; # Alias for base05
  border = "#cccccc"; # Alias for base03
  accent = "#ff6600"; # Onix orange (primary accent)
  accent2 = "#cc8800"; # Yellow for secondary

  # RGB values for colors that need transparency
  accent_rgb = "255, 102, 0"; # RGB of accent (#ff6600)
  accent2_rgb = "204, 136, 0"; # RGB of accent2 (#cc8800)
  bg_dark_rgb = "245, 245, 245"; # RGB of bg_dark (#f5f5f5)

  # Opacity values
  opacity = {
    terminal = "0.95";
    popups = "0.95";
    notifications = "0.95";
  };

  # Hyprland-specific styling
  hypr = {
    active_border = "rgba(ff6600ff) rgba(cc8800ff) 45deg"; # Orange gradient
    inactive_border = "rgba(ccccccaa)";
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
      name = "Adwaita";
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Papirus-Light";
      package = pkgs.papirus-icon-theme;
    };
    preferDarkTheme = false;
  };

  # Matching wallpapers - for onix themes, wallpapers are symlinked manually
  # The main wallpaper should exist in ~/Pictures/Wallpapers/
  wallpapers = {
    # Main wallpaper that gets auto-set
    main = "1-kanagawa.jpg";

    # No collection - we'll use manually symlinked wallpapers from ~/git/wallpapers
    collection = { };
  };
}
