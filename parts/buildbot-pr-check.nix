{ pkgs, ... }:
{
  packages.buildbot-pr-check = pkgs.callPackage ../pkgs/buildbot-pr-check { };
}
