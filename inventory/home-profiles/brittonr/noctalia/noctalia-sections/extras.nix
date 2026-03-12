# Templates, hooks, plugins, and desktop widgets for noctalia-shell
_config: {
  # -- Templates --
  templates = {
    activeTemplates = [ ];
    enableUserTheming = false;
  };

  # -- Hooks --
  hooks = {
    enabled = false;
    wallpaperChange = "";
    darkModeChange = "";
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
