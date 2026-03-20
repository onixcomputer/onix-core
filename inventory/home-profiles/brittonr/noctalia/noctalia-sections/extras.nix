# Templates, hooks, plugins, and desktop widgets for noctalia-shell
_config: {
  # -- Templates --
  # Built-in templates generate per-app config fragments whenever
  # colors change.  User templates (enableUserTheming) extend this
  # to fish, bat, delta, eza, starship, and swayosd via
  # ~/.config/noctalia/user-templates.toml (provided by home-manager).
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
      {
        id = "btop";
        enabled = true;
      }
      {
        id = "helix";
        enabled = true;
      }
    ];
    enableUserTheming = true;
  };

  # -- Hooks --
  # Built-in + user templates handle all app theming. Hooks only
  # need to reload niri after templates write noctalia.kdl.
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
