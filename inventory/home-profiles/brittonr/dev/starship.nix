{ config, ... }:
let
  c = config.colors;
in
{
  programs.starship = {
    enable = true;

    # Enable for interactive shells only
    enableInteractive = true;

    # Enable transient prompt
    enableTransience = true;

    # Enable shell integrations
    enableBashIntegration = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
    settings = {
      format = "[](color_orange)$username[](bg:color_cyan fg:color_orange)$directory[](fg:color_cyan bg:color_gray)$git_branch$git_status[](fg:color_gray bg:color_green)$c$rust$golang$nodejs$php$python[](fg:color_green bg:color_bg3)$docker_context[](fg:color_bg3 bg:color_bg1)$time[ ](fg:color_bg1)\n$line_break$character";

      palette = "onix-dark";

      palettes.onix-dark = {
        color_orange = c.grayscale.white;
        color_cyan = c.grayscale.light;
        color_gray = c.grayscale.medium;
        color_green = c.grayscale.dim;
        color_yellow = c.editor.type_dark;
        color_red = c.grayscale.muted;
        color_bg1 = c.bg;
        color_bg3 = c.bg_highlight;
        color_fg0 = c.fg;
      };

      right_format = "$cmd_duration";

      username = {
        show_always = true;
        style_user = "bg:color_orange fg:color_bg1";
        style_root = "bg:color_red fg:color_bg1";
        format = "[ $user ]($style)";
      };

      directory = {
        style = "fg:color_bg1 bg:color_cyan";
        format = "[ $path ]($style)";
        truncation_length = 3;
        truncation_symbol = "…/";
      };

      git_branch = {
        symbol = "";
        style = "bg:color_gray fg:color_bg1";
        format = "[ $symbol $branch ]($style)";
      };

      git_status = {
        style = "bg:color_gray fg:color_bg1";
        format = "[$all_status$ahead_behind ]($style)";
      };

      nodejs = {
        symbol = "";
        style = "bg:color_green fg:color_bg1";
        format = "[ $symbol ($version) ]($style)";
      };

      rust = {
        symbol = "";
        style = "bg:color_green fg:color_bg1";
        format = "[ $symbol ($version) ]($style)";
      };

      golang = {
        symbol = "";
        style = "bg:color_green fg:color_bg1";
        format = "[ $symbol ($version) ]($style)";
      };

      php = {
        symbol = "";
        style = "bg:color_green fg:color_bg1";
        format = "[ $symbol ($version) ]($style)";
      };

      python = {
        symbol = "";
        style = "bg:color_green fg:color_bg1";
        format = "[ $symbol ($version) ]($style)";
      };

      c = {
        symbol = "";
        style = "bg:color_green fg:color_bg1";
        format = "[ $symbol ($version) ]($style)";
      };

      docker_context = {
        symbol = "";
        style = "bg:color_bg3 fg:${c.docker_accent}";
        format = "[ $symbol $context ]($style)";
      };

      time = {
        disabled = false;
        time_format = "%R";
        style = "bg:color_bg1 fg:color_fg0";
        format = "[  $time ]($style)";
      };

      character = {
        success_symbol = "[➜](bold fg:${c.grayscale.medium})";
        error_symbol = "[✗](bold fg:${c.grayscale.dim})";
      };

      cmd_duration = {
        min_time = 0;
        format = " [$duration](fg:${c.grayscale.dim})";
        show_milliseconds = true;
      };
    };
  };
}
