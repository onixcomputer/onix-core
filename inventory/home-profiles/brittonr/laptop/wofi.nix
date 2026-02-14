{ pkgs, config, ... }:
{
  programs.wofi = {
    enable = true;

    settings = {
      inherit (config.launcher) width height;
      location = "center";
      show = "drun";
      prompt = "Apps";
      filter_rate = 100;
      allow_markup = true;
      no_actions = true;
      halign = "fill";
      orientation = "vertical";
      content_halign = "fill";
      insensitive = true;
      allow_images = true;
      image_size = config.launcher.iconSize;
      gtk_dark = true;
    };

    style = ''
      * {
        font-family: "${config.font.ui}";
        color: ${config.colors.fg};
      }

      window {
        border: 3px solid ${config.colors.term_blue};
        background: ${config.colors.term_bg};
        border-radius: 15px;
      }

      #input {
        margin: 1.5em;
        margin-bottom: 0em;
        padding: 1em;
        border: none;
        font-weight: bold;
        background: ${config.colors.term_bg};
        color: ${config.colors.fg};
        border-radius: 15px;
      }

      #input:focus {
        border: 1px solid ${config.colors.term_blue};
      }

      #inner-box {
        margin: 1.5em;
        margin-top: 0.5em;
      }

      #outer-box {
        margin-bottom: 0.5em;
      }

      #scroll {
        margin-top: 5px;
      }

      #text {
        margin-left: 0.5em;
        color: ${config.colors.fg};
      }

      #text:selected {
        color: ${config.colors.bg_dark};
      }

      #entry {
        margin-top: 0.5em;
        border-radius: 15px;
      }

      #entry:selected {
        background: linear-gradient(90deg, ${config.colors.term_blue} 0%, ${config.colors.term_bright_magenta} 80%);
      }
    '';
  };

  home.packages = with pkgs; [
    (writeShellScriptBin "wofi-emoji" ''
      ${wofi}/bin/wofi -d -i --show dmenu | wl-copy
    '')
  ];
}
