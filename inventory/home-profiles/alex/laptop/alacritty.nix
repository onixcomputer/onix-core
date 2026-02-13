{ config, ... }:
let
  theme = config.theme.colors;
in
{
  programs.alacritty = {
    enable = true;
    settings = {
      env.TERM = "xterm-256color";

      font = {
        normal = {
          family = "CaskaydiaMono Nerd Font Mono";
          style = "Regular";
        };
        bold = {
          family = "CaskaydiaMono Nerd Font Mono";
          style = "Bold";
        };
        italic = {
          family = "CaskaydiaMono Nerd Font Mono";
          style = "Italic";
        };
        size = 14;
      };

      window = {
        padding = {
          x = 14;
          y = 14;
        };
        decorations = "None";
        opacity = 0.98;
      };

      keyboard.bindings = [
        {
          key = "F12";
          action = "ToggleFullscreen";
        }
      ];

      colors = {
        primary = {
          background = theme.bg;
          foreground = theme.fg_dim;
        };

        normal = {
          black = theme.term_black;
          red = theme.term_red;
          green = theme.term_green;
          yellow = theme.term_yellow;
          blue = theme.term_blue;
          magenta = theme.term_magenta;
          cyan = theme.term_cyan;
          white = theme.term_white;
        };

        bright = {
          black = theme.term_bright_black;
          red = theme.term_bright_red;
          green = theme.term_bright_green;
          yellow = theme.term_bright_yellow;
          blue = theme.term_bright_blue;
          magenta = theme.term_bright_magenta;
          cyan = theme.term_bright_cyan;
          white = theme.term_bright_white;
        };

        selection = {
          background = theme.accent;
        };
      };
    };
  };
}
