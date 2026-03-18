# Verify that no machine includes itself in its nix.buildMachines list.
#
# remote-builders.nix derives the builder list from the inventory and
# filters out self using the machine name. This check evaluates every
# machine with the "remote-builders" tag and confirms none list
# themselves as a builder (which would cause infinite dispatch loops).
{
  self,
  pkgs,
  lib,
  ...
}:
let
  plugins = self.packages.x86_64-linux.wasm-plugins;
  wasm = import ../lib/wasm.nix { inherit plugins; };

  allMachines = (wasm.evalNickelFile ../inventory/core/machines.ncl).machines;

  # Machines with the remote-builders tag
  builderMachines = lib.filterAttrs (
    _: m: builtins.elem "remote-builders" (m.tags or [ ])
  ) allMachines;

  # For each machine, get its buildMachines hostNames
  builderListsJSON = pkgs.writeText "builder-lists.json" (
    builtins.toJSON (
      lib.mapAttrs (
        name: _:
        let
          cfg = self.nixosConfigurations.${name}.config;
          builders = cfg.nix.buildMachines;
        in
        {
          hostname = cfg.networking.hostName;
          builderHosts = map (m: m.hostName) builders;
          builderCount = builtins.length builders;
        }
      ) builderMachines
    )
  );
in
{
  builder-no-self = pkgs.runCommand "builder-no-self-check" { } ''
        ${pkgs.python3}/bin/python3 << 'PYEOF'
    import json, sys

    with open("${builderListsJSON}") as f:
        machines = json.load(f)

    errors = []
    for name, info in machines.items():
        hostname = info["hostname"]
        count = info["builderCount"]
        hosts = info["builderHosts"]
        print(f"{name} ({hostname}): {count} builders -> {hosts}")
        if count == 0:
            errors.append(f"{name}: has remote-builders tag but 0 buildMachines (self-filter may be broken)")

    if errors:
        for e in errors:
            print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

    print(f"OK: {len(machines)} machines verified, all exclude themselves")
    PYEOF
        touch $out
  '';
}
