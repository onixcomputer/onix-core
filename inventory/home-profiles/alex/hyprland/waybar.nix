_: {
  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 38;
        spacing = 0;
        margin = "0";

        modules-left = [ "hyprland/workspaces" ];
        modules-center = [ "clock" ];
        modules-right = [
          "tray"
          "network"
          "bluetooth"
          "pulseaudio"
          "group/resources"
          "custom/power"
        ];

        "group/resources" = {
          orientation = "horizontal";
          drawer = {
            transition-duration = 400;
            children-class = "drawer-child";
            transition-left-to-right = false; # Expands right, keeping CPU in place
          };
          modules = [
            "cpu"
            "temperature"
            "memory"
          ];
        };

        "hyprland/workspaces" = {
          on-click = "activate";
          format = "{icon}";
          format-icons = {
            "1" = "1";
            "2" = "2";
            "3" = "3";
            "4" = "4";
            "5" = "5";
            "6" = "6";
            "7" = "7";
            "8" = "8";
            "9" = "9";
            active = "●";
            default = "";
          };
          on-scroll-up = "hyprctl dispatch workspace e+1";
          on-scroll-down = "hyprctl dispatch workspace e-1";
          persistent-workspaces = {
            "1" = [ ];
            "2" = [ ];
            "3" = [ ];
            "4" = [ ];
            "5" = [ ];
          };
        };

        clock = {
          interval = 1;
          format = "{:%I:%M %p}";
          format-alt = "{:%A, %B %d, %Y}";
          tooltip-format = "<tt><small>{calendar}</small></tt>";
          calendar = {
            mode = "year";
            mode-mon-col = 3;
            weeks-pos = "right";
            on-scroll = 1;
            format = {
              months = "<span color='#ffead3'><b>{}</b></span>";
              days = "<span color='#ecc6d9'><b>{}</b></span>";
              weeks = "<span color='#99ffdd'><b>W{}</b></span>";
              weekdays = "<span color='#ffcc66'><b>{}</b></span>";
              today = "<span color='#ff6699'><b><u>{}</u></b></span>";
            };
          };
        };

        cpu = {
          interval = 1;
          format = "󰍛 {usage:02}%";
          tooltip = true;
          on-click = "alacritty -e btop";
        };

        memory = {
          interval = 1;
          format = "󰘚 {used:0.1f}G/{total:0.1f}G";
          tooltip-format = "Memory: {percentage}%\nUsed: {used:0.2f}GB\nTotal: {total:0.2f}GB";
          on-click = "alacritty -e btop";
        };

        temperature = {
          interval = 1;
          format = "󰔏 {temperatureC}°C";
          hwmon-path-abs = [
            "/sys/devices/pci0000:00/0000:00:18.3/hwmon" # AMD k10temp typical path
            "/sys/devices/platform/coretemp.0/hwmon" # Intel coretemp typical path
            "/sys/devices/pci0000:00/0000:00:01.3/0000:*/0000:*/hwmon" # AMD chipset path
          ];
          input-filename = "temp1_input";
          critical-threshold = 80;
          format-critical = "󰸁 {temperatureC}°C";
          tooltip-format = "CPU Temperature: {temperatureC}°C / {temperatureF}°F";
          on-click = "alacritty -e btop";
        };

        pulseaudio = {
          format = "{icon} {volume}%";
          format-muted = "󰝟";
          format-icons = {
            default = [
              "󰕿"
              "󰖀"
              "󰕾"
            ];
          };
          on-click = "pavucontrol";
          on-click-right = "pamixer -t";
          scroll-step = 5;
        };

        tray = {
          icon-size = 20;
          spacing = 6;
          show-passive-items = true;
        };

        network = {
          interval = 5;
          format-wifi = "󰖩 {signalStrength}%";
          format-ethernet = "󰈁 Wired";
          format-linked = "󰈁 No IP";
          format-disconnected = "󰖪";
          format-disabled = "󰖪";
          tooltip-format = "{ifname}: {ipaddr}/{cidr}";
          tooltip-format-wifi = "WiFi: {essid} ({signalStrength}%)\n{ifname}: {ipaddr}/{cidr}\n↑ {bandwidthUpBytes} ↓ {bandwidthDownBytes}";
          tooltip-format-ethernet = "Ethernet: {ifname}\n{ipaddr}/{cidr}\n↑ {bandwidthUpBytes} ↓ {bandwidthDownBytes}";
          tooltip-format-disconnected = "Disconnected";
          on-click = "rofi-wifi";
          on-click-right = "alacritty -e nmtui";
        };

        bluetooth = {
          format-on = "󰂯";
          format-off = "󰂲";
          format-disabled = "󰂲";
          format-connected = "󰂱 {num_connections}";
          format-connected-battery = "󰂱 {device_battery_percentage}%";
          tooltip-format = "{controller_alias}\t{controller_address}";
          tooltip-format-connected = "{controller_alias}\t{controller_address}\n\n{device_enumerate}";
          tooltip-format-enumerate-connected = "{device_alias}\t{device_address}";
          tooltip-format-enumerate-connected-battery = "{device_alias}\t{device_address}\t{device_battery_percentage}%";
          on-click = "rfkill toggle bluetooth";
          on-click-right = "alacritty -e bluetoothctl";
        };

        "custom/power" = {
          format = "󰐥";
          tooltip = false;
          on-click = "wofi-power";
        };
      };
    };

    style = ''
      * {
        border: none;
        border-radius: 0;
        font-family: "CaskaydiaMono Nerd Font";
        font-size: 15px;
        min-height: 0;
      }

      window#waybar {
        background: transparent;
        color: #c0caf5;
      }

      tooltip {
        background: #24283b;
        border-radius: 0.6em;
        border-width: 2px;
        border-style: solid;
        border-color: #16161e;
        padding: 0.5em;
      }

      tooltip label {
        color: #c0caf5;
        font-size: 0.9em;
      }

      #workspaces {
        background: #16161e;
        border-radius: 0.7em;
        margin: 0.3em;
        margin-left: 0.8em;
        padding: 0.2em;
      }

      #workspaces button {
        padding: 0 0.5em;
        margin: 0 0.1em;
        border-radius: 0.6em;
        color: #7aa2f7;
        background: transparent;
        transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
      }

      #workspaces button:first-child {
        margin-left: 0;
      }

      #workspaces button:last-child {
        margin-right: 0;
      }

      #workspaces button.active {
        background: #7aa2f7;
        color: #16161e;
        border-radius: 0.6em;
        transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
        font-size: 1.6em;
        padding: 0 0.6em;
        margin: 0 0.15em;
      }

      #workspaces button:hover {
        background: #7aa2f7;
        color: #16161e;
        border-radius: 0.6em;
        transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
      }

      #clock {
        color: #7aa2f7;
        background: #16161e;
        border-radius: 0.7em;
        margin: 0.3em;
        padding: 0 0.8em;
      }

      .modules-right {
        margin-right: 0.8em;
      }

      #tray {
        background: #16161e;
        border-radius: 0.7em;
        padding: 0.3em 0.6em;
        margin: 0.3em 0.2em;
      }

      #tray > .passive {
        -gtk-icon-effect: dim;
      }

      #tray > .needs-attention {
        -gtk-icon-effect: highlight;
      }

      #network {
        background: #16161e;
        color: #7aa2f7;
        border-radius: 0.7em;
        padding: 0 0.8em;
        margin: 0.3em 0.2em;
      }

      #network.wifi {
        color: #7aa2f7;
      }

      #network.ethernet {
        color: #bb9af7;  /* Purple for wired to distinguish */
      }

      #network.linked {
        color: #f7768e;  /* Red-ish for linked but no internet */
      }

      #network.disconnected,
      #network.disabled {
        color: #313244;
        background: #16161e;
      }

      #bluetooth {
        background: #16161e;
        color: #7aa2f7;
        border-radius: 0.7em;
        padding: 0 0.8em;
        margin: 0.3em 0.2em;
      }

      #bluetooth.off,
      #bluetooth.disabled {
        color: #313244;
        background: #16161e;
      }

      #bluetooth.connected {
        color: #9ece6a;
      }

      #pulseaudio {
        background: #16161e;
        color: #7aa2f7;
        border-radius: 0.7em;
        padding: 0 0.8em;
        margin: 0.3em 0.2em;
      }

      #pulseaudio.muted {
        color: #313244;
      }

      box#resources {
        background: #16161e;
        border-radius: 0.7em;
        margin: 0.3em 0.2em;
        padding: 0 0.4em;
      }

      #cpu {
        color: #7aa2f7;
        padding: 0 0.2em;
        background: transparent;
      }

      #memory {
        color: #7aa2f7;
        padding: 0 0.6em;
        background: transparent;
      }

      #temperature {
        color: #7aa2f7;
        padding: 0 0.4em;
        background: transparent;
      }

      #temperature.critical {
        color: #f7768e;
      }

      #custom-power {
        background: #16161e;
        color: #7aa2f7;
        border-radius: 0.7em;
        padding: 0 0.8em;
        margin: 0.3em 0.2em;
        margin-right: 0.8em;
      }

      /* Group drawer styling - matching dotfiles approach */
      /* The drawer transition is handled by waybar internally */
      /* We just style the modules consistently */

    '';
  };
}
