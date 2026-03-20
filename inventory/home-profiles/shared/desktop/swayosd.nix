{ config, ... }:
let
  theme = config.theme.data;
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
      border: 2px solid ${theme.accent.hex};
      background-color: ${theme.bg.hex}e6; /* 90% opacity */
    }

    label {
      font-family: '${config.font.ui}', 'CaskaydiaMono Nerd Font', monospace;
      font-size: 11pt;
      color: ${theme.fg.hex};
    }

    image {
      color: ${theme.accent.hex};
    }

    progressbar {
      border-radius: ${toString theme.hypr.rounding}px;
    }

    progress {
      background-color: ${theme.accent.hex};
    }
  '';
}
