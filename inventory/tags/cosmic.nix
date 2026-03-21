{ lib, pkgs, ... }:
{
  # COSMIC Desktop Environment (System76)
  # Compositor, panel, applets, settings, file manager, terminal, etc.
  services = {
    desktopManager.cosmic.enable = true;

    # COSMIC's own greeter (replaces tuigreet from greeter.nix)
    displayManager.cosmic-greeter.enable = true;

    # dbus-broker: high-performance D-Bus (default on Arch/Fedora)
    dbus.implementation = "broker";
  };

  # Plymouth boot splash
  boot = {
    plymouth = {
      enable = lib.mkDefault true;
      theme = lib.mkDefault "bgrt";
    };
    consoleLogLevel = lib.mkDefault 0;
    initrd.verbose = lib.mkDefault false;
    kernelParams = lib.mkDefault [
      "quiet"
      "splash"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
    ];
  };

  environment.systemPackages = with pkgs; [
    xdg-utils
    desktop-file-utils
    shared-mime-info
    powertop
    acpi
    bluetui
  ];
}
