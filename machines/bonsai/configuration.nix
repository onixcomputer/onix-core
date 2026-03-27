{ inputs, pkgs, ... }:
let
  grubWallpaper = pkgs.fetchurl {
    name = "nixos-grub-wallpaper.jpg";
    url = "https://raw.githubusercontent.com/adeci/wallpapers/main/nix-grub-2880x1920.jpg";
    sha256 = "sha256-Xu3KlpNMiZzS2fXYGGx0u0Qch7CoEus6ODwNVL4Bq4U=";
  };
in
{
  imports = [
    inputs.nixos-hardware.nixosModules.gpd-pocket-4
  ];

  # Per-machine home-manager config: monitor layout for GPD Pocket 4
  home-manager.sharedModules = [
    {
      monitors = {
        primary = {
          name = "eDP-1";
          mode = "1600x2560@143.999";
          scale = 2;
          position = {
            x = 0;
            y = 0;
          };
          vrr = false;
        };
        secondary = {
          name = "DP-3";
          mode = "preferred";
          scale = 1;
          position = {
            x = 1280;
            y = 0;
          };
          vrr = false;
        };
        builtin = {
          name = "eDP-1";
        };
      };
    }
  ];

  networking.hostName = "bonsai";
  # timeZone handled by automatic-timezoned via laptop tag

  # GRUB wallpaper (theme from grub-theme tag)
  boot.loader.grub2-theme = {
    customResolution = "2880x1920";
    splashImage = grubWallpaper;
  };

  nix = {
    buildMachines = [
      {
        protocol = "ssh-ng";
        hostName = "britton-desktop";
        systems = [ "aarch64-linux" ];
        maxJobs = 8;
        speedFactor = 15;
        supportedFeatures = [
          "nixos-test"
          "big-parallel"
          "kvm"
        ];
        sshUser = "brittonr";
      }
    ];
  };

  programs.ssh = {
    extraConfig = ''
      Host britton-desktop
        IdentityAgent /run/user/1555/gcr/ssh
    '';
    knownHosts.britton-desktop = {
      hostNames = [ "britton-desktop" ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIe2N5OW2IY12lTvJZOFnMxw74eA/UhWJvCAd9OhUpsE";
    };
  };

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
