{ lib, ... }:
{
  options.wallpaper = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      fillColor = "000000";
      fillMode = "crop";
      automationEnabled = false;
      changeMode = "random";
      randomIntervalSec = 300;
      transitionDuration = 1500;
      transitionType = "random";

      gif = {
        transitionType = "fade";
        transitionDuration = 2;
        transitionFps = 60;
      };

      static = {
        transitionType = "center";
        transitionDuration = 3;
        transitionFps = 60;
        transitionStep = 90;
        transitionPos = "center";
        transitionBezier = ".54,0,.34,.99";
      };
    };
    description = "Wallpaper settings";
  };
}
