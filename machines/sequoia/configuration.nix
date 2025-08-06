{ pkgs, ... }:
{
  networking = {
    hostName = "sequoia";
    networkmanager.enable = true;
  };

  time.timeZone = "America/New_York";

  environment.systemPackages = with pkgs; [
    claude-code
    comma
  ];

  home-manager.backupFileExtension = "backup";

  system.stateVersion = "25.05";
}
