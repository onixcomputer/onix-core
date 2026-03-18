{ pkgs, lib, config, ... }:

{
  programs.mpv = {
    enable = true;

    config = lib.mkForce {
      # Video
      profile = "gpu-hq";
      vo = "gpu-next";
      gpu-api = "vulkan";
      hwdec = "auto-safe";

      # Audio
      volume = config.media.mpv.defaultVolume;
      volume-max = config.media.mpv.maxVolume;
      audio-pitch-correction = "yes";

      # Subtitles
      sub-auto = "fuzzy";
      sub-font-size = config.media.mpv.subFontSize;
      sub-color = config.media.subtitles.color;
      sub-border-color = config.media.subtitles.borderColor;
      sub-border-size = config.media.mpv.subBorderSize;

      # UI
      osc = "yes";
      osd-bar = "yes";
      osd-font-size = config.media.mpv.osdFontSize;

      # Playback
      save-position-on-quit = "yes";
      keep-open = "yes";

      # Cache
      cache = "yes";
      cache-secs = config.media.mpv.cacheSecs;
      demuxer-max-bytes = config.media.mpv.demuxerMaxBytes;
      demuxer-max-back-bytes = config.media.mpv.demuxerMaxBytes;

      # Screenshot
      screenshot-format = "png";
      screenshot-directory = config.paths.screenshots;
      screenshot-template = config.media.mpv.screenshotTemplate;
    };

    bindings = lib.mkForce {
      # Mouse controls
      "WHEEL_UP" = "add volume ${toString config.media.mpv.volumeStep}";
      "WHEEL_DOWN" = "add volume -${toString config.media.mpv.volumeStep}";
      "MBTN_LEFT_DBL" = "cycle fullscreen";

      # Keyboard shortcuts
      "ctrl+s" = "screenshot";
      "s" = "cycle sub";
      "a" = "cycle audio";
      "SPACE" = "cycle pause";
      "f" = "cycle fullscreen";

      # Seek controls
      "RIGHT" = "seek ${toString config.media.mpv.seekShort}";
      "LEFT" = "seek -${toString config.media.mpv.seekShort}";
      "UP" = "seek ${toString config.media.mpv.seekLong}";
      "DOWN" = "seek -${toString config.media.mpv.seekLong}";

      # Speed controls
      "[" = "add speed -${toString config.media.mpv.speedStep}";
      "]" = "add speed ${toString config.media.mpv.speedStep}";
      "BS" = "set speed 1.0";
    };

    scripts = with pkgs.mpvScripts; [
      mpris
      thumbfast
      sponsorblock
    ];
  };
}
