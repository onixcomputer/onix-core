{
  pkgs,
  config,
  lib,
  ...
}:
let
  theme = config.theme.colors;
  # Helper for colors that still need stripping
  c = color: lib.removePrefix "#" color;
  anim = config.animations;
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;
    settings = {
      "$mod" = "SUPER";
      "$terminal" = "kitty";
      "$browser" = "firefox";
      "$fileManager" = "thunar";

      env = [
        "ELECTRON_OZONE_PLATFORM_HINT,auto"
      ];

      # Autostart
      exec-once = [
        # Pass all environment variables to systemd/dbus so services inherit them
        # This ensures NVIDIA VA-API vars (LIBVA_DRIVER_NAME, NVD_BACKEND, MOZ_DISABLE_RDD_SANDBOX)
        # are available to Firefox and other apps started from the session
        "${pkgs.dbus}/bin/dbus-update-activation-environment --systemd --all"
        "eval $(${pkgs.gnome-keyring}/bin/gnome-keyring-daemon --start --components=ssh) && systemctl --user import-environment SSH_AUTH_SOCK"
        "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
        "${pkgs.wl-clip-persist}/bin/wl-clip-persist --clipboard regular --all-mime-type-regex '^(?!x-kde-passwordManagerHint).+'"
        "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist store"
        "${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${pkgs.cliphist}/bin/cliphist store"
        "${pkgs.waybar}/bin/waybar"
        "${pkgs.dunst}/bin/dunst"
        "${pkgs.hypridle}/bin/hypridle"
        "restore-wallpaper"
      ];

      # General
      general = {
        inherit (theme.hypr) gaps_in gaps_out border_size;
        "col.active_border" = theme.hypr.active_border;
        "col.inactive_border" = theme.hypr.inactive_border;
        resize_on_border = false;
        allow_tearing = false;
        layout = "dwindle";
      };

      # Decoration
      decoration = {
        inherit (theme.hypr) rounding;

        # Keep window opacity the same for active and inactive windows
        active_opacity = 1.0;
        inactive_opacity = 1.0;

        shadow = {
          enabled = true;
          range = 2;
          render_power = 3;
          color = "rgba(${c theme.bg_dark}ee)";
        };

        blur = {
          enabled = true;
          inherit (config.opacity.blur)
            size
            passes
            vibrancy
            noise
            ;
          contrast = 1.0;
          brightness = 0.8;
          special = true; # Blur on special workspaces too
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
        "noanim, rofi" # Disable animations for rofi
        "noanim, selection"

        # Notification animations only for dunst
        "animation slide, notifications"
        "animation fadeIn, notifications"
        "ignorezero, notifications"
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
        follow_mouse = if config.input.mouse.focusFollows then 1 else 0;
        sensitivity = 0;
        mouse_refocus = false;

        touchpad = {
          natural_scroll = config.input.touchpad.naturalScroll;
        };
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

        # Terminal transparency (same for active and inactive)
        "opacity ${toString config.opacity.terminal} ${toString config.opacity.terminal}, class:^(kitty)$"

        # Network settings - float and center
        "float, class:^(nm-connection-editor)$"
        "center, class:^(nm-connection-editor)$"
        "size 800 600, class:^(nm-connection-editor)$"

        # Bluetooth manager - float and center
        "float, class:^(\\.blueman-manager-wrapped)$"
        "center, class:^(\\.blueman-manager-wrapped)$"
        "size 900 600, class:^(\\.blueman-manager-wrapped)$"

      ];

      # Keybindings
      bind = [
        # Window management
        "$mod, Q, killactive"
        "$mod, S, togglesplit"
        "$mod, P, pseudo"
        "$mod, V, togglefloating"
        ", F11, fullscreen, 0"
        #"$mod, bracketright, exec, hyprctl dispatch exit"

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
        "$mod SHIFT, Return, exec, terminal-cwd"
        "$mod, F, exec, $fileManager"
        "$mod, B, exec, $browser"
        "$mod, R, exec, rofi -show run"
        # Clipboard manager - shows history with rofi, hides line numbers
        "$mod, C, exec, ${pkgs.cliphist}/bin/cliphist list | ${pkgs.rofi}/bin/rofi -dmenu -display-columns 2 -p 'Clipboard' | ${pkgs.cliphist}/bin/cliphist decode | ${pkgs.wl-clipboard}/bin/wl-copy"
        # Clipboard delete menu
        "$mod SHIFT, C, exec, ${pkgs.cliphist}/bin/cliphist list | ${pkgs.rofi}/bin/rofi -dmenu -display-columns 2 -p 'Delete Entry' | ${pkgs.cliphist}/bin/cliphist delete"
        # Wipe entire clipboard history
        "$mod ALT, C, exec, ${pkgs.rofi}/bin/rofi -dmenu -p 'Wipe clipboard history? (type yes)' | grep -q '^yes$' && ${pkgs.cliphist}/bin/cliphist wipe && notify-send 'Clipboard' 'History cleared'"
        "$mod, space, exec, rofi -show drun"
        "$mod, W, exec, rofi-wallpaper"
        "$mod, N, exec, notify-send -t 1000 'WiFi 󰤨' 'Scanning networks...' && rofi-network-menu"
        "$mod, Delete, exec, rofi-power"

        "$mod, comma, exec, dunstctl close"
        "$mod SHIFT, comma, exec, dunstctl close-all"

        # Instant fullscreen screenshot (Fn+F11 or Print key)
        ", Print, exec, grim ${config.paths.screenshots}/$(date +'screenshot_%Y-%m-%d_%H-%M-%S.png') && notify-send 'Screenshot' 'Saved to ${config.paths.screenshots}' -i camera-photo"
        # Region selection screenshot (defined in screenshot.nix with lock)
        "$mod SHIFT, S, exec, screenshot-wrapper -m region -o ${config.paths.screenshots}"
        # Window selection screenshot (defined in screenshot.nix with lock)
        "$mod SHIFT, W, exec, screenshot-wrapper -m window -o ${config.paths.screenshots}"

        # Color picker
        "$mod SHIFT, P, exec, hyprpicker -a"

        "$mod, mouse_down, workspace, e+1"
        "$mod, mouse_up, workspace, e-1"
      ];

      # Media controls (repeatable)
      bindel = [
        ", XF86AudioRaiseVolume, exec, swayosd-client --output-volume raise"
        ", XF86AudioLowerVolume, exec, swayosd-client --output-volume lower"
        ", XF86AudioMute, exec, swayosd-client --output-volume mute-toggle"
        ", XF86AudioMicMute, exec, swayosd-client --input-volume mute-toggle"
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
