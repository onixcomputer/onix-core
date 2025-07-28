{ inputs, ... }:
{
  programs.firefox = {
    enable = true;
    profiles.alex = {
      extensions.packages = [
        inputs.firefox-addons.packages."x86_64-linux".ublock-origin
      ];
    };
  };
}
