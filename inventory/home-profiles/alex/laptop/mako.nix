{ config, ... }:
let
  theme = config.theme.colors;
in
{
  services.mako = {
    enable = true;

    settings = {
      default-timeout = 5000;
      width = 420;
      height = 110;
      padding = 10;
      margin = 20;
      border-size = 2;
      border-radius = 0;
      anchor = "top-right";
      font = "CaskaydiaMono Nerd Font 11";
      icons = true;
      max-icon-size = 32;

      background-color = theme.bg;
      text-color = theme.fg_dim;
      border-color = theme.cyan;
      progress-color = theme.cyan;
    };

    extraConfig = ''
      [app-name=Spotify]
      invisible=1

      [mode=do-not-disturb]
      invisible=true

      [mode=do-not-disturb app-name=notify-send]
      invisible=false
    '';
  };
}
