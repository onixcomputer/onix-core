{ inputs, self, ... }:
let
  # Wasm plugins are arch-independent (wasm32-unknown-unknown) —
  # pick any host system to build them.
  plugins = self.packages.x86_64-linux.wasm-plugins;
  wasm = import "${self}/lib/wasm.nix" { inherit plugins; };

  allMachines = (wasm.evalNickelFile ./machines.ncl).machines;

  # Strip `system` — it's consumed by flake checks (machinesPerSystem)
  # but isn't a clan-core inventory option.
  machines = builtins.mapAttrs (_: m: removeAttrs m [ "system" ]) allMachines;

  users = import ./users.nix { inherit inputs; };
in
{
  inherit machines;
  inherit (users) instances;
}
