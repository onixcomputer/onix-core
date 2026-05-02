# General and UI settings for noctalia-shell
_config: {
  # -- General --
  general = {
    avatarImage = "/home/brittonr/.face";
    dimmerOpacity = 0.2;
    showScreenCorners = false;
    forceBlackScreenCorners = false;
    scaleRatio = 1;
    radiusRatio = 1;
    iRadiusRatio = 1;
    boxRadiusRatio = 1;
    screenRadiusRatio = 1;
    animationSpeed = 1;
    animationDisabled = false;
    compactLockScreen = false;
    lockScreenAnimations = false;
    lockOnSuspend = false;
    showSessionButtonsOnLockScreen = true;
    showHibernateOnLockScreen = false;
    enableShadows = true;
    shadowDirection = "bottom_right";
    shadowOffsetX = 2;
    shadowOffsetY = 3;
    language = "";
    allowPanelsOnScreenWithoutBar = true;
    showChangelogOnStartup = true;
    telemetryEnabled = false;
    enableLockScreenCountdown = true;
    lockScreenCountdownDuration = 10000;
    autoStartAuth = false;
    allowPasswordWithFprintd = false;
    clockStyle = "custom";
    clockFormat = "hh\\nmm";
    lockScreenMonitors = [ ];
    lockScreenBlur = 0;
    lockScreenTint = 0;
    keybinds = {
      keyUp = [ "Up" ];
      keyDown = [ "Down" ];
      keyLeft = [ "Left" ];
      keyRight = [ "Right" ];
      keyEnter = [ "Return" ];
      keyEscape = [ "Esc" ];
      keyRemove = [ "Del" ];
    };
    reverseScroll = false;
  };

  # -- UI --
  ui = {
    fontDefault = "Sans";
    fontFixed = "monospace";
    fontDefaultScale = 1;
    fontFixedScale = 1;
    tooltipsEnabled = true;
    panelBackgroundOpacity = 0.93;
    panelsAttachedToBar = true;
    settingsPanelMode = "attached";
    wifiDetailsViewMode = "grid";
    bluetoothDetailsViewMode = "grid";
    networkPanelView = "wifi";
    bluetoothHideUnnamedDevices = false;
    boxBorderEnabled = false;
  };

  # -- Location & Weather --
  location = {
    name = "nyc";
    weatherEnabled = true;
    weatherShowEffects = true;
    useFahrenheit = false;
    use12hourFormat = false;
    showWeekNumberInCalendar = true;
    showCalendarEvents = true;
    showCalendarWeather = true;
    analogClockInCalendar = false;
    firstDayOfWeek = -1;
    hideWeatherTimezone = false;
    hideWeatherCityName = false;
  };

  # -- Calendar --
  calendar = {
    cards = [
      {
        enabled = true;
        id = "calendar-header-card";
      }
      {
        enabled = true;
        id = "calendar-month-card";
      }
      {
        enabled = true;
        id = "weather-card";
      }
    ];
  };
}
