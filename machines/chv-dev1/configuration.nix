# chv-dev1 — Cloud Hypervisor x86_64-linux guest on britton-desktop.
#
# Direct kernel boot, virtio I/O, deployed via `clan machines update chv-dev1`.
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
  networking.hostName = "chv-dev1";
  time.timeZone = "America/New_York";

  # SSH — primary access and clan deploy target.
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  # zram swap — no physical swap partition in a lightweight VM.
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
