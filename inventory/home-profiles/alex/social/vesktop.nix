{ pkgs, ... }:
{
  programs.vesktop = {
    enable = true;
    package = pkgs.vesktop.overrideAttrs (oldAttrs: {
      nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ pkgs.imagemagick ];
      postPatch = (oldAttrs.postPatch or "") + ''
        convert -coalesce ${
          pkgs.fetchurl {
            url = "https://raw.githubusercontent.com/adeci/wallpapers/refs/heads/main/nixos.gif";
            hash = "sha256-XGpc+QhVqBUvNxIarc50y8qvPAHwziR8pLI2TyBWXsQ=";
          }
        } static/splash.webp

        # Fix EACCES permission denied when @electron/fuses tries to modify electron binary
        # Remove electronFuses from package.json since we can't write to the binary
        # copied from the read-only Nix store
        ${pkgs.jq}/bin/jq 'del(.build.electronFuses)' package.json > package.json.tmp
        mv package.json.tmp package.json
      '';
    });
  };

  xdg.desktopEntries.vesktop = {
    name = "Vesktop";
    exec = "vesktop --enable-features=UseOzonePlatform --ozone-platform=wayland --enable-wayland-ime --disable-gpu-sandbox %U";
    icon = "vesktop";
    terminal = false;
    type = "Application";
    categories = [
      "Network"
      "InstantMessaging"
    ];
  };
}
