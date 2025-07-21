{ inputs, ... }:
let
  inherit (inputs.nixpkgs) lib;

  module_definitions = {
    "tailscale" = import ./tailscale;
  };

in
lib.foldr lib.recursiveUpdate { } [ module_definitions ]
