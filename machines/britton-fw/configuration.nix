{ inputs, pkgs, ... }:
let
  grubWallpaper = pkgs.fetchurl {
    name = "nixos-grub-wallpaper.jpg";
    url = "https://raw.githubusercontent.com/adeci/wallpapers/main/nix-grub-2880x1920.jpg";
    sha256 = "sha256-Xu3KlpNMiZzS2fXYGGx0u0Qch7CoEus6ODwNVL4Bq4U=";
  };
  streetWallpaper = pkgs.fetchurl {
    name = "street-wallpaper.png";
    url = "https://raw.githubusercontent.com/adeci/wallpapers/main/street-full.jpg";
    sha256 = "sha256-XlSm8RzGwowJMT/DQBNwfsU4V6QuvP4kvwVm1pzw6SM=";
  };
in
{
  imports = [
    inputs.grub2-themes.nixosModules.default
    inputs.sddm-sugar-candy-nix.nixosModules.default
  ];

  networking = {
    hostName = "britton-fw";
    networkmanager.enable = true;
  };

  time.timeZone = "America/New_York";

  environment.systemPackages = with pkgs; [
    imagemagick # required for grub2-theme
    claude-code
  ];
  zramSwap = {
    enable = true;
    algorithm = "lz4"; # Fast compression
    memoryPercent = 87; # ~56GB of your 64GB RAM (87% of 64GB ≈ 56GB)
    priority = 100; # Higher priority than disk swap
  };

  # AIDEV-NOTE: Kernel tuning for compilation workloads
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

  home-manager.backupFileExtension = "backup";

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

  services = {
    #custom tokyo night theme
    displayManager.sddm = {
      enable = true;
      wayland.enable = true;
      sugarCandyNix = {
        enable = true;
        settings = {
          Background = streetWallpaper;
          ScreenWidth = 2880;
          ScreenHeight = 1920;
          FormPosition = "left";
          HaveFormBackground = true;
          PartialBlur = true;

          MainColor = "white";
          AccentColor = "#668ac4";
          BackgroundColor = "#1a1b26";
          OverrideLoginButtonTextColor = "white";

          HeaderText = "";
          DateFormat = "dddd, MMMM d";
          HourFormat = "HH:mm";

          ForceLastUser = true;
          ForceHideCompletePassword = true;
          ForcePasswordFocus = true;
        };
      };
    };

    fwupd.enable = true; # framework bios/firmware updates
  };

  system.stateVersion = "25.05";
}
