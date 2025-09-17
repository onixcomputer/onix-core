{ pkgs, ... }:

{
  programs.mpv = {
    enable = true;

    config = {
      # Video
      profile = "gpu-hq";
      vo = "gpu-next";
      gpu-api = "vulkan";
      hwdec = "auto-safe";

      # Audio
      volume = 100;
      volume-max = 200;
      audio-pitch-correction = "yes";

      # Subtitles
      sub-auto = "fuzzy";
      sub-font-size = 36;
      sub-color = "#FFFFFFFF";
      sub-border-color = "#FF000000";
      sub-border-size = 3;

      # UI
      osc = "yes";
      osd-bar = "yes";
      osd-font-size = 30;

      # Playback
      save-position-on-quit = "yes";
      keep-open = "yes";

      # Cache
      cache = "yes";
      cache-secs = 300;
      demuxer-max-bytes = "1024MiB";
      demuxer-max-back-bytes = "1024MiB";

      # Screenshot
      screenshot-format = "png";
      screenshot-directory = "~/Pictures/Screenshots";
      screenshot-template = "%F-%P-%n";
    };

    bindings = {
      # Mouse controls
      "WHEEL_UP" = "add volume 2";
      "WHEEL_DOWN" = "add volume -2";
      "MBTN_LEFT_DBL" = "cycle fullscreen";

      # Keyboard shortcuts
      "ctrl+s" = "screenshot";
      "s" = "cycle sub";
      "a" = "cycle audio";
      "SPACE" = "cycle pause";
      "f" = "cycle fullscreen";

      # Seek controls
      "RIGHT" = "seek 5";
      "LEFT" = "seek -5";
      "UP" = "seek 60";
      "DOWN" = "seek -60";

      # Speed controls
      "[" = "add speed -0.25";
      "]" = "add speed 0.25";
      "BS" = "set speed 1.0";
    };

    scripts = with pkgs.mpvScripts; [
      mpris
      thumbfast
      sponsorblock
    ];
  };
}
