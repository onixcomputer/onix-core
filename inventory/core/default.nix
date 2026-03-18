{ inputs, self, ... }:
let
  # Wasm plugins are arch-independent (wasm32-unknown-unknown) —
  # pick any host system to build them.
  plugins = self.packages.x86_64-linux.wasm-plugins;
  wasm = import "${self}/lib/wasm.nix" { inherit plugins; };

  allMachines = (wasm.evalNickelFile ./machines.ncl).machines;

  # Strip fields consumed by our tooling but not by clan-core's inventory.
  machines = builtins.mapAttrs (
    _: m:
    removeAttrs m [
      "system"
      "addresses"
    ]
  ) allMachines;

  users = import ./users.nix { inherit inputs; };
in
{
  inherit machines;
  inherit (users) instances;
}
