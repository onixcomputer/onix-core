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
    ./pmods/macrand.nix # MAC address randomization utilities
  ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      rocmPackages.clr.icd
    ];
  };

  networking = {
    hostName = "alex-fw";
  };

  time.timeZone = "America/New_York";

  hardware.printers = {
    ensurePrinters = [
      {
        name = "XeroxWorkCentre";
        location = "Office";
        description = "Xerox WorkCentre 6605DN";
        deviceUri = "ipp://192.168.50.5:631/ipp/print";
        model = "everywhere";
      }
    ];
    ensureDefaultPrinter = "XeroxWorkCentre";
  };

  environment.systemPackages = with pkgs; [
    imagemagick # required for grub2-theme
    os-prober
    signal-desktop
    atlauncher
  ];

  boot.loader = {
    timeout = 1;
    grub = {
      timeoutStyle = "menu";
      useOSProber = true;
    };
    grub2-theme = {
      enable = true;
      theme = "stylish";
      footer = true;
      customResolution = "2880x1920";
      splashImage = grubWallpaper;
    };
  };

  boot.kernel.sysctl = {
    "vm.swappiness" = 60; # Balanced swapping
    "vm.dirty_ratio" = 15; # Reduce dirty pages
    "vm.dirty_background_ratio" = 5; # Earlier writeback
    "vm.overcommit_memory" = 1; # Allow overcommit for compilation
    "vm.page-cluster" = 0; # Optimize for ZRAM
  };

  zramSwap = {
    enable = true;
    algorithm = "lz4"; # compression
    memoryPercent = 87; # ~56GB of 64GB RAM
    priority = 100; # prio over disk swap
  };

  services = {
    gnome.gnome-keyring.enable = true;
    fprintd.enable = true;
    fwupd.enable = true; # framework bios/firmware updates

    # Network printing support
    printing = {
      enable = true;
      browsing = true; # Enable network printer discovery
      defaultShared = false; # Don't share local printers
      drivers = with pkgs; [
        gutenprint # Common printer drivers including Xerox
        hplip # HP printer drivers
        epson-escpr2 # Epson drivers
        brlaser # Brother laser printer drivers
        splix # Samsung/Xerox SPL printers
      ];
    };

    # Auto-configure Xerox WorkCentre 6605DN
    avahi = {
      enable = true; # Already enabled in tags/all.nix but explicit here for clarity
      nssmdns4 = true; # Enable .local domain resolution
      openFirewall = true; # Open firewall for mDNS
    };

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
  };

  security.pam.services = {
    login.enableGnomeKeyring = true;
    greetd.enableGnomeKeyring = true;
    sudo.fprintAuth = false;
    hyprlock = { };
  };
}
