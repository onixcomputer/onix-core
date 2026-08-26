{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
in
{
  _class = "clan.service";
  manifest = {
    name = "bookshelf";
    readme = "Private browser and OPDS library for owned EPUB and PDF files";
  };

  roles.server = {
    description = "Tailnet-only Bookshelf Node server";
    interface = mkSettings.mkInterface schema.server;

    perInstance =
      { extendSettings, ... }:
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
            settingsLib = import ./settings.nix { inherit lib; };
            validationErrors = settingsLib.validate settings;
            bookshelfPackage = pkgs.callPackage ../../pkgs/bookshelf { };
            serviceUser = "bookshelf";
            serviceGroup = "bookshelf";
            privateDirectoryMode = "0700";
            sourceFileMode = "0600";
            serviceUmask = "0077";
            runtimeDirectory = "bookshelf";
            runtimeRoot = "/run/${runtimeDirectory}";
            runtimeApplication = "${runtimeRoot}/app";
            syncCacheDirectory = "bookshelf-sync";
            syncCachePath = "/var/cache/${syncCacheDirectory}";
            syncBuildDirectory = "${syncCachePath}/build";
            configurationDirectory = pkgs.writeTextDir "bookshelf.config.json" (
              builtins.toJSON {
                input = settings.sourceDir;
                output = syncBuildDirectory;
                storage = {
                  provider = "fs";
                  directory = settings.libraryDir;
                };
              }
            );
            prepareRuntime = pkgs.writeShellScript "prepare-bookshelf-runtime" ''
              rm -rf ${lib.escapeShellArg runtimeApplication}
              cp -a ${lib.escapeShellArg "${bookshelfPackage}/lib/bookshelf/apps/bookshelf"} ${lib.escapeShellArg runtimeApplication}
              chmod -R u+w ${lib.escapeShellArg runtimeApplication}
              ln -sfn ${lib.escapeShellArg "${bookshelfPackage}/lib/bookshelf/node_modules"} ${lib.escapeShellArg "${runtimeRoot}/node_modules"}
            '';
            importTool = pkgs.writeShellApplication {
              name = "bookshelf-import";
              runtimeInputs = [
                pkgs.coreutils
                pkgs.systemd
              ];
              text = ''
                if [ "$#" -eq 0 ]; then
                  echo "usage: sudo bookshelf-import BOOK.epub|BOOK.pdf [...]" >&2
                  exit 1
                fi

                if [ "$(id -u)" -ne 0 ]; then
                  echo "bookshelf-import must run as root" >&2
                  exit 1
                fi

                for source_path in "$@"; do
                  if [ ! -f "$source_path" ]; then
                    echo "not a regular file: $source_path" >&2
                    exit 1
                  fi

                  case "$source_path" in
                    *.epub|*.EPUB|*.pdf|*.PDF) ;;
                    *)
                      echo "unsupported book type: $source_path" >&2
                      exit 1
                      ;;
                  esac
                done

                for source_path in "$@"; do
                  source_name="$(basename -- "$source_path")"
                  install -o ${serviceUser} -g ${serviceGroup} -m ${sourceFileMode} -- \
                    "$source_path" ${lib.escapeShellArg settings.sourceDir}/"$source_name"
                done

                systemctl start --wait bookshelf-publish.service
              '';
            };
          in
          {
            assertions = [
              {
                assertion = validationErrors == [ ];
                message = lib.concatStringsSep "; " validationErrors;
              }
            ];

            users.groups.${serviceGroup} = { };
            users.users.${serviceUser} = {
              isSystemUser = true;
              group = serviceGroup;
              description = "Bookshelf service account";
            };

            systemd.tmpfiles.rules = [
              "d ${settings.sourceDir} ${privateDirectoryMode} ${serviceUser} ${serviceGroup} -"
              "d ${settings.libraryDir} ${privateDirectoryMode} ${serviceUser} ${serviceGroup} -"
            ];

            environment.systemPackages = [ importTool ];

            # r[impl onix.bookshelf.runtime]
            # r[impl onix.bookshelf.network]
            systemd.services.bookshelf = {
              description = "Private Bookshelf ebook library";
              wantedBy = [ "multi-user.target" ];
              after = [
                "network-online.target"
                "tailscaled.service"
              ];
              wants = [ "network-online.target" ];
              unitConfig.RequiresMountsFor = [ settings.libraryDir ];
              environment = {
                BOOKSHELF_DIRECTORY = settings.libraryDir;
                BOOKSHELF_PROVIDER = "fs";
                BOOKSHELF_READ_ONLY = if settings.readOnly then "1" else "0";
                BOOKSHELF_SITE_URL = settings.siteUrl;
                HOSTNAME = settings.bindAddress;
                NEXT_TELEMETRY_DISABLED = "1";
                NODE_ENV = "production";
                PORT = toString settings.port;
              };
              path = [ pkgs.nodejs_24 ];
              serviceConfig = {
                ExecStartPre = prepareRuntime;
                ExecStart = "${pkgs.nodejs_24}/bin/node ${runtimeApplication}/server.js";
                User = serviceUser;
                Group = serviceGroup;
                UMask = serviceUmask;
                RuntimeDirectory = runtimeDirectory;
                RuntimeDirectoryMode = privateDirectoryMode;
                WorkingDirectory = runtimeApplication;
                Restart = "on-failure";
                RestartSec = settings.restartDelaySeconds;
                ReadWritePaths = [ settings.libraryDir ];
                PrivateDevices = true;
                PrivateTmp = true;
                ProtectClock = true;
                ProtectControlGroups = true;
                ProtectHome = true;
                ProtectHostname = true;
                ProtectKernelLogs = true;
                ProtectKernelModules = true;
                ProtectKernelTunables = true;
                ProtectProc = "invisible";
                ProtectSystem = "strict";
                CapabilityBoundingSet = "";
                AmbientCapabilities = "";
                LockPersonality = true;
                NoNewPrivileges = true;
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

            # r[impl onix.bookshelf.publish]
            systemd.services.bookshelf-publish = {
              description = "Publish owned books into the private Bookshelf library";
              after = [ "local-fs.target" ];
              unitConfig.RequiresMountsFor = [
                settings.sourceDir
                settings.libraryDir
              ];
              serviceConfig = {
                Type = "oneshot";
                ExecStart = "${bookshelfPackage}/bin/bookshelf-sync";
                User = serviceUser;
                Group = serviceGroup;
                UMask = serviceUmask;
                WorkingDirectory = configurationDirectory;
                CacheDirectory = syncCacheDirectory;
                CacheDirectoryMode = privateDirectoryMode;
                ReadOnlyPaths = [ settings.sourceDir ];
                ReadWritePaths = [
                  settings.libraryDir
                  syncCachePath
                ];
                PrivateDevices = true;
                PrivateTmp = true;
                ProtectClock = true;
                ProtectControlGroups = true;
                ProtectHome = true;
                ProtectHostname = true;
                ProtectKernelLogs = true;
                ProtectKernelModules = true;
                ProtectKernelTunables = true;
                ProtectSystem = "strict";
                CapabilityBoundingSet = "";
                AmbientCapabilities = "";
                LockPersonality = true;
                NoNewPrivileges = true;
                RestrictAddressFamilies = [ "AF_UNIX" ];
                RestrictNamespaces = true;
                RestrictRealtime = true;
                RestrictSUIDSGID = true;
                SystemCallArchitectures = "native";
              };
            };

            networking.firewall = lib.mkIf (settings.openFirewall && settings.firewallInterface != null) {
              interfaces.${settings.firewallInterface}.allowedTCPPorts = [ settings.port ];
            };
          };
      };
  };

  perMachine = _: {
    nixosModule = _: { };
  };
}
