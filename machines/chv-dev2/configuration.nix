# chv-dev2 — Cloud Hypervisor x86_64-linux guest on britton-desktop.
#
# Direct kernel boot, virtio I/O, deployed via `clan machines update chv-dev2`.
# Host-side networking: TAP bridge 172.16.0.0/24, DHCP from dnsmasq.
{
  pkgs,
  ...
}:
{
  imports = [
    ./disko.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "chv-dev2";
  time.timeZone = "America/New_York";

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  zramSwap.enable = true;

  environment.systemPackages = with pkgs; [
    btop
    git
    htop
    jq
    ripgrep
    vim
  ];

  system.stateVersion = "25.05";
}
