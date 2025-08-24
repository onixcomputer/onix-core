{ pkgs, ... }:
{
  networking = {
    hostName = "sequoia";
  };

  time.timeZone = "America/New_York";

  environment.systemPackages = with pkgs; [
    claude-code
    comma
    gh
    nix-output-monitor
  ];

  home-manager.backupFileExtension = "backup";

  system.stateVersion = "25.05";
}
