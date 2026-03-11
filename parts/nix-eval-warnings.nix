{ pkgs, ... }:
{
  packages.nix-eval-warnings = pkgs.callPackage ../pkgs/nix-eval-warnings { };
}
