{ config, ... }:
{
  services.mako = {
    enable = true;

    settings = {
      default-timeout = config.notifications.timeout;
      inherit (config.notifications) width height;
      inherit (config.notifications) padding margin;
      border-size = config.layout.borderWidth;
      border-radius = config.layout.borderRadius;
      anchor = config.notifications.position;
      font = "${config.font.ui} ${toString config.font.size.notification}";
      icons = true;
      max-icon-size = 32;

      background-color = config.colors.term_bg;
      text-color = config.colors.term_fg;
      border-color = config.colors.cyan;
      progress-color = config.colors.cyan;
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
