{ config, ... }:

{
  programs.cava = {
    enable = true;

    settings = {
      general = {
        inherit (config.media.cava) framerate;
        autosens = 1;
        sensitivity = 100;
        bars = 0;
        bar_width = 2;
        bar_spacing = 1;
        lower_cutoff_freq = 50;
        higher_cutoff_freq = 10000;
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
        integral = 77;
        monstercat = 0;
        waves = 0;
        gravity = 100;
        ignore = 0;
        noise_reduction = 0.77;
      };
    };
  };
}
