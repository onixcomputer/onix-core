{ lib, config, ... }:
let
  c = config.colors;
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
        color = "#FF${c.noHash c.grayscale.white}";
        borderColor = "#FF${c.noHash c.editor.black}";
      };

      # Gradient colors sourced from colors.rainbow palette
      cava = {
        framerate = 60;
        gradient = [
          "'${r.green}'"
          "'${r.cyan}'"
          "'${r.blue}'"
          "'${r.yellow}'"
          "'${r.orange}'"
          "'${r.red}'"
          "'${r.violet}'"
          "'${r.red}'" # repeated for 8-entry gradient
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
