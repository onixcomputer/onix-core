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

  networking.hostName = "britton-fw";
  time.timeZone = "America/New_York";

  # GRUB wallpaper (theme from grub-theme tag)
  boot.loader.grub2-theme = {
    customResolution = "2880x1920";
    splashImage = grubWallpaper;
  };

  nix = {
    settings = {
      # Enable experimental features for uid-range support
      experimental-features = [
        "auto-allocate-uids"
        "cgroups"
      ];
      auto-allocate-uids = true;
      trusted-users = [ "brittonr" ];
      # System features for NixOS container tests
      system-features = [
        "uid-range"
        "kvm"
        "nixos-test"
        "big-parallel"
        "benchmark"
      ];
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

  services = {
    # Framework laptop fingerprint
    fprintd.enable = true;

    # Framework firmware updates
    fwupd.enable = true;

    # Override greeter session for niri
    greetd.settings.default_session.command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd /etc/profiles/per-user/brittonr/bin/niri-session";
  };

  # Framework laptop fingerprint for sudo
  security.pam.services.sudo.fprintAuth = true;

  environment.systemPackages = with pkgs; [ signal-desktop ];
}
