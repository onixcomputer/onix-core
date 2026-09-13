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
            runServer = pkgs.writeShellScript "run-bookshelf-server" ''
              cd ${lib.escapeShellArg runtimeApplication}
              exec ${pkgs.nodejs_24}/bin/node server.js
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
            # r[impl onix.bookshelf.fetch]
            # Download an owned EPUB from a catalog into the source directory and
            # publish it. Project Gutenberg works keyless. Anna's Archive delegates to
            # the external 'annas-mcp' CLI and needs ANNAS_SECRET_KEY for downloads.
            fetchTool = pkgs.writeShellApplication {
              name = "bookshelf-fetch";
              runtimeInputs = [
                pkgs.coreutils
                pkgs.curl
                pkgs.gawk
                pkgs.gnused
                pkgs.jq
                pkgs.systemd
              ];
              text = ''
                set -euo pipefail

                source_dir='${lib.escapeShellArg settings.sourceDir}'
                service_user='${serviceUser}'
                service_group='${serviceGroup}'
                source_mode='${sourceFileMode}'

                usage() {
                  cat >&2 <<'EOF'
                usage: sudo bookshelf-fetch gutenberg "search terms" [--match N]
                       sudo bookshelf-fetch anna "search terms" [--md5 MD5]

                gutenberg downloads and publishes a Project Gutenberg EPUB (no key
                required). anna searches Anna's Archive through the 'annas-mcp' CLI;
                downloads need ANNAS_SECRET_KEY set (donation API key).
                EOF
                }

                if [ "$#" -eq 0 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
                  usage
                  exit 1
                fi
                if [ "$(id -u)" -ne 0 ]; then
                  echo "bookshelf-fetch must run as root" >&2
                  exit 1
                fi

                provider="$1"; shift

                publish() {
                  systemctl start --wait bookshelf-publish.service
                }

                sanitize_name() {
                  printf '%s' "$1" \
                    | tr '[:upper:]' '[:lower:]' \
                    | sed -E 's/[^[:alnum:]]+/-/g; s/^-+//; s/-+$//'
                }

                gutenberg_fetch() {
                  local query="$1" match="''${MATCH:-1}"
                  local encoded q_file results n=0 line id title author dest name
                  encoded="$(printf '%s' "$query" | jq -sRr @uri)"
                  q_file="$(mktemp)"
                  results="$(mktemp)"
                  curl -fsSL --max-time 60 -A 'Mozilla/5.0 (bookshelf-fetch)' \
                    "https://www.gutenberg.org/ebooks/search/?query=$encoded" -o "$q_file"
                  awk '
                    BEGIN { RS="<li class=\"booklink\""; OFS="|" }
                    NR==1 { next }
                    {
                      id=""; title=""; author=""
                      if (match($0, /href="\/ebooks\/[0-9]+"/)) {
                        s=substr($0,RSTART,RLENGTH); gsub(/[^0-9]/,"",s); id=s
                      }
                      if (match($0, /<span class="title">[^<]*<\/span>/)) {
                        t=substr($0,RSTART,RLENGTH); gsub(/<[^>]+>/,"",t); title=t
                      }
                      if (match($0, /<span class="subtitle">[^<]*<\/span>/)) {
                        a=substr($0,RSTART,RLENGTH); gsub(/<[^>]+>/,"",a); author=a
                      }
                      if (id != "") print id "|" title "|" author
                    }
                  ' "$q_file" > "$results"
                  if [ ! -s "$results" ]; then
                    echo "gutenberg: no results for '$query'" >&2
                    exit 1
                  fi
                  echo "gutenberg results:"
                  while IFS='|' read -r id title author; do
                    [ -n "$id" ] || continue
                    n=$((n+1))
                    printf '  %d) %s by %s\n' "$n" "$title" "$author"
                  done < "$results"
                  if [ "$match" -lt 1 ] || [ "$match" -gt "$n" ]; then
                    echo "gutenberg: --match $match out of range (1..$n)" >&2
                    exit 1
                  fi
                  line="$(sed -n "''${match}p" "$results")"
                  id="''${line%%|*}"
                  title="$(printf '%s' "''${line#*|}" | cut -d'|' -f1)"
                  name="$(sanitize_name "$title").epub"
                  dest="''${source_dir}/''${name}"
                  echo "downloading Gutenberg #$id -> $name"
                  if [ -e "$dest" ]; then
                    echo "already present, skipping: $dest"
                  else
                    curl -fsSL --max-time 120 -A 'Mozilla/5.0 (bookshelf-fetch)' \
                      "https://www.gutenberg.org/cache/epub/''${id}/pg''${id}.epub" \
                      -o "/tmp/.bookshelf-fetch-''${name}"
                    install -o "$service_user" -g "$service_group" -m "$source_mode" -- \
                      "/tmp/.bookshelf-fetch-''${name}" "$dest"
                    rm -f "/tmp/.bookshelf-fetch-''${name}"
                  fi
                  rm -f "$q_file" "$results"
                  publish
                }

                anna_fetch() {
                  local query="$1" md5="''${MD5:-}"
                  if ! command -v annas-mcp >/dev/null 2>&1; then
                    echo "anna provider requires the 'annas-mcp' CLI on PATH" >&2
                    exit 1
                  fi
                  if [ -z "$md5" ]; then
                    export ANNAS_DOWNLOAD_PATH="$source_dir"
                    if ! annas-mcp book-search "$query"; then
                      annas-mcp search "$query"
                    fi
                  else
                    if [ -z "''${ANNAS_SECRET_KEY:-}" ]; then
                      echo "warning: ANNAS_SECRET_KEY unset; anna download may fail" >&2
                    fi
                    export ANNAS_DOWNLOAD_PATH="$source_dir"
                    if ! annas-mcp book-download "$md5" "$query.epub"; then
                      annas-mcp download "$md5" "$query.epub"
                    fi
                    publish
                  fi
                }

                case "$provider" in
                  gutenberg)
                    query="$1"; shift || true
                    MATCH=1
                    while [ "$#" -gt 0 ]; do
                      case "$1" in
                        --match) MATCH="$2"; shift 2 || true ;;
                        *) shift ;;
                      esac
                    done
                    gutenberg_fetch "$query"
                    ;;
                  anna)
                    query="$1"; shift || true
                    MD5=
                    while [ "$#" -gt 0 ]; do
                      case "$1" in
                        --md5) MD5="$2"; shift 2 || true ;;
                        *) shift ;;
                      esac
                    done
                    anna_fetch "$query"
                    ;;
                  *)
                    usage
                    exit 1
                    ;;
                esac
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

            environment.systemPackages = [
              importTool
              fetchTool
            ];

            systemd = {
              tmpfiles.rules = [
                "d ${settings.sourceDir} ${privateDirectoryMode} ${serviceUser} ${serviceGroup} -"
                "d ${settings.libraryDir} ${privateDirectoryMode} ${serviceUser} ${serviceGroup} -"
              ];

              services = {
                # r[impl onix.bookshelf.runtime]
                # r[impl onix.bookshelf.network]
                bookshelf = {
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
                    ExecStart = runServer;
                    User = serviceUser;
                    Group = serviceGroup;
                    UMask = serviceUmask;
                    RuntimeDirectory = runtimeDirectory;
                    RuntimeDirectoryMode = privateDirectoryMode;
                    WorkingDirectory = runtimeRoot;
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
                bookshelf-publish = {
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
