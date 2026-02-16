{ config, ... }:
{
  programs.noctalia-shell = {
    enable = true;

    # Material 3 color mapping from onix-dark palette
    colors = {
      mPrimary = config.colors.accent;
      mOnPrimary = config.colors.bg;
      mSecondary = config.colors.accent2;
      mOnSecondary = config.colors.bg;
      mTertiary = config.colors.purple;
      mOnTertiary = config.colors.bg;
      mError = config.colors.red;
      mOnError = config.colors.bg;
      mSurface = config.colors.bg;
      mSurfaceVariant = config.colors.bg_highlight;
      mOnSurface = config.colors.fg;
      mOnSurfaceVariant = config.colors.fg_dim;
      mOutline = config.colors.border;
      mShadow = config.colors.bg_dark;
      mHover = config.colors.bg_highlight;
      mOnHover = config.colors.fg;
    };

    settings = {
      bar = {
        inherit (config.bar)
          position
          floating
          density
          displayMode
          showCapsule
          outerCorners
          ;
        backgroundOpacity = config.opacity.bars;
        monitors = [ ];
        widgets = {
          left = [
            { id = "Launcher"; }
            {
              id = "Clock";
              formatHorizontal = config.bar.clockFormat;
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

      notifications = {
        enabled = true;
        inherit (config.notifications) location;
        inherit (config.notifications.noctalia)
          lowUrgencyDuration
          normalUrgencyDuration
          criticalUrgencyDuration
          ;
        backgroundOpacity = 1;
      };

      osd = {
        inherit (config.osd) enabled location autoHideMs;
      };

      wallpaper = {
        enabled = true;
        directory = config.paths.wallpapersRepo;
        inherit (config.wallpaper)
          fillMode
          automationEnabled
          transitionDuration
          transitionType
          randomIntervalSec
          ;
        wallpaperChangeMode = config.wallpaper.changeMode;
      };

      appLauncher = {
        inherit (config.launcher)
          position
          sortByMostUsed
          viewMode
          enableClipboardHistory
          ;
        terminalCommand = "${config.apps.terminal.command} -e";
      };

      colorSchemes = {
        inherit (config.colorScheme)
          useWallpaperColors
          darkMode
          schedulingMode
          generationMethod
          ;
      };

      dock = {
        enabled = false;
      };
    };
  };
}
