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

  nixpkgs.overlays = [
    (_self: super: {
      # disable greeter reuse, force fresh greeter every time seems to fix issue
      gdm = super.gdm.overrideAttrs (oldAttrs: {
        patches = (oldAttrs.patches or [ ]) ++ [
          # Look for ALEXDEBUG in journalctl -fu display-manager
          ./pmods/gdm-stop-greeter-reuse.patch
        ];
      });
    })
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
    teamviewer
    signal-desktop
  ];
  services.teamviewer.enable = true;

  home-manager.backupFileExtension = "backup";

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

  services = {
    gnome.gnome-keyring.enable = true;
    displayManager.gdm = {
      enable = true;
      debug = true;
      wayland = true;
    };
    fprintd.enable = true;
    fwupd.enable = true; # framework bios/firmware updates
  };

  security.pam.services = {
    gdm.enableGnomeKeyring = true;
    # Disable fingerprint for sudo - password only
    sudo.fprintAuth = false;
  };

  system.stateVersion = "25.05";
}
