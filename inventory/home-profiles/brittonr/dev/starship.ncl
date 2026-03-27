# Starship prompt configuration.
#
# Takes flattened color strings + config values (via evalNickelFileWith).
# Full theme.data exceeds WASM stack when serialized as Nickel source;
# Nix extracts the needed .hex values before calling this.
fun a =>
  {
    format = "[](color_orange)$username[](bg:color_cyan fg:color_orange)$directory[](fg:color_cyan bg:color_gray)$git_branch$git_status[](fg:color_gray bg:color_green)$c$rust$golang$nodejs$php$python[](fg:color_green bg:color_bg3)$docker_context[](fg:color_bg3 bg:color_bg1)$time[ ](fg:color_bg1)\n$line_break$character",

    palette = "onix-dark",

    palettes = {
      onix-dark = {
        color_orange = a.grayscale_white,
        color_cyan = a.grayscale_light,
        color_gray = a.grayscale_medium,
        color_green = a.grayscale_dim,
        color_yellow = a.editor_type_dark,
        color_red = a.grayscale_muted,
        color_bg1 = a.bg,
        color_bg3 = a.bg_highlight,
        color_fg0 = a.fg,
      },
    },

    right_format = "$cmd_duration",

    username = {
      show_always = true,
      style_user = "bg:color_orange fg:color_bg1",
      style_root = "bg:color_red fg:color_bg1",
      format = "[ $user ]($style)",
    },

    directory = {
      style = "fg:color_bg1 bg:color_cyan",
      format = "[ $path ]($style)",
      truncation_length = a.truncationLength,
      truncation_symbol = "…/",
    },

    git_branch = {
      symbol = "",
      style = "bg:color_gray fg:color_bg1",
      format = "[ $symbol $branch ]($style)",
    },

    git_status = {
      style = "bg:color_gray fg:color_bg1",
      format = "[$all_status$ahead_behind ]($style)",
    },

    nodejs = {
      symbol = "",
      style = "bg:color_green fg:color_bg1",
      format = "[ $symbol ($version) ]($style)",
    },

    rust = {
      symbol = "",
      style = "bg:color_green fg:color_bg1",
      format = "[ $symbol ($version) ]($style)",
    },

    golang = {
      symbol = "",
      style = "bg:color_green fg:color_bg1",
      format = "[ $symbol ($version) ]($style)",
    },

    php = {
      symbol = "",
      style = "bg:color_green fg:color_bg1",
      format = "[ $symbol ($version) ]($style)",
    },

    python = {
      symbol = "",
      style = "bg:color_green fg:color_bg1",
      format = "[ $symbol ($version) ]($style)",
    },

    c = {
      symbol = "",
      style = "bg:color_green fg:color_bg1",
      format = "[ $symbol ($version) ]($style)",
    },

    docker_context = {
      symbol = "",
      style = "bg:color_bg3 fg:%{a.docker_accent}",
      format = "[ $symbol $context ]($style)",
    },

    time = {
      disabled = false,
      time_format = "%T",
      style = "bg:color_bg1 fg:color_fg0",
      format = "[  $time ]($style)",
    },

    character = {
      success_symbol = "[➜](bold fg:%{a.grayscale_medium})",
      error_symbol = "[✗](bold fg:%{a.grayscale_dim})",
    },

    cmd_duration = {
      min_time = a.cmdDurationMinTime,
      format = " [$duration](fg:%{a.grayscale_dim})",
      show_milliseconds = true,
    },
  }
