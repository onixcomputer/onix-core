{ pkgs, lib, ... }:
let
  traceyPkg = pkgs.callPackage ../pkgs/tracey { };
in
lib.optionalAttrs (builtins.elem pkgs.stdenv.hostPlatform.system (traceyPkg.meta.platforms or [ ]))
  {
    packages.tracey = traceyPkg;
  }
