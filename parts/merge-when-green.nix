{ pkgs, ... }:
let
  buildbot-pr-check = pkgs.callPackage ../pkgs/buildbot-pr-check { };
in
{
  packages.merge-when-green = pkgs.callPackage ../pkgs/merge-when-green {
    inherit buildbot-pr-check;
  };
}
