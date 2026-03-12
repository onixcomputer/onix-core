# Templates, hooks, plugins, and desktop widgets for noctalia-shell
_config: {
  # -- Templates --
  # Enable the built-in niri template so Noctalia generates
  # ~/.config/niri/noctalia.kdl whenever colours change.
  # The template-apply.sh post-hook adds `include "./noctalia.kdl"`
  # to config.kdl on first run; subsequent changes are picked up by
  # the systemd path watcher (noctalia-niri-sync).
  templates = {
    activeTemplates = [
      {
        id = "niri";
        enabled = true;
      }
      {
        id = "kitty";
        enabled = true;
      }
    ];
    enableUserTheming = false;
  };

  # -- Hooks --
  # Backup mechanism: if the systemd path watcher misses a change,
  # these hooks ensure niri reloads on dark-mode or wallpaper events.
  hooks = {
    enabled = true;
    darkModeChange = "niri msg action load-config-file";
    wallpaperChange = "niri msg action load-config-file";
    screenLock = "";
    screenUnlock = "";
    performanceModeEnabled = "";
    performanceModeDisabled = "";
    startup = "";
    session = "";
  };

  # -- Plugins --
  plugins = {
    autoUpdate = false;
  };

  # -- Desktop Widgets --
  desktopWidgets = {
    enabled = false;
    gridSnap = false;
    monitorWidgets = [ ];
  };
}
