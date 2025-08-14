{
  inputs,
  pkgs,
  ...
}:
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

  networking = {
    hostName = "alex-fw";
    networkmanager.enable = true;
  };

  time.timeZone = "America/New_York";

  environment.systemPackages = with pkgs; [
    imagemagick # required for grub2-theme
    claude-code
    comma
    os-prober
    gh
    signal-desktop
    nix-output-monitor
    pamtester
  ];

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

    greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd Hyprland";
          user = "greeter";
        };
      };
    };
  };

  home-manager.backupFileExtension = "backup";

  # Configure pam-any for simultaneous auth
  # security.pam-any = {
  #   enable = true;
  #   services = {
  #     # Test service for pam-any
  #     "pam-any-test" = {
  #       enable = true;
  #       mode = "One";  # Accept either method
  #       control = "required";
  #       order = 10000;
  #       modules = {
  #         # These are PAM service names that pam-any will call
  #         "test-fingerprint" = "Fingerprint";
  #         "test-password" = "Password";
  #       };
  #     };
  #   };
  # };

  security.pam.services = {
    login.enableGnomeKeyring = true;
    greetd.enableGnomeKeyring = true;
    sudo.fprintAuth = false;
  };

  system.stateVersion = "25.05";
}
