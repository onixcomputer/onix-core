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
      };

      cava = {
        framerate = 60;
        gradient = [
          "'#59cc33'"
          "'#80cc33'"
          "'#a6cc33'"
          "'#cccc33'"
          "'#cca633'"
          "'#cc8033'"
          "'#cc5933'"
          "'#cc3333'"
        ];
      };
    };
    description = "Media player and visualizer settings";
  };
}
