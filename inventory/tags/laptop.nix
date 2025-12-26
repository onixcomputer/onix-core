{ pkgs, ... }:
{
  programs.light.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # Faster WiFi reconnection and better power management
  networking.networkmanager.wifi.backend = "iwd";

  # High-performance D-Bus implementation (default on Arch/Fedora)
  services.dbus.implementation = "broker";

  services = {
    xserver = {
      enable = true;
      xkb = {
        layout = "us";
        variant = "";
      };
    };
    blueman.enable = true;
    power-profiles-daemon.enable = true;
    upower.enable = true;

    libinput = {
      enable = true;
      touchpad = {
        tapping = true;
        disableWhileTyping = true;
      };
    };
  };

  environment.systemPackages = with pkgs; [
    xdg-utils
    desktop-file-utils
    shared-mime-info
    brightnessctl
    powertop
    acpi
    libnotify
  ];
}
