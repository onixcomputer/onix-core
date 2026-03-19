# Solarized Dark theme by Ethan Schoonover
let mk_theme = import "./mk-theme.ncl" in

mk_theme {
  name = "Solarized Dark",
  author = "Ethan Schoonover",
  variant = "dark",

  # Surface colors
  base00 = "#002b36",
  base01 = "#073642",
  base02 = "#586e75",
  base03 = "#657b83",
  base04 = "#839496",
  base05 = "#93a1a1",
  base06 = "#eee8d5",
  base07 = "#fdf6e3",

  # Semantic colors
  red = "#dc322f",
  orange = "#cb4b16",
  yellow = "#b58900",
  green = "#859900",
  cyan = "#2aa198",
  blue = "#268bd2",
  purple = "#6c71c4",
  magenta = "#d33682",

  # Terminal colors
  term_black = "#073642",
  term_white = "#839496",
  term_bright_black = "#586e75",
  term_bright_red = "#cb4b16",
  term_bright_yellow = "#b58900",
  term_bright_blue = "#268bd2",
  term_bright_magenta = "#6c71c4",
  term_bright_cyan = "#2aa198",
  term_bright_white = "#fdf6e3",

  # Special
  bg_highlight = "#073642",
  fg = "#839496",
  fg_dim = "#657b83",
  border = "#586e75",
  accent2 = "#2aa198",

  # Hyprland
  hypr = {
    active_border = "rgba(dc322fff)",
    inactive_border = "rgba(586e75aa)",
    border_size = 3,
    gaps_in = 3,
    gaps_out = 3,
    rounding = 0,
  },

  # GTK
  gtk = {
    theme_name = "NumixSolarizedDarkBlue",
    icon_theme_name = "Papirus-Dark",
    prefer_dark_theme = true,
  },

  # Wallpapers
  wallpapers = {
    main = "solarized-dark_jellyfish.jpg",
    collection = {
      "solarized-dark_jellyfish.jpg" = {
        url = "https://raw.githubusercontent.com/adeci/wallpapers/main/solarized-dark/solarized-dark_jellyfish.jpg",
        sha256 = "sha256-vNBIkJj4QLXYgHkWi3FoXhIh65kT7FmCUokhjcBl6WQ=",
      },
      "solarized-dark_city.png" = {
        url = "https://raw.githubusercontent.com/adeci/wallpapers/main/solarized-dark/solarized-dark_city.png",
        sha256 = "sha256-rMDiMc4eyut0dl8ihs7RWn8eMgPbboJ+x4nXDCJl7J0=",
      },
      "solarized-dark_street.jpeg" = {
        url = "https://raw.githubusercontent.com/adeci/wallpapers/main/solarized-dark/solarized-dark_street.jpeg",
        sha256 = "sha256-8VAZs9AUtuHYL6spS+ZinXTNiQuF9puwBmAD3Ze+z40=",
      },
    },
  },
}
