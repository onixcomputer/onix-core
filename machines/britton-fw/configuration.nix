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
  # timeZone handled by automatic-timezoned via laptop tag

  # GRUB wallpaper (theme from grub-theme tag)
  boot.loader.grub2-theme = {
    customResolution = "2880x1920";
    splashImage = grubWallpaper;
  };

  nix.settings = {
    # Enable experimental features for uid-range support
    experimental-features = [
      "auto-allocate-uids"
      "cgroups"
    ];
    auto-allocate-uids = true;
    # System features for NixOS container tests
    system-features = [
      "uid-range"
      "kvm"
      "nixos-test"
      "big-parallel"
      "benchmark"
    ];
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
