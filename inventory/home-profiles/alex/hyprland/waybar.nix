{ config, ... }:
let
  theme = config.theme.colors;
in
{
  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 28; # Slightly taller for larger font
        spacing = 0;
        margin = "3 0 0 0"; # 3px top margin only

        modules-left = [ "hyprland/workspaces" ];
        modules-center = [ "group/clock" ];
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
            transition-duration = 450;
            children-class = "drawer-child";
            transition-left-to-right = false; # Expands right, keeping CPU in place
          };
          modules = [
            "cpu"
            "temperature"
            "memory"
          ];
        };

        "group/clock" = {
          orientation = "horizontal";
          drawer = {
            transition-duration = 450;
            children-class = "drawer-child";
            transition-left-to-right = false; # Expands right from main clock
          };
          modules = [
            "clock#time"
            "clock#date"
          ];
        };

        "hyprland/workspaces" = {
          on-click = "activate";
          format = "{name}";
          on-scroll-up = "hyprctl dispatch workspace e+1";
          on-scroll-down = "hyprctl dispatch workspace e-1";
          persistent-workspaces = {
            "*" = 10; # Show all 10 workspaces on all monitors
          };
        };

        "clock#time" = {
          interval = 1; # Update every second for smooth time
          format = "{:%I:%M:%S %p}"; # "03:45:23 PM" - 12 hour format
          format-alt = "{:%H:%M:%S}"; # "15:45:23" - 24 hour format on click
          tooltip = false; # No tooltip for time part
        };

        "clock#date" = {
          interval = 60; # Update every minute for date
          format = "{:%a %b %d}"; # "Sat Aug 16"
          tooltip = true; # Calendar tooltip on date
          tooltip-format = "<tt><small>{calendar}</small></tt>";
          calendar = {
            mode = "year"; # Always show year view
            mode-mon-col = 3;
            weeks-pos = "right";
            on-scroll = 1;
            format = {
              months = "<span color='${theme.yellow}'><b>{}</b></span>";
              days = "<span color='${theme.accent2}'><b>{}</b></span>";
              weeks = "<span color='${theme.cyan}'><b>W{}</b></span>";
              weekdays = "<span color='${theme.orange}'><b>{}</b></span>";
              today = "<span color='${theme.red}'><b><u>{}</u></b></span>";
            };
          };
        };

        cpu = {
          interval = 1;
          format = "󰍛 {usage:02}%";
          tooltip = false;
          on-click = "kitty -e btop";
        };

        memory = {
          interval = 1;
          format = "󰘚 {used:0.1f}G/{total:0.1f}G";
          tooltip = false;
          on-click = "kitty -e btop";
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
          tooltip = false;
          on-click = "kitty -e btop";
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
          format-disconnected = "󰖪 Off";
          format-disabled = "󰖪 Off";
          tooltip-format = "{ifname}: {ipaddr}/{cidr}";
          tooltip-format-wifi = "WiFi: {essid} ({signalStrength}%)\n{ifname}: {ipaddr}/{cidr}\n↑ {bandwidthUpBytes} ↓ {bandwidthDownBytes}";
          tooltip-format-ethernet = "Ethernet: {ifname}\n{ipaddr}/{cidr}\n↑ {bandwidthUpBytes} ↓ {bandwidthDownBytes}";
          tooltip-format-disconnected = "Disconnected";
          on-click = "notify-send -t 1000 'WiFi 󰤨' 'Scanning networks...' && rofi-network-menu"; # Show notification then menu
          on-click-right = "nm-connection-editor";
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
          on-click = "blueman-manager";
          on-click-right = "rfkill toggle bluetooth";
        };

        "custom/power" = {
          format = "󰐥";
          tooltip = false;
          on-click = "rofi-power";
        };
      };
    };

    style = ''
      * {
        border: none;
        border-radius: 0;
        font-family: "CaskaydiaMono Nerd Font";
        font-size: 16px;  /* Increased from 15px */
        min-height: 0;
      }

      window#waybar {
        background: transparent;
        color: ${theme.fg};
      }

      tooltip {
        background: ${theme.base01};
        border-radius: 0.6em;
        border-width: 2px;
        border-style: solid;
        border-color: ${theme.bg_dark};
        padding: 0.5em;
      }

      tooltip label {
        color: ${theme.fg};
        font-size: 0.9em;
      }

      #workspaces {
        background: rgba(${theme.bg_dark_rgb}, ${theme.waybar.module_bg_opacity});
        border-radius: 0.5em;
        margin: 0 0.2em;  /* No top/bottom margins */
        margin-left: 0.5em;
        padding: 0.15em 0.3em;
      }

      #workspaces button {
        padding: 0 0.4em;
        margin: 0 0.05em;
        border-radius: 0.5em;
        color: ${theme.accent};
        background: transparent;
        border: 1px solid transparent;
        transition: all 0.4s cubic-bezier(0.4, 0, 0.2, 1);
        font-weight: 500;
        min-width: 24px;
        font-size: 14px;
      }

      #workspaces button:first-child {
        margin-left: 0;
      }

      #workspaces button:last-child {
        margin-right: 0;
      }

      #workspaces button.active {
        background: linear-gradient(45deg, ${theme.accent}, ${theme.accent2});
        color: ${theme.bg_dark};
        border: 1px solid rgba(${theme.accent_rgb}, 0.2);  /* Accent with low opacity for subtle border */
        border-radius: 0.5em;
        box-shadow: 0 0 8px rgba(${theme.accent_rgb}, ${theme.waybar.workspace_active_shadow_opacity}), inset 0 0 12px rgba(${theme.accent_rgb}, 0.1);  /* Subtle inset glow */
        font-weight: 600;
        transition: all 0.4s cubic-bezier(0.4, 0, 0.2, 1);
      }

      #workspaces button.urgent {
        background: ${theme.red};  /* Red for urgent */
        color: ${theme.bg_dark};
        animation-name: pulse;
        animation-duration: 1s;
        animation-iteration-count: infinite;
      }

      #workspaces button:hover {
        background: rgba(${theme.accent_rgb}, ${theme.waybar.workspace_hover_opacity});
        border: 1px solid rgba(${theme.accent_rgb}, ${theme.waybar.workspace_hover_border_opacity});
        transition: all 0.25s ease-out;
      }

      #workspaces button.active:hover {
        box-shadow: 0 0 10px rgba(${theme.accent_rgb}, ${theme.waybar.workspace_active_hover_shadow_opacity}), inset 0 0 12px rgba(${theme.accent_rgb}, 0.15);  /* Stronger inset glow on hover */
      }

      @keyframes pulse {
        0% {
          box-shadow: 0 0 0 0 rgba(247, 118, 142, 0.7);
        }
        70% {
          box-shadow: 0 0 0 10px rgba(247, 118, 142, 0);
        }
        100% {
          box-shadow: 0 0 0 0 rgba(247, 118, 142, 0);
        }
      }

      box#clock {
        background: rgba(${theme.bg_dark_rgb}, ${theme.waybar.module_bg_opacity});
        border-radius: 0.5em;
        margin: 0 0.2em;  /* No top/bottom margins */
        padding: 0 0.3em;
      }

      #clock {
        color: ${theme.accent};
        padding: 0 0.3em;
        background: transparent;
      }

      .modules-right {
        margin-right: 0.8em;
      }

      #tray {
        background: rgba(${theme.bg_dark_rgb}, ${theme.waybar.module_bg_opacity});
        border-radius: 0.5em;
        padding: 0.2em 0.4em;
        margin: 0 0.15em;  /* No top/bottom margins */
      }

      #tray > .passive {
        -gtk-icon-effect: dim;
      }

      #tray > .needs-attention {
        -gtk-icon-effect: highlight;
      }

      #network {
        background: rgba(${theme.bg_dark_rgb}, ${theme.waybar.module_bg_opacity});
        color: ${theme.accent};
        border-radius: 0.5em;
        padding: 0 0.6em;
        margin: 0 0.15em;  /* No top/bottom margins */
      }

      #network.wifi {
        color: ${theme.accent};
      }

      #network.ethernet {
        color: ${theme.accent2};  /* Secondary accent for wired to distinguish */
      }

      #network.linked {
        color: ${theme.red};  /* Red for linked but no internet */
      }

      #network.disconnected,
      #network.disabled {
        color: ${theme.base03};
        background: ${theme.bg_dark};
      }

      #bluetooth {
        background: rgba(${theme.bg_dark_rgb}, ${theme.waybar.module_bg_opacity});
        color: ${theme.accent};
        border-radius: 0.5em;
        padding: 0 0.6em;
        margin: 0 0.15em;  /* No top/bottom margins */
      }

      #bluetooth.off,
      #bluetooth.disabled {
        color: ${theme.base03};
        background: ${theme.bg_dark};
      }

      #bluetooth.connected {
        color: ${theme.green};
      }

      #pulseaudio {
        background: rgba(${theme.bg_dark_rgb}, ${theme.waybar.module_bg_opacity});
        color: ${theme.accent};
        border-radius: 0.5em;
        padding: 0 0.6em;
        margin: 0 0.15em;  /* No top/bottom margins */
      }

      #pulseaudio.muted {
        color: ${theme.base03};
      }

      box#resources {
        background: rgba(${theme.bg_dark_rgb}, ${theme.waybar.module_bg_opacity});
        border-radius: 0.5em;
        margin: 0 0.15em;  /* No top/bottom margins */
        padding: 0 0.3em;
      }

      #cpu {
        color: ${theme.accent};
        padding: 0 0.2em;
        background: transparent;
      }

      #memory {
        color: ${theme.accent};
        padding: 0 0.6em;
        background: transparent;
      }

      #temperature {
        color: ${theme.accent};
        padding: 0 0.4em;
        background: transparent;
      }

      #temperature.critical {
        color: ${theme.red};  /* Red for critical temperature */
      }

      #custom-power {
        background: rgba(${theme.bg_dark_rgb}, ${theme.waybar.module_bg_opacity});
        color: ${theme.accent};
        border-radius: 0.5em;
        padding: 0 0.6em;
        margin: 0 0.15em;  /* No top/bottom margins */
        margin-right: 0.5em;
      }

      /* Group drawer styling - matching dotfiles approach */
      /* The drawer transition is handled by waybar internally */
      /* We just style the modules consistently */

    '';
  };
}
