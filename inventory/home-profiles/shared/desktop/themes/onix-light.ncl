# Onix Light theme — professional light theme with orange accents
let mk_theme = import "./mk-theme.ncl" in

mk_theme {
  name = "Onix Light",
  author = "Onix Computer",
  variant = "light",

  # Surface colors
  base00 = "#ffffff",
  base01 = "#f5f5f5",
  base02 = "#e0e0e0",
  base03 = "#cccccc",
  base04 = "#999999",
  base05 = "#666666",
  base06 = "#333333",
  base07 = "#000000",

  # Semantic colors
  red = "#cc0000",
  orange = "#ff6600",
  yellow = "#cc8800",
  green = "#00aa00",
  cyan = "#0088aa",
  blue = "#0066cc",
  purple = "#8800cc",
  magenta = "#cc00aa",

  # Terminal colors
  term_black = "#333333",
  term_white = "#e0e0e0",
  term_bright_black = "#666666",
  term_bright_red = "#ff0000",
  term_bright_green = "#00ff00",
  term_bright_yellow = "#ffaa00",
  term_bright_blue = "#0088ff",
  term_bright_magenta = "#ff00dd",
  term_bright_cyan = "#00ddff",
  term_bright_white = "#ffffff",

  # Special
  bg_dark = "#f5f5f5",
  accent = "#ff6600",
  accent2 = "#cc8800",

  # Opacity
  opacity = {
    terminal = "0.95",
    popups = "0.95",
    notifications = "0.95",
  },

  # Hyprland
  hypr = {
    active_border = "rgba(ff6600ff) rgba(cc8800ff) 45deg",
    inactive_border = "rgba(ccccccaa)",
    border_size = 2,
    gaps_in = 8,
    gaps_out = 8,
    rounding = 0,
  },

  # Waybar
  waybar = {
    module_radius = "0",
  },

  # GTK
  gtk = {
    theme_name = "Adwaita",
    icon_theme_name = "Papirus-Light",
    prefer_dark_theme = false,
  },

  # Wallpapers
  wallpapers = {
    main = "1-kanagawa.jpg",
    collection = {},
  },
}
