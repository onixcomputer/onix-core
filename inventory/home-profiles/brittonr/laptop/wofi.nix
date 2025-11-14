{ pkgs, ... }:
{
  programs.wofi = {
    enable = true;

    settings = {
      width = 600;
      height = 500;
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
      image_size = 40;
      gtk_dark = true;
    };

    style = ''
      /* Tokyo Night theme - official folke colors */
      * {
        font-family: "CaskaydiaMono Nerd Font";
        color: #c0caf5;
      }

      window {
        border: 3px solid #7aa2f7;
        background: #1a1b26;
        border-radius: 15px;
      }

      #input {
        margin: 1.5em;
        margin-bottom: 0em;
        padding: 1em;
        border: none;
        font-weight: bold;
        background: #1a1b26;
        color: #c0caf5;
        border-radius: 15px;
      }

      #input:focus {
        border: 1px solid #7aa2f7;
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
        color: #c0caf5;
      }

      #text:selected {
        color: #15161e;
      }

      #entry {
        margin-top: 0.5em;
        border-radius: 15px;
      }

      #entry:selected {
        background: linear-gradient(90deg, #7aa2f7 0%, #bb9af7 80%);
      }
    '';
  };

  home.packages = with pkgs; [
    (writeShellScriptBin "wofi-emoji" ''
      ${wofi}/bin/wofi -d -i --show dmenu | wl-copy
    '')
  ];
}
