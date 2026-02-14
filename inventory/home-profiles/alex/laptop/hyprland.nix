{
  config,
  pkgs,
  ...
}:
let
  theme = config.theme.colors;
  anim = config.animations;
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;
    settings = {
      # Variables
      "$mod" = "SUPER";
      "$terminal" = config.apps.terminal.command;
      "$browser" = config.apps.browser.command;
      "$fileManager" = config.apps.fileManager.command;

      # Monitors
      monitor = [
        "eDP-1,2880x1920@120,auto,2"
        "DP-3, preferred, auto, 1, mirror, eDP-1" # monitor 2 mirror for presentation/jetkvm
      ];

      # Autostart
      exec-once = [
        # Fix slow app startup - update D-Bus environment first
        "${pkgs.dbus}/bin/dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"

        "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
        "${pkgs.wl-clip-persist}/bin/wl-clip-persist --clipboard regular --all-mime-type-regex '^(?!x-kde-passwordManagerHint).+'"
        "${pkgs.waybar}/bin/waybar"
        "${pkgs.mako}/bin/mako"
        "${pkgs.swayosd}/bin/swayosd-server"
        "${pkgs.hypridle}/bin/hypridle"
      ];

      # General
      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        "col.active_border" = theme.hypr.active_border;
        "col.inactive_border" = theme.hypr.inactive_border;
        resize_on_border = false;
        allow_tearing = false;
        layout = "dwindle";
      };

      # Decoration
      decoration = {
        rounding = 0;

        shadow = {
          enabled = true;
          range = 2;
          render_power = 3;
          color = "rgba(1a1a1aee)";
        };

        blur = {
          enabled = true;
          size = 3;
          passes = 1;
          vibrancy = 0.1696;
        };
      };

      # Animations
      animations = {
        enabled = true;
        bezier = anim.hyprBeziers;
        animation = anim.hyprAnimations;
      };

      # Layer rules
      layerrule = [
        "noanim,wofi"
        "noanim, selection"
      ];

      # Layout
      dwindle = {
        pseudotile = true;
        preserve_split = true;
        force_split = 2;
      };

      # Input
      input = {
        kb_layout = config.input.keyboard.layout;
        kb_options = "compose:caps";

        follow_mouse = if config.input.mouse.focusFollows then 1 else 0;
        sensitivity = 0;
        mouse_refocus = false;

        touchpad = {
          natural_scroll = config.input.touchpad.naturalScroll;
        };
      };

      # Gestures
      gestures = {
        workspace_swipe = false;
      };

      # Misc
      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
        focus_on_activate = true;
      };

      # Window rules
      windowrule = [
        "float, class:xdg-desktop-portal-gtk, title:^(Open.*Files?|Save.*Files?|All Files|Save)"
        "center, class:xdg-desktop-portal-gtk, title:^(Open.*Files?|Save.*Files?|All Files|Save)"

        "nofocus,class:^$,title:^$,xwayland:1,floating:1,fullscreen:0,pinned:0"

        "opacity ${toString config.opacity.terminal} ${toString config.opacity.terminal}, class:^(${config.apps.terminal.appId})$"

      ];

      # Keybindings
      bind = [
        # Window management
        "$mod, Q, killactive"
        "$mod, S, togglesplit"
        "$mod, P, pseudo"
        "$mod, V, togglefloating"
        ", F11, fullscreen, 0"

        # Vim bindings for focus
        "$mod, H, movefocus, l"
        "$mod, L, movefocus, r"
        "$mod, K, movefocus, u"
        "$mod, J, movefocus, d"

        # Keep arrow keys for compatibility
        "$mod, left, movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up, movefocus, u"
        "$mod, down, movefocus, d"

        # Vim bindings for swap
        "$mod SHIFT, H, swapwindow, l"
        "$mod SHIFT, L, swapwindow, r"
        "$mod SHIFT, K, swapwindow, u"
        "$mod SHIFT, J, swapwindow, d"

        # Keep arrow keys for compatibility
        "$mod SHIFT, left, swapwindow, l"
        "$mod SHIFT, right, swapwindow, r"
        "$mod SHIFT, up, swapwindow, u"
        "$mod SHIFT, down, swapwindow, d"

        "$mod, minus, resizeactive, -100 0"
        "$mod, equal, resizeactive, 100 0"
        "$mod SHIFT, minus, resizeactive, 0 -100"
        "$mod SHIFT, equal, resizeactive, 0 100"

        # Workspaces
        "$mod, code:10, workspace, 1"
        "$mod, code:11, workspace, 2"
        "$mod, code:12, workspace, 3"
        "$mod, code:13, workspace, 4"
        "$mod, code:14, workspace, 5"
        "$mod, code:15, workspace, 6"
        "$mod, code:16, workspace, 7"
        "$mod, code:17, workspace, 8"
        "$mod, code:18, workspace, 9"
        "$mod, code:19, workspace, 10"

        "$mod SHIFT, code:10, movetoworkspace, 1"
        "$mod SHIFT, code:11, movetoworkspace, 2"
        "$mod SHIFT, code:12, movetoworkspace, 3"
        "$mod SHIFT, code:13, movetoworkspace, 4"
        "$mod SHIFT, code:14, movetoworkspace, 5"
        "$mod SHIFT, code:15, movetoworkspace, 6"
        "$mod SHIFT, code:16, movetoworkspace, 7"
        "$mod SHIFT, code:17, movetoworkspace, 8"
        "$mod SHIFT, code:18, movetoworkspace, 9"
        "$mod SHIFT, code:19, movetoworkspace, 10"

        # Applications
        "$mod, Return, exec, $terminal"
        "$mod, F, exec, $fileManager"
        "$mod, B, exec, $browser"
        "$mod, R, exec, pkill wofi || wofi --show run"
        "$mod, space, exec, pkill wofi || wofi --show drun"
        "$mod, bracketleft, exec, pkill wofi || wofi-power"

        "$mod, comma, exec, makoctl dismiss"
        "$mod SHIFT, comma, exec, makoctl dismiss --all"

        ", PRINT, exec, hyprshot -m output"
        "SHIFT, PRINT, exec, hyprshot -m window"
        "$mod SHIFT, S, exec, hyprshot -m region"

        "$mod, PRINT, exec, hyprpicker -a"

        "$mod, mouse_down, workspace, e+1"
        "$mod, mouse_up, workspace, e-1"
      ];

      # Media controls (repeatable)
      bindel = [
        ", XF86AudioRaiseVolume, exec, swayosd-client --output-volume raise"
        ", XF86AudioLowerVolume, exec, swayosd-client --output-volume lower"
        ", XF86AudioMute, exec, swayosd-client --output-volume mute-toggle"
        ", XF86AudioMicMute, exec, swayosd-client --input-volume mute-toggle"

        ", XF86MonBrightnessUp, exec, swayosd-client --brightness raise"
        ", XF86MonBrightnessDown, exec, swayosd-client --brightness lower"
      ];

      # Media playback (works when locked)
      bindl = [
        ", XF86AudioNext, exec, playerctl next"
        ", XF86AudioPause, exec, playerctl play-pause"
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioPrev, exec, playerctl previous"
      ];

      # Mouse bindings
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];
    };
  };
}
