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
      swayosd = 0.97;
      # Hex alpha suffixes for color+alpha patterns (appended to hex colors)
      hex = {
        opaque = "ff"; # 100%
        high = "ee"; # 93% - notifications, active elements
        medium = "aa"; # 67% - inactive elements
        low = "70"; # 44% - shadows, overlays
        subtle = "40"; # 25% - very faint overlays
      };
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
