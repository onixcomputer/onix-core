# Nix-side requirements of the typed Nickel services.
#
# Nickel cannot import NixOS modules or build packages, and a module cannot
# read public artifacts it declares itself. A service declares what it needs
# in the optional sidecar onixos/services/<name>.nix:
#
#   { self, inputs }:
#   {
#     nixosModules = [ inputs.example.nixosModules.default ];  # imported on every OnixOS machine
#     overlays = [ (final: prev: { example = ...; }) ];        # applied to mkFlake's package set
#     inputs = [ "other-service" ];                            # evaluated before this module
#   }
#
# Every listed NixOS module must only declare options until its service
# enables it.
{ self, inputs }:
let
  inherit (inputs.nixpkgs) lib;
  serviceDir = ../services;
  sidecars =
    lib.mapAttrs'
      (
        file: _type:
        lib.nameValuePair (lib.removeSuffix ".nix" file) (
          import (serviceDir + "/${file}") { inherit self inputs; }
        )
      )
      (
        lib.filterAttrs (file: type: type == "regular" && lib.hasSuffix ".nix" file) (
          builtins.readDir serviceDir
        )
      );
in
{
  nixosModules = lib.concatMap (sidecar: sidecar.nixosModules or [ ]) (lib.attrValues sidecars);
  overlays = lib.concatMap (sidecar: sidecar.overlays or [ ]) (lib.attrValues sidecars);
  moduleInputs = lib.mapAttrs (_name: sidecar: sidecar.inputs or [ ]) sidecars;
}
