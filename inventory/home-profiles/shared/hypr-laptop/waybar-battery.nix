{ lib, config, ... }:
let
  theme = config.theme.colors;
in
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
        warning = 20;
        critical = 10;
        plugordie = 5;
      };
      format = "{icon} {capacity}%";
      format-icons = [
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
      format-charging = "󰂄 {capacity}%";
      format-plugged = "󰂄 {capacity}%";
      format-plugordie = "󰂃 {capacity}%";
      tooltip = true;
      tooltip-format = "{timeTo}, {capacity}%";
    };
  };

  # Add battery-specific CSS styles matching our theme
  programs.waybar.style = lib.mkAfter ''
    #battery {
      background: rgba(${theme.bg_dark_rgb}, ${theme.waybar.module_bg_opacity});
      color: ${theme.accent};  /* Theme color for normal state */
      border-radius: ${theme.waybar.module_radius};
      padding: 0 0.6em;
      margin: 0 0.15em;  /* No top/bottom margins */
    }

    #battery.warning {
      color: #e0af68;  /* Yellow/orange for warning */
    }

    #battery.critical {
      color: #f7768e;  /* Red for critical */
      background: rgba(247, 118, 142, 0.2);
    }

    #battery.plugordie {
      color: #f7768e;  /* Red for emergency */
      background: rgba(247, 118, 142, 0.3);
      animation-name: battery-critical-pulse;
      animation-duration: 2s;
      animation-iteration-count: infinite;
    }

    /* Charging and plugged always override everything - must come AFTER plugordie */
    #battery.charging,
    #battery.plugged,
    #battery.charging.warning,
    #battery.charging.critical,
    #battery.charging.plugordie,
    #battery.plugged.warning,
    #battery.plugged.critical,
    #battery.plugged.plugordie {
      color: #9ece6a;  /* Green for charging/plugged */
      background: rgba(${theme.bg_dark_rgb}, ${theme.waybar.module_bg_opacity});  /* Same as normal background */
      /* Override animation by setting duration to 0 */
      animation-duration: 0s;
      animation-name: none;
    }

    /* Slow pulsing animation for critical battery */
    @keyframes battery-critical-pulse {
      0% {
        background: rgba(247, 118, 142, 0.2);
      }
      50% {
        background: rgba(247, 118, 142, 0.4);
      }
      100% {
        background: rgba(247, 118, 142, 0.2);
      }
    }
  '';
}
