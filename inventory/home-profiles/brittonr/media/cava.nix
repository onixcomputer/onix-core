{ config, ... }:

{
  programs.cava = {
    enable = true;

    settings = {
      general = {
        inherit (config.media.cava) framerate sensitivity bars;
        autosens = 1;
        bar_width = config.media.cava.barWidth;
        bar_spacing = config.media.cava.barSpacing;
        lower_cutoff_freq = config.media.cava.lowerCutoffFreq;
        higher_cutoff_freq = config.media.cava.higherCutoffFreq;
        sleep_timer = 0;
      };

      input = {
        method = "pulse";
        source = "auto";
      };

      output = {
        method = "ncurses";
        channels = "stereo";
        mono_option = "average";
        reverse = 0;
        raw_target = "/dev/stdout";
        data_format = "binary";
        bit_format = "16bit";
      };

      color = {
        gradient = 1;
        gradient_count = builtins.length config.media.cava.gradient;
        gradient_color_1 = builtins.elemAt config.media.cava.gradient 0;
        gradient_color_2 = builtins.elemAt config.media.cava.gradient 1;
        gradient_color_3 = builtins.elemAt config.media.cava.gradient 2;
        gradient_color_4 = builtins.elemAt config.media.cava.gradient 3;
        gradient_color_5 = builtins.elemAt config.media.cava.gradient 4;
        gradient_color_6 = builtins.elemAt config.media.cava.gradient 5;
        gradient_color_7 = builtins.elemAt config.media.cava.gradient 6;
        gradient_color_8 = builtins.elemAt config.media.cava.gradient 7;
      };

      smoothing = {
        inherit (config.media.cava.smoothing) integral;
        monstercat = 0;
        waves = 0;
        inherit (config.media.cava.smoothing) gravity;
        ignore = 0;
        noise_reduction = config.media.cava.smoothing.noiseReduction;
      };
    };
  };
}
