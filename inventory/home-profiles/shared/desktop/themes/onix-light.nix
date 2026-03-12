# Onix Light theme - professional light theme with orange accents
{ pkgs }:
let
  mkTheme = import ./mk-theme.nix { inherit pkgs; };
in
mkTheme {
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
  red = "#cc0000";
  orange = "#ff6600"; # Primary accent (Onix orange)
  yellow = "#cc8800";
  green = "#00aa00";
  cyan = "#0088aa";
  blue = "#0066cc";
  purple = "#8800cc";
  magenta = "#cc00aa";

  # Terminal colors (16-color palette)
  term_black = "#333333";
  term_white = "#e0e0e0";
  term_bright_black = "#666666";
  term_bright_red = "#ff0000";
  term_bright_green = "#00ff00";
  term_bright_yellow = "#ffaa00";
  term_bright_blue = "#0088ff";
  term_bright_magenta = "#ff00dd";
  term_bright_cyan = "#00ddff";
  term_bright_white = "#ffffff";

  # Special UI colors
  bg_dark = "#f5f5f5"; # Alias for base01
  accent = "#ff6600"; # Onix orange
  accent2 = "#cc8800"; # Yellow for secondary

  # Override opacity for more professional look
  opacity = {
    terminal = "0.95";
    popups = "0.95";
    notifications = "0.95";
  };

  # Hyprland-specific styling
  hypr = {
    active_border = "rgba(ff6600ff) rgba(cc8800ff) 45deg";
    inactive_border = "rgba(ccccccaa)";
    border_size = 2;
    gaps_in = 8;
    gaps_out = 8;
    rounding = 0; # Sharp corners for professional look
  };

  # Override waybar for sharp corners to match hyprland
  waybar = {
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

  # Matching wallpapers - manually symlinked
  wallpapers = {
    main = "1-kanagawa.jpg";
    collection = { };
  };
}
