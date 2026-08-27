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
  storageGeneratorNameFor = instanceName: "niks3-${instanceName}-storage";
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
            apiGeneratorName = apiGeneratorNameFor instanceName;
            apiTokenFile = config.clan.core.vars.generators.${apiGeneratorName}.files."api-token".path;
            accessKeyFile = config.clan.core.vars.generators.${storageGeneratorName}.files."access-key".path;
            secretKeyFile = config.clan.core.vars.generators.${storageGeneratorName}.files."secret-key".path;
            signingKeyFile = config.clan.core.vars.generators.${storageGeneratorName}.files."signing-key".path;
            storageEnvironmentFile =
              config.clan.core.vars.generators.${storageGeneratorName}.files."aws-env".path;
            rustfsAdminEnvironmentFile =
              config.clan.core.vars.generators.${settings.rustfsAdminGenerator}.files."env-file".path;
            policyName = "niks3-${instanceName}";
            storageAuthority = lib.removePrefix "http://" (
              lib.removePrefix "https://" settings.storageEndpoint
            );
            serverUrl = "http://${settings.bindAddress}:${toString settings.port}";
            minioClient = lib.getExe pkgs.minio-client;
            bucketPolicy = pkgs.writeText "${policyName}-policy.json" (
              policyLib.render {
                inherit (settings) bucketName;
                allowDelete = true;
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

            users.users.niks3.extraGroups = [ uploaderGroup ];

            networking.firewall = lib.mkIf settings.openFirewall {
              interfaces.${settings.firewallInterface}.allowedTCPPorts = [ settings.port ];
            };

            services.niks3 = {
              enable = true;
              package = niks3Package;
              serverPackage = niks3ServerPackage;
              httpAddr = "${settings.bindAddress}:${toString settings.port}";
              inherit apiTokenFile;
              signKeyFiles = [ signingKeyFile ];
              cacheUrl = serverUrl;
              inherit serverUrl;
              inherit (settings) maxNarSize;
              readProxy.enable = true;
              database.createLocally = true;
              s3 = {
                endpoint = storageAuthority;
                bucket = settings.bucketName;
                inherit (settings) region;
                useSSL = lib.hasPrefix "https://" settings.storageEndpoint;
                bucketLookup = "path";
                inherit accessKeyFile;
                inherit secretKeyFile;
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

            systemd.services.niks3 = {
              after = lib.optional settings.provisionStorage "niks3-storage-provision.service";
              requires = lib.optional settings.provisionStorage "niks3-storage-provision.service";
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
          in
          {
            imports = [ inputs.niks3.nixosModules.niks3-auto-upload ];
            inherit (evaluated) assertions;

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
            };

            services.niks3-auto-upload = {
              enable = true;
              package = hookPackage;
              inherit (settings) serverUrl;
              authTokenFile = apiTokenFile;
              inherit (settings) batchSize;
              idleExitTimeout = settings.idleExitTimeoutSeconds;
              inherit (settings) maxConcurrentUploads;
              inherit (settings) verifyS3Integrity;
            };
          };
      };
  };
}
