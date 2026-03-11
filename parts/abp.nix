{ pkgs, ... }:
{
  packages.abp = pkgs.callPackage ../pkgs/abp { };
}
