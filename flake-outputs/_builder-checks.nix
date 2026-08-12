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
  builderTargetData = wasm.evalNickelFile ../inventory/tags/builder-targets.ncl;
  invalidBuilderTargetEvaluation = builtins.tryEval (
    builtins.deepSeq (wasm.evalNickelFile ../inventory/tags/fixtures/invalid-builder-target-empty-ssh-host.ncl) true
  );
  expectedAspenBuilderHost = "aspen1.local";
  staleAspenBuilderHost = "10.10.10.1";
  aspenTarget = lib.findFirst (target: target.name == "aspen1") null builderTargetData.targets;
  configuredAspenBuilderHost = if aspenTarget == null then null else aspenTarget.sshHost or null;
  desktopConfig = self.nixosConfigurations.britton-desktop.config;
  desktopBuilderHosts = map (builder: builder.hostName) desktopConfig.nix.buildMachines;
  desktopAspenHostNames = desktopConfig.programs.ssh.knownHosts.aspen1.hostNames or [ ];

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
        # Positive and negative coverage for
        # r[verify onix.remote_builder.routing.contract],
        # r[verify onix.remote_builder.routing.aspen],
        # r[verify onix.remote_builder.routing.selection],
        # r[verify onix.remote_builder.routing.host_key], and
        # r[verify onix.remote_builder.routing.invalid].
        ${lib.optionalString (configuredAspenBuilderHost != expectedAspenBuilderHost) ''
          echo "Aspen must declare ${expectedAspenBuilderHost} as its builder endpoint" >&2
          exit 1
        ''}
        ${lib.optionalString (!(builtins.elem expectedAspenBuilderHost desktopBuilderHosts)) ''
          echo "britton-desktop must select ${expectedAspenBuilderHost} as a builder" >&2
          exit 1
        ''}
        ${lib.optionalString (builtins.elem staleAspenBuilderHost desktopBuilderHosts) ''
          echo "britton-desktop must not select the cluster-only Aspen endpoint" >&2
          exit 1
        ''}
        ${lib.optionalString (!(builtins.elem expectedAspenBuilderHost desktopAspenHostNames)) ''
          echo "Aspen's managed host key must bind ${expectedAspenBuilderHost}" >&2
          exit 1
        ''}
        ${lib.optionalString invalidBuilderTargetEvaluation.success ''
          echo "the empty builder SSH host fixture passed its Nickel contract" >&2
          exit 1
        ''}

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
