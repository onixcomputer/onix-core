{ lib, pkgs, ... }:
{
  # XDG Portal services for desktop integration
  # Provides file chooser, screen sharing, etc. for sandboxed apps
  xdg.portal = {
    enable = lib.mkDefault true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };
}
