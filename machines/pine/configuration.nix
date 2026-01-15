{ pkgs, ... }:
{
  networking.hostName = "pine";
  time.timeZone = "America/Chicago";

  # PineNote has no TPM - disable to prevent missing module errors
  boot.initrd.systemd.tpm2.enable = false;
  systemd.tpm2.enable = false;

  # NetworkManager for WiFi
  networking.networkmanager.enable = true;

  # Sway compositor - pinenote-nixos provides sway-dbus-integration for e-ink
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };

  # XDG portal for Wayland
  xdg.portal = {
    enable = true;
    wlr.enable = true;
  };

  # Essential packages for e-ink device
  environment.systemPackages = with pkgs; [
    foot
    firefox
    git
  ];

  system.stateVersion = "24.11";
}
