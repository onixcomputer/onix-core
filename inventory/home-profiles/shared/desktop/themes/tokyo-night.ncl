# Tokyo Night theme by enkia
let mk_theme = import "./mk-theme.ncl" in

mk_theme {
  name = "Tokyo Night",
  author = "enkia",
  variant = "dark",

  # Surface colors (8 levels from darkest to lightest)
  base00 = "#1a1b26",
  base01 = "#24283b",
  base02 = "#414868",
  base03 = "#565f89",
  base04 = "#787c99",
  base05 = "#a9b1d6",
  base06 = "#c0caf5",
  base07 = "#ffffff",

  # Semantic colors
  red = "#f7768e",
  orange = "#ff9e64",
  yellow = "#e0af68",
  green = "#9ece6a",
  cyan = "#7dcfff",
  blue = "#7aa2f7",
  purple = "#bb9af7",
  magenta = "#ad8ee6",

  # Terminal colors
  term_black = "#32344a",
  term_red = "#f7768e",
  term_green = "#9ece6a",
  term_yellow = "#e0af68",
  term_blue = "#7aa2f7",
  term_magenta = "#ad8ee6",
  term_cyan = "#449dab",
  term_white = "#787c99",

  term_bright_black = "#444b6a",
  term_bright_red = "#ff7a93",
  term_bright_green = "#b9f27c",
  term_bright_yellow = "#ff9e64",
  term_bright_blue = "#7da6ff",
  term_bright_magenta = "#bb9af7",
  term_bright_cyan = "#0db9d7",
  term_bright_white = "#acb0d0",

  # Special
  bg_dark = "#16161e",
  term_bg = "#1a1b26",
  term_fg = "#a9b1d6",
  term_selection = "#7aa2f7",

  # Hyprland
  hypr = {
    active_border = "rgba(7aa2f7ff) rgba(bb9af7ff) 45deg",
    inactive_border = "rgba(565f89aa)",
    border_size = 3,
    gaps_in = 3,
    gaps_out = 3,
    rounding = 0,
  },

  # GTK (names only — packages added in Nix)
  gtk = {
    theme_name = "Tokyonight-Dark",
    icon_theme_name = "Papirus-Dark",
    prefer_dark_theme = true,
  },

  # Wallpapers (URLs/hashes only — fetchurl added in Nix)
  wallpapers = {
    main = "tokyo-night_nix.png",
    collection = {
      "tokyo-night_nix.png" = {
        url = "https://raw.githubusercontent.com/adeci/wallpapers/main/tokyo-night/tokyo-night_nix.png",
        sha256 = "sha256-W5GaKCOiV2S3NuORGrRaoOE2x9X6gUS+wYf7cQkw9CY=",
      },
      "tokyo-night_street.jpg" = {
        url = "https://raw.githubusercontent.com/adeci/wallpapers/main/tokyo-night/tokyo-night_street.jpg",
        sha256 = "sha256-XlSm8RzGwowJMT/DQBNwfsU4V6QuvP4kvwVm1pzw6SM=",
      },
    },
  },
}
