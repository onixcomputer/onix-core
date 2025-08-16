# Network management configuration
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    networkmanager
    networkmanagerapplet # Provides nm-connection-editor binary only
  ];

  # Explicitly disable nm-applet service (we use waybar + rofi instead)
  services.network-manager-applet.enable = false;
}
