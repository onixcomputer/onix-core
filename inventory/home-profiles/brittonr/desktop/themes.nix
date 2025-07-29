{ pkgs, ... }:
let
  darkForestWallpaper = pkgs.fetchurl {
    name = "dark-forest-wallpaper.jxl";
    url = "https://raw.githubusercontent.com/adeci/wallpapers/main/dark-forest.jxl";
    sha256 = "sha256-jbY5p0vKLdearaZh1kuQytVsPia6h2AsEbOAqGpxEWw=";
  };
in
{
  services.hyprpaper = {
    enable = true;
    settings = {
      ipc = "on";
      splash = false;

      preload = [
        "${darkForestWallpaper}"
      ];

      wallpaper = [
        ",${darkForestWallpaper}"
      ];
    };
  };
}
