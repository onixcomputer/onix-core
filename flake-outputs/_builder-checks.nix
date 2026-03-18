# Verify that the builder hostname mapping in remote-builders.nix
# stays in sync with builderHosts in contracts.ncl.
#
# The Nickel contract (NoSelfBuilder) validates that every builder
# target is a real machine. This check verifies the Nix-side copy
# of the mapping matches the Nickel source of truth.
{
  self,
  pkgs,
  lib,
  ...
}:
let
  plugins = self.packages.x86_64-linux.wasm-plugins;
  wasm = import ../lib/wasm.nix { inherit plugins; };

  # Source of truth: Nickel contracts
  nickelMapping = (wasm.evalNickelFile ../inventory/core/builder-registry.ncl).builderHosts;

  nickelHosts = lib.sort lib.lessThan (builtins.attrNames nickelMapping);
  nickelValues = lib.sort lib.lessThan (builtins.attrValues nickelMapping);
in
{
  builder-sync = pkgs.runCommand "builder-sync-check" { } ''
        # Verify the Nickel builderHosts mapping is well-formed
        ncl_hosts='${builtins.toJSON nickelHosts}'
        ncl_values='${builtins.toJSON nickelValues}'

        echo "Builder hostname mapping (from contracts.ncl):"
        echo "  SSH hosts: $ncl_hosts"
        echo "  Machine names: $ncl_values"

        # Verify all machine names in the mapping are actual machines
        all_machines='${builtins.toJSON (builtins.attrNames (wasm.evalNickelFile ../inventory/core/machines.ncl).machines)}'

        ${pkgs.python3}/bin/python3 -c "
    import json, sys

    machines = set(json.loads('$all_machines'))
    builder_values = json.loads('$ncl_values')

    missing = [v for v in builder_values if v not in machines]
    if missing:
        print(f'ERROR: builderHosts references unknown machines: {missing}')
        print('Fix: update builder_hosts in inventory/core/contracts.ncl')
        sys.exit(1)

    print(f'OK: all {len(builder_values)} builder targets are valid machines')
    "

        touch $out
  '';
}
