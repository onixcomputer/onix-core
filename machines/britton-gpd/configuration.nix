{ inputs, pkgs, ... }:
let
  grubWallpaper = pkgs.fetchurl {
    name = "nixos-grub-wallpaper.jpg";
    url = "https://raw.githubusercontent.com/adeci/wallpapers/main/nix-grub-2880x1920.jpg";
    sha256 = "sha256-Xu3KlpNMiZzS2fXYGGx0u0Qch7CoEus6ODwNVL4Bq4U=";
  };
in
{
  # Use nix with radicle-fetcher support (skip tests to avoid build failures)
  # Temporarily disabled - patch doesn't apply to Nix 2.31.2
  # nixpkgs.overlays = [
  #   inputs.self.overlays.nix-radicle
  # ];
  imports = [
    inputs.grub2-themes.nixosModules.default
  ];

  networking = {
    hostName = "britton-gpd";
  };

  time.timeZone = "America/New_York";
  # time.timeZone = "Asia/Bangkok";

  # GPD Pocket 4 screen orientation fixes and kernel tuning
  boot = {
    # fbcon=rotate:1 fixes orientation after grub menu (grub menu itself stays rotated)
    # panel_orientation fixes the display panel orientation detection
    kernelParams = [
      "fbcon=rotate:1"
      "video=eDP-1:panel_orientation=right_side_up"
    ];

    # Kernel parameters for compilation workloads
    # - Swappiness 60: Balanced between keeping working set in RAM vs using ZRAM
    # - Dirty ratios reduced: Prevent large write bursts that stall compilation
    # - Overcommit enabled: Allow memory-hungry compilers to allocate optimistically
    # - Page-cluster 0: Single-page reads optimal for ZRAM (no sequential benefit)
    kernel.sysctl = {
      "vm.swappiness" = 60; # Balanced swapping
      "vm.dirty_ratio" = 15; # Reduce dirty pages
      "vm.dirty_background_ratio" = 5; # Earlier writeback
      "vm.overcommit_memory" = 1; # Allow overcommit for compilation
      "vm.page-cluster" = 0; # Optimize for ZRAM
    };

    loader = {
      timeout = 1;
      grub = {
        timeoutStyle = "menu";
      };
      grub2-theme = {
        enable = true;
        theme = "stylish";
        footer = true;
        customResolution = "2880x1920";
        splashImage = grubWallpaper;
      };
    };
  };

  # Enable iio-sensor-proxy for accelerometer/orientation sensor support
  hardware.sensor.iio.enable = true;

  environment.systemPackages = with pkgs; [
    imagemagick # required for grub2-theme
    signal-desktop
  ];

  zramSwap = {
    enable = true;
    algorithm = "lz4"; # Fast compression
    memoryPercent = 87; # ~56GB of your 64GB RAM (87% of 64GB ≈ 56GB)
    priority = 100; # Higher priority than disk swap
  };

  nix = {
    distributedBuilds = true;
    settings = {
      builders-use-substitutes = true;
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
    buildMachines = [
      #  {
      #   protocol = "ssh-ng";
      #   hostName = "m2.bison-tailor.ts.net";
      #   systems = [ "aarch64-linux" ];
      #   maxJobs = 6;
      #   speedFactor = 2;
      #   supportedFeatures = [
      #     "nixos-test"
      #     "benchmark"
      #     "big-parallel"
      #   ];
      #   mandatoryFeatures = [ ];
      #   sshUser = "root";
      #   sshKey = "/root/.ssh/id_m2";
      # }
      {
        protocol = "ssh-ng";
        hostName = "leviathan.cymric-daggertooth.ts.net";
        systems = [ "x86_64-linux" ];
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
    ];
  };

  programs.ssh = {
    knownHosts = {
      leviathan = {
        hostNames = [ "leviathan.cymric-daggertooth.ts.net" ];
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOEtV2xoOv+N4c5sg5oBqM/Xy+aZHf+5GHOhzXKYduXG";
      };
    };
    extraConfig = ''
      Host leviathan.cymric-daggertooth.ts.net
        IdentityAgent /run/user/1555/gcr/ssh
    '';
  };

  services = {
    gnome.gnome-keyring.enable = true;

    pulseaudio.enable = false;

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    # GPD Pocket 4 fingerprint sensor
    # Works with libfprint driver from: https://github.com/ftfpteams/focaltech-linux-fingerprint-driver
    # Fedora package: libfprint-2-2_1.94.4+tod1_redhat_all_x64_20250219.install
    # Note: Linux/KDE fingerprint support has limitations:
    # - No fingerprint unlock for LUKS encryption on boot
    # - No fingerprint option on session login screen
    # - May randomly not work when resuming from lock screen
    fprintd.enable = true;

    # Keyd for dual-function keys (Caps Lock = Esc on tap, Ctrl on hold)
    keyd = {
      enable = true;
      keyboards = {
        default = {
          ids = [ "*" ];
          settings = {
            main = {
              capslock = "overload(control, esc)";
            };
          };
        };
      };
    };

    greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd /etc/profiles/per-user/brittonr/bin/niri-session";
          user = "greeter";
        };
      };
    };

    # Accelerometer mount matrix for correct orientation in KDE/session
    # Fixes orientation sensor for iio-sensor-proxy
    udev.extraHwdb = ''
      sensor:modalias:acpi:MXC*
       ACCEL_MOUNT_MATRIX=-1, 0, 0; 0, 1, 0; 0, 0, 1
    '';

    # Add udev rules for IIO device buffer access
    udev.extraRules = ''
      # Allow iio-sensor-proxy to access IIO device buffers
      SUBSYSTEM=="iio", KERNEL=="iio*", MODE="0666"
      SUBSYSTEM=="iio", KERNEL=="iio*", RUN+="${pkgs.coreutils}/bin/chmod a+rw /sys$devpath/buffer/enable"
      SUBSYSTEM=="iio", KERNEL=="iio*", RUN+="${pkgs.coreutils}/bin/chmod a+rw /sys$devpath/buffer/length"
    '';
  };

  # Portal services for VM integration
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  security = {
    rtkit.enable = true;
    pam.services = {
      login.enableGnomeKeyring = true;
      greetd.enableGnomeKeyring = true;
      # sudo.fprintAuth = true;
      hyprlock = { };
    };
  };

}
