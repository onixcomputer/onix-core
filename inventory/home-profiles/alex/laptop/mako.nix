_: {
  services.mako = {
    enable = true;

    settings = {
      default-timeout = 5000;
      width = 420;
      height = 110;
      padding = 10;
      margin = 20;
      border-size = 2;
      border-radius = 0; # Tokyo Night uses no rounding
      anchor = "top-right";
      font = "Liberation Sans 11";
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
