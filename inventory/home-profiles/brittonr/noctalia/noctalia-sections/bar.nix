# Bar settings for noctalia-shell
config: {
  bar = {
    barType = "simple";
    inherit (config.bar)
      position
      floating
      density
      displayMode
      showCapsule
      outerCorners
      ;
    capsuleOpacity = 1;
    capsuleColorKey = "none";
    backgroundOpacity = config.opacity.bars;
    useSeparateOpacity = false;
    monitors = [ ];
    showOutline = false;
    marginVertical = 4;
    marginHorizontal = 4;
    frameThickness = 8;
    frameRadius = 12;
    hideOnOverview = false;
    autoHideDelay = 500;
    autoShowDelay = 150;
    screenOverrides = [ ];
    widgets = {
      left = [
        {
          id = "Launcher";
          icon = "rocket";
          iconColor = "none";
        }
        {
          id = "Workspace";
          hideUnoccupied = true;
          labelMode = "index";
          characterCount = 2;
          colorizeIcons = false;
          emptyColor = "secondary";
          enableScrollWheel = true;
          focusedColor = "primary";
          followFocusedScreen = false;
          groupedBorderOpacity = 1;
          iconScale = 0.8;
          occupiedColor = "secondary";
          pillSize = 0.6;
          showApplications = false;
          showBadge = true;
          showLabelsOnlyWhenOccupied = true;
          unfocusedIconsOpacity = 1;
        }
        {
          id = "ActiveWindow";
          colorizeIcons = false;
          hideMode = "hidden";
          maxWidth = 145;
          scrollingMode = "hover";
          showIcon = true;
          textColor = "none";
          useFixedWidth = false;
        }
      ];
      center = [
        {
          id = "Clock";
          formatHorizontal = config.bar.clockFormat;
          formatVertical = "HH mm - dd MM";
          tooltipFormat = config.bar.clockFormat;
          clockColor = "none";
          customFont = "";
          useCustomFont = false;
        }
        {
          id = "MediaMini";
          compactMode = false;
          compactShowAlbumArt = true;
          compactShowVisualizer = false;
          hideMode = "hidden";
          hideWhenIdle = false;
          maxWidth = 350;
          panelShowAlbumArt = true;
          panelShowVisualizer = true;
          scrollingMode = "always";
          showAlbumArt = true;
          showArtistFirst = true;
          showProgressRing = true;
          showVisualizer = false;
          textColor = "none";
          useFixedWidth = false;
          visualizerType = "linear";
        }
      ];
      right = [
        {
          id = "SystemMonitor";
          compactMode = false;
          diskPath = "/";
          iconColor = "none";
          showCpuFreq = true;
          showCpuTemp = true;
          showCpuUsage = true;
          showDiskAvailable = false;
          showDiskUsage = true;
          showDiskUsageAsPercent = true;
          showGpuTemp = true;
          showLoadAverage = false;
          showMemoryAsPercent = true;
          showMemoryUsage = true;
          showNetworkStats = true;
          showSwapUsage = false;
          textColor = "none";
          useMonospaceFont = true;
          usePadding = false;
        }
        {
          id = "Tray";
          blacklist = [ ];
          chevronColor = "none";
          colorizeIcons = false;
          drawerEnabled = true;
          hidePassive = false;
          pinned = [ ];
        }
        {
          id = "Network";
          displayMode = "onhover";
          iconColor = "none";
          textColor = "none";
        }
        { id = "plugin:tailscale"; }
        { id = "plugin:privacy-indicator"; }
        { id = "plugin:screen-recorder"; }
        {
          id = "Bluetooth";
          displayMode = "onhover";
          iconColor = "none";
          textColor = "none";
        }
        {
          id = "Battery";
          warningThreshold = config.power.battery.warning;
          deviceNativePath = "__default__";
          displayMode = "graphic-clean";
          hideIfIdle = false;
          hideIfNotDetected = true;
          showNoctaliaPerformance = false;
          showPowerProfiles = false;
        }
        {
          id = "Volume";
          displayMode = "onhover";
          iconColor = "none";
          middleClickCommand = "pwvucontrol || pavucontrol";
          textColor = "none";
        }
        {
          id = "Brightness";
          displayMode = "onhover";
          iconColor = "none";
          textColor = "none";
        }
        {
          id = "NotificationHistory";
          hideWhenZero = false;
          hideWhenZeroUnread = false;
          iconColor = "none";
          showUnreadBadge = true;
          unreadBadgeColor = "primary";
        }
        {
          id = "ControlCenter";
          colorizeDistroLogo = false;
          colorizeSystemIcon = "none";
          customIconPath = "";
          enableColorization = false;
          icon = "noctalia";
          useDistroLogo = false;
        }
      ];
    };
  };
}
