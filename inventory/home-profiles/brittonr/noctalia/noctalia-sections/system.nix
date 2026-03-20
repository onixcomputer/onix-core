# System monitor, audio, brightness, network, and color settings for noctalia-shell
config: {
  # -- System Monitor Thresholds --
  systemMonitor = {
    cpuWarningThreshold = 80;
    cpuCriticalThreshold = 90;
    tempWarningThreshold = config.power.temperature.critical;
    tempCriticalThreshold = 90;
    gpuWarningThreshold = 80;
    gpuCriticalThreshold = 90;
    memWarningThreshold = 80;
    memCriticalThreshold = 90;
    swapWarningThreshold = 80;
    swapCriticalThreshold = 90;
    diskWarningThreshold = 80;
    diskCriticalThreshold = 90;
    diskAvailWarningThreshold = 20;
    diskAvailCriticalThreshold = 10;
    batteryWarningThreshold = config.power.battery.warning;
    batteryCriticalThreshold = config.power.battery.critical;
    enableDgpuMonitoring = true;
    useCustomColors = false;
    warningColor = "";
    criticalColor = "";
    externalMonitor = "resources || missioncenter || jdsystemmonitor || corestats || system-monitoring-center || gnome-system-monitor || plasma-systemmonitor || mate-system-monitor || ukui-system-monitor || deepin-system-monitor || pantheon-system-monitor";
  };

  # -- Audio --
  audio = {
    volumeStep = config.audio.volume.step;
    volumeOverdrive = false;
    cavaFrameRate = 30;
    visualizerType = "linear";
    mprisBlacklist = [ ];
    preferredPlayer = "";
    volumeFeedback = false;
  };

  # -- Brightness --
  brightness = {
    brightnessStep = 5;
    enforceMinimum = true;
    enableDdcSupport = false;
  };

  # -- Network --
  network = {
    wifiEnabled = true;
    airplaneModeEnabled = false;
    bluetoothRssiPollingEnabled = false;
    bluetoothRssiPollIntervalMs = 60000;
    wifiDetailsViewMode = "grid";
    bluetoothDetailsViewMode = "grid";
    bluetoothHideUnnamedDevices = false;
    disableDiscoverability = false;
  };

  # -- Color Schemes --
  colorSchemes = {
    inherit (config.colorScheme)
      useWallpaperColors
      darkMode
      schedulingMode
      generationMethod
      ;
    predefinedScheme = "Onix";
    manualSunrise = "06:30";
    manualSunset = "18:30";
    monitorForColors = "";
  };

  # -- Night Light --
  nightLight = {
    enabled = false;
    forced = false;
    autoSchedule = true;
    nightTemp = "4000";
    dayTemp = "6500";
    manualSunrise = "06:30";
    manualSunset = "18:30";
  };
}
