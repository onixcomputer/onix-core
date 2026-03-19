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
  # noctalia-theme-sync propagates colors to all themed apps (fish,
  # starship, helix, btop, bat, delta, eza, swayosd). The built-in
  # niri and kitty templates handle those two. The niri reload
  # is chained after the sync script.
  hooks = {
    enabled = true;
    darkModeChange = "noctalia-theme-sync; niri msg action load-config-file";
    wallpaperChange = "noctalia-theme-sync; niri msg action load-config-file";
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
