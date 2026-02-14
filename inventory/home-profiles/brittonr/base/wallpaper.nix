{ lib, ... }:
{
  options.wallpaper = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      fillColor = "000000";

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
    description = "Wallpaper transition settings for swww";
  };
}
