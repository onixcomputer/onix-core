# Verify remote builder list invariants.
#
# remote-builders.nix derives the builder list from the inventory and filters
# out self using the machine name. This check evaluates every machine with the
# "remote-builders" tag and confirms none list themselves as a builder (which
# would cause infinite dispatch loops). It also guards known non-routable
# builder targets such as britton-air.
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

  # Machines with the remote-builders tag.
  builderMachines = lib.filterAttrs (
    _: m: builtins.elem "remote-builders" (m.tags or [ ])
  ) allMachines;

  # For each machine, get its evaluated nix.buildMachines entries.
  builderListsJSON = pkgs.writeText "builder-lists.json" (
    builtins.toJSON (
      lib.mapAttrs (
        name: _:
        let
          cfg = self.nixosConfigurations.${name}.config;
          builders = cfg.nix.buildMachines;
          machine = allMachines.${name};
        in
        {
          hostname = cfg.networking.hostName;
          lan = machine.addresses.lan or null;
          builderHosts = map (m: m.hostName) builders;
          builders = map (m: {
            inherit (m) hostName systems supportedFeatures;
          }) builders;
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
        lan = info.get("lan")
        hosts = info["builderHosts"]
        print(f"{name} ({hostname}): {len(hosts)} builders -> {hosts}")

        self_hosts = {name, hostname}
        if lan:
            self_hosts.add(lan)
        overlap = sorted(self_hosts.intersection(hosts))
        if overlap:
            errors.append(f"{name}: includes itself as remote builder via {overlap}")

        if "192.168.1.60" in hosts:
            errors.append(
                f"{name}: includes britton-air 192.168.1.60 despite empty allowedConsumers"
            )

        for builder in info["builders"]:
            if builder["hostName"] == "192.168.1.60":
                systems = builder.get("systems", [])
                if "aarch64-linux" in systems:
                    errors.append(
                        f"{name}: advertises nested aarch64-linux through britton-air Darwin endpoint"
                    )

    if errors:
        for e in errors:
            print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

    print(f"OK: {len(machines)} machines verified, builder reachability guards passed")
    PYEOF
        touch $out
  '';
}
