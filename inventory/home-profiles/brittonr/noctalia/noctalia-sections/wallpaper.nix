# Wallpaper settings for noctalia-shell
config: {
  # -- Wallpaper --
  wallpaper = {
    enabled = true;
    overviewEnabled = false;
    directory = config.paths.wallpapersRepo;
    monitorDirectories = [ ];
    enableMultiMonitorDirectories = false;
    showHiddenFiles = false;
    viewMode = "single";
    setWallpaperOnAllMonitors = true;
    inherit (config.wallpaper)
      fillMode
      automationEnabled
      transitionDuration
      transitionType
      randomIntervalSec
      ;
    wallpaperChangeMode = config.wallpaper.changeMode;
    fillColor = "#000000";
    useSolidColor = true;
    solidColor = "#000000";
    skipStartupTransition = false;
    transitionEdgeSmoothness = 0.05;
    panelPosition = "follow_bar";
    hideWallpaperFilenames = false;
    overviewBlur = 0.4;
    overviewTint = 0.6;
    useWallhaven = false;
    wallhavenQuery = "";
    wallhavenSorting = "relevance";
    wallhavenOrder = "desc";
    wallhavenCategories = "111";
    wallhavenPurity = "100";
    wallhavenRatios = "";
    wallhavenApiKey = "";
    wallhavenResolutionMode = "atleast";
    wallhavenResolutionWidth = "";
    wallhavenResolutionHeight = "";
    sortOrder = "name";
    favorites = [ ];
  };
}
