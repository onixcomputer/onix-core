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

  networking.hostName = "bonsai";
  time.timeZone = "America/New_York";

  # GPD screen orientation fixes
  boot.kernelParams = [
    "fbcon=rotate:1"
    "video=eDP-1:panel_orientation=right_side_up"
  ];

  # GRUB wallpaper (theme from grub-theme tag)
  boot.loader.grub2-theme = {
    customResolution = "2880x1920";
    splashImage = grubWallpaper;
  };

  # Remote builder configuration
  nix = {
    buildMachines = [
      {
        protocol = "ssh-ng";
        hostName = "leviathan.cymric-daggertooth.ts.net";
        systems = [
          "x86_64-linux"
        ];
        maxJobs = 7;
        speedFactor = 20;
        supportedFeatures = [
          "nixos-test"
          "benchmark"
          "big-parallel"
          "kvm"
        ];
        mandatoryFeatures = [ ];
        sshUser = "brittonr";
      }
      {
        protocol = "ssh-ng";
        hostName = "britton-desktop";
        systems = [
          "aarch64-linux"
        ];
        maxJobs = 8;
        speedFactor = 15;
        supportedFeatures = [
          "nixos-test"
          "big-parallel"
          "kvm"
        ];
        mandatoryFeatures = [ ];
        sshUser = "brittonr";
      }
    ];
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

  # SSH agent forwarding for remote builds
  programs.ssh.extraConfig = ''
    Host leviathan.cymric-daggertooth.ts.net
      IdentityAgent /run/user/1555/gcr/ssh
    Host britton-desktop
      IdentityAgent /run/user/1555/gcr/ssh
  '';

  # Known host for britton-desktop remote builder
  programs.ssh.knownHosts.britton-desktop = {
    hostNames = [ "britton-desktop" ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIe2N5OW2IY12lTvJZOFnMxw74eA/UhWJvCAd9OhUpsE";
  };

  # GPD hardware sensors for rotation detection
  hardware.sensor.iio.enable = true;

  services = {
    fprintd.enable = true;

    # Override greeter session for niri
    greetd.settings.default_session.command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd /etc/profiles/per-user/brittonr/bin/niri-session";

    # GPD suspend/wake fixes
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
        # RP2350/RP2040 BOOTSEL mode
        SUBSYSTEM=="usb", ATTRS{idVendor}=="2e8a", MODE="0666"
        SUBSYSTEM=="block", ATTRS{idVendor}=="2e8a", MODE="0666"
        # Realtek SD card reader access
        SUBSYSTEM=="usb", ATTRS{idVendor}=="0bda", ATTRS{idProduct}=="0316", MODE="0666", GROUP="plugdev", TAG+="uaccess"
        SUBSYSTEM=="block", ATTRS{idVendor}=="0bda", ATTRS{idProduct}=="0316", GROUP="brittonr", MODE="0660"
        # Allwinner FEL mode (sunxi USB flashing)
        SUBSYSTEM=="usb", ATTR{idVendor}=="1f3a", ATTR{idProduct}=="efe8", MODE="0666", GROUP="plugdev", TAG+="uaccess"
        # Glasgow Digital Interface Explorer
        SUBSYSTEM=="usb", ATTRS{idVendor}=="20b7", ATTRS{idProduct}=="9db1", MODE="0666", GROUP="plugdev", TAG+="uaccess"
        # Rockchip USB (maskrom/loader mode)
        SUBSYSTEM=="usb", ATTR{idVendor}=="2207", MODE="0666"
      '';
    };
  };

  # LTE Modem (Quectel EC25) with 9eSIM support
  # Hardware: Quectel EC25 LTE modem with 9eSIM programmable SIM card
  # Devices:
  #   /dev/ttyUSB0-3 - Serial ports (AT commands on ttyUSB2)
  #   /dev/cdc-wdm0  - QMI control interface
  #
  # eSIM Management (lpac via QMI):
  #   # List profiles
  #   sudo LPAC_APDU_QMI_DEVICE=/dev/cdc-wdm0 LPAC_APDU=qmi lpac profile list | jq
  #
  #   # Get chip info
  #   sudo LPAC_APDU_QMI_DEVICE=/dev/cdc-wdm0 LPAC_APDU=qmi lpac chip info | jq
  #
  #   # Download profile (use activation code from eSIM provider)
  #   sudo LPAC_APDU_QMI_DEVICE=/dev/cdc-wdm0 LPAC_APDU=qmi lpac profile download -a 'LPA:1$rsp.example.com$MATCHING-ID'
  #
  #   # Enable a profile
  #   sudo LPAC_APDU_QMI_DEVICE=/dev/cdc-wdm0 LPAC_APDU=qmi lpac profile enable <ICCID>
  #
  # Network connection (after profile enabled):
  #   sudo systemctl start ModemManager
  #   mmcli -L                                    # List modems
  #   mmcli -m 0                                  # Show modem info
  #   sudo nmcli connection add type gsm con-name "LTE" ifname "*" apn "YOUR_APN"
  #   nmcli connection up LTE
  networking.modemmanager.enable = true;

  environment.systemPackages = with pkgs; [
    signal-desktop
    modemmanager
    libqmi
    libmbim
    lpac # eSIM profile management via QMI
    dolphin-emu # Dolphin Gamecube/Wii emulator
  ];

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
