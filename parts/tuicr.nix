{ pkgs, ... }:
{
  packages.tuicr = pkgs.callPackage ../pkgs/tuicr { };
}
