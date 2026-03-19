# Service inventory loader.
#
# Data-only service instances live in services.ncl (validated by
# Nickel contracts). Services needing Nix-specific features
# (extraModules) remain as .nix files and are merged in here.
{ inputs, self, ... }:
let
  inherit (inputs.nixpkgs) lib;

  # Wasm plugins — arch-independent, pick any host system.
  plugins = self.packages.x86_64-linux.wasm-plugins;
  wasm = import "${self}/lib/wasm.nix" { inherit plugins; };

  # Contract-validated service instances from Nickel.
  nclServices = wasm.evalNickelFile ./services.ncl;

  # Services that need Nix paths (extraModules) stay as .nix.
  nixServices = {
    borgbackup = import ./borgbackup.nix { inherit inputs; };
    matrix-synapse = import ./matrix-synapse.nix { inherit inputs; };
  };
in
lib.foldr lib.recursiveUpdate nclServices (lib.attrValues nixServices)
