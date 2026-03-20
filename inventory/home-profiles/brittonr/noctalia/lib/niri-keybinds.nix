# Niri keybindings - extracted from niri.nix for modularity
# Returns KDL binds block as a string
{
  config,
  pkgs,
  lib,
}:
let
  k = config.keymap;
  up = lib.toUpper;
  ipc = target: action: ''"noctalia-shell" "ipc" "call" "${target}" "${action}"'';
in
''
  binds {
      ${k.modifiers.wm}+Shift+Slash { show-hotkey-overlay; }

      // Window management
      ${k.modifiers.wm}+${k.wm.close} { close-window; }
      ${k.modifiers.wm}+${k.wm.toggleTabs} { toggle-column-tabbed-display; }
      ${k.modifiers.wm}+${k.wm.fullscreen} { fullscreen-window; }
      ${k.modifiers.secondary}+F { toggle-window-floating; }
      ${k.modifiers.wm}+Y { spawn "toggle-sticky-window"; }
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

      // Column operations - consume/expel focused window
      ${k.modifiers.wm}+BracketLeft { consume-or-expel-window-left; }
      ${k.modifiers.wm}+BracketRight { consume-or-expel-window-right; }

      // Resizing
      ${k.modifiers.wm}+Minus { set-column-width "-${toString config.layout.resizePercent}%"; }
      ${k.modifiers.wm}+Equal { set-column-width "+${toString config.layout.resizePercent}%"; }

      // Resizing height (Mod+Shift+Minus/Equal)
      ${k.modifiers.wm}+Shift+Minus { set-window-height "-${toString config.layout.resizePercent}%"; }
      ${k.modifiers.wm}+Shift+Equal { set-window-height "+${toString config.layout.resizePercent}%"; }

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
      ${k.modifiers.wm}+${k.wm.terminal} { spawn "${config.apps.terminal.command}" "start"; }
      ${k.modifiers.wm}+Shift+${k.wm.terminal} { spawn "sh" "-c" "cd $(${pkgs.xcwd}/bin/xcwd) && exec ${config.apps.terminal.command} start"; }
      ${k.modifiers.wm}+${k.wm.fileManager} { spawn "sh" "-c" "cd $(${pkgs.xcwd}/bin/xcwd) && exec ${config.apps.terminal.command} start -- ${config.apps.fileManager.command}"; }
      ${k.modifiers.wm}+${k.wm.browser} { spawn "${config.apps.browser.command}"; }
      ${k.modifiers.wm}+${k.wm.sysmon} { spawn "${config.apps.terminal.command}" "start" "--" "${config.apps.sysmon.command}"; }

      // Noctalia launcher (replaces fuzzel)
      ${k.modifiers.wm}+${k.wm.launcher} { spawn ${ipc "launcher" "toggle"}; }

      // Noctalia clipboard history (replaces cliphist + fuzzel)
      ${k.modifiers.wm}+${k.wm.clipboard} { spawn ${ipc "launcher" "clipboard"}; }

      // Noctalia control center and session menu (new features)
      ${k.modifiers.wm}+N { spawn ${ipc "controlCenter" "toggle"}; }
      ${k.modifiers.wm}+G { spawn ${ipc "sessionMenu" "toggle"}; }

      // Theme toggle via Noctalia dark mode
      ${k.modifiers.wm}+${k.wm.themeToggle} { spawn ${ipc "darkMode" "toggle"}; }

      // Screenshots: Print uses niri's built-in screenshot to avoid
      // wlr-screencopy compositor stall (~27ms vs ~45ms for grim).
      // Region/edit still use grim+slurp+satty for annotation.
      Print { screenshot-screen; }
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
      // Mod+L is vim nav (focus-column-right), so use Mod+Shift+Escape
      ${k.modifiers.wm}+Shift+Escape { spawn ${ipc "lockScreen" "lock"}; }

      // Wallpaper picker (new - Noctalia built-in)
      ${k.modifiers.wm}+Shift+W { spawn ${ipc "wallpaper" "toggle"}; }

      // Overview toggle (also accessible via 4-finger swipe or hot corner)
      ${k.modifiers.wm}+${k.wm.overview} { toggle-overview; }

      // Touchpad scroll bindings for volume via Noctalia
      ${k.modifiers.wm}+TouchpadScrollUp { spawn ${ipc "volume" "increase"}; }
      ${k.modifiers.wm}+TouchpadScrollDown { spawn ${ipc "volume" "decrease"}; }

      // Monitor focus (Mod+Shift = monitor scope)
      ${k.modifiers.wm}+Escape { focus-monitor-previous; }
      ${k.modifiers.wm}+Shift+${up k.nav.left} { focus-monitor-left; }
      ${k.modifiers.wm}+Shift+${up k.nav.right} { focus-monitor-right; }
      ${k.modifiers.wm}+Shift+${up k.nav.up} { focus-monitor-up; }
      ${k.modifiers.wm}+Shift+${up k.nav.down} { focus-monitor-down; }
      ${k.modifiers.wm}+Shift+Left { focus-monitor-left; }
      ${k.modifiers.wm}+Shift+Right { focus-monitor-right; }
      ${k.modifiers.wm}+Shift+Up { focus-monitor-up; }
      ${k.modifiers.wm}+Shift+Down { focus-monitor-down; }

      // Move column to monitor (Mod+Ctrl+Shift = move + monitor scope)
      ${k.modifiers.wm}+Control+Shift+${up k.nav.left} { move-column-to-monitor-left; }
      ${k.modifiers.wm}+Control+Shift+${up k.nav.right} { move-column-to-monitor-right; }
      ${k.modifiers.wm}+Control+Shift+${up k.nav.up} { move-column-to-monitor-up; }
      ${k.modifiers.wm}+Control+Shift+${up k.nav.down} { move-column-to-monitor-down; }
      ${k.modifiers.wm}+Control+Shift+Left { move-column-to-monitor-left; }
      ${k.modifiers.wm}+Control+Shift+Right { move-column-to-monitor-right; }
      ${k.modifiers.wm}+Control+Shift+Up { move-column-to-monitor-up; }
      ${k.modifiers.wm}+Control+Shift+Down { move-column-to-monitor-down; }

      // Column layout
      ${k.modifiers.wm}+${k.wm.maxColumn} { maximize-column; }
      ${k.modifiers.wm}+Shift+${k.wm.maxColumn} { fit-workspace-columns; }
      ${k.modifiers.wm}+Control+${k.wm.maxColumn} { fit-workspace-columns grid=true; }
      ${k.modifiers.wm}+${k.wm.presetWidth} { switch-preset-column-width; }

      // Power management
      ${k.modifiers.wm}+Shift+O { power-off-monitors; }
  }
''
