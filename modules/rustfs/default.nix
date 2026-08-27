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
            singleNodeStartTimeoutSeconds = 30;
            serviceRestartDelaySeconds = 10;
            stopTimeoutSeconds = 30;
            openFileLimit = 1048576;
            processLimit = 32768;
            clusterStartTimeoutSeconds = settings.topologyWaitTimeoutSeconds + clusterStartupGraceSeconds;
            startTimeoutSeconds =
              if topology.distributed then clusterStartTimeoutSeconds else singleNodeStartTimeoutSeconds;
            enabledPorts = [ settings.apiPort ] ++ lib.optional settings.enableConsole settings.consolePort;
            serviceName = settings.serviceName;
            serviceEnvironment = {
              RUSTFS_ADDRESS = "${settings.bindAddress}:${toString settings.apiPort}";
              RUSTFS_CONSOLE_ADDRESS = "${settings.bindAddress}:${toString settings.consolePort}";
              RUSTFS_CONSOLE_ENABLE = if settings.enableConsole then "true" else "false";
              RUSTFS_VOLUMES = topology.volumes;
            }
            // topology.distributedEnvironment;
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

            users.users.rustfs = {
              isSystemUser = true;
              group = "rustfs";
            };
            users.groups.rustfs = { };

            networking.firewall = lib.mkIf settings.openFirewall (
              if settings.firewallInterface == null then
                { allowedTCPPorts = enabledPorts; }
              else
                { interfaces.${settings.firewallInterface}.allowedTCPPorts = enabledPorts; }
            );

            systemd.tmpfiles.settings."10-${serviceName}".${settings.dataDir}.d = {
              mode = stateDirectoryMode;
              user = "rustfs";
              group = "rustfs";
            };

            # r[impl onix.rustfs_cluster.instances]
            systemd.services.${serviceName} = {
              description = "RustFS object storage instance ${instanceName}";
              documentation = [ "https://rustfs.com/docs/" ];
              wantedBy = [ "multi-user.target" ];
              after = [
                "network-online.target"
                "tailscaled.service"
              ];
              wants = [
                "network-online.target"
                "tailscaled.service"
              ];
              unitConfig.RequiresMountsFor = [ settings.dataDir ];
              environment = serviceEnvironment;
              preStart = ''
                if [ -z "$RUSTFS_ACCESS_KEY" ] || [ -z "$RUSTFS_SECRET_KEY" ]; then
                  echo "RustFS instance ${instanceName} requires generated credentials" >&2
                  exit 1
                fi
              '';
              serviceConfig = {
                Type = "notify";
                NotifyAccess = "main";
                User = "rustfs";
                Group = "rustfs";
                EnvironmentFile = environmentFile;
                ExecStart = lib.getExe pkgs.rustfs;
                LimitNOFILE = openFileLimit;
                LimitNPROC = processLimit;
                TasksMax = "infinity";
                Restart = "always";
                RestartSec = "${toString serviceRestartDelaySeconds}s";
                OOMScoreAdjust = toString settings.oomScoreAdjust;
                Nice = settings.nice;
                CPUWeight = settings.cpuWeight;
                IOWeight = settings.ioWeight;
                SendSIGKILL = false;
                TimeoutStartSec = "${toString startTimeoutSeconds}s";
                TimeoutStopSec = "${toString stopTimeoutSeconds}s";
                UMask = serviceUmask;
                NoNewPrivileges = true;
                ProtectHome = true;
                PrivateTmp = true;
                PrivateDevices = true;
                ProtectClock = true;
                ProtectKernelTunables = true;
                ProtectKernelModules = true;
                ProtectControlGroups = true;
                ProtectSystem = "strict";
                ReadWritePaths = [ settings.dataDir ];
                RestrictSUIDSGID = true;
                RestrictRealtime = true;
                CapabilityBoundingSet = "";
                AmbientCapabilities = "";
                LockPersonality = true;
                MemoryDenyWriteExecute = true;
                RestrictAddressFamilies = [
                  "AF_UNIX"
                  "AF_INET"
                  "AF_INET6"
                  "AF_NETLINK"
                ];
              };
            };
          };
      };
  };

  roles.backup = {
    description = "Object-level backup and restore probes for authoritative RustFS buckets";
    interface = mkSettings.mkInterface schema.backup;

    perInstance =
      { extendSettings, instanceName, ... }:
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
            settings = extendSettings (ms.mkDefaults schema.backup);
            evaluated = import ./backup-settings.nix { inherit lib; } settings;
            adminEnvironmentFile =
              config.clan.core.vars.generators.${settings.adminGenerator}.files."env-file".path;
            sourceAuthority = lib.removePrefix "http://" (lib.removePrefix "https://" settings.sourceEndpoint);
            sourceScheme = if lib.hasPrefix "https://" settings.sourceEndpoint then "https" else "http";
            snapshotRoot = "${settings.targetDir}/snapshots";
            latestLink = "${settings.targetDir}/latest";
            directoryMode = "0700";
            fileMode = "0600";
            serviceUmask = "0077";
            minioClient = lib.getExe pkgs.minio-client;
            backupScript = pkgs.writeShellScript "rustfs-authority-backup" ''
              set -eu
              umask ${serviceUmask}

              timestamp="$(${pkgs.coreutils}/bin/date -u +%Y%m%dT%H%M%SZ)"
              staging=${lib.escapeShellArg "${settings.targetDir}/.partial"}-$timestamp
              completed=${lib.escapeShellArg snapshotRoot}/$timestamp
              mc_config_dir="$(${pkgs.coreutils}/bin/mktemp -d)"
              cleanup() {
                ${pkgs.coreutils}/bin/rm -rf "$mc_config_dir" "$staging"
              }
              trap cleanup EXIT HUP INT TERM

              ${pkgs.coreutils}/bin/install -d -m ${directoryMode} \
                ${lib.escapeShellArg settings.targetDir} \
                ${lib.escapeShellArg snapshotRoot} \
                "$staging"
              export MC_CONFIG_DIR="$mc_config_dir"
              export MC_HOST_source="${sourceScheme}://$RUSTFS_ACCESS_KEY:$RUSTFS_SECRET_KEY@${sourceAuthority}"

              ${lib.concatMapStringsSep "\n" (bucket: ''
                ${minioClient} mirror \
                  "source/${bucket}" \
                  "$staging/${bucket}" \
                  --config-dir "$mc_config_dir"
              '') settings.buckets}

              (
                cd "$staging"
                ${pkgs.findutils}/bin/find . -type f ! -name MANIFEST.b3 -print0 \
                  | ${pkgs.coreutils}/bin/sort -z \
                  | while IFS= read -r -d "" object; do
                      ${pkgs.b3sum}/bin/b3sum "$object"
                    done
              ) > "$staging/MANIFEST.b3"
              ${pkgs.coreutils}/bin/chmod ${fileMode} "$staging/MANIFEST.b3"
              ${pkgs.coreutils}/bin/mv "$staging" "$completed"
              ${pkgs.coreutils}/bin/ln -sfn "$completed" ${lib.escapeShellArg latestLink}
              ${pkgs.findutils}/bin/find ${lib.escapeShellArg snapshotRoot} \
                -mindepth 1 -maxdepth 1 -type d \
                -mtime +${toString settings.retentionDays} \
                -exec ${pkgs.coreutils}/bin/rm -rf -- {} +
            '';
            restoreProbeScript = pkgs.writeShellScript "rustfs-authority-restore-probe" ''
              set -eu
              umask ${serviceUmask}

              snapshot="$(${pkgs.coreutils}/bin/readlink -f ${lib.escapeShellArg latestLink})"
              test -d "$snapshot"
              test -s "$snapshot/MANIFEST.b3"
              (
                cd "$snapshot"
                ${pkgs.b3sum}/bin/b3sum --check MANIFEST.b3
              )

              restore_source="$(${pkgs.findutils}/bin/find "$snapshot" -type f ! -name MANIFEST.b3 -print -quit)"
              test -n "$restore_source"
              mc_config_dir="$(${pkgs.coreutils}/bin/mktemp -d)"
              restored_file="$(${pkgs.coreutils}/bin/mktemp)"
              cleanup() {
                ${minioClient} rm --recursive --force \
                  "source/${settings.restoreProbeBucket}" \
                  --config-dir "$mc_config_dir" >/dev/null 2>&1 || true
                ${minioClient} rb --force \
                  "source/${settings.restoreProbeBucket}" \
                  --config-dir "$mc_config_dir" >/dev/null 2>&1 || true
                ${pkgs.coreutils}/bin/rm -rf "$mc_config_dir"
                ${pkgs.coreutils}/bin/rm -f "$restored_file"
              }
              trap cleanup EXIT HUP INT TERM

              export MC_CONFIG_DIR="$mc_config_dir"
              export MC_HOST_source="${sourceScheme}://$RUSTFS_ACCESS_KEY:$RUSTFS_SECRET_KEY@${sourceAuthority}"
              ${minioClient} mb --ignore-existing \
                "source/${settings.restoreProbeBucket}" \
                --config-dir "$mc_config_dir"
              ${minioClient} cp \
                "$restore_source" \
                "source/${settings.restoreProbeBucket}/restore-probe-object" \
                --config-dir "$mc_config_dir"
              ${minioClient} cp \
                "source/${settings.restoreProbeBucket}/restore-probe-object" \
                "$restored_file" \
                --config-dir "$mc_config_dir"
              ${pkgs.diffutils}/bin/cmp "$restore_source" "$restored_file"
            '';
          in
          {
            assertions = evaluated.assertions;

            systemd.tmpfiles.rules = [
              "d ${settings.targetDir} ${directoryMode} root root - -"
              "d ${snapshotRoot} ${directoryMode} root root - -"
            ];

            # r[impl onix.rustfs_build_caches.recovery.backup]
            systemd.services."rustfs-authority-backup-${instanceName}" = {
              description = "Back up authoritative RustFS buckets";
              path = [ pkgs.getent ];
              after = [
                "network-online.target"
                "tailscaled.service"
              ];
              wants = [
                "network-online.target"
                "tailscaled.service"
              ];
              unitConfig.RequiresMountsFor = [ settings.targetDir ];
              serviceConfig = {
                Type = "oneshot";
                ExecStart = backupScript;
                EnvironmentFile = adminEnvironmentFile;
                UMask = serviceUmask;
                NoNewPrivileges = true;
                PrivateTmp = true;
                ProtectHome = true;
                ProtectSystem = "strict";
                ReadWritePaths = [ settings.targetDir ];
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
            systemd.timers."rustfs-authority-backup-${instanceName}" = {
              description = "Schedule authoritative RustFS bucket backups";
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnCalendar = settings.schedule;
                Persistent = true;
                Unit = "rustfs-authority-backup-${instanceName}.service";
              };
            };

            # r[impl onix.rustfs_build_caches.recovery.restore]
            systemd.services."rustfs-authority-restore-probe-${instanceName}" = {
              description = "Verify one bounded RustFS object restore";
              path = [ pkgs.getent ];
              after = [
                "network-online.target"
                "tailscaled.service"
              ];
              wants = [
                "network-online.target"
                "tailscaled.service"
              ];
              unitConfig.RequiresMountsFor = [ settings.targetDir ];
              serviceConfig = {
                Type = "oneshot";
                ExecStart = restoreProbeScript;
                EnvironmentFile = adminEnvironmentFile;
                UMask = serviceUmask;
                NoNewPrivileges = true;
                PrivateTmp = true;
                ProtectHome = true;
                ProtectSystem = "strict";
                ReadOnlyPaths = [ settings.targetDir ];
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
          };
      };
  };

  perMachine = _: {
    nixosModule = _: { };
  };
}
