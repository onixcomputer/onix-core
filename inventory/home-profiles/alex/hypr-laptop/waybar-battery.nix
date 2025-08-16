{ lib, ... }:
{
  # Add battery module to waybar for laptops
  programs.waybar.settings.mainBar = {
    modules-right = lib.mkForce [
      "tray"
      "network"
      "bluetooth"
      "pulseaudio"
      "group/resources"
      "battery"
      "custom/power"
    ];

    battery = {
      interval = 1;
      states = {
        warning = 30;
        critical = 15;
      };
      format = "{icon} {capacity}%";
      format-charging = "󰂄 {capacity}%";
      format-plugged = "󰂄 {capacity}%";
      format-icons = [
        "󰂎"
        "󰁺"
        "󰁻"
        "󰁼"
        "󰁽"
        "󰁾"
        "󰁿"
        "󰂀"
        "󰂁"
        "󰂂"
        "󰁹"
      ];
    };
  };

  # Add battery-specific CSS styles
  programs.waybar.style = lib.mkAfter ''
    #battery {
      background: #16161e;
      color: #7aa2f7;
      border-radius: 0.7em;
      padding: 0 0.8em;
      margin: 0.3em 0.2em;
    }

    #battery.charging,
    #battery.plugged {
      color: #0b8e37;
    }

    #battery.warning {
      color: #f9e2af;
      animation: warning-blink 0.5s linear 3;
    }

    #battery.critical {
      background-color: #f38ba8;
      color: #1e1e2e;
      animation: critical-blink 0.5s linear 3;
    }

    @keyframes warning-blink {
      0% {
        background-color: #16161e;
        color: #f9e2af;
      }
      50% {
        background-color: #f9e2af;
        color: #16161e;
      }
      100% {
        background-color: #16161e;
        color: #f9e2af;
      }
    }

    @keyframes critical-blink {
      0% {
        background-color: #f38ba8;
        color: #1e1e2e;
      }
      50% {
        background-color: #1e1e2e;
        color: #f38ba8;
      }
      100% {
        background-color: #f38ba8;
        color: #1e1e2e;
      }
    }
  '';
}
