{ lib, ... }:
{
  options.paths = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      screenshots = "~/Screenshots";
      wallpapers = "~/Pictures/Wallpapers";
      downloads = "~/Downloads";
      wallpapersRepo = "~/git/wallpapers";
      defaultWallpaper = "~/git/wallpapers/1-matte-black.jpg";
    };
    description = "Common user directories";
  };
}
