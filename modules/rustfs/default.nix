{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
in
{
  _class = "clan.service";
  manifest = {
    name = "rustfs";
    readme = "RustFS single-node S3-compatible object storage with Clan-managed credentials";
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
            generatorName = "rustfs-${instanceName}";
            environmentFile = config.clan.core.vars.generators.${generatorName}.files."env-file".path;
            accessKeyByteCount = 10;
            secretKeyByteCount = 32;
            secretFileMode = "0400";
            stateDirectoryMode = "0700";
            serviceUmask = "0077";
            enabledPorts = [ settings.apiPort ] ++ lib.optional settings.enableConsole settings.consolePort;
          in
          {
            assertions = [
              {
                assertion = settings.dataDir != "" && lib.hasPrefix "/" settings.dataDir;
                message = "rustfs dataDir must be a non-empty absolute path";
              }
              {
                assertion = !lib.hasInfix " " settings.dataDir;
                message = "rustfs dataDir must not contain spaces because RUSTFS_VOLUMES uses spaces as separators";
              }
              {
                assertion = !settings.enableConsole || settings.apiPort != settings.consolePort;
                message = "rustfs apiPort and consolePort must differ when the console is enabled";
              }
            ];

            clan.core.vars.generators.${generatorName} = {
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
                RUSTFS_VOLUMES = settings.dataDir;
              };
            };

            networking.firewall = lib.mkIf settings.openFirewall (
              if settings.firewallInterface == null then
                { allowedTCPPorts = enabledPorts; }
              else
                { interfaces.${settings.firewallInterface}.allowedTCPPorts = enabledPorts; }
            );

            systemd.tmpfiles.settings."20-rustfs-hardening".${settings.dataDir}.d = {
              mode = stateDirectoryMode;
              user = "rustfs";
              group = "rustfs";
            };

            systemd.services.rustfs = {
              unitConfig.RequiresMountsFor = [ settings.dataDir ];
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
              };
            };
          };
      };
  };

  perMachine = _: {
    nixosModule = _: { };
  };
}
