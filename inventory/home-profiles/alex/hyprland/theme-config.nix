{ lib, ... }:

{
  theme.active = lib.mkDefault "solarized-dark";
  theme.autoSetMatchingWallpaper = lib.mkDefault true;
}
