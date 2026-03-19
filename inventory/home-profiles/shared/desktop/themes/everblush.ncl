# Everblush theme — dark, vibrant, and beautiful
let mk_theme = import "./mk-theme.ncl" in

mk_theme {
  name = "Everblush",
  author = "Everblush",
  variant = "dark",

  # Surface colors
  base00 = "#141b1e",
  base01 = "#232a2d",
  base02 = "#2d3437",
  base03 = "#3b4244",
  base04 = "#575e61",
  base05 = "#b3b9b8",
  base06 = "#dadada",
  base07 = "#ffffff",

  # Semantic colors
  red = "#e57474",
  orange = "#fcb163",
  yellow = "#e5c76b",
  green = "#8ccf7e",
  cyan = "#6cbfbf",
  blue = "#67b0e8",
  purple = "#c47fd5",
  magenta = "#c47fd5",

  # Terminal colors
  term_black = "#232a2d",
  term_white = "#b3b9b8",
  term_bright_black = "#3b4244",
  term_bright_red = "#ef7d7d",
  term_bright_green = "#96d988",
  term_bright_yellow = "#f4d67a",
  term_bright_blue = "#71baf2",
  term_bright_magenta = "#ce89df",
  term_bright_cyan = "#67cbe7",
  term_bright_white = "#dadada",

  # Special
  bg_dark = "#0d1316",
  accent2 = "#8ccf7e",

  # Hyprland
  hypr = {
    active_border = "rgba(67b0e8ff) rgba(8ccf7eff) 45deg",
    inactive_border = "rgba(3b4244aa)",
    border_size = 4,
    gaps_in = 4,
    gaps_out = 4,
    rounding = 12,
  },

  # GTK
  gtk = {
    theme_name = "Adwaita",
    icon_theme_name = "Papirus-Light",
    prefer_dark_theme = false,
  },

  # Wallpapers
  wallpapers = {
    main = "everblush_mountain.png",
    collection = {
      "everblush_mountain.png" = {
        url = "https://raw.githubusercontent.com/adeci/wallpapers/main/everblush/everblush_mountain.png",
        sha256 = "sha256-zaQu4syTlxwLnTwfkhz2yXSyYSkUJnozpVqJYbJHZdU=",
      },
      "everblush_circles.png" = {
        url = "https://raw.githubusercontent.com/adeci/wallpapers/main/everblush/everblush_circles.png",
        sha256 = "sha256-8VrcK4WWsc6hZQBga/FbjQlmLujskneoe3oIs8BZYZk=",
      },
      "everblush_anger.png" = {
        url = "https://raw.githubusercontent.com/adeci/wallpapers/main/everblush/everblush_anger.png",
        sha256 = "sha256-39LolpURE+b4PEbuyZM/upmwU+RwtoogvDrSpHyMhL0=",
      },
      "everblush_pacman.png" = {
        url = "https://raw.githubusercontent.com/adeci/wallpapers/main/everblush/everblush_pacman.png",
        sha256 = "sha256-kaYs0m3qYQU9G3HEBJV5gmGpYL9SnD6eqwNV0nlqHIM=",
      },
      "swampcat.mp4" = {
        url = "https://raw.githubusercontent.com/adeci/wallpapers/main/everblush/swampcat.mp4",
        sha256 = "sha256-+uCCPUYVRFkpt13eMjwITftcaPZLtGpC2g+dWor5Prk=",
      },
    },
  },
}
