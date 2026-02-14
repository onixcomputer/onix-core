{ config, ... }:
{
  programs.alacritty = {
    enable = true;
    settings = {
      env.TERM = "xterm-256color";

      font = {
        normal = {
          family = config.font.mono;
          style = "Regular";
        };
        bold = {
          family = config.font.mono;
          style = "Bold";
        };
        italic = {
          family = config.font.mono;
          style = "Italic";
        };
        size = 14;
      };

      window = {
        padding = {
          x = config.layout.terminal.padding;
          y = config.layout.terminal.padding;
        };
        decorations = "None";
        opacity = config.opacity.terminal;
      };

      keyboard.bindings = [
        {
          key = "F12";
          action = "ToggleFullscreen";
        }
      ];

      colors = {
        primary = {
          background = config.colors.term_bg;
          foreground = config.colors.term_fg;
        };

        normal = {
          black = config.colors.term_black;
          red = config.colors.term_red;
          green = config.colors.term_green;
          yellow = config.colors.term_yellow;
          blue = config.colors.term_blue;
          magenta = config.colors.term_magenta;
          cyan = config.colors.term_cyan;
          white = config.colors.term_white;
        };

        bright = {
          black = config.colors.term_bright_black;
          red = config.colors.term_bright_red;
          green = config.colors.term_bright_green;
          yellow = config.colors.term_bright_yellow;
          blue = config.colors.term_bright_blue;
          magenta = config.colors.term_bright_magenta;
          cyan = config.colors.term_bright_cyan;
          white = config.colors.term_bright_white;
        };

        selection = {
          background = config.colors.term_selection;
        };
      };
    };
  };
}
