{ pkgs, ... }:
let
  # Wallpaper configuration
  wallpaperConfig = {
    # Resize mode for static images and GIFs (swww):
    # - "fit": Show entire image, may have borders
    # - "crop": Cover screen, may crop content
    # - "stretch": Stretch to fill screen (distorts aspect ratio)
    # - "no": Don't resize, center content
    resizeMode = "crop";

    # Resize mode for video wallpapers (mpvpaper):
    # - "fit": Show entire video, may have borders (panscan=0.0)
    # - "crop": Cover screen, may crop content (panscan=1.0)
    videoResizeMode = "crop";

    # Fill color for padding when using fit mode (hex without #)
    fillColor = "000000";

    # Image scaling filter
    # Options: Nearest (pixel art), Bilinear, CatmullRom, Mitchell, Lanczos3 (default, smoothest)
    filter = "Lanczos3";

    # Transition for static images when changing wallpapers
    # Options: none, simple, fade, left, right, top, bottom, wipe, wave, grow, center, any, outer, random
    # Note: 'simple' is basic fade (ignores duration), 'fade' uses bezier curves
    # 'center'/'any'/'grow' are expanding circles, 'outer' is shrinking circle
    transitionType = "center";

    # Transition duration in seconds (integer only, doesn't work with 'simple' transition)
    transitionDuration = "3";

    # Transition FPS (smoothness of transition)
    transitionFps = "60";

    # Transition step - how fast transition approaches new image (2-255)
    # Lower = smoother but slower, Higher = faster but more abrupt, 255 = instant
    # Default: 2 for 'simple', 90 for others
    transitionStep = "90";

    # Angle for wipe and wave transitions (degrees)
    # 0 = right to left, 90 = top to bottom, 180 = left to right, 270 = bottom to top
    transitionAngle = "45";

    # Position for grow/outer transitions
    # Options: center, top, left, right, bottom, top-left, top-right, bottom-left, bottom-right
    # Or use coordinates like "0.5,0.5" for percentages or "200,400" for pixels
    transitionPos = "center";

    # Bezier curve for fade transition (x1,y1,x2,y2)
    # Use https://cubic-bezier.com to get values
    transitionBezier = ".54,0,.34,.99";

    # Wave dimensions for wave transition (width,height in pixels)
    transitionWave = "20,20";
  };
in
{
  # Create wallpaper config file that can be modified at runtime
  xdg.configFile."wallpaper/config" = {
    text = ''
      # Wallpaper configuration
      RESIZE_MODE=${wallpaperConfig.resizeMode}
      VIDEO_RESIZE_MODE=${wallpaperConfig.videoResizeMode}
      FILL_COLOR=${wallpaperConfig.fillColor}
      FILTER=${wallpaperConfig.filter}
      TRANSITION_TYPE=${wallpaperConfig.transitionType}
      TRANSITION_DURATION=${wallpaperConfig.transitionDuration}
      TRANSITION_FPS=${wallpaperConfig.transitionFps}
      TRANSITION_STEP=${wallpaperConfig.transitionStep}
      TRANSITION_ANGLE=${wallpaperConfig.transitionAngle}
      TRANSITION_POS=${wallpaperConfig.transitionPos}
      TRANSITION_BEZIER=${wallpaperConfig.transitionBezier}
      TRANSITION_WAVE=${wallpaperConfig.transitionWave}
    '';
    onChange = ''
      echo "Wallpaper config updated. Changes will apply on next wallpaper change."
    '';
  };
  home = {
    packages = with pkgs; [
      # Tokyo Night GTK theme for GTK3 apps
      tokyo-night-gtk

      # Icon themes
      papirus-icon-theme

      # Wallpaper tools
      swww # For GIF support and static images
      mpvpaper # For video wallpapers
      imagemagick # For generating thumbnails
      jq # For parsing JSON (monitor dimensions)
    ];

    # Set GTK_THEME environment variable and wallpaper config
    sessionVariables = {
      GTK_THEME = "Tokyonight-Dark";
      WALLPAPER_RESIZE_MODE = wallpaperConfig.resizeMode;
      WALLPAPER_VIDEO_RESIZE_MODE = wallpaperConfig.videoResizeMode;
      WALLPAPER_TRANSITION_TYPE = wallpaperConfig.transitionType;
      WALLPAPER_TRANSITION_DURATION = wallpaperConfig.transitionDuration;
      WALLPAPER_TRANSITION_FPS = wallpaperConfig.transitionFps;
    };
  };

  # GTK theme configuration
  gtk = {
    enable = true;

    theme = {
      name = "Tokyonight-Dark";
      package = pkgs.tokyo-night-gtk;
    };

    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };

    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };

    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
  };

  # dconf settings for GNOME/GTK apps dark mode
  dconf = {
    enable = true;
    settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        gtk-theme = "Tokyonight-Dark";
        icon-theme = "Papirus-Dark";
      };
    };
  };

  # Qt theme configuration to match GTK
  qt = {
    enable = true;
    platformTheme.name = "gtk";
    style.name = "adwaita-dark";
  };

  # Explicitly disable hyprpaper service - let waytrogen manage all backends
  services.hyprpaper.enable = false;
}
