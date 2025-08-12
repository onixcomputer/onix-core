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
    gh
  ];

  home-manager.backupFileExtension = "backup";

  system.stateVersion = "25.05";
}
