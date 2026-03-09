{ lib, ... }:

{
  theme.active = lib.mkDefault "tokyo-night";
  theme.autoSetMatchingWallpaper = lib.mkDefault true;
}
