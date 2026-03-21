{ inputs, pkgs, ... }:
{
  home.packages = [
    inputs.nitrous.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
