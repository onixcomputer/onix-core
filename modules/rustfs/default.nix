{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
in
{
  _class = "clan.service";
  manifest = {
    name = "rustfs";
    readme = "RustFS single-node or distributed S3-compatible object storage with Clan-managed credentials";
  };

  roles.server = {
    description = "RustFS object storage server";
    interface = mkSettings.mkInterface schema.server;

    perInstance =
      {
        instanceName,
        extendSettings,
        ...
      }:
      {
        nixosModule =
          {
            config,
            lib,
            pkgs,
            ...
          }:
          let
            ms = import ../../lib/mk-settings.nix { inherit lib; };
            settings = extendSettings (ms.mkDefaults schema.server);
            topology = import ./topology.nix { inherit lib; } settings;
            generatorName = "rustfs-${instanceName}";
            environmentFile = config.clan.core.vars.generators.${generatorName}.files."env-file".path;
            accessKeyByteCount = 10;
            secretKeyByteCount = 32;
            secretFileMode = "0400";
            stateDirectoryMode = "0700";
            serviceUmask = "0077";
            clusterStartupGraceSeconds = 30;
            clusterStartTimeoutSeconds = settings.topologyWaitTimeoutSeconds + clusterStartupGraceSeconds;
            enabledPorts = [ settings.apiPort ] ++ lib.optional settings.enableConsole settings.consolePort;
          in
          {
            assertions = topology.assertions;

            clan.core.vars.generators.${generatorName} = {
              # r[impl onix.rustfs_cluster.credentials]
              share = topology.shareCredentials;
              files."env-file" = {
                secret = true;
                deploy = true;
                owner = "root";
                group = "root";
                mode = secretFileMode;
              };
              runtimeInputs = [ pkgs.openssl ];
              script = ''
                access_key="$(${pkgs.openssl}/bin/openssl rand -hex ${toString accessKeyByteCount})"
                secret_key="$(${pkgs.openssl}/bin/openssl rand -hex ${toString secretKeyByteCount})"
                printf 'RUSTFS_ACCESS_KEY=%s\nRUSTFS_SECRET_KEY=%s\n' \
                  "$access_key" "$secret_key" > "$out/env-file"
              '';
            };

            services.rustfs = {
              enable = true;
              inherit environmentFile;
              settings = {
                RUSTFS_ADDRESS = "${settings.bindAddress}:${toString settings.apiPort}";
                RUSTFS_CONSOLE_ADDRESS = "${settings.bindAddress}:${toString settings.consolePort}";
                RUSTFS_CONSOLE_ENABLE = if settings.enableConsole then "true" else "false";
                # Nixpkgs uses this path for tmpfiles ownership. The distributed
                # URL list is applied to the systemd environment below.
                RUSTFS_VOLUMES = settings.dataDir;
              }
              // topology.distributedEnvironment;
            };

            networking.firewall = lib.mkIf settings.openFirewall (
              if settings.firewallInterface == null then
                { allowedTCPPorts = enabledPorts; }
              else
                { interfaces.${settings.firewallInterface}.allowedTCPPorts = enabledPorts; }
            );

            systemd.tmpfiles.settings."10-rustfs".${settings.dataDir}.d.mode = stateDirectoryMode;

            systemd.services.rustfs = {
              # r[impl onix.rustfs_cluster.rollout]
              after = lib.optionals topology.distributed [
                "network-online.target"
                "tailscaled.service"
              ];
              wants = lib.optionals topology.distributed [
                "network-online.target"
                "tailscaled.service"
              ];
              unitConfig.RequiresMountsFor = [ settings.dataDir ];
              environment.RUSTFS_VOLUMES = lib.mkForce topology.volumes;
              serviceConfig = {
                UMask = serviceUmask;
                ProtectSystem = "strict";
                ReadWritePaths = [ settings.dataDir ];
                CapabilityBoundingSet = "";
                AmbientCapabilities = "";
                LockPersonality = true;
                MemoryDenyWriteExecute = true;
                RestrictAddressFamilies = [
                  "AF_UNIX"
                  "AF_INET"
                  "AF_INET6"
                ];
              }
              // lib.optionalAttrs topology.distributed {
                TimeoutStartSec = lib.mkForce "${toString clusterStartTimeoutSeconds}s";
              };
            };
          };
      };
  };

  perMachine = _: {
    nixosModule = _: { };
  };
}
