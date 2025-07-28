{ pkgs, ... }:
{
  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      # ===== VARIABLES =====
      "$mod" = "SUPER";
      "$terminal" = "alacritty";
      "$browser" = "firefox";
      "$fileManager" = "nautilus";

      # ===== MONITORS =====
      # Default monitor configuration - users can override in their own config
      monitor = [
        "eDP-1,2880x1920@120,auto,2"
        "DP-3, preferred, auto, 1, mirror, eDP-1" # monitor 2 mirror for presentation/jetkvm
      ];

      # ===== AUTOSTART =====
      exec-once = [
        # Core services
        "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
        "${pkgs.wl-clip-persist}/bin/wl-clip-persist --clipboard regular --all-mime-type-regex '^(?!x-kde-passwordManagerHint).+'"
        "${pkgs.waybar}/bin/waybar"
        "${pkgs.mako}/bin/mako"
        "${pkgs.swayosd}/bin/swayosd-server"
        "${pkgs.hypridle}/bin/hypridle"
      ];

      # ===== GENERAL =====
      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
        "col.inactive_border" = "rgba(595959aa)";
        resize_on_border = false;
        allow_tearing = false;
        layout = "dwindle";
      };

      # ===== DECORATION  =====
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

      # ===== ANIMATIONS (from looknfeel.conf) =====
      animations = {
        enabled = true;

        bezier = [
          "easeOutQuint,0.23,1,0.32,1"
          "easeInOutCubic,0.65,0.05,0.36,1"
          "linear,0,0,1,1"
          "almostLinear,0.5,0.5,0.75,1.0"
          "quick,0.15,0,0.1,1"
        ];

        animation = [
          "global, 1, 10, default"
          "border, 1, 5.39, easeOutQuint"
          "windows, 1, 4.79, easeOutQuint"
          "windowsIn, 1, 4.1, easeOutQuint, popin 87%"
          "windowsOut, 1, 1.49, linear, popin 87%"
          "fadeIn, 1, 1.73, almostLinear"
          "fadeOut, 1, 1.46, almostLinear"
          "fade, 1, 3.03, quick"
          "layers, 1, 3.81, easeOutQuint"
          "layersIn, 1, 4, easeOutQuint, fade"
          "layersOut, 1, 1.5, linear, fade"
          "fadeLayersIn, 1, 1.79, almostLinear"
          "fadeLayersOut, 1, 1.39, almostLinear"
          "workspaces, 0, 0, default"
        ];
      };

      # ===== LAYER RULES (from looknfeel.conf) =====
      layerrule = [
        "noanim,walker"
        "noanim, selection" # Remove 1px border around hyprshot screenshots
      ];

      # ===== DWINDLE LAYOUT (from looknfeel.conf) =====
      dwindle = {
        pseudotile = true;
        preserve_split = true;
        force_split = 2; # Always split on the right
      };

      # ===== MASTER LAYOUT (from looknfeel.conf) =====
      master = {
        new_status = "master";
      };

      # ===== INPUT (from input.conf) =====
      input = {
        kb_layout = "us";
        kb_variant = "";
        kb_model = "";
        kb_options = "compose:caps";
        kb_rules = "";

        follow_mouse = 1;
        sensitivity = 0;

        touchpad = {
          natural_scroll = false;
        };
      };

      # ===== GESTURES (from input.conf) =====
      gestures = {
        workspace_swipe = false;
      };

      # ===== MISC (from looknfeel.conf) =====
      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
        focus_on_activate = true;
      };

      # ===== WINDOW RULES (from windows.conf) =====
      windowrule = [
        # Float and center file pickers
        "float, class:xdg-desktop-portal-gtk, title:^(Open.*Files?|Save.*Files?|All Files|Save)"
        "center, class:xdg-desktop-portal-gtk, title:^(Open.*Files?|Save.*Files?|All Files|Save)"

        # Fix XWayland dragging issues
        "nofocus,class:^$,title:^$,xwayland:1,floating:1,fullscreen:0,pinned:0"

        # Opacity settings - Only terminal gets transparency
        "opacity 0.97 0.97, class:^(Alacritty|alacritty)$"

      ];

      # ===== KEYBINDINGS (from bindings/*.conf) =====
      bind = [
        # === Window Management (from tiling.conf) ===
        "$mod, Q, killactive"
        "$mod, J, togglesplit"
        "$mod, P, pseudo"
        "$mod, V, togglefloating"
        ", F11, fullscreen, 0"

        # Move focus
        "$mod, left, movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up, movefocus, u"
        "$mod, down, movefocus, d"

        # Swap windows
        "$mod SHIFT, left, swapwindow, l"
        "$mod SHIFT, right, swapwindow, r"
        "$mod SHIFT, up, swapwindow, u"
        "$mod SHIFT, down, swapwindow, d"

        # Resize windows
        "$mod, minus, resizeactive, -100 0"
        "$mod, equal, resizeactive, 100 0"
        "$mod SHIFT, minus, resizeactive, 0 -100"
        "$mod SHIFT, equal, resizeactive, 0 100"

        # Workspaces (using code: for reliability like Omarchy)
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

        # Move to workspace
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

        # === Application Bindings ===
        "$mod, Return, exec, $terminal"
        "$mod, F, exec, $fileManager"
        "$mod, B, exec, $browser"
        "$mod, R, exec, walker"
        "$mod, space, exec, walker"

        # === Utilities ===
        # Notifications
        "$mod, comma, exec, makoctl dismiss"
        "$mod SHIFT, comma, exec, makoctl dismiss --all"

        # Screenshots
        ", PRINT, exec, hyprshot -m region"
        "SHIFT, PRINT, exec, hyprshot -m window"
        "CTRL, PRINT, exec, hyprshot -m output"

        # Color picker
        "$mod, PRINT, exec, hyprpicker -a"

        # === Scroll through workspaces ===
        "$mod, mouse_down, workspace, e+1"
        "$mod, mouse_up, workspace, e-1"
      ];

      # ===== MEDIA BINDINGS (bindel for repeat) =====
      bindel = [
        # Volume controls
        ", XF86AudioRaiseVolume, exec, swayosd-client --output-volume raise"
        ", XF86AudioLowerVolume, exec, swayosd-client --output-volume lower"
        ", XF86AudioMute, exec, swayosd-client --output-volume mute-toggle"
        ", XF86AudioMicMute, exec, swayosd-client --input-volume mute-toggle"

        # Brightness controls
        ", XF86MonBrightnessUp, exec, swayosd-client --brightness raise"
        ", XF86MonBrightnessDown, exec, swayosd-client --brightness lower"
      ];

      # ===== MEDIA PLAYBACK (bindl for locked) =====
      bindl = [
        ", XF86AudioNext, exec, playerctl next"
        ", XF86AudioPause, exec, playerctl play-pause"
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioPrev, exec, playerctl previous"
      ];

      # ===== MOUSE BINDINGS =====
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];
    };
  };
}
