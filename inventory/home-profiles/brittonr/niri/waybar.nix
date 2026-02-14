{
  inputs,
  pkgs,
  config,
  ...
}:
let
  theme = config.theme.colors;

  # Define wrapped fuzzel so we can reference it in waybar on-click actions
  wrappedFuzzel =
    (inputs.wrappers.wrapperModules.fuzzel.apply {
      inherit pkgs;

      settings = {
        main = {
          terminal = config.apps.terminal.command;
          layer = "overlay";
          width = 50;
          horizontal-pad = 20;
          vertical-pad = 10;
          inner-pad = 10;
        };

        colors = {
          background = "${builtins.substring 1 6 theme.bg}ff";
          text = "${builtins.substring 1 6 theme.fg}ff";
          match = "${builtins.substring 1 6 theme.accent}ff";
          selection = "${builtins.substring 1 6 theme.accent}ff";
          selection-text = "${builtins.substring 1 6 theme.bg}ff";
          border = "${builtins.substring 1 6 theme.accent}ff";
        };

        border = {
          width = config.layout.borderWidth;
          radius = config.layout.borderRadius;
        };
      };
    }).wrapper;

  wrappedWaybar =
    (inputs.wrappers.wrapperModules.waybar.apply {
      inherit pkgs;

      settings = {
        layer = "top";
        position = "top";
        inherit (config.bar) height spacing;

        modules-left = [
          "niri/workspaces"
          "niri/window"
          "custom/kitty"
          "custom/launcher"
          "custom/nixos"
        ];
        modules-center = [ "clock" ];
        modules-right = [
          "custom/media-prev"
          "mpris"
          "custom/media-next"
          "pulseaudio"
          "network"
          "disk"
          "cpu"
          "temperature"
          "memory"
          "battery"
        ];

        "niri/workspaces" = {
          format = "{name}";
        };

        "niri/window" = {
          format = "{}";
          max-length = 50;
        };

        clock = {
          format = "{:%Y-%m-%d %H:%M}";
          tooltip-format = "<tt><small>{calendar}</small></tt>";
          calendar = {
            mode = "month";
            on-scroll = 1;
            format = {
              months = "<span color='${config.bar.calendar.months}'><b>{}</b></span>";
              days = "<span color='${config.bar.calendar.days}'><b>{}</b></span>";
              weeks = "<span color='${config.bar.calendar.weeks}'><b>W{}</b></span>";
              weekdays = "<span color='${config.bar.calendar.weekdays}'><b>{}</b></span>";
              today = "<span color='${config.bar.calendar.today}'><b><u>{}</u></b></span>";
            };
          };
        };

        cpu = {
          format = "CPU {usage}%";
          tooltip = false;
        };

        temperature = {
          interval = 2;
          format = "TEMP {temperatureC}°C";
          hwmon-path-abs = [
            "/sys/devices/pci0000:00/0000:00:18.3/hwmon" # AMD k10temp
            "/sys/devices/platform/coretemp.0/hwmon" # Intel coretemp
          ];
          input-filename = "temp1_input";
          critical-threshold = 80;
          format-critical = "TEMP {temperatureC}°C!";
          tooltip = true;
          tooltip-format = "CPU Temperature: {temperatureC}°C";
        };

        memory = {
          format = "MEM {}%";
        };

        disk = {
          path = "/";
          format = "DISK {percentage_used}%";
          tooltip-format = "{used} / {total} ({free} free)";
        };

        battery = {
          states = {
            warning = 30;
            critical = 15;
          };
          format = "BAT {capacity}%";
          format-charging = "CHG {capacity}%";
          format-plugged = "PLUG {capacity}%";
        };

        network = {
          format-wifi = "WIFI {essid}";
          format-ethernet = "ETH {ipaddr}";
          format-disconnected = "DISCONN";
          tooltip-format = "{ifname} via {gwaddr}";
        };

        pulseaudio = {
          format = "VOL {volume}%";
          format-muted = "MUTE";
          on-click = "pavucontrol";
        };

        mpris = {
          format = "{player_icon} {artist} - {title}";
          format-paused = "{player_icon} {artist} - {title}";
          player-icons = {
            default = "";
            spotify = "";
            librewolf = "";
            chromium = "";
            mpv = "";
          };
          max-length = 40;
          on-click = "${pkgs.playerctl}/bin/playerctl play-pause";
        };

        "custom/media-prev" = {
          format = "&lt;&lt;";
          tooltip = true;
          tooltip-format = "Previous Track";
          on-click = "${pkgs.playerctl}/bin/playerctl previous";
        };

        "custom/media-next" = {
          format = "&gt;&gt;";
          tooltip = true;
          tooltip-format = "Next Track";
          on-click = "${pkgs.playerctl}/bin/playerctl next";
        };

        "custom/kitty" = {
          format = "";
          tooltip = true;
          tooltip-format = "Launch Terminal";
          on-click = config.apps.terminal.command;
        };

        "custom/launcher" = {
          format = "";
          tooltip = true;
          tooltip-format = "Application Launcher";
          on-click = "${wrappedFuzzel}/bin/fuzzel";
        };

        "custom/nixos" = {
          format = "";
          tooltip = true;
          tooltip-format = "NixOS Generations";
          on-click = "fuzzel-generations";
        };
      };

      "style.css" = {
        content = ''
          * {
              border: none;
              border-radius: 0;
              font-family: "${config.font.ui}";
              font-size: 13px;
          }

          window#waybar {
              background-color: ${theme.bg};
              color: ${theme.fg};
          }

          #workspaces button {
              padding: 0 8px;
              color: ${theme.fg_dim};
              background-color: transparent;
          }

          #workspaces button.active {
              background-color: ${theme.bg_highlight};
              color: ${theme.accent};
              border-bottom: 2px solid ${theme.accent};
          }

          #workspaces button.urgent {
              background-color: ${theme.red};
              color: ${theme.fg};
          }

          #window,
          #clock,
          #cpu,
          #temperature,
          #memory,
          #disk,
          #battery,
          #network,
          #pulseaudio,
          #mpris,
          #custom-kitty,
          #custom-launcher,
          #custom-nixos,
          #custom-media-prev,
          #custom-media-next {
              padding: 0 10px;
          }

          #temperature.critical {
              color: ${theme.red};
              font-weight: bold;
          }

          #custom-kitty,
          #custom-launcher,
          #custom-nixos {
              color: ${theme.accent};
              font-size: 16px;
          }

          #custom-kitty:hover,
          #custom-launcher:hover,
          #custom-nixos:hover {
              background-color: ${theme.bg_highlight};
              color: ${theme.fg};
          }

          #mpris {
              color: ${theme.green};
          }

          #mpris.paused {
              color: ${theme.fg_dim};
          }

          #custom-media-prev,
          #custom-media-next {
              color: ${theme.accent};
              font-size: 14px;
              padding: 0 5px;
          }

          #custom-media-prev:hover,
          #custom-media-next:hover {
              background-color: ${theme.bg_highlight};
              color: ${theme.fg};
          }

          #battery.warning {
              color: ${theme.yellow};
          }

          #battery.critical {
              color: ${theme.red};
              font-weight: bold;
          }
        '';
      };
    }).wrapper;
in
{
  home.packages = [ wrappedWaybar ];

  # Export the wrapped waybar for use by other modules
  home.sessionVariables.WRAPPED_WAYBAR = "${wrappedWaybar}/bin/waybar";
}
