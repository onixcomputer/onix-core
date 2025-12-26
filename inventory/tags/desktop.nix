{ pkgs, ... }:
{
  programs.light.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

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

    libinput = {
      enable = true;
      touchpad = {
        tapping = true;
        naturalScrolling = true;
        disableWhileTyping = false;
      };
    };
  };

  environment.systemPackages = with pkgs; [
    xdg-utils
    desktop-file-utils
    shared-mime-info
    powertop
    acpi
  ];
}
