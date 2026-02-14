{ config, ... }:
let
  theme = config.theme.colors;
in
{
  services.mako = {
    enable = true;

    settings = {
      default-timeout = config.notifications.timeout;
      inherit (config.notifications) width height;
      padding = 10;
      margin = 20;
      border-size = config.layout.borderWidth;
      border-radius = config.layout.borderRadius;
      anchor = config.notifications.position;
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
