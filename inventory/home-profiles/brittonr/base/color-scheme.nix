{ lib, ... }:
{
  options.colorScheme = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      useWallpaperColors = true;
      darkMode = true;
      schedulingMode = "off"; # darkman handles light/dark switching
      generationMethod = "tonal-spot";
    };
    description = "Color scheme generation settings (Material You)";
  };
}
