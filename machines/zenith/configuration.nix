{ inputs, pkgs, ... }:
let
  grubWallpaper = pkgs.fetchurl {
    name = "nixos-grub-wallpaper.jpg";
    url = "https://raw.githubusercontent.com/adeci/wallpapers/main/nix-grub-1920x1200.png";
    sha256 = "sha256-pJ4NAewz7V4wmggPD02fVYKVqr0di/Bky8ZWWqFgBiQ=";
  };
in
{
  imports = [
    inputs.grub2-themes.nixosModules.default
    ../alex-fw/pmods/macrand.nix
  ];

  networking.hostName = "zenith";
  time.timeZone = "America/New_York";

  # GRUB wallpaper (theme from grub-theme tag)
  boot.loader = {
    efi.canTouchEfiVariables = true;
    grub = {
      enable = true;
      device = "nodev";
      efiSupport = true;
      useOSProber = true;
    };
    grub2-theme = {
      customResolution = "1920x1200";
      splashImage = grubWallpaper;
    };
  };

  # Framework firmware updates
  services.fwupd.enable = true;

  environment.systemPackages = with pkgs; [ os-prober ];
}
