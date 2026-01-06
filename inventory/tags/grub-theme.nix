{ lib, pkgs, ... }:
{
  # Note: grub2-themes module must be imported in machine config
  # (NixOS module system requires option declarations before definitions)

  # ImageMagick required for grub2-theme image processing
  environment.systemPackages = [ pkgs.imagemagick ];

  boot.loader = {
    timeout = lib.mkDefault 1;
    grub.timeoutStyle = lib.mkDefault "menu";

    # Stylish theme with footer, resolution configured per-machine
    grub2-theme = {
      enable = lib.mkDefault true;
      theme = lib.mkDefault "stylish";
      footer = lib.mkDefault true;
      # customResolution and splashImage should be set per-machine
    };
  };
}
