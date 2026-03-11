{ pkgs, ... }:
{
  packages.ccusage = pkgs.callPackage ../pkgs/ccusage { };
}
