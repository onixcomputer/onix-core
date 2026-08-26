{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
in
{
  _class = "clan.service";

  manifest = {
    name = "celld";
    readme = "Private Celld Durable Objects fleet backed by bucket-scoped S3-compatible storage";
  };

  roles.server = {
    description = "Celld Worker and Durable Objects node";
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
            inputs,
            ...
          }:
          let
            ms = import ../../lib/mk-settings.nix { inherit lib; };
            settings = extendSettings (ms.mkDefaults schema.server);
            evaluated = import ./settings.nix { inherit lib; } settings;
            celldPackage = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.celld;
            credentialGeneratorName = "celld-${instanceName}";
            credentialEnvironmentFile =
              config.clan.core.vars.generators.${credentialGeneratorName}.files."aws-env".path;
            rustfsAdminEnvironmentFile =
              config.clan.core.vars.generators.${settings.rustfsAdminGenerator}.files."env-file".path;
            celldUser = "celld";
            celldGroup = "celld";
            secretKeyByteCount = 32;
            privateDirectoryMode = "0700";
            secretFileMode = "0400";
            serviceUmask = "0077";
            millisecondsPerSecond = 1000;
            shutdownMarginSeconds = 10;
            shutdownDrainSeconds = builtins.div (
              settings.shutdownDrainMilliseconds + millisecondsPerSecond - 1
            ) millisecondsPerSecond;
            timeoutStopSeconds = shutdownDrainSeconds + shutdownMarginSeconds;
            provisionStateDirectory = "/var/lib/celld-provision";
            policyName = "celld-${instanceName}";
            storageAuthority = lib.removePrefix "http://" settings.storageEndpoint;
            counterProject = pkgs.runCommand "onix-celld-counter-worker" { } ''
              install -d "$out"
              install -m 0444 ${./counter-worker/index.js} "$out/index.js"
              install -m 0444 ${./counter-worker/wrangler.jsonc} "$out/wrangler.jsonc"
            '';
            deploymentMarker = "${provisionStateDirectory}/counter-project";
            minioClient = lib.getExe pkgs.minio-client;
            celldExecutable = lib.getExe celldPackage;
            esbuildExecutable = lib.getExe pkgs.esbuild;
            bucketPolicy = pkgs.writeText "${policyName}-policy.json" (
              builtins.toJSON {
                Version = "2012-10-17";
                Statement = [
                  {
                    Effect = "Allow";
                    Action = [ "s3:*" ];
                    Resource = [
                      "arn:aws:s3:::${settings.bucketName}"
                      "arn:aws:s3:::${settings.bucketName}/*"
                    ];
                  }
                ];
              }
            );
            provisionStorage = pkgs.writeShellScript "celld-provision-storage" ''
              set -eu
              umask ${serviceUmask}

              mc_config_dir="$(${pkgs.coreutils}/bin/mktemp -d)"
              cleanup() {
                ${pkgs.coreutils}/bin/rm -rf "$mc_config_dir"
              }
              trap cleanup EXIT HUP INT TERM

              export MC_CONFIG_DIR="$mc_config_dir"
              export MC_HOST_rustfs="http://$RUSTFS_ACCESS_KEY:$RUSTFS_SECRET_KEY@${storageAuthority}"

              ${minioClient} mb --ignore-existing \
                "rustfs/${settings.bucketName}" \
                --config-dir "$mc_config_dir"

              printf '%s\n%s\n' "$AWS_ACCESS_KEY_ID" "$AWS_SECRET_ACCESS_KEY" \
                | ${minioClient} admin user add rustfs --config-dir "$mc_config_dir"

              ${minioClient} admin policy create \
                rustfs \
                ${lib.escapeShellArg policyName} \
                ${lib.escapeShellArg bucketPolicy} \
                --config-dir "$mc_config_dir"

              ${minioClient} admin policy attach \
                rustfs \
                ${lib.escapeShellArg policyName} \
                --user "$AWS_ACCESS_KEY_ID" \
                --config-dir "$mc_config_dir"

              ${lib.optionalString settings.deployCounter ''
                expected_project=${lib.escapeShellArg counterProject}
                deployed_project=""
                if test -f ${lib.escapeShellArg deploymentMarker}; then
                  deployed_project="$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg deploymentMarker})"
                fi

                if test "$deployed_project" != "$expected_project" \
                  || ! ${minioClient} stat \
                    "rustfs/${settings.bucketName}/deploy/current.json" \
                    --config-dir "$mc_config_dir" >/dev/null 2>&1; then
                  CELLD_ESBUILD=${lib.escapeShellArg esbuildExecutable} \
                    ${celldExecutable} deploy "$expected_project" \
                    --bucket ${lib.escapeShellArg evaluated.bucketUri} \
                    --endpoint ${lib.escapeShellArg settings.storageEndpoint} \
                    --region ${lib.escapeShellArg settings.region}
                  printf '%s\n' "$expected_project" \
                    | ${pkgs.coreutils}/bin/install -m 0600 /dev/stdin ${lib.escapeShellArg deploymentMarker}
                fi
              ''}
            '';
          in
          {
            assertions = evaluated.assertions;

            # r[impl onix.celld_rustfs.storage]
            clan.core.vars.generators.${credentialGeneratorName} = {
              share = true;
              files."aws-env" = {
                secret = true;
                deploy = true;
                owner = celldUser;
                group = celldGroup;
                mode = secretFileMode;
              };
              runtimeInputs = [ pkgs.openssl ];
              script = ''
                secret_key="$(${lib.getExe pkgs.openssl} rand -hex ${toString secretKeyByteCount})"
                printf 'AWS_ACCESS_KEY_ID=%s\nAWS_SECRET_ACCESS_KEY=%s\n' \
                  ${lib.escapeShellArg settings.accessKeyId} "$secret_key" > "$out/aws-env"
              '';
            };

            users.groups.${celldGroup} = { };
            users.users.${celldUser} = {
              isSystemUser = true;
              group = celldGroup;
              home = settings.stateDir;
              createHome = false;
            };

            systemd.tmpfiles.settings."10-celld" = {
              ${settings.stateDir}.d = {
                mode = privateDirectoryMode;
                user = celldUser;
                group = celldGroup;
              };
              ${provisionStateDirectory}.d = lib.mkIf settings.provisionStorage {
                mode = privateDirectoryMode;
                user = "root";
                group = "root";
              };
            };

            # r[impl onix.celld_rustfs.security]
            networking.firewall = lib.mkIf settings.openFirewall {
              interfaces.${settings.firewallInterface}.allowedTCPPorts = [
                settings.publicPort
                settings.internalPort
              ];
            };

            systemd.services.celld-storage-provision = lib.mkIf settings.provisionStorage {
              description = "Provision bucket-scoped RustFS storage for Celld";
              wantedBy = [ "multi-user.target" ];
              before = [ "celld.service" ];
              after = [
                "network-online.target"
                "rustfs.service"
                "tailscaled.service"
              ];
              wants = [
                "network-online.target"
                "rustfs.service"
                "tailscaled.service"
              ];
              path = [ pkgs.getent ];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
                ExecStart = provisionStorage;
                EnvironmentFile = [
                  rustfsAdminEnvironmentFile
                  credentialEnvironmentFile
                ];
                UMask = serviceUmask;
                NoNewPrivileges = true;
                PrivateTmp = true;
                ProtectHome = true;
                ProtectSystem = "strict";
                ReadWritePaths = [ provisionStateDirectory ];
                CapabilityBoundingSet = "";
                AmbientCapabilities = "";
                LockPersonality = true;
                RestrictAddressFamilies = [
                  "AF_UNIX"
                  "AF_INET"
                  "AF_INET6"
                ];
                RestrictRealtime = true;
                RestrictSUIDSGID = true;
                SystemCallArchitectures = "native";
              };
            };

            # r[impl onix.celld_rustfs.composition]
            # r[impl onix.celld_rustfs.runtime]
            systemd.services.celld = {
              description = "Self-hosted Durable Objects node";
              wantedBy = [ "multi-user.target" ];
              after = [
                "network-online.target"
                "tailscaled.service"
              ]
              ++ lib.optional settings.provisionStorage "celld-storage-provision.service";
              wants = [
                "network-online.target"
                "tailscaled.service"
              ];
              requires = lib.optional settings.provisionStorage "celld-storage-provision.service";
              environment = {
                CELLD_BUCKET = evaluated.bucketUri;
                CELLD_ADDR = evaluated.publicListener;
                CELLD_INTERNAL_ADDR = evaluated.internalListener;
                CELLD_ADVERTISE = evaluated.internalListener;
                CELLD_WATCH = settings.stateDir;
                CELLD_STORAGE_PROBE = "1";
                CELLD_TTL_MS = toString settings.leaseTtlMilliseconds;
                CELLD_SHUTDOWN_DRAIN_MS = toString settings.shutdownDrainMilliseconds;
                CELLD_DURABILITY = "fleet";
                CELLD_OUTPUT_GATE = "1";
                S3_ENDPOINT = settings.storageEndpoint;
                AWS_REGION = settings.region;
                RUST_LOG = "info";
              };
              serviceConfig = {
                Type = "simple";
                ExecStart = celldExecutable;
                EnvironmentFile = credentialEnvironmentFile;
                User = celldUser;
                Group = celldGroup;
                WorkingDirectory = settings.stateDir;
                Restart = "always";
                RestartSec = settings.restartDelaySeconds;
                TimeoutStopSec = timeoutStopSeconds;
                UMask = serviceUmask;
                NoNewPrivileges = true;
                PrivateDevices = true;
                PrivateTmp = true;
                ProtectClock = true;
                ProtectControlGroups = true;
                ProtectHome = true;
                ProtectKernelLogs = true;
                ProtectKernelModules = true;
                ProtectKernelTunables = true;
                ProtectSystem = "strict";
                ReadWritePaths = [ settings.stateDir ];
                CapabilityBoundingSet = "";
                AmbientCapabilities = "";
                LockPersonality = true;
                RemoveIPC = true;
                RestrictAddressFamilies = [
                  "AF_UNIX"
                  "AF_INET"
                  "AF_INET6"
                ];
                RestrictNamespaces = true;
                RestrictRealtime = true;
                RestrictSUIDSGID = true;
                SystemCallArchitectures = "native";
              };
            };
          };
      };
  };
}
