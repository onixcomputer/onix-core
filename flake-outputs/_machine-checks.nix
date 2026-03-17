# Build all machine configurations as nix flake checks.
# Catches eval/build failures in CI without deploying.
#
# machinesPerSystem is derived from the `system` field in
# inventory/core/machines.ncl — no manual list to maintain.
{
  self,
  lib,
  pkgs,
  system,
  ...
}:
let
  plugins = self.packages.x86_64-linux.wasm-plugins;
  wasm = import ../lib/wasm.nix { inherit plugins; };
  machinesDef = (wasm.evalNickelFile ../inventory/core/machines.ncl).machines;

  # Group machine names by their `system` field from machines.ncl
  machinesPerSystem = builtins.groupBy (name: machinesDef.${name}.system) (lib.attrNames machinesDef);

  nixosMachines = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux (
    lib.mapAttrs' (n: lib.nameValuePair "nixos-${n}") (
      lib.genAttrs (machinesPerSystem.${system} or [ ]) (
        name: self.nixosConfigurations.${name}.config.system.build.toplevel
      )
    )
  );

  darwinMachines = lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin (
    lib.mapAttrs' (n: lib.nameValuePair "darwin-${n}") (
      lib.genAttrs (machinesPerSystem.${system} or [ ]) (
        name: self.darwinConfigurations.${name}.config.system.build.toplevel
      )
    )
  );
in
{
  checks = nixosMachines // darwinMachines;
}
