# Onix Dark theme - professional dark theme with orange accents
{ pkgs }:
let
  mkTheme = import ./mk-theme.nix { inherit pkgs; };
in
mkTheme {
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
  red = "#ff4444";
  orange = "#ff6600"; # Primary accent (Onix orange)
  yellow = "#ffaa00";
  green = "#44ff44";
  cyan = "#00ffff";
  blue = "#4488ff";
  purple = "#aa44ff";
  magenta = "#ff44ff";

  # Terminal colors (16-color palette)
  term_black = "#1a1a1a";
  term_white = "#b3b3b3";
  term_bright_black = "#404040";
  term_bright_red = "#ff6666";
  term_bright_green = "#66ff66";
  term_bright_yellow = "#ffcc00";
  term_bright_blue = "#66aaff";
  term_bright_magenta = "#cc66ff";
  term_bright_cyan = "#66ffff";
  term_bright_white = "#e6e6e6";

  # Special UI colors
  bg = "#1a1a1a"; # Use base01 instead of base00
  accent = "#ff6600"; # Onix orange
  accent2 = "#ffaa00"; # Yellow for secondary

  # Override opacity for more professional look
  opacity = {
    terminal = "0.95";
    popups = "0.95";
    notifications = "0.95";
  };

  # Hyprland-specific styling
  hypr = {
    active_border = "rgba(ff6600ff) rgba(ffaa00ff) 45deg";
    inactive_border = "rgba(404040aa)";
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
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    preferDarkTheme = true;
  };

  # Matching wallpapers - manually symlinked
  wallpapers = {
    main = "1-matte-black.jpg";
    collection = { };
  };
}
