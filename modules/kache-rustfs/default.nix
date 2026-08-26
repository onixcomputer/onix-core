{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
in
{
  _class = "clan.service";

  manifest = {
    name = "kache-rustfs";
    readme = "Interactive Kache daemon with a bucket-scoped RustFS remote";
  };

  roles.client = {
    description = "Kache client and RustFS remote provisioner";
    interface = mkSettings.mkInterface schema.client;

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
            settings = extendSettings (ms.mkDefaults schema.client);
            evaluated = import ./settings.nix { inherit lib; } settings;
            kachePackage = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.kache;
            policyLib = import ../../lib/rustfs-bucket-policy.nix { inherit lib; };
            credentialGeneratorName = "kache-rustfs-${instanceName}";
            credentialEnvironmentFile =
              config.clan.core.vars.generators.${credentialGeneratorName}.files."aws-env".path;
            rustfsAdminEnvironmentFile =
              config.clan.core.vars.generators.${settings.rustfsAdminGenerator}.files."env-file".path;
            secretKeyByteCount = 32;
            secretFileMode = "0400";
            serviceUmask = "0077";
            daemonIdleTimeoutSeconds = 0;
            policyName = "kache-rustfs-${instanceName}";
            storageAuthority = lib.removePrefix "http://" (
              lib.removePrefix "https://" settings.storageEndpoint
            );
            minioClient = lib.getExe pkgs.minio-client;
            bucketPolicy = pkgs.writeText "${policyName}-policy.json" (
              policyLib.render {
                bucketName = settings.bucketName;
                allowDelete = true;
                allowMultipart = true;
              }
            );
            kacheConfigFile = (pkgs.formats.toml { }).generate "kache-rustfs.toml" {
              cache = {
                local_store = settings.cacheDir;
                local_max_size = settings.cacheMaxSize;
                local_only = false;
                daemon_idle_timeout_secs = daemonIdleTimeoutSeconds;
                remote = evaluated.remoteConfig;
              };
            };
            provisionStorage = pkgs.writeShellScript "kache-rustfs-provision-storage" ''
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
            syncTool = pkgs.writeShellApplication {
              name = "kache-rustfs-sync";
              runtimeInputs = [ kachePackage ];
              text = ''
                set -a
                # shellcheck source=/dev/null
                . ${lib.escapeShellArg credentialEnvironmentFile}
                set +a
                export KACHE_CONFIG=${lib.escapeShellArg kacheConfigFile}
                export KACHE_CACHE_DIR=${lib.escapeShellArg settings.cacheDir}
                export KACHE_LOCAL_ONLY=0
                exec kache sync "$@"
              '';
            };
          in
          {
            assertions = evaluated.assertions ++ [
              {
                assertion = builtins.hasAttr settings.serviceUser config.users.users;
                message = "kache-rustfs serviceUser must name an existing NixOS user";
              }
            ];

            clan.core.vars.generators.${credentialGeneratorName} = {
              files."aws-env" = {
                secret = true;
                deploy = true;
                owner = settings.serviceUser;
                group = "users";
                mode = secretFileMode;
              };
              runtimeInputs = [ pkgs.openssl ];
              script = ''
                secret_key="$(${lib.getExe pkgs.openssl} rand -hex ${toString secretKeyByteCount})"
                printf 'AWS_ACCESS_KEY_ID=%s\nAWS_SECRET_ACCESS_KEY=%s\n' \
                  ${lib.escapeShellArg settings.accessKeyId} "$secret_key" > "$out/aws-env"
              '';
            };

            environment.systemPackages = [ syncTool ];

            systemd.services.kache-rustfs-storage-provision = lib.mkIf settings.provisionStorage {
              description = "Provision bucket-scoped RustFS storage for Kache";
              wantedBy = [ "multi-user.target" ];
              before = [ "kache-rustfs.service" ];
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

            systemd.services.kache-rustfs = {
              description = "Interactive Kache daemon with RustFS remote storage";
              wantedBy = [ "multi-user.target" ];
              after = [
                "network-online.target"
                "tailscaled.service"
              ]
              ++ lib.optional settings.provisionStorage "kache-rustfs-storage-provision.service";
              wants = [
                "network-online.target"
                "tailscaled.service"
              ];
              requires = lib.optional settings.provisionStorage "kache-rustfs-storage-provision.service";
              unitConfig.RequiresMountsFor = [ settings.cacheDir ];
              environment = {
                KACHE_CONFIG = kacheConfigFile;
                KACHE_CACHE_DIR = settings.cacheDir;
                KACHE_DAEMON_IDLE_TIMEOUT = toString daemonIdleTimeoutSeconds;
                KACHE_LOCAL_ONLY = "0";
                KACHE_LOG = "kache=info";
              };
              serviceConfig = {
                ExecStart = "${lib.getExe kachePackage} daemon run";
                User = settings.serviceUser;
                Group = "users";
                EnvironmentFile = credentialEnvironmentFile;
                Restart = "always";
                RestartSec = settings.restartDelaySeconds;
                UMask = serviceUmask;
                ReadWritePaths = [ settings.cacheDir ];
                NoNewPrivileges = true;
                PrivateDevices = true;
                PrivateTmp = true;
                ProtectHome = true;
                ProtectSystem = "strict";
                ProtectControlGroups = true;
                ProtectKernelModules = true;
                ProtectKernelTunables = true;
                CapabilityBoundingSet = "";
                AmbientCapabilities = "";
                LockPersonality = true;
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
