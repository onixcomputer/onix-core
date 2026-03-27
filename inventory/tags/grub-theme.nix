{
  lib,
  pkgs,
  inputs,
  ...
}:
{
  imports = [ inputs.grub2-themes.nixosModules.default ];

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
