{ pkgs, lib, ... }:
lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
  packages.branchfs = pkgs.callPackage ../pkgs/branchfs { };
}
