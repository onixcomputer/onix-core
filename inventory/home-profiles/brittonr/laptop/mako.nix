{ config, ... }:
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
      font = "${config.font.ui} ${toString config.font.size.notification}";
      icons = true;
      max-icon-size = 32;

      # Tokyo Night colors
      background-color = "#1a1b26";
      text-color = "#a9b1d6";
      border-color = "#33ccff";
      progress-color = "#33ccff";
    };

    # Extra configuration for specific app behaviors
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
