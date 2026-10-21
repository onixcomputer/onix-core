{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
  exactNames = names: lib.all (name: builtins.match "[A-Za-z0-9][A-Za-z0-9-]*" name != null) names;
  validPort = port: port >= 1 && port <= 65535;
  endpoint =
    address: port: "${if lib.hasInfix ":" address then "[${address}]" else address}:${toString port}";
  cacheKey =
    inputs: instanceName:
    let
      source = "${inputs.self}/vars/shared/niks3-${instanceName}-storage/signing-key-public/value";
    in
    if builtins.pathExists source then
      lib.fileContents source
    else
      throw "nix-build-farm: missing public cache signing key ${source}; generate the niks3 storage vars before activating the farm";
in
{
  _class = "clan.service";

  manifest = {
    name = "nix-build-farm";
    readme = "Scheduled mTLS Nix build farm with automatic signed niks3 publication";
    description = "Private gRPC workers, Envoy routing, and fork-matched Nix clients";
    categories = [
      "Development"
      "Network"
    ];
  };

  roles.node = {
    description = "Local-only build worker, optionally hosting the farm scheduler";
    interface = mkSettings.mkInterface schema.node;
    perInstance = { instanceName, extendSettings, ... }: {
      nixosModule =
        {
          config,
          inputs,
          lib,
          pkgs,
          ...
        }:
        let
          settings = extendSettings (mkSettings.mkDefaults schema.node);
          machineName = config.clan.core.settings.machine.name;
          package = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.nix-grpc-store;
          pki = import ./pki.nix {
            inherit
              config
              lib
              pkgs
              instanceName
              ;
            role = "node";
            commonName = "worker-${machineName}";
            owner = "nix-grpc-daemon";
            dnsNames = [
              machineName
              "${machineName}.local"
            ];
            ipAddresses = [ settings.address ];
            serverAuth = true;
            restartUnits = [ "nix-grpc-daemon.service" ];
          };
          principals =
            map (name: "ci-${name}") settings.allowedClients
            ++ map (name: "worker-${name}") settings.workerNames
            ++ map (name: "lb-${name}") settings.balancerNames;
          apiGenerator = "niks3-${settings.cacheInstance}-api";
          waitForAddress = pkgs.writeShellScript "${instanceName}-wait-worker-address" ''
            set -eu
            for attempt in $(${pkgs.coreutils}/bin/seq 1 60); do
              if ${pkgs.iproute2}/bin/ip -json address show dev tailscale0 2>/dev/null \
                | ${pkgs.jq}/bin/jq -e --arg address ${lib.escapeShellArg settings.address} \
                  'any(.[].addr_info[]; .local == $address)' >/dev/null; then
                exit 0
              fi
              ${pkgs.coreutils}/bin/sleep 1
            done
            echo 'Farm worker Tailnet listener address is not ready' >&2
            exit 1
          '';
        in
        {
          imports = [ "${inputs.nix-grpc-store}/nixos/server.nix" ];

          assertions = [
            {
              assertion = settings.isScheduler == (settings.schedulerAddress == "");
              message = "nix-build-farm: the scheduler uses its in-process queue; other nodes require schedulerAddress";
            }
            {
              assertion = settings.maxJobs >= 1 && settings.maxJobs <= 63 && validPort settings.port;
              message = "nix-build-farm: node maxJobs must be 1..63 and port must be 1..65535";
            }
            {
              assertion =
                exactNames (settings.allowedClients ++ settings.workerNames ++ settings.balancerNames)
                && settings.allowedClients != [ ]
                && settings.workerNames != [ ]
                && settings.balancerNames != [ ]
                && lib.elem machineName settings.workerNames;
              message = "nix-build-farm: nonempty exact client/worker/balancer machine lists, including this worker, are required; wildcards are forbidden";
            }
          ];

          clan.core.vars.generators = pki.generators;

          # A farm worker must never delegate a build back into the farm.
          nix.distributedBuilds = lib.mkForce false;
          nix.buildMachines = lib.mkForce [ ];
          nix.settings.builders = lib.mkForce "";

          services.nix-grpc-daemon = {
            enable = true;
            inherit package;
            trustClients = true;
            idleTimeout = null;
            listen = endpoint settings.address settings.port;
            advertise = endpoint settings.address settings.port;
            workerName = machineName;
            roles = [ "builder" ] ++ lib.optional settings.isScheduler "scheduler";
            scheduler = if settings.schedulerAddress == "" then null else settings.schedulerAddress;
            inherit (settings) maxJobs minFree;
            tls = {
              inherit (pki.tls) certFile keyFile;
              clientCaFile = pki.tls.caFile;
            };
            accessRules = map (cn: {
              inherit cn;
              role = "trusted";
            }) (lib.unique principals);
            trustedProxies = map (name: "lb-${name}") settings.balancerNames;
            anonymousRole = null;
            oidc = null;
            niks3 = {
              package = inputs.niks3.packages.${pkgs.stdenv.hostPlatform.system}.niks3;
              url = settings.cacheUrl;
              inherit (settings) cacheUrl;
              tokenFile = config.clan.core.vars.generators.${apiGenerator}.files.api-token.path;
              publicKeys = [ (cacheKey inputs settings.cacheInstance) ];
              # The daemon owns a long-lived acknowledged push subprocess.
              # Bound both its request concurrency and per-request NAR uploads.
              pushFlags = [
                "--parallel-pushes"
                "1"
                "--max-concurrent-uploads"
                "1"
                "--verify-s3-integrity"
              ];
            };
          };

          networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ settings.port ];
          systemd.services.nix-grpc-daemon = {
            wants = [
              "network-online.target"
              "tailscaled-autoconnect.service"
            ];
            requires = [ "tailscaled.service" ];
            after = [
              "network-online.target"
              "tailscaled.service"
              "tailscaled-autoconnect.service"
            ];
            # Upstream also supplies this: the push client must query the
            # persistent fork's store rather than an unrelated nixpkgs Nix.
            path = [ config.nix.package ];
            serviceConfig = {
              SupplementaryGroups = [ "niks3-uploaders" ];
              ExecStartPre = [ waitForAddress ];
              RestartSec = 5;
            };
          };
        };
    };
  };

  roles.balancer = {
    description = "Private-CA Envoy endpoint routing requests to registered farm workers";
    interface = mkSettings.mkInterface schema.balancer;
    perInstance = { instanceName, extendSettings, ... }: {
      nixosModule =
        {
          config,
          inputs,
          lib,
          pkgs,
          ...
        }:
        let
          settings = extendSettings (mkSettings.mkDefaults schema.balancer);
          machineName = config.clan.core.settings.machine.name;
          pki = import ./pki.nix {
            inherit
              config
              lib
              pkgs
              instanceName
              ;
            role = "balancer";
            commonName = "lb-${machineName}";
            owner = "envoy";
            dnsNames = [
              settings.hostName
              machineName
              "${machineName}.local"
            ];
            serverAuth = true;
            restartUnits = [ "envoy.service" ];
          };
          schedulerParts = builtins.match "(.*):([0-9]+)" settings.schedulerAddress;
          schedulerHost = lib.removeSuffix "]" (lib.removePrefix "[" (builtins.elemAt schedulerParts 0));
          schedulerPort = builtins.elemAt schedulerParts 1;
          localNode = config.services.nix-grpc-daemon.enable or false;
          waitForScheduler = pkgs.writeShellScript "${instanceName}-wait-scheduler" ''
            set -eu
            for attempt in $(${pkgs.coreutils}/bin/seq 1 30); do
              if ${pkgs.netcat-openbsd}/bin/nc -z -w 1 \
                ${lib.escapeShellArg schedulerHost} ${lib.escapeShellArg schedulerPort}; then
                exit 0
              fi
              ${pkgs.coreutils}/bin/sleep 1
            done
            echo 'Farm scheduler Tailnet listener is not ready' >&2
            exit 1
          '';
        in
        {
          imports = [ "${inputs.nix-grpc-store}/nixos/lb.nix" ];
          assertions = [
            {
              assertion = settings.systems != [ ] && validPort settings.port && schedulerParts != null;
              message = "nix-build-farm: balancer requires systems, a valid listener port, and scheduler host:port";
            }
          ];
          clan.core.vars.generators = pki.generators;

          services.nix-grpc-farm-lb = {
            enable = true;
            # DNS identifies the certificate; bind a stable address before
            # mDNS announces hostName on the client-facing LAN.
            listen = "[::]:${toString settings.port}";
            inherit (settings) systems;
            scheduler = settings.schedulerAddress;
            admin = "127.0.0.1:9901";
            tls = {
              inherit (pki.tls) certFile keyFile;
              clientCaFile = pki.tls.caFile;
              upstream = { inherit (pki.tls) certFile keyFile caFile; };
            };
          };
          # Upstream sanitizes XFCC and permits a cert-less handshake for its
          # optional OIDC mode. Our nodes have no anonymous/OIDC role, so no
          # forwarded client can build without an exact authorized principal.
          networking.firewall.allowedTCPPorts = [ settings.port ];

          # Stable ownership is required for Clan-deployed credentials;
          # NixOS Envoy otherwise allocates a transient DynamicUser uid.
          users.users.envoy = {
            isSystemUser = true;
            group = "envoy";
          };
          users.groups.envoy = { };
          systemd.services.envoy = {
            wants = [ "tailscaled-autoconnect.service" ] ++ lib.optional localNode "nix-grpc-daemon.service";
            requires = [ "tailscaled.service" ];
            after = [
              "tailscaled.service"
              "tailscaled-autoconnect.service"
            ]
            ++ lib.optional localNode "nix-grpc-daemon.service";
            serviceConfig = {
              DynamicUser = lib.mkForce false;
              User = "envoy";
              Group = "envoy";
              ExecStartPre = [ waitForScheduler ];
              Restart = lib.mkForce "on-failure";
              RestartSec = 5;
            };
          };
        };
    };
  };

  roles.client = {
    description = "Nix-daemon-only mTLS farm credentials and per-system gRPC builders";
    interface = mkSettings.mkInterface schema.client;
    perInstance = { instanceName, extendSettings, ... }: {
      nixosModule =
        {
          config,
          inputs,
          lib,
          pkgs,
          ...
        }:
        let
          settings = extendSettings (mkSettings.mkDefaults schema.client);
          machineName = config.clan.core.settings.machine.name;
          pki = import ./pki.nix {
            inherit
              config
              lib
              pkgs
              instanceName
              ;
            role = "client";
            commonName = "ci-${machineName}";
            owner = "root";
            dnsNames = [
              machineName
              "${machineName}.local"
            ];
            restartUnits = [ "nix-daemon.service" ];
          };
          query =
            system:
            lib.concatStringsSep "&" (
              lib.mapAttrsToList (name: value: "${name}=${lib.escapeURL (toString value)}") {
                inherit system;
                ca-cert = pki.tls.caFile;
                client-cert = pki.tls.certFile;
                client-key = pki.tls.keyFile;
              }
            );
        in
        {
          imports = [ "${inputs.nix-grpc-store}/nixos/client.nix" ];
          assertions = [
            {
              assertion =
                settings.systems != [ ]
                && settings.maxJobs > 0
                && validPort settings.port
                && builtins.match "[A-Za-z0-9][A-Za-z0-9.-]*" settings.hostName != null;
              message = "nix-build-farm: client requires systems, positive maxJobs, a valid port, and a DNS endpoint";
            }
          ];
          clan.core.vars.generators = pki.generators;
          programs.nix-grpc-store = {
            enable = true;
            package = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.nix-grpc-store;
            daemonEgressPorts = [ settings.port ];
          };
          # mDNS is link-local; remote Tailnet clients must resolve the same
          # certificate name without depending on the ingress host's LAN.
          networking.hosts = lib.mkIf (settings.hostAddress != "") {
            ${settings.hostAddress} = [ settings.hostName ];
          };
          nix.distributedBuilds = true;
          # Merge with independent external builders; inventory routing
          # removes the old SSH entries for the workers this replaces.
          nix.buildMachines = map (system: {
            hostName = "grpc://${endpoint settings.hostName settings.port}?${query system}";
            protocol = null;
            systems = [ system ];
            inherit (settings) maxJobs supportedFeatures;
          }) (lib.unique settings.systems);
          nix.settings = {
            extra-substituters = [ settings.cacheUrl ];
            extra-trusted-public-keys = [ (cacheKey inputs "nix-cache") ];
          };
        };
    };
  };
}
