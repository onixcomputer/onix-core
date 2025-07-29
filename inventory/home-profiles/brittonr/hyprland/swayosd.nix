{ config, ... }:
{
  services.swayosd = {
    enable = true;
    stylePath = "${config.xdg.configHome}/swayosd/style.css";
  };

  # Create the style file
  xdg.configFile."swayosd/style.css".text = ''
    window {
      border-radius: 5px;
      opacity: 0.97;
      border: 2px solid #89b4fa;
      background-color: rgba(30, 30, 46, 0.9);
    }

    label {
      font-family: 'JetBrainsMono Nerd Font', monospace;
      font-size: 11pt;
      color: #cdd6f4;
    }

    image {
      color: #89b4fa;
    }

    progressbar {
      border-radius: 5px;
    }

    progress {
      background-color: #89b4fa;
    }
  '';
}
