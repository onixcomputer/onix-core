{
  pkgs,
  lib,
  ...
}:
{
  system.stateVersion = "24.05";
  nixpkgs.hostPlatform = "x86_64-linux";

  networking = {
    hostName = "test-vm";
    interfaces.eth0.useDHCP = lib.mkDefault true;
    firewall.allowedTCPPorts = [ 22 ];
  };

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = lib.mkForce true;
    };
  };

  users.users.root.initialPassword = "test";
  services.getty.autologinUser = "root";

  environment.systemPackages = with pkgs; [
    vim
    htop
  ];
}
