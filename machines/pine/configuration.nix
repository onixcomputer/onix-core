{ pkgs, ... }:
{
  networking.hostName = "pine";
  time.timeZone = "America/Chicago";

  # PineNote boot configuration
  boot = {
    # U-Boot with extlinux boot (not EFI)
    # U-Boot sysboot reads /boot/extlinux/extlinux.conf
    loader.grub.enable = false;
    loader.generic-extlinux-compatible.enable = true;

    # Kernel parameters for PineNote e-ink display
    kernelParams = [
      "console=ttyS2,1500000n8" # UART console
      "console=tty0"
      "earlycon"
    ];

    # PineNote has no TPM - disable to prevent missing module errors
    initrd.systemd.tpm2.enable = false;
  };
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
