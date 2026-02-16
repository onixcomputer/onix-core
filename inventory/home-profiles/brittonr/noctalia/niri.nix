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
  # Access the shared keymap
  k = config.keymap;
  up = lib.toUpper;
  mon = config.monitors;

  # Noctalia IPC helper - all shell IPC calls go through qs
  ipc = target: action: ''"qs" "-c" "noctalia-shell" "ipc" "call" "${target}" "${action}"'';

  # Define wrapped niri package with custom config
  wrappedNiri =
    (inputs.wrappers.wrapperModules.niri.apply {
      inherit pkgs;

      "config.kdl" = {
        content = /* kdl */ ''
                          // Niri configuration with Noctalia Shell integration
                          // Noctalia provides: bar, notifications, launcher, OSD, wallpaper, lock screen

                          input {
                              keyboard {
                                  xkb {
                                      layout "${config.input.keyboard.layout}"
                                  }
                              }

                              touchpad {
                                  ${if config.input.touchpad.tap then "tap" else ""}
                                  ${if config.input.touchpad.naturalScroll then "natural-scroll" else ""}
                                  ${
                                    if config.input.touchpad.disableWhileTyping then
                                      ''
                                        dwt  // disable while typing
                                        dwtp // disable while trackpointing''
                                    else
                                      ""
                                  }
                                  drag true
                                  drag-lock
                                  click-method "${config.input.touchpad.clickMethod}"
                                  scroll-method "${config.input.touchpad.scrollMethod}"
                                  accel-speed ${toString config.input.touchpad.accelSpeed}
                                  accel-profile "${config.input.touchpad.accelProfile}"
                              }

                              // Touchscreen settings for GPD Pocket 4
                              touch {
                                  map-to-output "${mon.builtin.name}"
                              }

                              // Tablet/stylus settings (if applicable)
                              tablet {
                                  map-to-output "${mon.builtin.name}"
                              }

                              ${if config.input.mouse.focusFollows then "focus-follows-mouse" else ""}
                              ${if config.input.mouse.warpToFocus then "warp-mouse-to-focus" else ""}
                          }

                          // Gesture configuration for touchpad and touchscreen
                          gestures {
                              // Scroll the view when dragging near monitor edges
                              dnd-edge-view-scroll {
                                  trigger-width ${toString config.gestures.dndEdgeScroll.triggerWidth}
                                  delay-ms ${toString config.gestures.dndEdgeScroll.delayMs}
                                  max-speed ${toString config.gestures.dndEdgeScroll.maxSpeed}
                              }

                              // Enable hot corner to toggle overview (top-left)
                              hot-corners {
                                  top-left
                              }
                          }

                          // Primary monitor (top) - LG ULTRAGEAR+
                          output "${mon.primary.name}" {
                              mode "${mon.primary.mode}"
                              scale ${toString mon.primary.scale}
                              position x=${toString mon.primary.position.x} y=${toString mon.primary.position.y}
                              ${if mon.primary.vrr then "variable-refresh-rate" else ""}
                          }

                          // Secondary monitor (below, centered) - Portable monitor via HDMI
                          output "${mon.secondary.name}" {
                              mode "${mon.secondary.mode}"
                              scale ${toString mon.secondary.scale}
                              position x=${toString mon.secondary.position.x} y=${toString mon.secondary.position.y}
                          }


                          prefer-no-csd

                          layout {
                              empty-workspace-above-first
                              gaps ${toString config.layout.gaps}
                              center-focused-column "never"
                              preset-column-widths {
                                  ${builtins.concatStringsSep "\n                                  " (
                                    map (w: "proportion ${toString w}") config.layout.presetColumnWidths
                                  )}
                              }

                              focus-ring {
                                  active-color "${theme.accent}"
                                  inactive-color "${theme.border}"
                                  width ${toString config.layout.focusRingWidth}
                              }

                              border {
                                  width ${toString config.layout.borderWidth}
                                  active-color "${theme.accent}"
                                  inactive-color "${theme.border}"
                              }
                          }

                          ${builtins.concatStringsSep "\n                          " (
                            map (name: "workspace \"${name}\"") config.workspaces.names
                          )}

                          // Startup services - Noctalia replaces waybar, swayosd, swww, mako
                          spawn-at-startup "noctalia-shell"
                          spawn-at-startup "${pkgs.wl-clipboard}/bin/wl-paste" "--watch" "${pkgs.cliphist}/bin/cliphist" "store"
                          spawn-at-startup "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
                          spawn-at-startup "${pkgs.networkmanagerapplet}/bin/nm-applet"
                          spawn-at-startup "${pkgs.blueman}/bin/blueman-applet"

                          // Startup applications
                          spawn-at-startup "vesktop" "--enable-features=UseOzonePlatform" "--ozone-platform=wayland" "--enable-wayland-ime" "--disable-gpu-sandbox"
                          spawn-at-startup "element-desktop"
                          spawn-at-startup "${config.apps.terminal.command}" "--title" "${config.apps.sysmon.name}" "-e" "${config.apps.sysmon.command}"
                          spawn-at-startup "${config.apps.terminal.command}" "--title" "journalctl" "-e" "journalctl -f"

                          // Window rules: workspace assignments
                          ${builtins.concatStringsSep "\n                          " (
                            map (rule: ''
                              window-rule {
                                  match app-id=r#"${rule.appId}$"#
                                  open-on-workspace "${rule.workspace}"
                                  ${if rule ? maximized && rule.maximized then "open-maximized true" else ""}
                              }'') config.windowRules.assignments
                          )}

                          // Window rules: title-specific overrides
                          ${builtins.concatStringsSep "\n                          " (
                            map (rule: ''
                              window-rule {
                                  match app-id=r#"${rule.appId}$"# title="${rule.title}"
                                  ${if rule ? workspace then ''open-on-workspace "${rule.workspace}"'' else ""}
                                  ${if rule ? maximized && rule.maximized then "open-maximized true" else ""}
                                  ${if rule ? floating && rule.floating then "open-floating true" else ""}
                              }'') config.windowRules.titleOverrides
                          )}

                          window-rule {
              match app-id=r#"${config.apps.terminal.appId}$"# title="^${config.apps.fileManager.name}$"
          }

          // Indicate screencasted windows with red colors.
          window-rule {
              match is-window-cast-target=true

              focus-ring {
                  active-color "${config.colors.screencast_active}"
                  inactive-color "${config.colors.screencast_inactive}"
              }

              border {
                  inactive-color "${config.colors.screencast_inactive}"
              }

              shadow {
                  color "${config.colors.screencast_inactive}${config.opacity.hex.low}"
              }

              tab-indicator {
                  active-color "${config.colors.screencast_active}"
                  inactive-color "${config.colors.screencast_inactive}"
              }
          }

          xwayland-satellite {
              // off
              path "xwayland-satellite"
          }

                          binds {
                              ${k.modifiers.wm}+Shift+Slash { show-hotkey-overlay; }

                              // Window management
                              ${k.modifiers.wm}+${k.wm.close} { close-window; }
                              ${k.modifiers.wm}+${k.wm.toggleTabs} { toggle-column-tabbed-display; }
                              ${k.modifiers.wm}+${k.wm.fullscreen} { fullscreen-window; }
                              ${k.modifiers.secondary}+F { toggle-window-floating; }
                              ${k.modifiers.wm}+${k.wm.reload} { spawn "niri" "msg" "action" "load-config-file"; }

                              // Vim bindings for focus
                              ${k.modifiers.wm}+${up k.nav.left} { focus-column-left; }
                              ${k.modifiers.wm}+${up k.nav.right} { focus-column-right; }
                              ${k.modifiers.wm}+${up k.nav.up} { focus-window-or-workspace-up; }
                              ${k.modifiers.wm}+${up k.nav.down} { focus-window-or-workspace-down; }

                              // Scroll wheel for workspace switching
                              ${k.modifiers.wm}+WheelScrollUp { focus-workspace-up; }
                              ${k.modifiers.wm}+WheelScrollDown { focus-workspace-down; }

                              // Arrow keys for compatibility
                              ${k.modifiers.wm}+Left { focus-column-left; }
                              ${k.modifiers.wm}+Right { focus-column-right; }
                              ${k.modifiers.wm}+Up { focus-window-up; }
                              ${k.modifiers.wm}+Down { focus-window-down; }

                              // Alt+HJKL for unified navigation (same as Mod layer)
                              ${k.modifiers.secondary}+${up k.nav.left} { focus-column-left; }
                              ${k.modifiers.secondary}+${up k.nav.right} { focus-column-right; }
                              ${k.modifiers.secondary}+${up k.nav.up} { focus-window-or-workspace-up; }
                              ${k.modifiers.secondary}+${up k.nav.down} { focus-window-or-workspace-down; }

                              // Vim bindings for moving windows/columns
                              ${k.modifiers.wm}+Control+${up k.nav.left} { move-column-left; }
                              ${k.modifiers.wm}+Control+${up k.nav.right} { move-column-right; }
                              ${k.modifiers.wm}+Control+${up k.nav.up} { move-window-up-or-to-workspace-up; }
                              ${k.modifiers.wm}+Control+${up k.nav.down} { move-window-down-or-to-workspace-down; }

                              // Arrow keys for moving windows
                              ${k.modifiers.wm}+Control+Left { move-column-left; }
                              ${k.modifiers.wm}+Control+Right { move-column-right; }
                              ${k.modifiers.wm}+Control+Up { move-window-up; }
                              ${k.modifiers.wm}+Control+Down { move-window-down; }

                              // Column operations - consume/expel windows
                              ${k.modifiers.wm}+BracketLeft { consume-window-into-column; }
                              ${k.modifiers.wm}+BracketRight { expel-window-from-column; }

                              // Resizing
                              ${k.modifiers.wm}+Minus { set-column-width "-${toString config.layout.resizePercent}%"; }
                              ${k.modifiers.wm}+Equal { set-column-width "+${toString config.layout.resizePercent}%"; }

                              // Vim bindings for resizing
                              ${k.modifiers.wm}+Shift+${up k.nav.left} { set-column-width "-${toString config.layout.resizePercent}%"; }
                              ${k.modifiers.wm}+Shift+${up k.nav.right} { set-column-width "+${toString config.layout.resizePercent}%"; }
                              ${k.modifiers.wm}+Shift+${up k.nav.down} { set-window-height "+${toString config.layout.resizePercent}%"; }
                              ${k.modifiers.wm}+Shift+${up k.nav.up} { set-window-height "-${toString config.layout.resizePercent}%"; }

                              // Workspaces (1-10)
                              ${k.modifiers.wm}+1 { focus-workspace 1; }
                              ${k.modifiers.wm}+2 { focus-workspace 2; }
                              ${k.modifiers.wm}+3 { focus-workspace 3; }
                              ${k.modifiers.wm}+4 { focus-workspace 4; }
                              ${k.modifiers.wm}+5 { focus-workspace 5; }
                              ${k.modifiers.wm}+6 { focus-workspace 6; }
                              ${k.modifiers.wm}+7 { focus-workspace 7; }
                              ${k.modifiers.wm}+8 { focus-workspace 8; }
                              ${k.modifiers.wm}+9 { focus-workspace 9; }
                              ${k.modifiers.wm}+0 { focus-workspace 10; }

                              ${k.modifiers.wm}+Shift+1 { move-column-to-workspace 1; }
                              ${k.modifiers.wm}+Shift+2 { move-column-to-workspace 2; }
                              ${k.modifiers.wm}+Shift+3 { move-column-to-workspace 3; }
                              ${k.modifiers.wm}+Shift+4 { move-column-to-workspace 4; }
                              ${k.modifiers.wm}+Shift+5 { move-column-to-workspace 5; }
                              ${k.modifiers.wm}+Shift+6 { move-column-to-workspace 6; }
                              ${k.modifiers.wm}+Shift+7 { move-column-to-workspace 7; }
                              ${k.modifiers.wm}+Shift+8 { move-column-to-workspace 8; }
                              ${k.modifiers.wm}+Shift+9 { move-column-to-workspace 9; }
                              ${k.modifiers.wm}+Shift+0 { move-column-to-workspace 10; }

                              // Applications
                              ${k.modifiers.wm}+${k.wm.terminal} { spawn "${config.apps.terminal.command}"; }
                              ${k.modifiers.wm}+Shift+${k.wm.terminal} { spawn "sh" "-c" "cd $(${pkgs.xcwd}/bin/xcwd) && ${config.apps.terminal.command} --title float"; }
                              ${k.modifiers.wm}+${k.wm.fileManager} { spawn "sh" "-c" "cd $(${pkgs.xcwd}/bin/xcwd) && ${config.apps.terminal.command} --title ${config.apps.fileManager.name} -e ${config.apps.fileManager.command}"; }
                              ${k.modifiers.wm}+${k.wm.browser} { spawn "${config.apps.browser.command}"; }
                              ${k.modifiers.wm}+${k.wm.sysmon} { spawn "${config.apps.terminal.command}" "--title" "${config.apps.sysmon.name}" "-e" "${config.apps.sysmon.command}"; }

                              // Noctalia launcher (replaces fuzzel)
                              ${k.modifiers.wm}+R { spawn ${ipc "launcher" "toggle"}; }
                              ${k.modifiers.wm}+${k.wm.launcher} { spawn ${ipc "launcher" "toggle"}; }

                              // Noctalia clipboard history (replaces cliphist + fuzzel)
                              ${k.modifiers.wm}+${k.wm.clipboard} { spawn ${ipc "launcher" "clipboard"}; }

                              // Noctalia control center and session menu (new features)
                              ${k.modifiers.wm}+N { spawn ${ipc "controlCenter" "toggle"}; }
                              ${k.modifiers.wm}+G { spawn ${ipc "sessionMenu" "toggle"}; }

                              // Theme toggle via Noctalia dark mode
                              ${k.modifiers.wm}+${k.wm.themeToggle} { spawn ${ipc "darkMode" "toggle"}; }

                              // Screenshots (unchanged - these use grim/slurp/satty)
                              Print { spawn "screenshot-screen"; }
                              ${k.modifiers.wm}+${k.wm.screenshot} { spawn "screenshot-region"; }
                              ${k.modifiers.wm}+Print { spawn "screenshot-screen-edit"; }
                              ${k.modifiers.wm}+Shift+P { spawn "color-picker"; }

                              // Notifications via Noctalia (replaces makoctl)
                              ${k.modifiers.wm}+Comma { spawn ${ipc "notifications" "dismissAll"}; }
                              ${k.modifiers.wm}+Shift+Comma { spawn ${ipc "notifications" "clear"}; }

                              // Media controls via Noctalia OSD (replaces swayosd)
                              XF86AudioRaiseVolume { spawn ${ipc "volume" "increase"}; }
                              XF86AudioLowerVolume { spawn ${ipc "volume" "decrease"}; }
                              XF86AudioMute { spawn ${ipc "volume" "muteOutput"}; }
                              XF86AudioMicMute { spawn ${ipc "volume" "muteInput"}; }
                              XF86AudioNext { spawn "playerctl" "next"; }
                              XF86AudioPause { spawn "playerctl" "play-pause"; }
                              XF86AudioPlay { spawn "playerctl" "play-pause"; }
                              XF86AudioPrev { spawn "playerctl" "previous"; }

                              // Brightness via Noctalia OSD (replaces swayosd/light)
                              XF86MonBrightnessUp { spawn ${ipc "brightness" "increase"}; }
                              XF86MonBrightnessDown { spawn ${ipc "brightness" "decrease"}; }

                              // Lock screen (new - Noctalia built-in)
                              ${k.modifiers.wm}+L { spawn ${ipc "lockScreen" "lock"}; }

                              // Wallpaper picker (new - Noctalia built-in)
                              ${k.modifiers.wm}+Shift+W { spawn ${ipc "wallpaper" "toggle"}; }

                              // Overview toggle (also accessible via 4-finger swipe or hot corner)
                              ${k.modifiers.wm}+${k.wm.overview} { toggle-overview; }

                              // Touchpad scroll bindings for volume via Noctalia
                              ${k.modifiers.wm}+TouchpadScrollUp { spawn ${ipc "volume" "increase"}; }
                              ${k.modifiers.wm}+TouchpadScrollDown { spawn ${ipc "volume" "decrease"}; }

                              // Monitor navigation (for multi-monitor setups)
                              ${k.modifiers.wm}+Escape { focus-monitor-previous; }
                              ${k.modifiers.wm}+Shift+Up { focus-monitor-up; }
                              ${k.modifiers.wm}+Shift+Down { focus-monitor-down; }
                              ${k.modifiers.wm}+Shift+Left { focus-monitor-left; }
                              ${k.modifiers.wm}+Shift+Right { focus-monitor-right; }

                              // Move focused column to another monitor
                              ${k.modifiers.wm}+Control+Shift+Up { move-column-to-monitor-up; }
                              ${k.modifiers.wm}+Control+Shift+Down { move-column-to-monitor-down; }
                              ${k.modifiers.wm}+Control+Shift+Left { move-column-to-monitor-left; }
                              ${k.modifiers.wm}+Control+Shift+Right { move-column-to-monitor-right; }

                              // Column layout
                              ${k.modifiers.wm}+${k.wm.maxColumn} { maximize-column; }
                              ${k.modifiers.wm}+${k.wm.presetWidth} { switch-preset-column-width; }

                              // Power management
                              ${k.modifiers.wm}+Shift+O { power-off-monitors; }
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
    # File manager for portal file chooser
    pkgs.nautilus
    # Auto-rotation daemon for tablet/convertible devices
    pkgs.rot8
    # Wayland forwarding over SSH
    pkgs.waypipe
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
  # GPD Pocket 4 rotations mapped to match device orientation (270 default)
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
          ${wrappedNiri}/bin/niri msg output ${config.monitors.builtin.name} transform 270
          ;;
        "90")
          echo "  -> Applying transform 180" >> "$LOG"
          ${wrappedNiri}/bin/niri msg output ${config.monitors.builtin.name} transform normal
          ;;
        "inverted")
          echo "  -> Applying transform 90" >> "$LOG"
          ${wrappedNiri}/bin/niri msg output ${config.monitors.builtin.name} transform 90
          ;;
        "270")
          echo "  -> Applying transform normal" >> "$LOG"
          ${wrappedNiri}/bin/niri msg output ${config.monitors.builtin.name} transform 180
          ;;
      esac
    '';
    executable = true;
  };
}
