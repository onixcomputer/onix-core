# Scheduled mTLS Nix build farm: node role.
#
# Port of the node role of onix-core's Clan nix-build-farm service
# (modules/nix-build-farm, pki.nix): same settings, defaults and NixOS output,
# and the per-machine nix-build-farm-node certificate. The sidecar
# nix-build-farm.nix imports nix-grpc-store's nixos/server.nix and adds
# onix-core's fork-built nix-grpc-store and the niks3 client to the package
# set. Balancer and client roles are not ported.
#
# Where Nickel cannot follow Clan:
# - The machine name is args.machine_name (Clan: clan.core.settings.machine.name).
# - cache_public_key replaces Clan's eval-time read of
#   vars/shared/niks3-<cache_instance>-storage/signing-key-public/value.
# - The colocated niks3 uploader declares niks3-<cache_instance>-api; this
#   role wires it and fails without that uploader, as Clan's lookup did.
# - The tailscale0 address probe must run unsandboxed ("+"), so it lives in
#   /etc/<instance>-wait-worker-address with iproute2 and jq on the unit path.
# - nix-build-farm-ca is not declared: OnixOS deploys every declared secret,
#   and Clan never deploys the CA key (deploy = false). The node certificate
#   is therefore declared without its CA dependency; its generator still
#   expects the CA under $in/<instance>-ca like Clan's.
fun onix =>
  let nixlib = import "../lib/nixos.ncl" in
  let MaxJobs = std.contract.from_predicate (fun n => std.is_number n && n % 1 == 0 && n >= 1 && n <= 63) in
  let shell_quote = fun value => "'%{std.string.replace "'" "'\\''" value}'" in
  let unique = fun values =>
    std.array.fold_left (fun acc value => if std.array.elem value acc then acc else acc @ [value]) [] values
  in
  let endpoint = fun host port =>
    if std.string.contains ":" host then "[%{host}]:%{std.to_string port}" else "%{host}:%{std.to_string port}"
  in
  let wait_script = fun worker_address =>
    m%"
      #!/bin/sh
      set -eu
      for attempt in $(seq 1 60); do
        if ip -json address show dev tailscale0 2>/dev/null \
          | jq -e --arg address %{shell_quote worker_address} \
            'any(.[].addr_info[]; .local == $address)' >/dev/null; then
          exit 0
        fi
        sleep 1
      done
      echo 'Farm worker Tailnet listener address is not ready' >&2
      exit 1
    "%
  in
  let leaf_generator = fun ca_name common_name sans =>
    m%"
      umask 077
      ca="$in"/%{shell_quote ca_name}
      openssl x509 -checkend 31536000 -noout -in "$ca/ca-cert"
      openssl req -new -newkey rsa:3072 -noenc -sha256 \
        -subj %{shell_quote "/CN=%{common_name}"} \
        -keyout "$out/key" -out leaf.csr
      cat > leaf.ext <<'EOF'
      basicConstraints=critical,CA:FALSE
      keyUsage=critical,digitalSignature,keyEncipherment
      extendedKeyUsage=serverAuth,clientAuth
      subjectKeyIdentifier=hash
      authorityKeyIdentifier=keyid,issuer
      subjectAltName=%{sans}
      EOF
      openssl x509 -req -sha256 -days 365 \
        -in leaf.csr -CA "$ca/ca-cert" -CAkey "$ca/key" \
        -set_serial "0x$(openssl rand -hex 16)" \
        -extfile leaf.ext -out "$out/cert"
      openssl verify -CAfile "$ca/ca-cert" -purpose sslclient "$out/cert"
      openssl verify -CAfile "$ca/ca-cert" -purpose sslserver "$out/cert"
      cp "$ca/ca-cert" "$out/ca-cert"
    "%
  in
  ({
    interface = {
      manifest = {
        name = "onix-core/nix-build-farm",
        description = "Private mTLS gRPC Nix build workers publishing signed outputs to niks3.",
        categories = ["nix", "build"],
      },
      portability = {
        status = 'platform_specific,
        requires.typed_namespaces = ["artifacts", "artifact_wiring"],
        platform_leaves = [
          {
            namespace = "nixos",
            targets = ["nixos"],
            rationale = "nix-grpc-daemon, nix.conf, firewall and systemd ordering are NixOS services",
          },
        ],
      },
      packages = ["onix-core-nix-grpc-store", "onix-core-niks3", "iproute2", "jq"],
      roles.node = {
        address
          | doc "Tailnet IP used for the worker listener and scheduler advertisement."
          | onix.IpAddress,
        scheduler_address
          | doc "Scheduler host:port; empty uses the in-process scheduler."
          | String
          | priority -5
          = "",
        is_scheduler
          | doc "Run the scheduler as well as the local builder."
          | Bool
          | priority -5
          = false,
        max_jobs
          | doc "Concurrent local builds, from 1 through 63."
          | MaxJobs
          | priority -5
          = 16,
        min_free
          | doc "Stop accepting builds below this free space under /nix."
          | onix.NonEmptyString
          | priority -5
          = "100G",
        cache_url
          | doc "Private niks3 publication and binary cache endpoint."
          | onix.Url
          | priority -5
          = "http://100.100.103.95:39400",
        cache_instance
          | doc "Existing niks3 instance supplying API token and public signing key."
          | onix.NonEmptyString
          | priority -5
          = "nix-cache",
        cache_public_key
          | doc "Public signing key of cache_url (niks3-<cache_instance>-storage/signing-key-public)."
          | onix.NixPublicKey,
        allowed_clients
          | doc "Exact machine names authorized as ci- certificate principals."
          | Array onix.Hostname
          | priority -5
          = [],
        worker_names
          | doc "Exact machine names authorized as worker- certificate principals."
          | Array onix.Hostname
          | priority -5
          = [],
        balancer_names
          | doc "Exact machine names authorized as lb- certificate principals and trusted proxies."
          | Array onix.Hostname
          | priority -5
          = [],
        port
          | doc "Worker gRPC port, admitted only on tailscale0."
          | onix.Port
          | priority -5
          = 50052,
      },
    },

    impl = fun args =>
      let cfg = args.settings in
      let machine = args.machine_name in
      let leaf_artifact = "%{args.instance_name}-node" in
      let ca_artifact = "%{args.instance_name}-ca" in
      let api_artifact = "niks3-%{cfg.cache_instance}-api" in
      let wait_script_name = "%{args.instance_name}-wait-worker-address" in
      let listen_endpoint = endpoint cfg.address cfg.port in
      let common_name = "worker-%{machine}" in
      let sans =
        std.string.join
          ","
          ((unique [machine, "%{machine}.local"] |> std.array.map (fun n => "DNS:%{n}")) @ ["IP:%{cfg.address}"])
      in
      let principals =
        unique (
          (cfg.allowed_clients |> std.array.map (fun n => "ci-%{n}"))
          @ (cfg.worker_names |> std.array.map (fun n => "worker-%{n}"))
          @ (cfg.balancer_names |> std.array.map (fun n => "lb-%{n}"))
        )
      in
      let has_cache_uploader =
        args.placement_facts.colocated_roles
        |> std.array.any (fun r =>
          r.instance_name == cfg.cache_instance && r.service == "niks3" && r.role_name == "uploader"
        )
      in
      let wire = fun art file_name option =>
        onix.artifact_wiring { artifact = art, file = file_name, nixos_option = option }
      in
      let node_file = onix.artifact_file { owner = "nix-grpc-daemon", group = "nix-grpc-daemon", mode = "0400" } in
      let restart = { restartUnits = ["nix-grpc-daemon.service"] } in
      if !has_cache_uploader then
        std.fail_with "nix-build-farm: %{machine} has no niks3 uploader role of instance %{cfg.cache_instance}, which supplies %{api_artifact}"
      else
        {
          output =
            {
              nixos = {
                assertions = [
                  {
                    assertion = cfg.is_scheduler == (cfg.scheduler_address == ""),
                    message = "nix-build-farm: the scheduler uses its in-process queue; other nodes require schedulerAddress",
                  },
                  {
                    assertion =
                      cfg.allowed_clients != []
                      && cfg.worker_names != []
                      && cfg.balancer_names != []
                      && std.array.elem machine cfg.worker_names,
                    message = "nix-build-farm: nonempty exact client/worker/balancer machine lists, including this worker, are required; wildcards are forbidden",
                  },
                ],
                # A farm worker must never delegate a build back into the farm.
                nix = {
                  distributedBuilds = nixlib.mk_force false,
                  buildMachines = nixlib.mk_force [],
                  settings.builders = nixlib.mk_force "",
                },
                services.nix-grpc-daemon = {
                  enable = true,
                  package = args.packages.onix-core-nix-grpc-store,
                  trustClients = true,
                  idleTimeout = null,
                  listen = listen_endpoint,
                  advertise = listen_endpoint,
                  workerName = machine,
                  roles = ["builder"] @ (if cfg.is_scheduler then ["scheduler"] else []),
                  scheduler = if cfg.scheduler_address == "" then null else cfg.scheduler_address,
                  maxJobs = cfg.max_jobs,
                  minFree = cfg.min_free,
                  accessRules = principals |> std.array.map (fun principal => { cn = principal, role = "trusted" }),
                  trustedProxies = cfg.balancer_names |> std.array.map (fun n => "lb-%{n}"),
                  anonymousRole = null,
                  oidc = null,
                  niks3 = {
                    package = args.packages.onix-core-niks3,
                    url = cfg.cache_url,
                    cacheUrl = cfg.cache_url,
                    publicKeys = [cfg.cache_public_key],
                    # The daemon owns a long-lived acknowledged push subprocess.
                    pushFlags = ["--parallel-pushes", "1", "--max-concurrent-uploads", "1", "--verify-s3-integrity"],
                  },
                },
                networking.firewall.interfaces.tailscale0.allowedTCPPorts = [cfg.port],
                environment.etc."%{wait_script_name}" = {
                  mode = "0555",
                  text = wait_script cfg.address,
                },
                systemd.services.nix-grpc-daemon = {
                  wants = ["network-online.target", "tailscaled-autoconnect.service"],
                  requires = ["tailscaled.service"],
                  after = ["network-online.target", "tailscaled.service", "tailscaled-autoconnect.service"],
                  path = [args.packages.iproute2, args.packages.jq],
                  serviceConfig = {
                    SupplementaryGroups = ["niks3-uploaders"],
                    # The probe reads tailscale0 over netlink, which the daemon's
                    # RestrictAddressFamilies forbids; "+" runs it unsandboxed.
                    ExecStartPre = ["+/etc/%{wait_script_name}"],
                    RestartSec = 5,
                  },
                },
                sops.secrets = {
                  "%{leaf_artifact}/key" = restart,
                  "%{leaf_artifact}/cert" = restart,
                  "%{leaf_artifact}/ca-cert" = restart,
                },
              },
              artifact_wiring = [
                wire leaf_artifact "cert" "services.nix-grpc-daemon.tls.certFile",
                wire leaf_artifact "key" "services.nix-grpc-daemon.tls.keyFile",
                wire leaf_artifact "ca-cert" "services.nix-grpc-daemon.tls.clientCaFile",
                wire api_artifact "api-token" "services.nix-grpc-daemon.niks3.tokenFile",
              ],
            }
            & onix.artifact_declaration {
              name = leaf_artifact,
              # The leaf and the CA copy are encrypted only for stable runtime
              # paths and atomic rotation alongside the private key.
              files = {
                key = node_file,
                cert = node_file,
                ca-cert = node_file,
              },
              generator_script = leaf_generator ca_artifact common_name sans,
              description = "mTLS identity %{common_name} for %{args.instance_name}, signed by %{ca_artifact}",
            },
        },

    tests | not_exported =
      let base =
        interface.roles.node
        & {
          cache_public_key = "onix-niks3-1:1Vg2qs7firQQJ/08DpDIXVBY41v6gPbHuwQlqr7EoQU=",
          allowed_clients = ["bonsai", "aspen3", "britton-desktop"],
          worker_names = ["aspen1", "aspen2"],
          balancer_names = ["aspen1"],
        }
      in
      let worker_settings = base & { address = "100.82.25.30", scheduler_address = "100.100.103.95:50052" } in
      let scheduler_settings = base & { address = "100.100.103.95", is_scheduler = true } in
      let test_packages = {
        onix-core-nix-grpc-store = "grpc-pkg",
        onix-core-niks3 = "niks3-pkg",
        iproute2 = "iproute2-pkg",
        jq = "jq-pkg",
      }
      in
      let run = fun machine role_settings =>
        (
          impl (
            onix.testing.mock_args {
              service = "nix-build-farm",
              role_name = 'node,
              settings = role_settings,
              instance_name = "nix-build-farm",
              machine_name = machine,
              packages = test_packages,
              placement_facts = {
                current = { instance_name = "nix-build-farm", role_name = "node", machine_name = machine, machines = [machine] },
                colocated_roles = [
                  { instance_name = "nix-cache", service = "niks3", role_name = "uploader", machines = [machine], settings = {}, same_machine = true },
                ],
                role_targets = {},
              },
            }
          )
        ).output
      in
      let worker = run "aspen2" worker_settings in
      let scheduler = run "aspen1" scheduler_settings in
      let daemon = worker.nixos.services.nix-grpc-daemon in
      let unit = worker.nixos.systemd.services.nix-grpc-daemon in
      let leaf = worker.artifacts.nix-build-farm-node in
      let wiring_for = fun option =>
        std.array.first (worker.artifact_wiring |> std.array.filter (fun w => w.nixos_option == option))
      in
      [
        interface.roles.node.port == 50052,
        interface.roles.node.max_jobs == 16,
        interface.roles.node.min_free == "100G",
        interface.roles.node.cache_instance == "nix-cache",
        daemon.package == "grpc-pkg",
        daemon.listen == "100.82.25.30:50052",
        daemon.advertise == "100.82.25.30:50052",
        daemon.workerName == "aspen2",
        daemon.roles == ["builder"],
        daemon.scheduler == "100.100.103.95:50052",
        daemon.idleTimeout == null,
        daemon.maxJobs == 16,
        (daemon.accessRules |> std.array.map (fun r => r.cn)) == ["ci-bonsai", "ci-aspen3", "ci-britton-desktop", "worker-aspen1", "worker-aspen2", "lb-aspen1"],
        std.array.all (fun r => r.role == "trusted") daemon.accessRules,
        daemon.trustedProxies == ["lb-aspen1"],
        daemon.niks3.package == "niks3-pkg",
        daemon.niks3.url == "http://100.100.103.95:39400",
        daemon.niks3.publicKeys == ["onix-niks3-1:1Vg2qs7firQQJ/08DpDIXVBY41v6gPbHuwQlqr7EoQU="],
        daemon.niks3.pushFlags == ["--parallel-pushes", "1", "--max-concurrent-uploads", "1", "--verify-s3-integrity"],
        scheduler.nixos.services.nix-grpc-daemon.roles == ["builder", "scheduler"],
        scheduler.nixos.services.nix-grpc-daemon.scheduler == null,
        (run "aspen2" (base & { address = "fd00::2", scheduler_address = "x:1" })).nixos.services.nix-grpc-daemon.listen == "[fd00::2]:50052",
        std.array.all (fun a => a.assertion) worker.nixos.assertions,
        std.array.all (fun a => a.assertion) scheduler.nixos.assertions,
        !(std.array.first (run "aspen2" (worker_settings & { is_scheduler = true })).nixos.assertions).assertion,
        !(std.array.at 1 (run "aspen3" worker_settings).nixos.assertions).assertion,
        worker.nixos.nix.distributedBuilds.content == false,
        worker.nixos.nix.buildMachines.content == [],
        worker.nixos.nix.settings.builders.content == "",
        worker.nixos.networking.firewall.interfaces.tailscale0.allowedTCPPorts == [50052],
        unit.requires == ["tailscaled.service"],
        unit.serviceConfig.SupplementaryGroups == ["niks3-uploaders"],
        unit.serviceConfig.ExecStartPre == ["+/etc/nix-build-farm-wait-worker-address"],
        unit.serviceConfig.RestartSec == 5,
        unit.path == ["iproute2-pkg", "jq-pkg"],
        worker.nixos.environment.etc."nix-build-farm-wait-worker-address".mode == "0555",
        std.string.contains "--arg address '100.82.25.30'" worker.nixos.environment.etc."nix-build-farm-wait-worker-address".text,
        leaf.files.key.secret,
        leaf.files.key.owner == "nix-grpc-daemon",
        leaf.files.cert.group == "nix-grpc-daemon",
        leaf.files.ca-cert.mode == "0400",
        !(std.record.has_field "shared" leaf),
        std.string.contains "subjectAltName=DNS:aspen2,DNS:aspen2.local,IP:100.82.25.30" leaf.generator_script,
        std.string.contains "-subj '/CN=worker-aspen2'" leaf.generator_script,
        std.string.contains "ca=\"$in\"/'nix-build-farm-ca'" leaf.generator_script,
        worker.nixos.sops.secrets."nix-build-farm-node/key".restartUnits == ["nix-grpc-daemon.service"],
        (wiring_for "services.nix-grpc-daemon.tls.clientCaFile").file == "ca-cert",
        (wiring_for "services.nix-grpc-daemon.niks3.tokenFile").artifact == "niks3-nix-cache-api",
      ]
      |> std.test.assert_all,
  }
  ) | onix.ServiceModule
