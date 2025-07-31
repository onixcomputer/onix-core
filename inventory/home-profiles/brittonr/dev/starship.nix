_:

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
      format = "[](color_pink)$username[](bg:color_purple fg:color_pink)$directory[](fg:color_purple bg:color_blue)$git_branch$git_status[](fg:color_blue bg:color_green)$c$rust$golang$nodejs$php$python[](fg:color_green bg:color_bg3)$docker_context[](fg:color_bg3 bg:color_bg1)$time[ ](fg:color_bg1)\n$line_break$character";

      palette = "everblush";

      palettes.everblush = {
        color_pink = "#e57474";
        color_purple = "#c47fd5";
        color_blue = "#67b0e8";
        color_green = "#8ccf7e";
        color_yellow = "#e5c76b";
        color_orange = "#fcb163";
        color_bg1 = "#2d2d2d";
        color_bg3 = "#3d3d3d";
        color_fg0 = "#dadada";
      };

      right_format = "$cmd_duration";

      username = {
        show_always = true;
        style_user = "bg:color_pink fg:color_bg1";
        style_root = "bg:color_pink fg:color_bg1";
        format = "[ $user ]($style)";
      };

      directory = {
        style = "fg:color_bg1 bg:color_purple";
        format = "[ $path ]($style)";
        truncation_length = 3;
        truncation_symbol = "…/";
      };

      git_branch = {
        symbol = "";
        style = "bg:color_blue fg:color_bg1";
        format = "[ $symbol $branch ]($style)";
      };

      git_status = {
        style = "bg:color_blue fg:color_bg1";
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
        style = "bg:color_bg3 fg:#83a598";
        format = "[ $symbol $context ]($style)";
      };

      time = {
        disabled = false;
        time_format = "%R";
        style = "bg:color_bg1 fg:color_fg0";
        format = "[  $time ]($style)";
      };

      character = {
        success_symbol = "[➜](bold fg:#8ccf7e)";
        error_symbol = "[✗](bold fg:#e57474)";
      };

      cmd_duration = {
        min_time = 0;
        format = " [$duration](fg:#808080)";
        show_milliseconds = true;
      };
    };
  };
}
