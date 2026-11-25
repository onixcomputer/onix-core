{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
in
{
  _class = "clan.service";

  manifest = {
    name = "gdrive-backup";
    description = "Encrypted off-site Restic backups and cold storage CLI backed by Google Drive via rclone";
    readme = "Provisions per-account rclone OAuth configs and Restic passwords via Clan SOPS vars, installs operator CLI wrappers, and runs idle-priority scheduled Restic backups per host.";
    categories = [
      "Backup"
      "Storage"
    ];
  };

  roles.default = {
    description = "Machine participating in encrypted Google Drive backups and/or cold storage access";
    interface = mkSettings.mkInterface schema.default;

    perInstance =
      { instanceName, extendSettings, ... }:
      {
        nixosModule =
          {
            config,
            pkgs,
            lib,
            ...
          }:
          let
            ms = import ../../lib/mk-settings.nix { inherit lib; };
            cfg = extendSettings (ms.mkDefaults schema.default);
            generatorName = instanceName;
            rcloneSecretPath = config.clan.core.vars.generators.${generatorName}.files."rclone-conf".path;
            resticPasswordPath =
              config.clan.core.vars.generators.${generatorName}.files."restic-password".path;
            defaultRepo = "rclone:${cfg.remoteName}:${cfg.repoPrefix}/${config.networking.hostName}";
            bwLimitFlag = lib.optionalString (
              cfg.bandwidthLimit != null
            ) "--bwlimit ${lib.escapeShellArg cfg.bandwidthLimit}";

            # Stage the read-only SOPS rclone.conf into a private 0700 temp dir so
            # rclone can refresh short-lived OAuth access tokens cleanly during a run.
            rcloneWrapper = pkgs.writeShellApplication {
              name = "rclone-${cfg.remoteName}";
              runtimeInputs = [
                pkgs.coreutils
                pkgs.rclone
              ];
              text = ''
                set -euo pipefail
                umask 077
                secret=${lib.escapeShellArg rcloneSecretPath}
                if [ ! -r "$secret" ]; then
                  echo "rclone-${cfg.remoteName}: cannot read $secret (root or wheel membership required)" >&2
                  exit 1
                fi
                scratch=$(mktemp -d)
                trap 'rm -rf -- "$scratch"' EXIT
                cp -- "$secret" "$scratch/rclone.conf"
                chmod 600 "$scratch/rclone.conf"
                rc=0
                rclone \
                  --config "$scratch/rclone.conf" \
                  --tpslimit ${toString cfg.tpsLimit} \
                  --drive-use-trash=false \
                  ${bwLimitFlag} \
                  "$@" || rc=$?
                exit "$rc"
              '';
            };

            # Dedicated rclone.program binary for Restic's rclone: backend so
            # quoting and upload caps are always applied consistently.
            rcloneForRestic = pkgs.writeShellApplication {
              name = "rclone-restic-${instanceName}";
              runtimeInputs = [
                pkgs.coreutils
                pkgs.rclone
              ];
              text = ''
                set -euo pipefail
                umask 077
                secret=${lib.escapeShellArg rcloneSecretPath}
                scratch=$(mktemp -d)
                trap 'rm -rf -- "$scratch"' EXIT
                cp -- "$secret" "$scratch/rclone.conf"
                chmod 600 "$scratch/rclone.conf"
                rc=0
                rclone \
                  --config "$scratch/rclone.conf" \
                  --tpslimit ${toString cfg.tpsLimit} \
                  --max-transfer ${lib.escapeShellArg cfg.maxTransfer} \
                  --cutoff-mode=soft \
                  --drive-use-trash=false \
                  ${bwLimitFlag} \
                  "$@" || rc=$?
                exit "$rc"
              '';
            };

            resticWrapper = pkgs.writeShellApplication {
              name = "restic-${instanceName}";
              runtimeInputs = [ pkgs.restic ];
              text = ''
                set -euo pipefail
                export RESTIC_REPOSITORY="''${RESTIC_REPOSITORY:-${defaultRepo}}"
                export RESTIC_PASSWORD_FILE="''${RESTIC_PASSWORD_FILE:-${resticPasswordPath}}"
                exec restic \
                  --option rclone.program=${lib.getExe rcloneForRestic} \
                  "$@"
              '';
            };

            excludeArgs = lib.concatMapStringsSep " \\\n  " (
              pattern: "--exclude ${lib.escapeShellArg pattern}"
            ) cfg.excludes;

            backupScript = pkgs.writeShellApplication {
              name = "run-${instanceName}";
              runtimeInputs = [
                pkgs.coreutils
                pkgs.gnugrep
                pkgs.restic
              ]
              ++ lib.optional config.networking.networkmanager.enable pkgs.networkmanager;
              text = ''
                set -euo pipefail
                umask 077

                ${lib.optionalString config.networking.networkmanager.enable ''
                  network_ready=false
                  for _attempt in $(seq 1 30); do
                    if nm-online --quiet 2>/dev/null &&
                       ! nmcli --terse --fields GENERAL.METERED dev show 2>/dev/null | grep --quiet "yes"; then
                      network_ready=true
                      break
                    fi
                    echo "${instanceName}: waiting for unmetered network ($_attempt/30)..."
                    sleep 60
                  done
                  if [ "$network_ready" = "false" ]; then
                    echo "${instanceName}: timed out waiting for unmetered network, skipping run"
                    exit 0
                  fi
                ''}

                configured_paths=(
                  ${lib.concatMapStringsSep "\n  " lib.escapeShellArg cfg.paths}
                )
                existing_paths=()
                for p in "''${configured_paths[@]}"; do
                  if [ -e "$p" ]; then
                    existing_paths+=("$p")
                  else
                    echo "${instanceName}: skipping absent path: $p"
                  fi
                done

                if [ "''${#existing_paths[@]}" -eq 0 ]; then
                  echo "${instanceName}: no existing paths to back up, nothing to do"
                  exit 0
                fi

                export RESTIC_REPOSITORY=${lib.escapeShellArg defaultRepo}
                export RESTIC_PASSWORD_FILE=${lib.escapeShellArg resticPasswordPath}
                export RESTIC_CACHE_DIR="''${CACHE_DIRECTORY:-/var/cache/${instanceName}}"
                rclone_prog=${lib.getExe rcloneForRestic}

                if ! restic --option "rclone.program=$rclone_prog" snapshots --latest 1 >/dev/null 2>&1; then
                  echo "${instanceName}: initializing Restic repository at $RESTIC_REPOSITORY"
                  restic --option "rclone.program=$rclone_prog" init
                fi

                restic --option "rclone.program=$rclone_prog" backup \
                  --one-file-system \
                  --exclude-caches \
                  --tag "host:${config.networking.hostName}" \
                  --tag "instance:${instanceName}" \
                  ${excludeArgs} \
                  "''${existing_paths[@]}"

                restic --option "rclone.program=$rclone_prog" forget \
                  --keep-daily ${toString cfg.keepDaily} \
                  --keep-weekly ${toString cfg.keepWeekly} \
                  --keep-monthly ${toString cfg.keepMonthly} \
                  --prune \
                  --max-unused 5%
              '';
            };

            hasScheduledJob = cfg.enableTimer && cfg.paths != [ ];
          in
          {
            clan.core.vars.generators.${generatorName} = {
              share = true;
              files."rclone-conf" = {
                secret = true;
                deploy = true;
                owner = "root";
                group = "wheel";
                mode = "0440";
              };
              files."restic-password" = {
                secret = true;
                deploy = true;
                owner = "root";
                group = "wheel";
                mode = "0440";
              };
              runtimeInputs = [
                pkgs.coreutils
                pkgs.openssl
              ];
              prompts."rclone-conf" = {
                description = "Full rclone.conf containing [${cfg.remoteName}] (type = drive, scope = drive.file, with offline refresh_token)";
                type = "multiline";
                persist = true;
              };
              script = ''
                cp "$prompts/rclone-conf" "$out/rclone-conf"
                openssl rand -base64 32 | tr -d '\n' > "$out/restic-password"
              '';
            };

            environment.systemPackages = lib.optionals cfg.installCli [
              rcloneWrapper
              resticWrapper
            ];

            systemd.services.${instanceName} = lib.mkIf hasScheduledJob {
              description = "Encrypted Google Drive Restic backup (${instanceName} -> ${cfg.remoteName})";
              after = [ "network-online.target" ];
              wants = [ "network-online.target" ];
              serviceConfig = {
                Type = "oneshot";
                ExecStart = lib.getExe backupScript;
                CacheDirectory = instanceName;
                CacheDirectoryMode = "0700";
                PrivateTmp = true;
                NoNewPrivileges = true;
                CPUSchedulingPolicy = "idle";
                IOSchedulingClass = "idle";
                Nice = 19;
              };
            };

            systemd.timers.${instanceName} = lib.mkIf hasScheduledJob {
              description = "Scheduled Google Drive Restic backup (${instanceName})";
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnCalendar = cfg.schedule;
                Persistent = true;
                RandomizedDelaySec = cfg.randomizedDelaySec;
                Unit = "${instanceName}.service";
              };
            };
          };
      };
  };

  roles.vault = {
    description = "Unified 60 TiB client-side encrypted Google Drive union vault (FUSE mount + optional cold S3 gateway)";
    interface = mkSettings.mkInterface schema.vault;

    perInstance =
      { instanceName, extendSettings, ... }:
      {
        nixosModule =
          {
            config,
            pkgs,
            lib,
            ...
          }:
          let
            ms = import ../../lib/mk-settings.nix { inherit lib; };
            cfg = extendSettings (ms.mkDefaults schema.vault);
            primaryConfPath =
              config.clan.core.vars.generators.${cfg.primaryGenerator}.files."rclone-conf".path;
            personalConfPath =
              config.clan.core.vars.generators.${cfg.personalGenerator}.files."rclone-conf".path;
            cryptPassPath =
              config.clan.core.vars.generators.${instanceName}.files."crypt-password".path;
            cryptSaltPath =
              config.clan.core.vars.generators.${instanceName}.files."crypt-salt".path;
            s3SecretPath =
              config.clan.core.vars.generators.${instanceName}.files."s3-secret-key".path;

            # Build a private 0600 rclone.conf combining both Drive OAuth configs,
            # two matching crypt overlays (so each account is independently decryptable),
            # and a 60 TiB union remote balancing new writes by most free space (mfs).
            renderVaultConfig = pkgs.writeShellApplication {
              name = "render-${instanceName}-rclone-conf";
              runtimeInputs = [
                pkgs.coreutils
                pkgs.rclone
              ];
              text = ''
                set -euo pipefail
                umask 077
                out_conf="$1"
                primary_conf=${lib.escapeShellArg primaryConfPath}
                personal_conf=${lib.escapeShellArg personalConfPath}
                crypt_pass_file=${lib.escapeShellArg cryptPassPath}
                crypt_salt_file=${lib.escapeShellArg cryptSaltPath}

                for f in "$primary_conf" "$personal_conf" "$crypt_pass_file" "$crypt_salt_file"; do
                  if [ ! -r "$f" ]; then
                    echo "${instanceName}: cannot read $f" >&2
                    exit 1
                  fi
                done

                obscured_pass=$(rclone --config /dev/null obscure "$(cat "$crypt_pass_file")")
                obscured_salt=$(rclone --config /dev/null obscure "$(cat "$crypt_salt_file")")

                {
                  cat "$primary_conf"
                  printf '\n'
                  cat "$personal_conf"
                  printf '\n'
                  cat <<EOF
                [vault-primary]
                type = crypt
                remote = ${cfg.primaryRemote}:${cfg.vaultFolder}
                filename_encryption = standard
                directory_name_encryption = true
                password = $obscured_pass
                password2 = $obscured_salt

                [vault-personal]
                type = crypt
                remote = ${cfg.personalRemote}:${cfg.vaultFolder}
                filename_encryption = standard
                directory_name_encryption = true
                password = $obscured_pass
                password2 = $obscured_salt

                [${instanceName}]
                type = union
                upstreams = vault-primary: vault-personal:
                action_policy = epall
                create_policy = mfs
                search_policy = ff
                EOF
                } > "$out_conf"
                chmod 600 "$out_conf"
              '';
            };

            vaultCli = pkgs.writeShellApplication {
              name = "rclone-${instanceName}";
              runtimeInputs = [
                pkgs.coreutils
                pkgs.rclone
              ];
              text = ''
                set -euo pipefail
                umask 077
                scratch=$(mktemp -d)
                trap 'rm -rf -- "$scratch"' EXIT
                ${lib.getExe renderVaultConfig} "$scratch/rclone.conf"
                rc=0
                rclone \
                  --config "$scratch/rclone.conf" \
                  --tpslimit ${toString cfg.tpsLimit} \
                  --drive-use-trash=false \
                  "$@" || rc=$?
                exit "$rc"
              '';
            };

            vaultS3Cli = pkgs.writeShellApplication {
              name = "vault-s3";
              runtimeInputs = [
                pkgs.coreutils
                pkgs.rclone
              ];
              text = ''
                set -euo pipefail
                umask 077
                secret_file=${lib.escapeShellArg s3SecretPath}
                if [ ! -r "$secret_file" ]; then
                  echo "vault-s3: cannot read $secret_file (root or wheel membership required)" >&2
                  exit 1
                fi
                scratch=$(mktemp -d)
                trap 'rm -rf -- "$scratch"' EXIT
                s3_secret=$(cat "$secret_file")
                cat > "$scratch/s3.conf" <<EOF
                [vault]
                type = s3
                provider = Other
                access_key_id = ${cfg.s3AccessKeyId}
                secret_access_key = $s3_secret
                endpoint = ${cfg.s3Endpoint}
                EOF
                chmod 600 "$scratch/s3.conf"
                rc=0
                rclone --config "$scratch/s3.conf" "$@" || rc=$?
                exit "$rc"
              '';
            };

            vaultModelCli = pkgs.writeShellApplication {
              name = "vault-model";
              runtimeInputs = [
                pkgs.coreutils
                vaultS3Cli
              ];
              text = ''
                set -euo pipefail
                cmd="''${1:-help}"
                shift || true
                case "$cmd" in
                  ls)
                    sub="''${1:-}"
                    exec vault-s3 lsd "vault:models/''${sub#/}"
                    ;;
                  push)
                    if [ "$#" -lt 2 ]; then
                      echo "Usage: vault-model push <local-dir-or-file> <category/name>" >&2
                      echo "  Categories: gguf, safetensors, tt-metal, engines, checkpoints" >&2
                      exit 2
                    fi
                    src="$1"
                    dst="vault:models/''${2#/}"
                    vault-s3 copy "$src" "$dst" --links --transfers 4 --checkers 8 --progress
                    vault-s3 check "$src" "$dst" --size-only --links --checkers 8
                    ;;
                  pull)
                    if [ "$#" -lt 2 ]; then
                      echo "Usage: vault-model pull <category/name> <local-dir>" >&2
                      exit 2
                    fi
                    src="vault:models/''${1#/}"
                    dst="$2"
                    mkdir -p "$dst"
                    vault-s3 copy "$src" "$dst" --links --transfers 4 --checkers 8 --progress
                    ;;
                  *)
                    cat <<'USAGE'
                vault-model — Private 60 TiB model & compiled-engine registry (s3://models)

                Commands:
                  vault-model ls [subdir]                      List model buckets/directories
                  vault-model push <local-path> <cat/name>     Upload & size-verify weights or TT-Metal/vLLM caches
                  vault-model pull <cat/name> <local-dir>      Pull weights or compiled engines to local NVMe

                Standard categories: gguf, safetensors, tt-metal, engines, checkpoints
                USAGE
                    ;;
                esac
              '';
            };

            vaultArchiveCli = pkgs.writeShellApplication {
              name = "vault-archive";
              runtimeInputs = [
                pkgs.coreutils
                pkgs.gnutar
                pkgs.zstd
                vaultS3Cli
              ];
              text = ''
                set -euo pipefail
                cmd="''${1:-help}"
                shift || true
                host=${lib.escapeShellArg config.networking.hostName}
                case "$cmd" in
                  ls)
                    sub="''${1:-$host}"
                    exec vault-s3 lsl "vault:archives/''${sub#/}"
                    ;;
                  push)
                    if [ "$#" -lt 2 ]; then
                      echo "Usage: vault-archive push <local-dir> <archive-name>" >&2
                      exit 2
                    fi
                    src="$1"
                    name="$2"
                    if [ ! -d "$src" ]; then
                      echo "vault-archive: directory not found: $src" >&2
                      exit 1
                    fi
                    dst="vault:archives/$host/$name.tar.zst"
                    echo "Streaming tar+zstd of $src -> $dst ..."
                    tar --zstd -cf - -C "$(dirname "$src")" "$(basename "$src")" \
                      | vault-s3 rcat "$dst"
                    echo "Uploaded:"
                    vault-s3 lsl "$dst"
                    ;;
                  pull)
                    if [ "$#" -lt 2 ]; then
                      echo "Usage: vault-archive pull <host/archive-name.tar.zst> <dest-dir>" >&2
                      exit 2
                    fi
                    src="vault:archives/''${1#/}"
                    dst="$2"
                    mkdir -p "$dst"
                    vault-s3 cat "$src" | tar --zstd -xf - -C "$dst"
                    ;;
                  *)
                    cat <<'USAGE'
                vault-archive — Fast single-stream .tar.zst archival to 60 TiB vault (s3://archives)

                Commands:
                  vault-archive ls [host]                          List archived tarballs
                  vault-archive push <local-dir> <archive-name>    Stream tar.zst archive at full link speed
                  vault-archive pull <host/name.tar.zst> <dest>    Extract archived tarball to <dest>
                USAGE
                    ;;
                esac
              '';
            };

            vaultDuckdbCli = pkgs.writeShellApplication {
              name = "vault-duckdb";
              runtimeInputs = [
                pkgs.coreutils
                pkgs.duckdb
              ];
              text = ''
                set -euo pipefail
                umask 077
                secret_file=${lib.escapeShellArg s3SecretPath}
                if [ ! -r "$secret_file" ]; then
                  echo "vault-duckdb: cannot read $secret_file (root or wheel membership required)" >&2
                  exit 1
                fi
                scratch=$(mktemp -d)
                trap 'rm -rf -- "$scratch"' EXIT
                s3_secret=$(cat "$secret_file")
                endpoint_url=${lib.escapeShellArg cfg.s3Endpoint}
                use_ssl=false
                case "$endpoint_url" in
                  https://*) use_ssl=true ;;
                esac
                endpoint_host="''${endpoint_url#http://}"
                endpoint_host="''${endpoint_host#https://}"
                endpoint_host="''${endpoint_host%/}"
                cat > "$scratch/init.sql" <<EOF
                INSTALL httpfs;
                LOAD httpfs;
                CREATE SECRET gdrive_vault (
                  TYPE s3,
                  KEY_ID '${cfg.s3AccessKeyId}',
                  SECRET '$s3_secret',
                  ENDPOINT '$endpoint_host',
                  URL_STYLE 'path',
                  USE_SSL $use_ssl
                );
                EOF
                chmod 600 "$scratch/init.sql"
                rc=0
                duckdb -init "$scratch/init.sql" "$@" || rc=$?
                exit "$rc"
              '';
            };

            mountRunner = pkgs.writeShellApplication {
              name = "run-${instanceName}-mount";
              runtimeInputs = [
                pkgs.coreutils
                pkgs.rclone
              ];
              text = ''
                set -euo pipefail
                umask 077
                conf="''${RUNTIME_DIRECTORY}/rclone.conf"
                ${lib.getExe renderVaultConfig} "$conf"
                rclone --config "$conf" --tpslimit ${toString cfg.tpsLimit} mkdir ${lib.escapeShellArg "${cfg.primaryRemote}:${cfg.vaultFolder}"} || true
                rclone --config "$conf" --tpslimit ${toString cfg.tpsLimit} mkdir ${lib.escapeShellArg "${cfg.personalRemote}:${cfg.vaultFolder}"} || true
                uid=$(id -u ${lib.escapeShellArg cfg.mountUser})
                gid=$(id -g ${lib.escapeShellArg cfg.mountUser})
                exec rclone mount ${lib.escapeShellArg "${instanceName}:"} ${lib.escapeShellArg cfg.mountPoint} \
                  --config "$conf" \
                  --allow-other \
                  --uid "$uid" \
                  --gid "$gid" \
                  --umask 002 \
                  --vfs-cache-mode full \
                  --vfs-cache-max-size ${lib.escapeShellArg cfg.vfsCacheMaxSize} \
                  --vfs-cache-max-age ${lib.escapeShellArg cfg.vfsCacheMaxAge} \
                  --cache-dir "''${CACHE_DIRECTORY}" \
                  --dir-cache-time 72h \
                  --poll-interval 1m \
                  --vfs-read-chunk-size 64M \
                  --tpslimit ${toString cfg.tpsLimit} \
                  --drive-use-trash=false
              '';
            };

            s3Runner = pkgs.writeShellApplication {
              name = "run-${instanceName}-s3";
              runtimeInputs = [
                pkgs.coreutils
                pkgs.rclone
              ];
              text = ''
                set -euo pipefail
                umask 077
                conf="''${RUNTIME_DIRECTORY}/rclone.conf"
                ${lib.getExe renderVaultConfig} "$conf"
                rclone --config "$conf" --tpslimit ${toString cfg.tpsLimit} mkdir ${lib.escapeShellArg "${cfg.primaryRemote}:${cfg.vaultFolder}"} || true
                rclone --config "$conf" --tpslimit ${toString cfg.tpsLimit} mkdir ${lib.escapeShellArg "${cfg.personalRemote}:${cfg.vaultFolder}"} || true
                s3_secret=$(cat ${lib.escapeShellArg s3SecretPath})
                # RCLONE_AUTH_KEY is parsed as a CSV stringArray; wrap the pair in quotes
                # so the inner comma separates access key and secret key rather than items.
                export RCLONE_AUTH_KEY="\"${cfg.s3AccessKeyId},$s3_secret\""
                exec rclone serve s3 ${lib.escapeShellArg "${instanceName}:"} \
                  --config "$conf" \
                  --addr ${lib.escapeShellArg "${cfg.s3ListenAddress}:${toString cfg.s3Port}"} \
                  --vfs-cache-mode off \
                  --dir-cache-time 5m \
                  --poll-interval 1m \
                  --no-modtime \
                  --tpslimit ${toString cfg.tpsLimit} \
                  --drive-use-trash=false
              '';
            };
          in
          {
            clan.core.vars.generators.${instanceName} = {
              share = true;
              files."crypt-password" = {
                secret = true;
                deploy = true;
                owner = "root";
                group = "wheel";
                mode = "0440";
              };
              files."crypt-salt" = {
                secret = true;
                deploy = true;
                owner = "root";
                group = "wheel";
                mode = "0440";
              };
              files."s3-secret-key" = {
                secret = true;
                deploy = true;
                owner = "root";
                group = "wheel";
                mode = "0440";
              };
              runtimeInputs = [
                pkgs.coreutils
                pkgs.openssl
              ];
              script = ''
                openssl rand -base64 32 | tr -d '\n' > "$out/crypt-password"
                openssl rand -base64 32 | tr -d '\n' > "$out/crypt-salt"
                openssl rand -hex 24 | tr -d '\n' > "$out/s3-secret-key"
              '';
            };

            environment.systemPackages = [
              vaultCli
            ]
            ++ lib.optionals cfg.installVaultTools [
              vaultS3Cli
              vaultModelCli
              vaultArchiveCli
              vaultDuckdbCli
            ];

            programs.fuse.userAllowOther = lib.mkIf cfg.mountEnable true;

            systemd.tmpfiles.rules = lib.mkIf cfg.mountEnable [
              "d ${cfg.mountPoint} 0755 root root -"
            ];

            systemd.services."${instanceName}-mount" = lib.mkIf cfg.mountEnable {
              description = "Unified 60 TiB encrypted Google Drive FUSE mount (${cfg.mountPoint})";
              after = [ "network-online.target" ];
              wants = [ "network-online.target" ];
              wantedBy = [ "multi-user.target" ];
              path = [ "/run/wrappers" ];
              serviceConfig = {
                Type = "notify";
                ExecStart = lib.getExe mountRunner;
                ExecStop = "/run/wrappers/bin/fusermount -uz ${lib.escapeShellArg cfg.mountPoint}";
                RuntimeDirectory = "${instanceName}-mount";
                RuntimeDirectoryMode = "0700";
                CacheDirectory = "${instanceName}-mount";
                CacheDirectoryMode = "0700";
                Restart = "on-failure";
                RestartSec = "15s";
              };
            };

            systemd.services."${instanceName}-s3" = lib.mkIf cfg.s3Enable {
              description = "Cold S3 gateway over unified 60 TiB encrypted Google Drive vault";
              after = [
                "network-online.target"
                "tailscaled.service"
              ];
              wants = [
                "network-online.target"
                "tailscaled.service"
              ];
              wantedBy = [ "multi-user.target" ];
              serviceConfig = {
                Type = "simple";
                ExecStart = lib.getExe s3Runner;
                RuntimeDirectory = "${instanceName}-s3";
                RuntimeDirectoryMode = "0700";
                Restart = "on-failure";
                RestartSec = "15s";
              };
            };

            networking.firewall.interfaces.tailscale0.allowedTCPPorts = lib.mkIf (
              cfg.s3Enable && cfg.s3OpenTailscaleFirewall
            ) [ cfg.s3Port ];
          };
      };
  };
}
