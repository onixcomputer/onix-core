# Control center, session menu, and dock settings for noctalia-shell
_config: {
  # -- Control Center --
  controlCenter = {
    position = "close_to_bar_button";
    diskPath = "/";
    shortcuts = {
      left = [
        { id = "Network"; }
        { id = "Bluetooth"; }
        { id = "WallpaperSelector"; }
        { id = "NoctaliaPerformance"; }
      ];
      right = [
        { id = "Notifications"; }
        { id = "PowerProfile"; }
        { id = "KeepAwake"; }
        { id = "NightLight"; }
      ];
    };
    cards = [
      {
        enabled = true;
        id = "profile-card";
      }
      {
        enabled = true;
        id = "shortcuts-card";
      }
      {
        enabled = true;
        id = "audio-card";
      }
      {
        enabled = false;
        id = "brightness-card";
      }
      {
        enabled = true;
        id = "weather-card";
      }
      {
        enabled = true;
        id = "media-sysmon-card";
      }
    ];
  };

  # -- Session Menu --
  sessionMenu = {
    enableCountdown = true;
    countdownDuration = 10000;
    position = "center";
    showHeader = true;
    showKeybinds = true;
    largeButtonsStyle = true;
    largeButtonsLayout = "single-row";
    powerOptions = [
      {
        action = "lock";
        command = "";
        countdownEnabled = true;
        enabled = true;
        keybind = "1";
      }
      {
        action = "suspend";
        command = "";
        countdownEnabled = true;
        enabled = true;
        keybind = "2";
      }
      {
        action = "hibernate";
        command = "";
        countdownEnabled = true;
        enabled = true;
        keybind = "3";
      }
      {
        action = "reboot";
        command = "";
        countdownEnabled = true;
        enabled = true;
        keybind = "4";
      }
      {
        action = "logout";
        command = "";
        countdownEnabled = true;
        enabled = true;
        keybind = "5";
      }
      {
        action = "shutdown";
        command = "";
        countdownEnabled = true;
        enabled = true;
        keybind = "6";
      }
      {
        action = "rebootToUefi";
        command = "";
        countdownEnabled = true;
        enabled = true;
        keybind = "";
      }
    ];
  };

  # -- Dock --
  dock = {
    enabled = false;
    position = "bottom";
    displayMode = "auto_hide";
    backgroundOpacity = 1;
    floatingRatio = 1;
    size = 1;
    onlySameOutput = true;
    monitors = [ ];
    pinnedApps = [ ];
    colorizeIcons = false;
    pinnedStatic = false;
    inactiveIndicators = false;
    deadOpacity = 0.6;
    animationSpeed = 1;
  };
}
