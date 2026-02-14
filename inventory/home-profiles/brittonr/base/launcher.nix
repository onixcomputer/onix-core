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
    };
    description = "Application launcher (wofi/rofi) dimensions";
  };
}
