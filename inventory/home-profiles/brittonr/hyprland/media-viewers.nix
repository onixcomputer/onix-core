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

  # Other media viewers
  home.packages = with pkgs; [
    # Image viewer
    imv

    # PDF/document viewer
    evince
  ];

  # Set default applications
  xdg.mimeApps.defaultApplications = {
    # Images
    "image/png" = [ "imv.desktop" ];
    "image/jpeg" = [ "imv.desktop" ];
    "image/gif" = [ "imv.desktop" ];
    "image/webp" = [ "imv.desktop" ];

    # Videos
    "video/mp4" = [ "mpv.desktop" ];
    "video/x-matroska" = [ "mpv.desktop" ];
    "video/webm" = [ "mpv.desktop" ];

    # PDFs
    "application/pdf" = [ "org.gnome.Evince.desktop" ];
  };
}
