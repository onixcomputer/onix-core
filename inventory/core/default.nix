{ self, ... }:
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

  # Contract-validated user instances from Nickel.
  # profilesBasePath is a Nix path (triggers store copy) — can't be expressed
  # in Nickel. Inject it into every home-manager-profiles instance after eval.
  usersRaw = wasm.evalNickelFile ./users.ncl;

  instances = builtins.mapAttrs (
    _: inst:
    if (inst.module.name or "") == "home-manager-profiles" then
      inst
      // {
        roles = builtins.mapAttrs (
          _: role:
          role
          // {
            settings = (role.settings or { }) // {
              profilesBasePath = ../home-profiles;
            };
          }
        ) inst.roles;
      }
    else
      inst
  ) usersRaw.instances;
in
{
  inherit machines instances;
}
