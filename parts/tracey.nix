{ pkgs, ... }:
{
  packages.tracey = pkgs.callPackage ../pkgs/tracey { };
}
