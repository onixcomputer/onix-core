{ config, ... }:
{
  services.swayosd = {
    enable = true;
    stylePath = "${config.xdg.configHome}/swayosd/style.css";
  };

  # Create the style file
  xdg.configFile."swayosd/style.css".text = ''
    window {
      border-radius: ${toString config.layout.borderRadius}px;
      opacity: 0.97;
      border: ${toString config.layout.borderWidth}px solid ${config.colors.term_blue};
      background-color: rgba(${config.colors.hexToRgb config.colors.term_bg}, 0.9);
    }

    label {
      font-family: '${config.font.ui}', monospace;
      font-size: 11pt;
      color: ${config.colors.term_bright_white};
    }

    image {
      color: ${config.colors.term_blue};
    }

    progressbar {
      border-radius: ${toString config.layout.borderRadius}px;
    }

    progress {
      background-color: ${config.colors.term_blue};
    }
  '';
}
