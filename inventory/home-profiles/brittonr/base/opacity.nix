{ lib, ... }:
{
  options.opacity = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      terminal = 0.92;
      bars = 0.95;
      panels = 0.85;
      inactive = 0.9;
      blur = {
        size = 8;
        passes = 2;
        vibrancy = 0.2;
        noise = 0.02;
      };
    };
    description = "Transparency and blur settings for windows and UI elements";
  };
}
