# Overlays for mkFlake's package set.
#
# Package handles in typed Nickel modules (`interface.packages`) resolve
# against mkFlake's own nixpkgs import, not the machine's `pkgs`. Apply the
# overlays every machine gets from inventory/tags/common/shared-nix.nix, so a
# handle is the derivation the machine itself would build, then the service
# sidecars' overlays (onixos/nix/service-sidecars.nix).
{ self, inputs }:
let
  inherit (inputs.nixpkgs) lib;
  sidecars = import ./service-sidecars.nix { inherit self inputs; };
  sharedNixOverlay =
    final: prev:
    let
      # shared-nix.nix's overlays read only `pkgs.stdenv.hostPlatform`.
      sharedNix = import ../../inventory/tags/common/shared-nix.nix {
        _class = "nixos";
        inherit lib self inputs;
        pkgs = final;
      };
    in
    lib.composeManyExtensions sharedNix.nixpkgs.overlays final prev;
in
[ sharedNixOverlay ] ++ sidecars.overlays
