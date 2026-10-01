# Verify that farm workers cannot recurse, clients use authenticated ingress,
# and independent SSH builders retain their existing reachability boundaries.
{
  self,
  pkgs,
  lib,
  ...
}:
let
  plugins = self.packages.x86_64-linux.wasm-plugins;
  wasm = import ../lib/wasm.nix { inherit plugins; };
  aspen3Name = "aspen3";
  leviathanHostName = "leviathan.cymric-daggertooth.ts.net";
  leviathanBuildSystem = "x86_64-linux";
  leviathanTargetSystem = "aarch64-linux";
  leviathanSshUser = "brittonr";

  allMachines = self.lib.machines.definitions;
  invalidBuilderTargetEvaluation = builtins.tryEval (
    builtins.deepSeq (wasm.evalNickelFile ../inventory/tags/fixtures/invalid-builder-target-empty-ssh-host.ncl) true
  );
  farmWorkers = [
    "aspen1"
    "aspen2"
  ];
  farmClients = [
    "bonsai"
    "aspen3"
    "britton-desktop"
  ];

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
          isFarmWorker = cfg.services.nix-grpc-daemon.enable or false;
        in
        {
          hostname = cfg.networking.hostName;
          lan = machine.addresses.lan or null;
          inherit isFarmWorker;
          distributedBuilds = cfg.nix.distributedBuilds;
          aspenKnownHost = cfg.programs.ssh.knownHosts.aspen1 or null;
          builderHosts = map (m: m.hostName) builders;
          leviathanKnownHost = cfg.programs.ssh.knownHosts.leviathan or null;
          builders = map (m: {
            inherit (m)
              hostName
              protocol
              sshKey
              sshUser
              supportedFeatures
              systems
              ;
          }) builders;
        }
        // lib.optionalAttrs isFarmWorker {
          worker = {
            inherit (cfg.services.nix-grpc-daemon)
              listen
              accessRules
              anonymousRole
              trustedProxies
              ;
            publicPorts = cfg.networking.firewall.allowedTCPPorts;
            cacheUrl = cfg.services.nix-grpc-daemon.niks3.cacheUrl;
            pushFlags = cfg.services.nix-grpc-daemon.niks3.pushFlags;
            signingKeys = cfg.services.nix-grpc-daemon.niks3.publicKeys;
            queueActivation = cfg.systemd.sockets.niks3-auto-upload.wantedBy;
            queueGuard = cfg.systemd.services.niks3-auto-upload.unitConfig.ConditionPathExists;
          };
        }
      ) builderMachines
    )
  );
in
{
  builder-no-self = pkgs.runCommand "builder-no-self-check" { } ''
        # r[verify onix.build_farm.topology]
        # r[verify onix.build_farm.authentication]
        # r[verify onix.build_farm.publication]
        # r[verify onix.remote_builder.routing.invalid]
        ${lib.optionalString invalidBuilderTargetEvaluation.success ''
          echo "the empty builder SSH host fixture passed its Nickel contract" >&2
          exit 1
        ''}

        ${pkgs.python3}/bin/python3 << 'PYEOF'
    import json, sys
    from urllib.parse import parse_qs, urlsplit

    with open("${builderListsJSON}") as f:
        machines = json.load(f)

    aspen3_name = "${aspen3Name}"
    leviathan_host = "${leviathanHostName}"
    leviathan_build_system = "${leviathanBuildSystem}"
    leviathan_target_system = "${leviathanTargetSystem}"
    leviathan_ssh_user = "${leviathanSshUser}"
    farm_workers = set(json.loads('${builtins.toJSON farmWorkers}'))
    farm_clients = set(json.loads('${builtins.toJSON farmClients}'))

    errors = []
    for name, info in machines.items():
        hostname = info["hostname"]
        lan = info.get("lan")
        builders = info["builders"]
        hosts = [
            urlsplit(builder["hostName"]).hostname
            if "://" in builder["hostName"] else builder["hostName"]
            for builder in builders
        ]
        print(f"{name} ({hostname}): {len(hosts)} builders -> {hosts}")

        self_hosts = {name, hostname}
        if lan:
            self_hosts.add(lan)
        overlap = sorted(self_hosts.intersection(hosts))
        if overlap:
            errors.append(f"{name}: includes itself as remote builder via {overlap}")

        grpc_builders = [
            builder for builder in builders
            if builder["hostName"].startswith("grpc://")
        ]
        if info["isFarmWorker"] != (name in farm_workers):
            errors.append(f"{name}: unexpected farm worker admission")
        if name in farm_workers:
            if builders or info["distributedBuilds"]:
                errors.append(f"{name}: farm worker can recursively dispatch remote builds")
            worker = info["worker"]
            if worker["anonymousRole"] is not None:
                errors.append(f"{name}: anonymous farm access is enabled")
            expected_identities = (
                {f"ci-{client}" for client in farm_clients}
                | {f"worker-{worker}" for worker in farm_workers}
                | {"lb-aspen1"}
            )
            actual_identities = {rule["cn"] for rule in worker["accessRules"]}
            if actual_identities != expected_identities:
                errors.append(f"{name}: farm identity authorization differs from admission")
            if worker["trustedProxies"] != ["lb-aspen1"]:
                errors.append(f"{name}: forwarded identity trusted from an unexpected proxy")
            if 50052 in worker["publicPorts"]:
                errors.append(f"{name}: worker RPC port is exposed beyond the Tailnet firewall")
            if worker["listen"].startswith(("0.0.0.0:", "[::]:")):
                errors.append(f"{name}: worker listener is not bound to its private address")
            if worker["cacheUrl"] != "http://100.100.103.95:39400" or not worker["signingKeys"]:
                errors.append(f"{name}: farm output cache is missing its admitted endpoint or trust")
            push_flags = worker["pushFlags"]
            for flag in ("--parallel-pushes", "--max-concurrent-uploads"):
                if flag not in push_flags or push_flags[push_flags.index(flag) + 1:][:1] != ["1"]:
                    errors.append(f"{name}: {flag} does not bound farm publication")
            if worker["queueActivation"] or worker["queueGuard"] != "/run/niks3-maintenance-window":
                errors.append(f"{name}: farm activation bypasses maintenance queue admission")
        if name in farm_clients:
            if len(grpc_builders) != 1:
                errors.append(f"{name}: expected one admitted Linux farm route")
            for builder in grpc_builders:
                uri = urlsplit(builder["hostName"])
                query = parse_qs(uri.query)
                if uri.hostname != "aspen1.local" or uri.port != 50051:
                    errors.append(f"{name}: farm route bypasses admitted ingress")
                if builder["protocol"] is not None or builder["systems"] != ["x86_64-linux"]:
                    errors.append(f"{name}: farm route advertises an unadmitted transport or system")
                if query.get("system") != ["x86_64-linux"] or "insecure" in query:
                    errors.append(f"{name}: farm route omits its system or bypasses TLS")
                for key in ("ca-cert", "client-cert", "client-key"):
                    values = query.get(key, [])
                    if len(values) != 1 or not values[0].startswith("/"):
                        errors.append(f"{name}: farm route lacks runtime {key}")
                if any(
                    host in hosts
                    for host in ("10.10.10.1", "100.100.103.95")
                ):
                    errors.append(f"{name}: client bypasses farm scheduling through an old worker route")
        elif grpc_builders:
            errors.append(f"{name}: unadmitted farm client route")

        aspen_known_host = info.get("aspenKnownHost")
        if not aspen_known_host or "aspen1.local" not in aspen_known_host.get("hostNames", []):
            errors.append(f"{name}: farm cutover lost Aspen1's SSH deployment host-key binding")

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

        if name == aspen3_name:
            leviathan_builders = [
                builder
                for builder in info["builders"]
                if builder["hostName"] == leviathan_host
            ]
            if len(leviathan_builders) != 1:
                errors.append(
                    f"positive: {name} must have exactly one Leviathan cross builder"
                )
            else:
                builder = leviathan_builders[0]
                systems = builder.get("systems", [])
                if systems != [leviathan_build_system]:
                    errors.append(
                        f"positive: Leviathan must use build platform {leviathan_build_system}, got {systems}"
                    )
                if leviathan_target_system in systems:
                    errors.append(
                        f"negative: Leviathan must not advertise native {leviathan_target_system}"
                    )
                if builder.get("protocol") != "ssh-ng":
                    errors.append("positive: Leviathan must use the ssh-ng protocol")
                if builder.get("sshUser") != leviathan_ssh_user:
                    errors.append(
                        f"positive: Leviathan must use SSH user {leviathan_ssh_user}"
                    )
                if not builder.get("sshKey"):
                    errors.append("negative: Leviathan must not omit its SSH key")

            known_host = info.get("leviathanKnownHost")
            if known_host is None:
                errors.append("negative: aspen3 must not omit the Leviathan host key")
            else:
                if leviathan_host not in known_host.get("hostNames", []):
                    errors.append(
                        "positive: the Leviathan known-host entry must cover its builder hostname"
                    )
                if not known_host.get("publicKey", "").startswith("ssh-ed25519 "):
                    errors.append(
                        "negative: the Leviathan known-host entry must contain an Ed25519 key"
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
