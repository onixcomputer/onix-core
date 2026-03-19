# Onix Dark theme — professional dark theme with orange accents
let mk_theme = import "./mk-theme.ncl" in

mk_theme {
  name = "Onix Dark",
  author = "Onix Computer",
  variant = "dark",

  # Surface colors
  base00 = "#0d0d0d",
  base01 = "#1a1a1a",
  base02 = "#262626",
  base03 = "#404040",
  base04 = "#595959",
  base05 = "#b3b3b3",
  base06 = "#e6e6e6",
  base07 = "#ffffff",

  # Semantic colors
  red = "#ff4444",
  orange = "#ff6600",
  yellow = "#ffaa00",
  green = "#44ff44",
  cyan = "#00ffff",
  blue = "#4488ff",
  purple = "#aa44ff",
  magenta = "#ff44ff",

  # Terminal colors
  term_black = "#1a1a1a",
  term_white = "#b3b3b3",
  term_bright_black = "#404040",
  term_bright_red = "#ff6666",
  term_bright_green = "#66ff66",
  term_bright_yellow = "#ffcc00",
  term_bright_blue = "#66aaff",
  term_bright_magenta = "#cc66ff",
  term_bright_cyan = "#66ffff",
  term_bright_white = "#e6e6e6",

  # Special
  bg = "#1a1a1a",
  accent = "#ff6600",
  accent2 = "#ffaa00",
  comment = "#595959",
  term_bg = "#1a1a1a",
  term_fg = "#e6e6e6",
  term_selection = "#ff6600",

  # Opacity overrides
  opacity = {
    terminal = "0.95",
    popups = "0.95",
    notifications = "0.95",
  },

  # Hyprland
  hypr = {
    active_border = "rgba(ff6600ff) rgba(ffaa00ff) 45deg",
    inactive_border = "rgba(404040aa)",
    border_size = 2,
    gaps_in = 8,
    gaps_out = 8,
    rounding = 0,
  },

  # Waybar overrides
  waybar = {
    module_radius = "0",
  },

  # GTK
  gtk = {
    theme_name = "Adwaita-dark",
    icon_theme_name = "Papirus-Dark",
    prefer_dark_theme = true,
  },

  # Wallpapers
  wallpapers = {
    main = "1-matte-black.jpg",
    collection = {},
  },
}
