# Notifications and OSD settings for noctalia-shell
config: {
  # -- Notifications --
  notifications = {
    enabled = true;
    enableMarkdown = false;
    density = "default";
    monitors = [ ];
    inherit (config.notifications) location;
    overlayLayer = true;
    backgroundOpacity = 1;
    respectExpireTimeout = false;
    inherit (config.notifications.noctalia)
      lowUrgencyDuration
      normalUrgencyDuration
      criticalUrgencyDuration
      ;
    saveToHistory = {
      low = true;
      normal = true;
      critical = true;
    };
    sounds = {
      enabled = false;
      volume = 0.5;
      separateSounds = false;
      criticalSoundFile = "";
      normalSoundFile = "";
      lowSoundFile = "";
      excludedApps = "discord,firefox,chrome,chromium,edge";
    };
    enableMediaToast = false;
    enableKeyboardLayoutToast = true;
    enableBatteryToast = true;
  };

  # -- OSD --
  osd = {
    inherit (config.osd) enabled location autoHideMs;
    overlayLayer = true;
    backgroundOpacity = 1;
    enabledTypes = [
      0
      1
      2
    ];
    monitors = [ ];
  };
}
