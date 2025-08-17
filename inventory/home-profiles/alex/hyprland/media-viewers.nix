{ pkgs, ... }:
{
  # MPV video player with configuration
  programs.mpv = {
    enable = true;
    config = {
      # High quality video output
      profile = "gpu-hq";
      scale = "ewa_lanczossharp";
      cscale = "ewa_lanczossharp";

      # Video settings
      hwdec = "auto-safe";
      vo = "gpu";

      # Audio
      audio-pitch-correction = "yes";
      volume-max = 200;

      # Subtitles
      sub-auto = "fuzzy";
      sub-font = "Liberation Sans";
      sub-font-size = 36;

      # YouTube support
      ytdl-format = "bestvideo[height<=?1080]+bestaudio/best";

      # Cache
      cache = "yes";
      cache-secs = 300;

      # UI
      osc = "yes";
      osd-bar = "yes";
    };

    bindings = {
      # Volume controls
      "WHEEL_UP" = "add volume 2";
      "WHEEL_DOWN" = "add volume -2";

      # Seek controls
      "Shift+RIGHT" = "seek 10";
      "Shift+LEFT" = "seek -10";

      # Speed controls
      "[" = "multiply speed 0.9091";
      "]" = "multiply speed 1.1";
      "\\" = "set speed 1.0";

      # Screenshot
      "s" = "screenshot";
      "S" = "screenshot video";
    };
  };

  # Other media viewers and tools
  home.packages = with pkgs; [
    # Image viewer
    gthumb # Feature-rich image viewer with basic editing

    # PDF/document viewer
    evince

    # Media processing
    ffmpeg # Video/audio converter and processor
  ];

  # Set default applications
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      # Images - gThumb first, then imv
      "image/png" = [ "org.gnome.gThumb.desktop" ];
      "image/jpeg" = [ "org.gnome.gThumb.desktop" ];
      "image/jpg" = [ "org.gnome.gThumb.desktop" ];
      "image/gif" = [ "org.gnome.gThumb.desktop" ];
      "image/webp" = [ "org.gnome.gThumb.desktop" ];
      "image/bmp" = [ "org.gnome.gThumb.desktop" ];
      "image/svg+xml" = [ "org.gnome.gThumb.desktop" ];
      "image/tiff" = [ "org.gnome.gThumb.desktop" ];

      # Videos
      "video/mp4" = [ "mpv.desktop" ];
      "video/x-matroska" = [ "mpv.desktop" ];
      "video/webm" = [ "mpv.desktop" ];
      "video/avi" = [ "mpv.desktop" ];
      "video/quicktime" = [ "mpv.desktop" ];

      # PDFs
      "application/pdf" = [ "org.gnome.Evince.desktop" ];
    };
  };
}
