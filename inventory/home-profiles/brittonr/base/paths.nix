{ lib, ... }:
{
  options.paths = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      screenshots = "~/Screenshots";
      wallpapers = "~/Pictures/Wallpapers";
      downloads = "~/Downloads";
    };
    description = "Common user directories";
  };
}
