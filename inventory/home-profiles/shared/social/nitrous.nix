{ inputs, pkgs, ... }:
{
  home.packages = [
    inputs.nitrous.packages.${pkgs.system}.default
  ];
}
