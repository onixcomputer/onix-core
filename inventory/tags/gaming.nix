{ pkgs, ... }:
{
  # Steam gaming platform
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
  };

  # Gaming utilities
  environment.systemPackages = with pkgs; [
    gamemode
    gamescope
    mangohud
  ];
}
