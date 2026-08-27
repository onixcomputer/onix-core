{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
  upstreamVersion = "1.8.0";
  uploaderGroup = "niks3-uploaders";
  secretFileMode = "0400";
  sharedSecretFileMode = "0440";
  serviceUmask = "0077";
  secretKeyByteCount = 32;
  signingKeyName = "onix-niks3-1";
  backgroundResourceWeight = 10;
  backgroundNice = 10;
  backgroundCpuQuota = "100%";
  storageGeneratorNameFor = instanceName: "niks3-${instanceName}-storage";
  metadataBackupGeneratorNameFor = instanceName: "niks3-${instanceName}-metadata-backup";
  apiGeneratorNameFor = instanceName: "niks3-${instanceName}-api";
  publicKeySourceFor =
    inputs: instanceName:
    "${inputs.self}/vars/shared/${storageGeneratorNameFor instanceName}/signing-key-public/value";
in
{
  _class = "clan.service";

  manifest = {
    name = "niks3";
    readme = "Tailnet-only Nix binary cache with RustFS object storage";
  };

  roles.server = {
    description = "niks3 server with PostgreSQL metadata and RustFS objects";
    interface = mkSettings.mkInterface schema.server;

    perInstance =
      { extendSettings, instanceName, ... }:
      {
        nixosModule =
          {
            config,
            inputs,
            lib,
            pkgs,
            ...
          }:
          let
            ms = import ../../lib/mk-settings.nix { inherit lib; };
            settings = extendSettings (ms.mkDefaults schema.server);
            evaluated = import ./settings.nix { inherit lib; } "server" settings;
            niks3Package = inputs.niks3.packages.${pkgs.stdenv.hostPlatform.system}.niks3;
            niks3ServerPackage = inputs.niks3.packages.${pkgs.stdenv.hostPlatform.system}.niks3-server;
            policyLib = import ../../lib/rustfs-bucket-policy.nix { inherit lib; };
            storageGeneratorName = storageGeneratorNameFor instanceName;
            metadataBackupGeneratorName = metadataBackupGeneratorNameFor instanceName;
            apiGeneratorName = apiGeneratorNameFor instanceName;
            apiTokenFile = config.clan.core.vars.generators.${apiGeneratorName}.files."api-token".path;
            accessKeyFile = config.clan.core.vars.generators.${storageGeneratorName}.files."access-key".path;
            secretKeyFile = config.clan.core.vars.generators.${storageGeneratorName}.files."secret-key".path;
            signingKeyFile = config.clan.core.vars.generators.${storageGeneratorName}.files."signing-key".path;
            storageEnvironmentFile =
              config.clan.core.vars.generators.${storageGeneratorName}.files."aws-env".path;
            metadataBackupEnvironmentFile = lib.optionalString settings.metadataBackupEnabled (
              config.clan.core.vars.generators.${metadataBackupGeneratorName}.files."aws-env".path
            );
            metadataBackupAdminEnvironmentFile = lib.optionalString settings.metadataBackupEnabled (
              config.clan.core.vars.generators.${settings.metadataBackupAdminGenerator}.files."env-file".path
            );
            rustfsAdminEnvironmentFile =
              config.clan.core.vars.generators.${settings.rustfsAdminGenerator}.files."env-file".path;
            policyName = "niks3-${instanceName}";
            metadataBackupPolicyName = "niks3-${instanceName}-metadata-backup";
            storageAuthority = lib.removePrefix "http://" (
              lib.removePrefix "https://" settings.storageEndpoint
            );
            storageServiceUnit = "${settings.storageServiceName}.service";
            metadataBackupAuthority = lib.removePrefix "http://" (
              lib.removePrefix "https://" settings.metadataBackupEndpoint
            );
            serverUrl = "http://${settings.bindAddress}:${toString settings.port}";
            minioClient = lib.getExe pkgs.minio-client;
            bucketPolicy = pkgs.writeText "${policyName}-policy.json" (
              policyLib.render {
                bucketName = settings.bucketName;
                allowDelete = true;
                allowMultipart = true;
              }
            );
            metadataBackupPolicy = pkgs.writeText "${metadataBackupPolicyName}-policy.json" (
              policyLib.render {
                bucketName = settings.metadataBackupBucket;
                allowDelete = false;
                allowMultipart = true;
              }
            );
            provisionStorage = pkgs.writeShellScript "niks3-provision-storage" ''
              set -eu
              umask ${serviceUmask}

              mc_config_dir="$(${pkgs.coreutils}/bin/mktemp -d)"
              cleanup() {
                ${pkgs.coreutils}/bin/rm -rf "$mc_config_dir"
              }
              trap cleanup EXIT HUP INT TERM

              export MC_CONFIG_DIR="$mc_config_dir"
              export MC_HOST_rustfs="${
                if lib.hasPrefix "https://" settings.storageEndpoint then "https" else "http"
              }://$RUSTFS_ACCESS_KEY:$RUSTFS_SECRET_KEY@${storageAuthority}"

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
            '';
            metadataBackupDump = "${settings.metadataBackupDirectory}/niks3.sql.zstd";
            provisionMetadataBackup = pkgs.writeShellScript "niks3-provision-metadata-backup" ''
              set -eu
              umask ${serviceUmask}

              mc_config_dir="$(${pkgs.coreutils}/bin/mktemp -d)"
              cleanup() {
                ${pkgs.coreutils}/bin/rm -rf "$mc_config_dir"
              }
              trap cleanup EXIT HUP INT TERM

              export MC_CONFIG_DIR="$mc_config_dir"
              export MC_HOST_backup="${
                if lib.hasPrefix "https://" settings.metadataBackupEndpoint then "https" else "http"
              }://$RUSTFS_ACCESS_KEY:$RUSTFS_SECRET_KEY@${metadataBackupAuthority}"

              ${minioClient} mb --ignore-existing \
                "backup/${settings.metadataBackupBucket}" \
                --config-dir "$mc_config_dir"

              printf '%s\n%s\n' "$AWS_ACCESS_KEY_ID" "$AWS_SECRET_ACCESS_KEY" \
                | ${minioClient} admin user add backup --config-dir "$mc_config_dir"

              ${minioClient} admin policy create \
                backup \
                ${lib.escapeShellArg metadataBackupPolicyName} \
                ${lib.escapeShellArg metadataBackupPolicy} \
                --config-dir "$mc_config_dir"

              ${minioClient} admin policy attach \
                backup \
                ${lib.escapeShellArg metadataBackupPolicyName} \
                --user "$AWS_ACCESS_KEY_ID" \
                --config-dir "$mc_config_dir"
            '';
            uploadMetadataBackup = pkgs.writeShellScript "niks3-upload-metadata-backup" ''
              set -eu
              umask ${serviceUmask}

              test -s ${lib.escapeShellArg metadataBackupDump}
              mc_config_dir="$(${pkgs.coreutils}/bin/mktemp -d)"
              digest_file="$(${pkgs.coreutils}/bin/mktemp)"
              cleanup() {
                ${pkgs.coreutils}/bin/rm -rf "$mc_config_dir"
                ${pkgs.coreutils}/bin/rm -f "$digest_file"
              }
              trap cleanup EXIT HUP INT TERM

              export MC_CONFIG_DIR="$mc_config_dir"
              export MC_HOST_backup="${
                if lib.hasPrefix "https://" settings.metadataBackupEndpoint then "https" else "http"
              }://$AWS_ACCESS_KEY_ID:$AWS_SECRET_ACCESS_KEY@${metadataBackupAuthority}"

              object_name="postgresql/niks3-$(${pkgs.coreutils}/bin/date -u +%Y%m%dT%H%M%SZ).sql.zstd"
              ${pkgs.b3sum}/bin/b3sum ${lib.escapeShellArg metadataBackupDump} > "$digest_file"
              ${minioClient} cp \
                ${lib.escapeShellArg metadataBackupDump} \
                "backup/${settings.metadataBackupBucket}/$object_name" \
                --config-dir "$mc_config_dir"
              ${minioClient} cp \
                "$digest_file" \
                "backup/${settings.metadataBackupBucket}/$object_name.b3" \
                --config-dir "$mc_config_dir"
            '';
          in
          {
            imports = [ inputs.niks3.nixosModules.niks3 ];
            assertions = evaluated.assertions ++ [
              {
                assertion = niks3Package.version == upstreamVersion;
                message = "niks3 requires the reviewed version ${upstreamVersion}";
              }
            ];

            clan.core.vars.generators.${storageGeneratorName} = {
              share = true;
              files = {
                "access-key" = {
                  secret = true;
                  deploy = true;
                  owner = "niks3";
                  group = "niks3";
                  mode = secretFileMode;
                };
                "secret-key" = {
                  secret = true;
                  deploy = true;
                  owner = "niks3";
                  group = "niks3";
                  mode = secretFileMode;
                };
                "aws-env" = {
                  secret = true;
                  deploy = true;
                  owner = "root";
                  group = "root";
                  mode = secretFileMode;
                };
                "signing-key" = {
                  secret = true;
                  deploy = true;
                  owner = "niks3";
                  group = "niks3";
                  mode = secretFileMode;
                };
                "signing-key-public" = {
                  secret = false;
                  deploy = false;
                };
              };
              runtimeInputs = [
                config.nix.package
                pkgs.openssl
              ];
              script = ''
                secret_key="$(${lib.getExe pkgs.openssl} rand -hex ${toString secretKeyByteCount})"
                printf '%s' ${lib.escapeShellArg settings.accessKeyId} > "$out/access-key"
                printf '%s' "$secret_key" > "$out/secret-key"
                printf 'AWS_ACCESS_KEY_ID=%s\nAWS_SECRET_ACCESS_KEY=%s\n' \
                  ${lib.escapeShellArg settings.accessKeyId} "$secret_key" > "$out/aws-env"
                nix --extra-experimental-features "nix-command flakes" \
                  key generate-secret --key-name ${lib.escapeShellArg signingKeyName} > "$out/signing-key"
                nix --extra-experimental-features "nix-command flakes" \
                  key convert-secret-to-public < "$out/signing-key" > "$out/signing-key-public"
              '';
            };

            clan.core.vars.generators.${metadataBackupGeneratorName} = lib.mkIf settings.metadataBackupEnabled {
              share = true;
              files."aws-env" = {
                secret = true;
                deploy = true;
                owner = "root";
                group = "root";
                mode = secretFileMode;
              };
              runtimeInputs = [ pkgs.openssl ];
              script = ''
                secret_key="$(${lib.getExe pkgs.openssl} rand -hex ${toString secretKeyByteCount})"
                printf 'AWS_ACCESS_KEY_ID=%s\nAWS_SECRET_ACCESS_KEY=%s\n' \
                  ${lib.escapeShellArg settings.metadataBackupAccessKeyId} \
                  "$secret_key" > "$out/aws-env"
              '';
            };

            users.users.niks3.extraGroups = [ uploaderGroup ];

            networking.firewall = lib.mkIf settings.openFirewall {
              interfaces.${settings.firewallInterface}.allowedTCPPorts = [ settings.port ];
            };

            services.niks3 = {
              enable = true;
              package = niks3Package;
              serverPackage = niks3ServerPackage;
              httpAddr = "${settings.bindAddress}:${toString settings.port}";
              apiTokenFile = apiTokenFile;
              signKeyFiles = [ signingKeyFile ];
              cacheUrl = serverUrl;
              serverUrl = serverUrl;
              maxNarSize = settings.maxNarSize;
              readProxy.enable = true;
              database.createLocally = true;
              s3 = {
                endpoint = storageAuthority;
                bucket = settings.bucketName;
                region = settings.region;
                useSSL = lib.hasPrefix "https://" settings.storageEndpoint;
                bucketLookup = "path";
                accessKeyFile = accessKeyFile;
                secretKeyFile = secretKeyFile;
              };
              gc = {
                enable = true;
                olderThan = settings.gcOlderThan;
                failedUploadsOlderThan = settings.gcFailedUploadsOlderThan;
                schedule = settings.gcSchedule;
              };
            };

            systemd.services.niks3-storage-provision = lib.mkIf settings.provisionStorage {
              description = "Provision bucket-scoped RustFS storage for niks3";
              wantedBy = [ "multi-user.target" ];
              before = [ "niks3.service" ];
              after = [
                "network-online.target"
                storageServiceUnit
                "tailscaled.service"
              ];
              wants = [
                "network-online.target"
                storageServiceUnit
                "tailscaled.service"
              ];
              path = [ pkgs.getent ];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
                ExecStart = provisionStorage;
                EnvironmentFile = [
                  rustfsAdminEnvironmentFile
                  storageEnvironmentFile
                ];
                UMask = serviceUmask;
                NoNewPrivileges = true;
                PrivateTmp = true;
                ProtectHome = true;
                ProtectSystem = "strict";
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

            # r[impl onix.rustfs_build_caches.recovery.backup]
            services.postgresqlBackup = lib.mkIf settings.metadataBackupEnabled {
              enable = true;
              backupAll = false;
              databases = [ "niks3" ];
              location = settings.metadataBackupDirectory;
              startAt = settings.metadataBackupSchedule;
              compression = "zstd";
              pgdumpOptions = "--no-owner --no-privileges";
            };

            systemd.services.niks3-metadata-backup-provision = lib.mkIf settings.metadataBackupEnabled {
              description = "Provision narrow RustFS storage for niks3 metadata backups";
              wantedBy = [ "multi-user.target" ];
              before = [ "postgresqlBackup-niks3.service" ];
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
                ExecStart = provisionMetadataBackup;
                EnvironmentFile = [
                  metadataBackupAdminEnvironmentFile
                  metadataBackupEnvironmentFile
                ];
                UMask = serviceUmask;
                NoNewPrivileges = true;
                PrivateTmp = true;
                ProtectHome = true;
                ProtectSystem = "strict";
                CapabilityBoundingSet = "";
                AmbientCapabilities = "";
                LockPersonality = true;
                RestrictAddressFamilies = [
                  "AF_UNIX"
                  "AF_INET"
                  "AF_INET6"
                ];
              };
            };

            systemd.services.postgresqlBackup-niks3 = lib.mkIf settings.metadataBackupEnabled {
              after = [ "niks3-metadata-backup-provision.service" ];
              requires = [ "niks3-metadata-backup-provision.service" ];
              unitConfig.OnSuccess = [ "niks3-metadata-backup-upload.service" ];
            };

            systemd.services.niks3-metadata-backup-upload = lib.mkIf settings.metadataBackupEnabled {
              description = "Upload a BLAKE3-bound niks3 metadata backup";
              after = [
                "network-online.target"
                "niks3-metadata-backup-provision.service"
              ];
              wants = [ "network-online.target" ];
              requires = [ "niks3-metadata-backup-provision.service" ];
              serviceConfig = {
                Type = "oneshot";
                ExecStart = uploadMetadataBackup;
                EnvironmentFile = metadataBackupEnvironmentFile;
                UMask = serviceUmask;
                NoNewPrivileges = true;
                PrivateTmp = true;
                ProtectHome = true;
                ProtectSystem = "strict";
                ReadOnlyPaths = [ metadataBackupDump ];
                CapabilityBoundingSet = "";
                AmbientCapabilities = "";
                LockPersonality = true;
                RestrictAddressFamilies = [
                  "AF_UNIX"
                  "AF_INET"
                  "AF_INET6"
                ];
              };
            };

            systemd.services.niks3 = {
              after = lib.optional settings.provisionStorage "niks3-storage-provision.service";
              requires = lib.optional settings.provisionStorage "niks3-storage-provision.service";
              serviceConfig = {
                CPUQuota = backgroundCpuQuota;
                CPUWeight = backgroundResourceWeight;
                IOWeight = backgroundResourceWeight;
                Nice = backgroundNice;
              };
            };
          };
      };
  };

  roles.uploader = {
    description = "Crash-safe Nix post-build uploader and trusted read-proxy client";
    interface = mkSettings.mkInterface schema.uploader;

    perInstance =
      { extendSettings, instanceName, ... }:
      {
        nixosModule =
          {
            config,
            inputs,
            lib,
            pkgs,
            ...
          }:
          let
            ms = import ../../lib/mk-settings.nix { inherit lib; };
            settings = extendSettings (ms.mkDefaults schema.uploader);
            evaluated = import ./settings.nix { inherit lib; } "uploader" settings;
            apiGeneratorName = apiGeneratorNameFor instanceName;
            apiTokenFile = config.clan.core.vars.generators.${apiGeneratorName}.files."api-token".path;
            publicKeySource = publicKeySourceFor inputs instanceName;
            publicKeyAvailable = builtins.pathExists publicKeySource;
            publicKey = lib.optionalString publicKeyAvailable (lib.fileContents publicKeySource);
            hookPackage = inputs.niks3.packages.${pkgs.stdenv.hostPlatform.system}.niks3-hook;
            apiTokenByteCount = 32;
            healthProbeTimeoutSeconds = 3;
            queueMetricIntervalSeconds = 60;
            queueDatabase = "/var/lib/niks3-hook/upload-queue.db";
            queueMetricDirectory = "/var/lib/prometheus-node-exporter-text-files";
            queueMetricDirectoryMode = "0755";
            queueMetricFileMode = "0644";
            queueMetricFile = "${queueMetricDirectory}/niks3-upload-queue.prom";
            disabledPostBuildHook = pkgs.writeShellScript "niks3-post-build-upload-disabled" ''
              exit 0
            '';
            maintenanceGuard = pkgs.writeShellScript "niks3-maintenance-guard" ''
              set -eu
              ${lib.concatMapStringsSep "\n" (url: ''
                ${pkgs.curl}/bin/curl \
                  --fail \
                  --silent \
                  --show-error \
                  --max-time ${toString healthProbeTimeoutSeconds} \
                  --output /dev/null \
                  ${lib.escapeShellArg url}
              '') settings.maintenanceGuardUrls}
            '';
            queueMetricWriter = pkgs.writeShellApplication {
              name = "niks3-queue-metric-writer";
              runtimeInputs = [
                pkgs.coreutils
                pkgs.sqlite
              ];
              text = ''
                set -eu
                count=0
                if test -f ${lib.escapeShellArg queueDatabase}; then
                  count="$(sqlite3 -readonly ${lib.escapeShellArg queueDatabase} 'select count(*) from upload_queue;')"
                fi
                temporary_file="$(mktemp ${lib.escapeShellArg "${queueMetricDirectory}/.niks3-upload-queue.XXXXXX"})"
                trap 'rm -f "$temporary_file"' EXIT HUP INT TERM
                {
                  echo '# HELP onix_niks3_upload_queue_paths Durable store paths waiting for maintenance upload.'
                  echo '# TYPE onix_niks3_upload_queue_paths gauge'
                  printf 'onix_niks3_upload_queue_paths{node=%s} %s\n' \
                    ${lib.escapeShellArg config.networking.hostName} \
                    "$count"
                } > "$temporary_file"
                chmod ${queueMetricFileMode} "$temporary_file"
                mv "$temporary_file" ${lib.escapeShellArg queueMetricFile}
              '';
            };
          in
          {
            imports = [ inputs.niks3.nixosModules.niks3-auto-upload ];
            assertions = evaluated.assertions;

            clan.core.vars.generators.${apiGeneratorName} = {
              share = true;
              files."api-token" = {
                secret = true;
                deploy = true;
                owner = "root";
                group = uploaderGroup;
                mode = sharedSecretFileMode;
              };
              runtimeInputs = [ pkgs.openssl ];
              script = ''
                ${lib.getExe pkgs.openssl} rand -hex ${toString apiTokenByteCount} > "$out/api-token"
              '';
            };

            users.groups.${uploaderGroup} = { };

            nix.settings = {
              extra-substituters = [ settings.serverUrl ];
              extra-trusted-public-keys = lib.optional publicKeyAvailable publicKey;
            }
            // lib.optionalAttrs (!settings.automaticUploads) {
              post-build-hook = lib.mkForce disabledPostBuildHook;
            };

            services.niks3-auto-upload = {
              enable = true;
              package = hookPackage;
              serverUrl = settings.serverUrl;
              authTokenFile = apiTokenFile;
              batchSize = settings.batchSize;
              idleExitTimeout = settings.idleExitTimeoutSeconds;
              maxConcurrentUploads = settings.maxConcurrentUploads;
              verifyS3Integrity = settings.verifyS3Integrity;
            };

            # r[impl onix.rustfs_build_caches.uploaders.disabled]
            systemd.sockets.niks3-auto-upload.wantedBy = lib.mkIf (!settings.automaticUploads) (
              lib.mkForce [ ]
            );

            # r[impl onix.rustfs_build_caches.uploaders.maintenance]
            systemd.services.niks3-auto-upload = lib.mkIf (!settings.automaticUploads) {
              unitConfig.ConditionPathExists = settings.maintenanceMarker;
              serviceConfig.ExecStartPre = maintenanceGuard;
            };

            # r[impl onix.rustfs_build_caches.monitoring]
            services.prometheus.exporters.node.extraFlags =
              lib.mkIf (config.services.prometheus.exporters.node.enable)
                [ "--collector.textfile.directory=${queueMetricDirectory}" ];
            systemd.tmpfiles.rules = lib.mkIf config.services.prometheus.exporters.node.enable [
              "d ${queueMetricDirectory} ${queueMetricDirectoryMode} root root - -"
            ];
            systemd.services.niks3-queue-metrics = lib.mkIf config.services.prometheus.exporters.node.enable {
              description = "Export durable niks3 queue depth";
              serviceConfig = {
                Type = "oneshot";
                ExecStart = lib.getExe queueMetricWriter;
                NoNewPrivileges = true;
                PrivateTmp = true;
                ProtectHome = true;
                ProtectSystem = "strict";
                ReadWritePaths = [ queueMetricDirectory ];
                CapabilityBoundingSet = "";
                LockPersonality = true;
                RestrictAddressFamilies = [ "AF_UNIX" ];
              };
            };
            systemd.timers.niks3-queue-metrics = lib.mkIf config.services.prometheus.exporters.node.enable {
              description = "Refresh durable niks3 queue depth";
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnBootSec = "${toString queueMetricIntervalSeconds}s";
                OnUnitActiveSec = "${toString queueMetricIntervalSeconds}s";
                Unit = "niks3-queue-metrics.service";
              };
            };
          };
      };
  };
}
