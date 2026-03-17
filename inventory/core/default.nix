{ inputs, self, ... }:
let
  # Wasm plugins are arch-independent (wasm32-unknown-unknown) —
  # pick any host system to build them.
  plugins = self.packages.x86_64-linux.wasm-plugins;
  wasm = import "${self}/lib/wasm.nix" { inherit plugins; };

  machines = wasm.evalNickelFile ./machines.ncl;
  users = import ./users.nix { inherit inputs; };
in
{
  inherit (machines) machines;
  inherit (users) instances;
}
