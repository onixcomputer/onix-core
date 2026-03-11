{ config, pkgs, ... }:
{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # Faster WiFi reconnection and better power management
  networking.networkmanager.wifi.backend = "iwd";

  # Powertop auto-tune for battery life
  powerManagement.powertop.enable = true;
  # Powertop aggressively suspends USB devices including keyboards/mice.
  # Re-enable all HID devices after auto-tune runs.
  systemd.services.powertop.postStart = ''
    HIDDEVICES=$(ls /sys/bus/usb/drivers/usbhid | grep -oE '^[0-9]+-[0-9\.]+' | sort -u)
    for i in $HIDDEVICES; do
      echo -n "Enabling " | cat - /sys/bus/usb/devices/$i/product
      echo 'on' > /sys/bus/usb/devices/$i/power/control
    done
  '';
  systemd.services.powertop.serviceConfig = {
    Restart = "on-failure";
    RestartSec = "2s";
  };

  services = {
    # High-performance D-Bus implementation (default on Arch/Fedora)
    dbus.implementation = "broker";

    # Auto-suspend at 10% battery — pure udev, no daemon or polling
    udev.extraRules = ''
      SUBSYSTEM=="power_supply", ATTR{status}=="Discharging", ATTR{capacity}=="10", RUN+="${config.systemd.package}/bin/systemctl suspend"
    '';

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
