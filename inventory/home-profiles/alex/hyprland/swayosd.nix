{ config, ... }:
let
  theme = config.theme.colors;
in
{
  services.swayosd = {
    enable = true;
    stylePath = "${config.xdg.configHome}/swayosd/style.css";
  };

  # Create the style file with theme colors
  xdg.configFile."swayosd/style.css".text = ''
    window {
      border-radius: ${toString theme.hypr.rounding}px;
      opacity: 0.97;
      border: 2px solid ${theme.accent};
      background-color: ${theme.bg}e6; /* 90% opacity */
    }

    label {
      font-family: 'CaskaydiaMono Nerd Font', monospace;
      font-size: 11pt;
      color: ${theme.fg};
    }

    image {
      color: ${theme.accent};
    }

    progressbar {
      border-radius: ${toString theme.hypr.rounding}px;
    }

    progress {
      background-color: ${theme.accent};
    }
  '';
}
