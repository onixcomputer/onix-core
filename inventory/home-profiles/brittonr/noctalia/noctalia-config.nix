{ config, ... }:
{
  programs.noctalia-shell = {
    enable = true;
    # Package provided by NixOS module or flake overlay; set to null if using NixOS module
    # package = null;

    # Material 3 color mapping from onix-dark palette
    colors = {
      mPrimary = config.colors.accent; # #ff6600 - brand orange
      mOnPrimary = config.colors.bg; # dark bg for contrast on primary
      mSecondary = config.colors.accent2; # #ffaa00 - secondary gold
      mOnSecondary = config.colors.bg;
      mTertiary = config.colors.purple; # #aa44ff - tertiary purple
      mOnTertiary = config.colors.bg;
      mError = config.colors.red; # #ff4444
      mOnError = config.colors.bg;
      mSurface = config.colors.bg; # #1a1a1a
      mSurfaceVariant = config.colors.bg_highlight; # #262626
      mOnSurface = config.colors.fg; # #e6e6e6
      mOnSurfaceVariant = config.colors.fg_dim; # #b3b3b3
      mOutline = config.colors.border; # #404040
      mShadow = config.colors.bg_dark; # #0d0d0d
      mHover = config.colors.bg_highlight; # #262626
      mOnHover = config.colors.fg; # #e6e6e6
    };

    settings = {
      # Bar configuration
      bar = {
        position = "top";
        floating = false;
        density = "default";
        backgroundOpacity = 0.93;
        displayMode = "always_visible";
        showCapsule = true;
        outerCorners = true;
        monitors = [ ]; # all monitors
        widgets = {
          left = [
            { id = "Launcher"; }
            {
              id = "Clock";
              formatHorizontal = "HH:mm";
            }
            { id = "SystemMonitor"; }
            { id = "ActiveWindow"; }
            { id = "MediaMini"; }
          ];
          center = [
            {
              id = "Workspace";
              hideUnoccupied = false;
              labelMode = "none";
            }
          ];
          right = [
            { id = "Tray"; }
            { id = "NotificationHistory"; }
            { id = "Network"; }
            { id = "Bluetooth"; }
            {
              id = "Battery";
              warningThreshold = config.power.battery.warning;
            }
            { id = "Volume"; }
            { id = "Brightness"; }
            { id = "ControlCenter"; }
          ];
        };
      };

      # Notification settings
      notifications = {
        enabled = true;
        location = "top_right";
        lowUrgencyDuration = 3;
        normalUrgencyDuration = 8;
        criticalUrgencyDuration = 15;
        backgroundOpacity = 1;
      };

      # OSD for volume/brightness
      osd = {
        enabled = true;
        location = "top_right";
        autoHideMs = 2000;
      };

      # Wallpaper with Material 3 color extraction
      wallpaper = {
        enabled = true;
        directory = config.paths.wallpapersRepo;
        fillMode = "crop";
        automationEnabled = false;
        wallpaperChangeMode = "random";
        randomIntervalSec = 300;
        transitionDuration = 1500;
        transitionType = "random";
      };

      # Application launcher
      appLauncher = {
        position = "center";
        sortByMostUsed = true;
        terminalCommand = "${config.apps.terminal.command} -e";
        viewMode = "list";
        enableClipboardHistory = true;
      };

      # Color scheme - use wallpaper-based Material You by default,
      # with dark mode and location-based scheduling via darkman
      colorSchemes = {
        useWallpaperColors = true;
        darkMode = true;
        schedulingMode = "off"; # darkman handles light/dark switching
        generationMethod = "tonal-spot";
      };

      # Dock disabled (niri is a tiling WM, dock is for stacking)
      dock = {
        enabled = false;
      };
    };
  };
}
