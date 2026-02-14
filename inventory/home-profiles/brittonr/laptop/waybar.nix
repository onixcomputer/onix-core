{ config, ... }:
let
  wc = config.bar.waybar.colors;
  cal = config.bar.calendar;
in
{
  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        inherit (config.bar) height;
        spacing = 0;
        margin = "0";

        modules-left = [ "hyprland/workspaces" ];
        modules-center = [ "clock" ];
        modules-right = [
          "tray"
          "pulseaudio"
          "group/resources"
          "battery"
        ];

        "group/resources" = {
          orientation = "horizontal";
          modules = [
            "cpu"
            "memory"
            "temperature"
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
            inherit (config.icons.workspace) active default;
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
          interval = config.timing.polling.fast;
          format = "{:%I:%M %p}";
          format-alt = "{:%A, %B %d, %Y}";
          tooltip-format = "<tt><small>{calendar}</small></tt>";
          calendar = {
            mode = "year";
            mode-mon-col = 3;
            weeks-pos = "right";
            on-scroll = 1;
            format = {
              months = "<span color='${cal.months}'><b>{}</b></span>";
              days = "<span color='${cal.days}'><b>{}</b></span>";
              weeks = "<span color='${cal.weeks}'><b>W{}</b></span>";
              weekdays = "<span color='${cal.weekdays}'><b>{}</b></span>";
              today = "<span color='${cal.today}'><b><u>{}</u></b></span>";
            };
          };
        };

        cpu = {
          interval = config.timing.polling.fast;
          format = "${config.icons.system.cpu} {usage:02}%";
          tooltip = true;
          on-click = "alacritty -e btop";
        };

        memory = {
          interval = config.timing.polling.fast;
          format = "${config.icons.system.memory} {used:0.1f}G/{total:0.1f}G";
          tooltip-format = "Memory: {percentage}%\nUsed: {used:0.2f}GB\nTotal: {total:0.2f}GB";
          on-click = "alacritty -e btop";
        };

        temperature = {
          interval = config.timing.polling.fast;
          format = "${config.icons.system.temperature} {temperatureC}°C";
          thermal-zone = 0;
          critical-threshold = config.power.temperature.critical;
          format-critical = "${config.icons.system.temperatureCritical} {temperatureC}°C";
          tooltip-format = "CPU Temperature: {temperatureC}°C / {temperatureF}°F";
          on-click = "alacritty -e btop";
        };

        battery = {
          interval = config.timing.polling.fast;
          states = {
            inherit (config.power.battery) warning critical;
          };
          format = "{icon} {capacity}%";
          format-charging = "${config.icons.battery.charging} {capacity}%";
          format-plugged = "${config.icons.battery.plugged} {capacity}%";
          format-icons = config.icons.battery.levels;
        };

        pulseaudio = {
          format = "{icon} {volume}%";
          format-muted = config.icons.audio.muted;
          format-icons = {
            default = config.icons.audio.levels;
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
      };
    };

    style = ''
      * {
        border: none;
        border-radius: 0;
        font-family: "${config.font.ui}";
        font-size: ${toString config.font.size.bar}px;
        min-height: 0;
      }

      window#waybar {
        background: transparent;
        color: ${wc.fg};
      }

      tooltip {
        background: ${wc.tooltip_bg};
        border-radius: ${config.css.borderRadius.md};
        border-width: 2px;
        border-style: solid;
        border-color: ${wc.bg};
        padding: ${config.css.padding.md};
      }

      tooltip label {
        color: ${wc.fg};
        font-size: ${config.css.fontSizeEm.small};
      }

      #workspaces {
        background: ${wc.bg};
        border-radius: ${config.css.borderRadius.lg};
        margin: ${config.css.padding.sm};
        margin-left: ${config.css.padding.xl};
        padding: ${config.css.padding.xs};
      }

      #workspaces button {
        padding: 0 ${config.css.padding.md};
        margin: 0 ${config.css.marginEm.tiny};
        border-radius: ${config.css.borderRadius.md};
        color: ${wc.accent};
        background: transparent;
        transition: all ${config.css.transition.fast} ${config.css.transition.easing};
      }

      #workspaces button:first-child {
        margin-left: 0;
      }

      #workspaces button:last-child {
        margin-right: 0;
      }

      #workspaces button.active {
        background: ${wc.accent};
        color: ${wc.bg};
        border-radius: ${config.css.borderRadius.md};
        transition: all ${config.css.transition.fast} ${config.css.transition.easing};
        font-size: ${config.css.fontSizeEm.xlarge};
        padding: ${config.bar.waybar.modulePadding};
        margin: ${config.bar.waybar.moduleMargin};
      }

      #workspaces button:hover {
        background: ${wc.accent};
        color: ${wc.bg};
        border-radius: ${config.css.borderRadius.md};
        transition: all ${config.css.transition.fast} ${config.css.transition.easing};
      }

      #clock {
        color: ${wc.accent};
        background: ${wc.bg};
        border-radius: ${config.css.borderRadius.lg};
        margin: ${config.css.padding.sm};
        padding: 0 ${config.css.padding.xl};
      }

      .modules-right {
        margin-right: ${config.css.padding.xl};
      }

      #tray {
        background: ${wc.bg};
        border-radius: ${config.css.borderRadius.lg};
        padding: ${config.css.padding.sm} ${config.css.padding.lg};
        margin: ${config.css.padding.sm} ${config.css.padding.xs};
      }

      #tray > .passive {
        -gtk-icon-effect: dim;
      }

      #tray > .needs-attention {
        -gtk-icon-effect: highlight;
      }

      #pulseaudio {
        background: ${wc.bg};
        color: ${wc.accent};
        border-radius: ${config.css.borderRadius.lg};
        padding: 0 ${config.css.padding.xl};
        margin: ${config.css.padding.sm} ${config.css.padding.xs};
      }

      #pulseaudio.muted {
        color: ${wc.muted};
      }

      box#resources {
        background: ${wc.bg};
        border-radius: ${config.css.borderRadius.lg};
        margin: ${config.css.padding.sm} ${config.css.padding.xs};
        padding: 0 ${config.css.paddingEm.sm};
      }

      #cpu {
        color: ${wc.accent};
        padding: 0 ${config.css.padding.xs};
        background: transparent;
      }

      #memory {
        color: ${wc.accent};
        padding: 0 ${config.css.padding.lg};
        background: transparent;
      }

      #temperature {
        color: ${wc.accent};
        padding: 0 ${config.css.paddingEm.sm};
        background: transparent;
      }

      #temperature.critical {
        color: ${config.colors.term_red};
      }

      #battery {
        background: ${wc.bg};
        color: ${wc.accent};
        border-radius: ${config.css.borderRadius.lg};
        padding: 0 ${config.css.padding.xl};
        margin: ${config.css.padding.sm} ${config.css.padding.xs};
      }

      #battery.charging, #battery.plugged {
        color: ${wc.charging};
      }

      #battery.warning {
        color: ${wc.warning};
      }

      #battery.critical {
        background-color: ${wc.critical};
        color: ${wc.critical_bg};
        animation: blink ${config.bar.waybar.blinkDuration} linear infinite alternate;
      }

      @keyframes blink {
        to {
          background-color: ${wc.critical_bg};
          color: ${wc.critical};
        }
      }

    '';
  };
}
