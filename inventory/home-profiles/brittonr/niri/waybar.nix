{ inputs, pkgs, ... }:
let
  # Define wrapped fuzzel so we can reference it in waybar on-click actions
  wrappedFuzzel =
    (inputs.wrappers-niri.wrapperModules.fuzzel.apply {
      inherit pkgs;

      settings = {
        main = {
          terminal = "${pkgs.kitty}/bin/kitty";
          layer = "overlay";
          width = 50;
          horizontal-pad = 20;
          vertical-pad = 10;
          inner-pad = 10;
        };

        colors = {
          background = "1a1a1aff";
          text = "ffffffff";
          match = "ff6600ff";
          selection = "ff6600ff";
          selection-text = "000000ff";
          border = "ff6600ff";
        };

        border = {
          width = 2;
          radius = 0;
        };
      };
    }).wrapper;

  wrappedWaybar =
    (inputs.wrappers-waybar.wrapperModules.waybar.apply {
      inherit pkgs;

      settings = {
        layer = "top";
        position = "top";
        height = 30;
        spacing = 4;

        modules-left = [
          "niri/workspaces"
          "niri/window"
          "custom/kitty"
          "custom/launcher"
          "custom/nixos"
        ];
        modules-center = [ "clock" ];
        modules-right = [
          "pulseaudio"
          "network"
          "cpu"
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
              months = "<span color='#ffead3'><b>{}</b></span>";
              days = "<span color='#ecc6d9'><b>{}</b></span>";
              weeks = "<span color='#99ffdd'><b>W{}</b></span>";
              weekdays = "<span color='#ffcc66'><b>{}</b></span>";
              today = "<span color='#ff6699'><b><u>{}</u></b></span>";
            };
          };
        };

        cpu = {
          format = "CPU {usage}%";
          tooltip = false;
        };

        memory = {
          format = "MEM {}%";
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

        "custom/kitty" = {
          format = "";
          tooltip = true;
          tooltip-format = "Launch Terminal";
          on-click = "${pkgs.kitty}/bin/kitty";
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

      style = {
        content = ''
          * {
              border: none;
              border-radius: 0;
              font-family: monospace;
              font-size: 13px;
          }

          window#waybar {
              background-color: #1a1a1a;
              color: #ffffff;
          }

          #workspaces button {
              padding: 0 8px;
              color: #ffffff;
              background-color: transparent;
          }

          #workspaces button.active {
              background-color: #ff6600;
              color: #000000;
          }

          #workspaces button.urgent {
              background-color: #ff3300;
              color: #ffffff;
          }

          #window,
          #clock,
          #cpu,
          #memory,
          #battery,
          #network,
          #pulseaudio,
          #custom-kitty,
          #custom-launcher,
          #custom-nixos {
              padding: 0 10px;
          }

          #custom-kitty,
          #custom-launcher,
          #custom-nixos {
              color: #ff6600;
              font-size: 16px;
          }

          #custom-kitty:hover,
          #custom-launcher:hover,
          #custom-nixos:hover {
              background-color: #ff6600;
              color: #000000;
          }

          #battery.warning {
              color: #ff6600;
          }

          #battery.critical {
              color: #ff3300;
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
