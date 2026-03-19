{ lib, config, ... }:
let
  c = config.theme.data;
  r = c.rainbow;
in
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
        volumeStep = 2;
        speedStep = 0.25;
        screenshotTemplate = "%F-%P-%n";
      };

      subtitles = {
        color = "#FF${c.grayscale.white.no_hash}";
        borderColor = "#FF${c.editor.black.no_hash}";
      };

      # Gradient colors sourced from rainbow palette
      cava = {
        framerate = 60;
        gradient = [
          "'${r.green.hex}'"
          "'${r.cyan.hex}'"
          "'${r.blue.hex}'"
          "'${r.yellow.hex}'"
          "'${r.orange.hex}'"
          "'${r.red.hex}'"
          "'${r.violet.hex}'"
          "'${r.red.hex}'" # repeated for 8-entry gradient
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
