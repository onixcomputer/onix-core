{ pkgs, ... }:
{
  packages.iroh-ssh = pkgs.callPackage ../pkgs/iroh-ssh { };
}
