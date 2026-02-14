{ lib, ... }:
{
  options.lockscreen = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      clockFontSize = 86;
      dateFontSize = 22;
      fadeTimeout = 2000;
    };
    description = "Lock screen (hyprlock) styling settings";
  };
}
