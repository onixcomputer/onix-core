{ lib, ... }:
{
  options.accessibility = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      dpi = 96;
      fontScale = 1.0;
      keyboard = {
        repeatDelay = 250;
        repeatRate = 30;
      };
      highContrast = false;
    };
    description = "Accessibility settings";
  };
}
