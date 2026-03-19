# Service inventory loader.
#
# Service data lives in services.ncl (validated by Nickel contracts).
# Nix path stubs (extraModules) are merged in via recursiveUpdate.
{ inputs, self, ... }:
let
  inherit (inputs.nixpkgs) lib;

  # Wasm plugins — arch-independent, pick any host system.
  plugins = self.packages.x86_64-linux.wasm-plugins;
  wasm = import "${self}/lib/wasm.nix" { inherit plugins; };

  # Contract-validated service instances from Nickel.
  nclServices = wasm.evalNickelFile ./services.ncl;

  # Thin stubs that add Nix-only extraModules paths.
  nixStubs = [
    (import ./borgbackup.nix)
    (import ./matrix-synapse.nix)
  ];
in
lib.foldr lib.recursiveUpdate nclServices nixStubs
