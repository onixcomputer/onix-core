_:

{
  programs.cava = {
    enable = true;

    settings = {
      general = {
        framerate = 60;
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
        gradient_count = 8;
        gradient_color_1 = "'#59cc33'";
        gradient_color_2 = "'#80cc33'";
        gradient_color_3 = "'#a6cc33'";
        gradient_color_4 = "'#cccc33'";
        gradient_color_5 = "'#cca633'";
        gradient_color_6 = "'#cc8033'";
        gradient_color_7 = "'#cc5933'";
        gradient_color_8 = "'#cc3333'";
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
