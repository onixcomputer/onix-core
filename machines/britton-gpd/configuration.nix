{ inputs, pkgs, ... }:
let
  grubWallpaper = pkgs.fetchurl {
    name = "nixos-grub-wallpaper.jpg";
    url = "https://raw.githubusercontent.com/adeci/wallpapers/main/nix-grub-2880x1920.jpg";
    sha256 = "sha256-Xu3KlpNMiZzS2fXYGGx0u0Qch7CoEus6ODwNVL4Bq4U=";
  };
in
{
  imports = [ inputs.grub2-themes.nixosModules.default ];

  networking.hostName = "britton-gpd";
  time.timeZone = "America/New_York";

  # GPD Pocket 4 screen orientation fixes
  boot.kernelParams = [
    "fbcon=rotate:1"
    "video=eDP-1:panel_orientation=right_side_up"
  ];

  # GRUB wallpaper (theme from grub-theme tag)
  boot.loader.grub2-theme = {
    customResolution = "2880x1920";
    splashImage = grubWallpaper;
  };

  nix = {
    settings = {
      trusted-users = [ "brittonr" ];
      substituters = [
        "https://cache.dataaturservice.se/spectrum/"
        "https://cache.snix.dev"
        "https://nix-community.cachix.org"
        "https://cache.nixos.org/"
        "https://attic.radicle.xyz/radicle"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "spectrum-os.org-2:foQk3r7t2VpRx92CaXb5ROyy/NBdRJQG2uX2XJMYZfU="
        "cache.snix.dev-1:miTqzIzmCbX/DyK2tLNXDROk77CbbvcRdWA4y2F8pno="
        "radicle:TruHbueGHPm9iYSq7Gq6wJApJOqddWH+CEo+fsZnf4g="
      ];
    };
  };

  # GPD Pocket 4 specific hardware
  hardware.sensor.iio.enable = true;

  services = {
    fprintd.enable = true;

    # Override greeter session for niri
    greetd.settings.default_session.command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd /etc/profiles/per-user/brittonr/bin/niri-session";

    # GPD Pocket 4 suspend/wake fixes
    udev = {
      # Accelerometer mount matrix for correct orientation
      extraHwdb = ''
        sensor:modalias:acpi:MXC*
         ACCEL_MOUNT_MATRIX=-1, 0, 0; 0, 1, 0; 0, 0, 1
      '';
      # IIO device buffer access and USB wakeup fixes
      extraRules = ''
        SUBSYSTEM=="iio", KERNEL=="iio*", MODE="0666"
        SUBSYSTEM=="iio", KERNEL=="iio*", RUN+="${pkgs.coreutils}/bin/chmod a+rw /sys$devpath/buffer/enable"
        SUBSYSTEM=="iio", KERNEL=="iio*", RUN+="${pkgs.coreutils}/bin/chmod a+rw /sys$devpath/buffer/length"
        ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="258a", ATTRS{idProduct}=="000c", ATTR{power/wakeup}="disabled", ATTR{power/control}="on"
      '';
    };
  };

  environment.systemPackages = with pkgs; [ signal-desktop ];

  # Disable USB controller wakeup to prevent spurious wakes
  systemd.services.disable-usb-wakeup = {
    description = "Disable XHC0 USB controller wakeup";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c 'echo XHC0 > /proc/acpi/wakeup'";
      RemainAfterExit = true;
    };
  };

  # Fix intermittent touchscreen breakage after suspension
  systemd.services.fix-touchscreen = {
    description = "Manually reload i2c_hid_acpi module to fix touchscreen";
    serviceConfig = {
      Type = "oneshot";
      ExecStartPre = "${pkgs.kmod}/bin/modprobe -r i2c_hid_acpi";
      ExecStart = "${pkgs.kmod}/bin/modprobe i2c_hid_acpi";
    };
  };
}
