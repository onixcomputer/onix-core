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
    inputs.grub2-themes.nixosModules.default
  ];

  networking = {
    hostName = "britton-fw";
  };

  #time.timeZone = "America/New_York";
  time.timeZone = "Asia/Bangkok";

  environment.systemPackages = with pkgs; [
    imagemagick # required for grub2-theme
    signal-desktop
  ];

  services.udev.packages = [ pkgs.android-udev-rules ];
  zramSwap = {
    enable = true;
    algorithm = "lz4"; # Fast compression
    memoryPercent = 87; # ~56GB of your 64GB RAM (87% of 64GB ≈ 56GB)
    priority = 100; # Higher priority than disk swap
  };

  # - Swappiness 60: Balanced between keeping working set in RAM vs using ZRAM
  # - Dirty ratios reduced: Prevent large write bursts that stall compilation
  # - Overcommit enabled: Allow memory-hungry compilers to allocate optimistically
  # - Page-cluster 0: Single-page reads optimal for ZRAM (no sequential benefit)
  # Kernel parameters for compilation workloads
  boot.kernel.sysctl = {
    "vm.swappiness" = 60; # Balanced swapping
    "vm.dirty_ratio" = 15; # Reduce dirty pages
    "vm.dirty_background_ratio" = 5; # Earlier writeback
    "vm.overcommit_memory" = 1; # Allow overcommit for compilation
    "vm.page-cluster" = 0; # Optimize for ZRAM
  };

  boot.loader = {
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

  nix = {
    distributedBuilds = true;
    settings.builders-use-substitutes = true;
    buildMachines = [
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
          command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd Hyprland";
          user = "greeter";
        };
      };
    };
    fwupd.enable = true; # framework bios/firmware updates
  };

  security.pam.services = {
    login.enableGnomeKeyring = true;
    greetd.enableGnomeKeyring = true;
    sudo.fprintAuth = false;
    hyprlock = { };
  };
}
