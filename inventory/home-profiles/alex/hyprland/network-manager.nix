{ pkgs, ... }:
{
  home.packages = with pkgs; [
    networkmanagerapplet
    networkmanager_dmenu
  ];
  # Enable nm-applet service for system tray
  services.network-manager-applet = {
    enable = true;
  };
}
