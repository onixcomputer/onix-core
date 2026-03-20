# App launcher settings for noctalia-shell
config: {
  # -- App Launcher --
  appLauncher = {
    inherit (config.launcher)
      position
      sortByMostUsed
      viewMode
      enableClipboardHistory
      ;
    terminalCommand = "${config.apps.terminal.command} start --";
    autoPasteClipboard = false;
    enableClipPreview = true;
    clipboardWrapText = true;
    clipboardWatchTextCommand = "wl-paste --type text --watch cliphist store";
    clipboardWatchImageCommand = "wl-paste --type image --watch cliphist store";
    pinnedApps = [ ];
    useApp2Unit = false;
    customLaunchPrefixEnabled = false;
    customLaunchPrefix = "";
    showCategories = true;
    iconMode = "tabler";
    showIconBackground = false;
    enableSettingsSearch = true;
    enableWindowsSearch = true;
    enableSessionSearch = true;
    ignoreMouseInput = false;
    screenshotAnnotationTool = "";
    overviewLayer = false;
    density = "default";
  };
}
