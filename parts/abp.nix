{ pkgs, lib, ... }:
lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
  packages.abp = pkgs.callPackage ../pkgs/abp { };
}
