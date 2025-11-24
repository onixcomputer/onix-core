{
  inputs,
  pkgs,
  lib,
  config,
  ...
}:
let
  # Access the current theme colors
  theme = config.theme.colors;
  # Define wrapped fuzzel locally so we can reference it in the config
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
          background = "${builtins.substring 1 6 theme.bg}ff";
          text = "${builtins.substring 1 6 theme.fg}ff";
          match = "${builtins.substring 1 6 theme.accent}ff";
          selection = "${builtins.substring 1 6 theme.accent}ff";
          selection-text = "${builtins.substring 1 6 theme.bg}ff";
          border = "${builtins.substring 1 6 theme.accent}ff";
        };

        border = {
          width = 2;
          radius = 0;
        };
      };
    }).wrapper;

  # Define wrapped waybar locally so we can reference it in the config
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
        ];
        modules-center = [ "clock" ];
        modules-right = [
          "custom/theme-mode"
          "pulseaudio"
          "network"
          "cpu"
          "memory"
          "battery"
          "tray"
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

        tray = {
          spacing = 10;
        };

        "custom/theme-mode" = {
          exec = pkgs.writeShellScript "waybar-theme-mode" ''
            # Output current theme and darkman status
            output_theme() {
              scheme=$(${pkgs.dconf}/bin/dconf read /org/gnome/desktop/interface/color-scheme)

              # Check if darkman is running
              darkman_active="false"
              if ${pkgs.systemd}/bin/systemctl --user is-active --quiet darkman.service 2>/dev/null; then
                darkman_active="true"
                darkman_mode=$(${pkgs.darkman}/bin/darkman get 2>/dev/null || echo "unknown")
              fi

              # Build tooltip with darkman info
              if [[ "$darkman_active" == "true" ]]; then
                tooltip_suffix=" | Darkman: $darkman_mode"
              else
                tooltip_suffix=""
              fi

              case "$scheme" in
                "'prefer-dark'")
                  echo "{\"text\": \"DARK\", \"tooltip\": \"Dark Mode (Mod+T)$tooltip_suffix\", \"class\": \"dark\"}"
                  ;;
                "'prefer-light'")
                  echo "{\"text\": \"LIGHT\", \"tooltip\": \"Light Mode (Mod+T)$tooltip_suffix\", \"class\": \"light\"}"
                  ;;
                *)
                  echo "{\"text\": \"AUTO\", \"tooltip\": \"Auto Mode (Mod+T)$tooltip_suffix\", \"class\": \"auto\"}"
                  ;;
              esac
            }

            # Output initial state
            output_theme

            # Monitor dconf for changes and output updated theme
            ${pkgs.dconf}/bin/dconf watch /org/gnome/desktop/interface/color-scheme | while read -r line; do
              output_theme
            done
          '';
          return-type = "json";
          format = "{}";
          on-click = "toggle-theme-mode";
          on-click-right = "fuzzel-darkman";
          tooltip = true;
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
              background-color: ${theme.bg};
              color: ${theme.fg_dim};
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
          #memory,
          #battery,
          #network,
          #pulseaudio,
          #tray,
          #custom-theme-mode {
              padding: 0 10px;
          }

          #custom-theme-mode {
              color: ${theme.fg_dim};
          }

          #custom-theme-mode:hover {
              background-color: ${theme.bg_highlight};
              color: ${theme.fg};
          }

          #custom-theme-mode.light {
              color: ${theme.accent};
          }

          #custom-theme-mode.dark {
              color: ${theme.accent};
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

  # Define wrapped niri package with custom config
  wrappedNiri =
    (inputs.wrappers-niri.wrapperModules.niri.apply {
      inherit pkgs;

      "config.kdl" = {
        content = /* kdl */ ''
                          // Niri configuration matching Hyprland keybindings
                          // See: https://github.com/YaLTeR/niri/wiki/Configuration:-Overview

                          input {
                              keyboard {
                                  xkb {
                                      layout "us"
                                  }
                              }

                              touchpad {
                                  tap
                                  natural-scroll
                              }

                              focus-follows-mouse
                              warp-mouse-to-focus
                          }

                          output "eDP-1" {
                              mode "2560x1600@144"
                              scale 2.0
                              variable-refresh-rate
                          }
                          

                          prefer-no-csd

                          layout {
                              empty-workspace-above-first
                              gaps 8
                              center-focused-column "never"
                              preset-column-widths {
                                  proportion 0.33333
                                  proportion 0.5
                                  proportion 0.66667
                              }

                              focus-ring {
                                  active-color "${theme.accent}"
                                  inactive-color "${theme.border}"
                                  width 1
                              }

                              border {
                                  width 2
                                  active-color "${theme.accent}"
                                  inactive-color "${theme.border}"
                              }
                          }

                          spawn-at-startup "${wrappedWaybar}/bin/waybar"
                          spawn-at-startup "${pkgs.dunst}/bin/dunst"
                          spawn-at-startup "sh" "-c" "${pkgs.swww}/bin/swww-daemon && restore-wallpaper"
                          spawn-at-startup "${pkgs.wl-clipboard}/bin/wl-paste" "--watch" "${pkgs.cliphist}/bin/cliphist" "store"
                          spawn-at-startup "${pkgs.swayosd}/bin/swayosd-server"
                          spawn-at-startup "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
                          spawn-at-startup "${pkgs.networkmanagerapplet}/bin/nm-applet"
                          spawn-at-startup "${pkgs.blueman}/bin/blueman-applet"
                          spawn-at-startup "vesktop" "--enable-features=UseOzonePlatform" "--ozone-platform=wayland" "--enable-wayland-ime" "--disable-gpu-sandbox"
                          spawn-at-startup "element-desktop"
                          spawn-at-startup "kitty" "--title" "btop" "-e" "btop"
                          spawn-at-startup "kitty" "--title" "journalctl" "-e" "journalctl -f"
                          window-rule {
              match app-id=r#"firefox$"#

              open-on-workspace "web"
              open-maximized true
          }
          window-rule {
              match app-id="firefox$" title="^Picture-in-Picture$"

              open-floating true
          }
                          window-rule {
              match app-id=r#"kitty$"#

              open-on-workspace "term"

          }
          window-rule {
              match app-id=r#"vesktop$"#

              open-on-workspace "chat"
          }

          window-rule {
              match app-id=r#"Element$"#

              open-on-workspace "chat"
          }

          window-rule {
              match app-id=r#"kitty$"# title="^btop$"

              open-on-workspace "status"
              open-maximized true
          }
          window-rule {
              match app-id=r#"kitty$"# title="^journalctl$"

              open-on-workspace "status"
              open-maximized true
          }

          window-rule {
              match app-id=r#"kitty$"# title="^yazi$"
          }

          // Indicate screencasted windows with red colors.
          window-rule {
              match is-window-cast-target=true

              focus-ring {
                  active-color "#f38ba8"
                  inactive-color "#7d0d2d"
              }

              border {
                  inactive-color "#7d0d2d"
              }

              shadow {
                  color "#7d0d2d70"
              }

              tab-indicator {
                  active-color "#f38ba8"
                  inactive-color "#7d0d2d"
              }
          }
          workspace "term" {
          }
          workspace "web" {
          }

          workspace "chat" {
          }

          workspace "status" {
          }

          workspace "hidden" {
          }

          xwayland-satellite {
              // off
              path "xwayland-satellite"
          }

                          binds {
                              Mod+Shift+Slash { show-hotkey-overlay; }

                              // Window management
                              Mod+Q { close-window; }
                              Mod+W { toggle-column-tabbed-display; }
                              Mod+Shift+I { fullscreen-window; }
                              Alt+F { toggle-window-floating; }
                              Mod+Shift+R { spawn "niri" "msg" "action" "load-config-file"; }

                              // Vim bindings for focus
                              Mod+H { focus-column-left; }
                              Mod+L { focus-column-right; }
                              Mod+K { focus-workspace-up; }
                              Mod+J { focus-workspace-down; }

                              // Arrow keys for compatibility
                              Mod+Left { focus-column-left; }
                              Mod+Right { focus-column-right; }
                              Mod+Up { focus-window-up; }
                              Mod+Down { focus-window-down; }

                              // Alt+J/K for moving between tabs/windows
                              Alt+K { focus-window-up; }
                              Alt+J { focus-window-down; }

                              // Arrow keys for moving windows
                              Mod+Control+Left { move-column-left; }
                              Mod+Control+Right { move-column-right; }
                              Mod+Control+Up { move-window-up; }
                              Mod+Control+Down { move-window-down; }

                              // Column operations - consume/expel windows
                              Mod+BracketLeft { consume-window-into-column; }
                              Mod+BracketRight { expel-window-from-column; }

                              // Resizing
                              Mod+Minus { set-column-width "-10%"; }
                              Mod+Equal { set-column-width "+10%"; }

                              // Vim bindings for resizing
                              Mod+Shift+H { set-column-width "-10%"; }
                              Mod+Shift+L { set-column-width "+10%"; }
                              Mod+Shift+J { set-window-height "+10%"; }
                              Mod+Shift+K { set-window-height "-10%"; }

                              // Workspaces (1-10)
                              Mod+1 { focus-workspace 1; }
                              Mod+2 { focus-workspace 2; }
                              Mod+3 { focus-workspace 3; }
                              Mod+4 { focus-workspace 4; }
                              Mod+5 { focus-workspace 5; }
                              Mod+6 { focus-workspace 6; }
                              Mod+7 { focus-workspace 7; }
                              Mod+8 { focus-workspace 8; }
                              Mod+9 { focus-workspace 9; }
                              Mod+0 { focus-workspace 10; }

                              Mod+Shift+1 { move-column-to-workspace 1; }
                              Mod+Shift+2 { move-column-to-workspace 2; }
                              Mod+Shift+3 { move-column-to-workspace 3; }
                              Mod+Shift+4 { move-column-to-workspace 4; }
                              Mod+Shift+5 { move-column-to-workspace 5; }
                              Mod+Shift+6 { move-column-to-workspace 6; }
                              Mod+Shift+7 { move-column-to-workspace 7; }
                              Mod+Shift+8 { move-column-to-workspace 8; }
                              Mod+Shift+9 { move-column-to-workspace 9; }
                              Mod+Shift+0 { move-column-to-workspace 10; }

                              // Applications
                              Mod+Return { spawn "kitty"; }
                              Mod+Shift+Return { spawn "sh" "-c" "cd $(${pkgs.xcwd}/bin/xcwd) && kitty --title float"; }
                              Mod+F { spawn "sh" "-c" "cd $(${pkgs.xcwd}/bin/xcwd) && kitty --title yazi -e yazi"; }
                              Mod+B { spawn "firefox"; }
                              Mod+S { spawn "kitty" "--title" "btop" "-e" "btop"; }
                              Mod+R { spawn "${wrappedFuzzel}/bin/fuzzel"; }
                              Mod+Space { spawn "${wrappedFuzzel}/bin/fuzzel"; }
                              Mod+C { spawn "sh" "-c" "${pkgs.cliphist}/bin/cliphist list | ${wrappedFuzzel}/bin/fuzzel --dmenu | ${pkgs.cliphist}/bin/cliphist decode | ${pkgs.wl-clipboard}/bin/wl-copy"; }
                              Mod+Shift+C { spawn "sh" "-c" "${pkgs.cliphist}/bin/cliphist list | ${wrappedFuzzel}/bin/fuzzel --dmenu | ${pkgs.cliphist}/bin/cliphist delete"; }
                              Mod+N { spawn "sh" "-c" "notify-send -t 1000 'WiFi 󰤨' 'Scanning networks...' && fuzzel-network-menu"; }
                              Mod+G { spawn "fuzzel-generations"; }
                              Mod+T { spawn "toggle-theme-mode"; }
                              Mod+Shift+T { spawn "fuzzel-theme-mode"; }
                              Mod+D { spawn "fuzzel-darkman"; }

                              // Screenshots
                              Print { spawn "sh" "-c" "grim ~/Screenshots/$(date +'screenshot_%Y-%m-%d_%H-%M-%S.png') && notify-send 'Screenshot' 'Saved to ~/Screenshots' -i camera-photo"; }
                              Mod+Shift+S { spawn "screenshot-wrapper" "-m" "region" "-o" "~/Screenshots"; }

                              // Notifications
                              Mod+Comma { spawn "dunstctl" "close"; }
                              Mod+Shift+Comma { spawn "dunstctl" "close-all"; }

                              // Media controls
                              XF86AudioRaiseVolume { spawn "swayosd-client" "--output-volume" "raise"; }
                              XF86AudioLowerVolume { spawn "swayosd-client" "--output-volume" "lower"; }
                              XF86AudioMute { spawn "swayosd-client" "--output-volume" "mute-toggle"; }
                              XF86AudioMicMute { spawn "swayosd-client" "--input-volume" "mute-toggle"; }
                              XF86AudioNext { spawn "playerctl" "next"; }
                              XF86AudioPause { spawn "playerctl" "play-pause"; }
                              XF86AudioPlay { spawn "playerctl" "play-pause"; }
                              XF86AudioPrev { spawn "playerctl" "previous"; }
                          }
        '';
      };
    }).wrapper;
in
{
  home.packages = [
    pkgs.xwayland-satellite
    wrappedNiri
    # Portals for cross-desktop functionality (file pickers, screencasting, etc.)
    pkgs.xdg-desktop-portal-gtk
    pkgs.xdg-desktop-portal-gnome
    # Authentication agent, network, bluetooth (launched at startup)
    pkgs.polkit_gnome
    pkgs.networkmanagerapplet
    pkgs.blueman
    # File manager for portal file chooser (can be removed if using GTK portal)
    pkgs.nautilus
    # Auto-rotation daemon for tablet/convertible devices
    pkgs.rot8
  ];

  # Override the niri systemd service to use the wrapped binary
  systemd.user.services.niri = {
    Unit = {
      Description = "A scrollable-tiling Wayland compositor";
      BindsTo = "graphical-session.target";
      Before = "graphical-session.target";
      Wants = [
        "graphical-session-pre.target"
        "xdg-desktop-autostart.target"
      ];
      After = "graphical-session-pre.target";
      # Prevent restarting the service on configuration changes
      X-RestartIfChanged = false;
      X-StopIfChanged = false;
    };
    Service = {
      Slice = "session.slice";
      Type = "notify";
      ExecStart = "${wrappedNiri}/bin/niri --session";
    };
  };

  # Enable gnome-keyring service
  services.gnome-keyring = {
    enable = true;
    components = [ "secrets" ];
  };

  # Enable portals for file pickers, screencasting, etc.
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-gnome
    ];
    config = {
      common = {
        default = [ "gtk" ];
        "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
      };
      niri = {
        default = [
          "gnome"
          "gtk"
        ];
        "org.freedesktop.impl.portal.Screenshot" = [ "gnome" ];
        "org.freedesktop.impl.portal.ScreenCast" = [ "gnome" ];
      };
    };
  };

  # Set GNOME preferences for portal UI settings
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = lib.mkDefault "prefer-dark";
    };
  };

  # Configure rot8 for automatic screen rotation
  # Create rotation hook script for rot8
  # GPD Pocket 4 rotations mapped to match device orientation (270° default)
  home.file.".local/bin/rot8-niri-hook" = {
    text = ''
      #!/bin/sh
      # Log to file for debugging
      LOG="$HOME/.local/share/rot8-debug.log"
      mkdir -p "$(dirname "$LOG")"
      echo "$(date '+%Y-%m-%d %H:%M:%S') - Orientation: $ORIENTATION (prev: $PREV_ORIENTATION)" >> "$LOG"

      case "$ORIENTATION" in
        "normal")
          echo "  -> Applying transform 270" >> "$LOG"
          ${wrappedNiri}/bin/niri msg output eDP-1 transform 270
          ;;
        "90")
          echo "  -> Applying transform 180" >> "$LOG"
          ${wrappedNiri}/bin/niri msg output eDP-1 transform normal
          ;;
        "inverted")
          echo "  -> Applying transform 90" >> "$LOG"
          ${wrappedNiri}/bin/niri msg output eDP-1 transform 90
          ;;
        "270")
          echo "  -> Applying transform normal" >> "$LOG"
          ${wrappedNiri}/bin/niri msg output eDP-1 transform 180
          ;;
      esac
    '';
    executable = true;
  };

  # Automatically reload niri when configuration changes
  # home.activation.reloadNiri = lib.hm.dag.entryAfter ["writeBoundary"] ''
  #   # Validate niri configuration before applying
  #   echo "Validating niri configuration..."
  #   if ! $DRY_RUN_CMD ${wrappedNiri}/bin/niri validate --config ${wrappedNiri}/etc/niri/config.kdl; then
  #     echo "ERROR: Niri configuration validation failed!"
  #     echo "The configuration file at ${wrappedNiri}/etc/niri/config.kdl contains errors."
  #     echo "Please fix the configuration before rebuilding."
  #     exit 1
  #   fi
  #   echo "Niri configuration is valid"

  #   # Only reload if niri is running
  #   if ${pkgs.procps}/bin/pgrep -x niri > /dev/null; then
  #     $DRY_RUN_CMD ${wrappedNiri}/bin/niri msg action load-config-file || true
  #     echo "Niri configuration reloaded"
  #   fi
  # '';
}
