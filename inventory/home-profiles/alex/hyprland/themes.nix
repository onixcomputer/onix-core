{ pkgs, ... }:
let
  darkForestWallpaper = pkgs.fetchurl {
    name = "dark-forest-wallpaper.jxl";
    url = "https://raw.githubusercontent.com/adeci/wallpapers/main/dark-forest.jxl";
    sha256 = "0v0if5mai05k24n611xs4qz6rmfaj15xcqd6mnddfbfa9fkkkdld";
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
