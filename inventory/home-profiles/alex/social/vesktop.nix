{ pkgs, ... }:
{
  programs.vesktop = {
    enable = true;
    package = pkgs.vesktop.overrideAttrs (oldAttrs: {
      postPatch = (oldAttrs.postPatch or "") + ''
        cp -f ${
          pkgs.fetchurl {
            url = "https://raw.githubusercontent.com/adeci/wallpapers/refs/heads/main/nixos.gif";
            hash = "sha256-XGpc+QhVqBUvNxIarc50y8qvPAHwziR8pLI2TyBWXsQ=";
          }
        } static/shiggy.gif
      '';
    });
  };
}
