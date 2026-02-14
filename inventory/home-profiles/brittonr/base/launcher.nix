{ lib, ... }:
{
  options.launcher = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      width = 600;
      height = 500;
      iconSize = 40;
      spacing = 10;
      fuzzel = {
        widthPercent = 50;
        horizontalPad = 20;
        verticalPad = 10;
        innerPad = 10;
        scriptWidth = 60;
      };
    };
    description = "Application launcher (wofi/rofi/fuzzel) dimensions";
  };
}
