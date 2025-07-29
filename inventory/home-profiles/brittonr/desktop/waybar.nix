_: {
  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        reload_style_on_change = true;
        layer = "top";
        position = "top";
        spacing = 0;
        height = 26;

        modules-left = [ "hyprland/workspaces" ];
        modules-center = [ "clock" ];
        modules-right = [
          "tray"
          "bluetooth"
          "network"
          "pulseaudio"
          "cpu"
        ];

        "hyprland/workspaces" = {
          on-click = "activate";
          format = "{icon}";
          format-icons = {
            default = "";
            "1" = "1";
            "2" = "2";
            "3" = "3";
            "4" = "4";
            "5" = "5";
            "6" = "6";
            "7" = "7";
            "8" = "8";
            "9" = "9";
            active = "󱓻";
          };
          persistent-workspaces = {
            "1" = [ ];
            "2" = [ ];
            "3" = [ ];
            "4" = [ ];
            "5" = [ ];
          };
        };

        cpu = {
          interval = 5;
          format = "󰍛";
          on-click = "alacritty -e btop";
        };

        clock = {
          format = "{:%A %H:%M}";
          format-alt = "{:%d %B %Y}";
          tooltip = false;
        };

        network = {
          format-icons = [
            "󰤯"
            "󰤟"
            "󰤢"
            "󰤥"
            "󰤨"
          ];
          format = "{icon}";
          format-wifi = "{icon}";
          format-ethernet = "󰀂";
          format-disconnected = "󰖪";
          tooltip-format-wifi = "{essid} ({frequency} GHz)\n⇣{bandwidthDownBytes}  ⇡{bandwidthUpBytes}";
          tooltip-format-ethernet = "⇣{bandwidthDownBytes}  ⇡{bandwidthUpBytes}";
          tooltip-format-disconnected = "Disconnected";
          interval = 3;
          nospacing = 1;
          on-click = "alacritty -e nmtui";
        };

        bluetooth = {
          format = "";
          format-disabled = "󰂲";
          format-connected = "";
          tooltip-format = "Devices connected: {num_connections}";
          on-click = "blueman-manager";
        };

        pulseaudio = {
          format = "{icon}";
          on-click = "pavucontrol";
          on-click-right = "pamixer -t";
          tooltip-format = "Playing at {volume}%";
          scroll-step = 5;
          format-muted = "󰝟";
          format-icons = {
            default = [
              ""
              ""
              ""
            ];
          };
        };

        tray = {
          icon-size = 12;
          spacing = 12;
        };
      };
    };

    style = ''
      /* Tokyo Night theme */
      @define-color foreground #cdd6f4;
      @define-color background #1a1b26;

      * {
        border: none;
        border-radius: 0;
        min-height: 0;
        font-family: "CaskaydiaMono Nerd Font";
        font-size: 12px;
      }

      window#waybar {
        background-color: rgba(26, 27, 38, 0.9); /* #1a1b26 with transparency */
        color: #a9b1d6;
      }

      .modules-left {
        margin-left: 8px;
      }

      .modules-right {
        margin-right: 8px;
      }

      #workspaces button {
        all: initial;
        padding: 0 6px;
        margin: 0 1.5px;
        min-width: 9px;
        color: #565f89; /* Tokyo Night inactive */
      }

      #workspaces button:hover {
        background: rgba(122, 162, 247, 0.2); /* Tokyo Night blue with transparency */
        color: #a9b1d6;
      }

      #workspaces button.active {
        background-color: #7aa2f7; /* Tokyo Night blue */
        color: #1a1b26;
      }

      #tray,
      #cpu,
      #network,
      #bluetooth,
      #pulseaudio,
      #clock {
        min-width: 12px;
        margin: 0 7.5px;
        color: #a9b1d6;
      }

      tooltip {
        background: rgba(26, 27, 38, 0.95);
        border: 1px solid #33ccff; /* Tokyo Night cyan border */
        padding: 8px;
      }
    '';
  };
}
