{ lib, ... }:
{
  options.media = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      mpv = {
        subFontSize = 36;
        osdFontSize = 30;
        seekShort = 5;
        seekLong = 60;
        defaultVolume = 100;
        maxVolume = 200;
        subBorderSize = 3;
        cacheSecs = 300;
        demuxerMaxBytes = "1024MiB";
      };

      # Gradient colors sourced from colors.rainbow palette
      cava = {
        framerate = 60;
        gradient = [
          "'#98C379'" # rainbow.green
          "'#56B6C2'" # rainbow.cyan
          "'#61AFEF'" # rainbow.blue
          "'#E5C07B'" # rainbow.yellow
          "'#D19A66'" # rainbow.orange
          "'#E06C75'" # rainbow.red
          "'#C678DD'" # rainbow.violet
          "'#E06C75'" # rainbow.red (repeated for 8-entry gradient)
        ];
        sensitivity = 100;
        bars = 0;
        barWidth = 2;
        barSpacing = 1;
        lowerCutoffFreq = 50;
        higherCutoffFreq = 10000;
        smoothing = {
          integral = 77;
          gravity = 100;
          noiseReduction = 0.77;
        };
      };
    };
    description = "Media player and visualizer settings";
  };
}
