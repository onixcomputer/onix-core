{ lib, ... }:
{
  options.monitors = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      primary = {
        name = "DP-3";
        mode = "3840x2160@240.084";
        scale = 1.5;
        position = {
          x = 0;
          y = 0;
        };
        vrr = true;
      };
      secondary = {
        name = "HDMI-A-2";
        mode = "2880x1800@99.999";
        scale = 1.2;
        position = {
          x = 960;
          y = 2160;
        };
        vrr = false;
      };
      builtin = {
        name = "eDP-1";
      };
    };
    description = "Monitor output configurations for desktop and portable displays";
  };
}
