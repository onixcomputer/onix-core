{
  config,
  lib,
  pkgs,
  ...
}:
let
  backupJobName = "britton-desktop";
  backupUnitName = "borgbackup-job-${backupJobName}";
  stateRoot = "/var/lib/radicle";
  stagingRoot = "/run/radicle-backup-input";
  manifestRoot = "/run/radicle-backup-manifests";
  runtimeStateRoot = "/run/radicle-backup-state";
  restoreRoot = "/var/lib/radicle-restore-check";
  expectedNodeId = "z6MkfpHAyrqSqhpiSGayy6AjB6L5UWkKLvsZvLh5hYD7XSu8";
  expectedNodeFingerprint = "SHA256:zwNJTV2uBfWYcFXeFJs+eAfatqahgK8KKe+4gdGkOSE";
  targetAddress = "100.110.43.11";
  targetHostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEehqswjtdQwNb4o2/hV7Qg1HCZkpbLZDDbReDoPmf/p";
  privateKeyMode = "0400";
  publicKeyMode = "0444";
  privateDirectoryMode = "0700";
  dailyRetention = 7;
  weeklyRetention = 4;

  identityFiles = config.clan.core.vars.generators.radicle-node-radicle-forge-bootstrap.files;
  privateKeyPath = identityFiles.node-private-key.path;
  publicKeyPath = identityFiles.node-public-key.path;
  backupSshKeyPath = config.clan.core.vars.generators.borgbackup.files."borgbackup.ssh".path;
  backupRepoKeyPath = config.clan.core.vars.generators.borgbackup.files."borgbackup.repokey".path;
  backupManifest = import ./backup-manifest.nix { inherit pkgs; };
  knownHosts = pkgs.writeText "radicle-backup-known-hosts" ''
    ${targetAddress} ${targetHostKey}
  '';

  prepareBackup = pkgs.writeShellApplication {
    name = "radicle-backup-prepare";
    runtimeInputs = [
      backupManifest
      pkgs.coreutils
      pkgs.findutils
      pkgs.openssh
      pkgs.systemd
    ];
    text = ''
      record_active_unit() {
        unit="$1"
        marker="$2"
        if systemctl is-active --quiet "$unit"; then
          touch "$marker"
        fi
      }

      install -d -m ${privateDirectoryMode} ${lib.escapeShellArg runtimeStateRoot}
      rm -f ${lib.escapeShellArg runtimeStateRoot}/*
      record_active_unit radicle-node.service ${lib.escapeShellArg runtimeStateRoot}/node-active
      record_active_unit radicle-httpd.service ${lib.escapeShellArg runtimeStateRoot}/httpd-active
      record_active_unit radicle-policy-reconcile.timer ${lib.escapeShellArg runtimeStateRoot}/policy-timer-active

      node_id="$(/run/current-system/sw/bin/rad-system node status --only nid)"
      if test "$node_id" != ${lib.escapeShellArg expectedNodeId}; then
        echo "Radicle node identity changed before backup: $node_id" >&2
        exit 1
      fi

      systemctl stop radicle-policy-reconcile.timer
      systemctl stop radicle-httpd.service
      systemctl stop radicle-node.service

      rm -rf ${lib.escapeShellArg stagingRoot} ${lib.escapeShellArg manifestRoot}
      install -d -m ${privateDirectoryMode} ${lib.escapeShellArg stagingRoot}
      install -d -m ${privateDirectoryMode} ${lib.escapeShellArg manifestRoot}
      install -m ${privateKeyMode} ${lib.escapeShellArg privateKeyPath} ${lib.escapeShellArg stagingRoot}/node-private-key
      install -m ${publicKeyMode} ${lib.escapeShellArg publicKeyPath} ${lib.escapeShellArg stagingRoot}/node-public-key

      ssh-keygen -y -f ${lib.escapeShellArg stagingRoot}/node-private-key > ${lib.escapeShellArg stagingRoot}/derived-public-key
      if ! cmp ${lib.escapeShellArg stagingRoot}/derived-public-key ${lib.escapeShellArg stagingRoot}/node-public-key; then
        echo "staged Radicle private and public keys do not match" >&2
        exit 1
      fi
      fingerprint="$(ssh-keygen -lf ${lib.escapeShellArg stagingRoot}/derived-public-key)"
      case "$fingerprint" in
        *" ${expectedNodeFingerprint} "*) ;;
        *)
          echo "staged Radicle key does not preserve the reviewed fingerprint" >&2
          exit 1
          ;;
      esac
      rm ${lib.escapeShellArg stagingRoot}/derived-public-key

      {
        printf 'node_id=%s\n' "$node_id"
        printf 'node_fingerprint=%s\n' ${lib.escapeShellArg expectedNodeFingerprint}
        printf 'source_host=aspen1\n'
        printf 'source_failure_domain=aspen-primary-site\n'
        printf 'target_host=britton-desktop\n'
        printf 'target_failure_domain=britton-desktop-workstation\n'
        printf 'manifest_algorithm=blake3\n'
      } > ${lib.escapeShellArg stagingRoot}/observations

      find ${lib.escapeShellArg stateRoot}/storage -mindepth 1 -maxdepth 1 -type d -printf '%f\n' \
        | LC_ALL=C sort > ${lib.escapeShellArg stagingRoot}/repository-directories

      ${backupManifest}/bin/radicle-backup-manifest create \
        ${lib.escapeShellArg stateRoot} \
        ${lib.escapeShellArg stagingRoot}/radicle-state.b3m
      ${backupManifest}/bin/radicle-backup-manifest create \
        ${lib.escapeShellArg stagingRoot} \
        ${lib.escapeShellArg manifestRoot}/backup-inputs.b3m
    '';
  };

  cleanupBackup = pkgs.writeShellApplication {
    name = "radicle-backup-cleanup";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
    ];
    text = ''
      node_was_active=false
      httpd_was_active=false
      timer_was_active=false
      if test -e ${lib.escapeShellArg runtimeStateRoot}/node-active; then
        node_was_active=true
      fi
      if test -e ${lib.escapeShellArg runtimeStateRoot}/httpd-active; then
        httpd_was_active=true
      fi
      if test -e ${lib.escapeShellArg runtimeStateRoot}/policy-timer-active; then
        timer_was_active=true
      fi

      rm -rf \
        ${lib.escapeShellArg stagingRoot} \
        ${lib.escapeShellArg manifestRoot}

      if test "$node_was_active" = true; then
        systemctl start radicle-node.service
      fi
      if test "$httpd_was_active" = true; then
        systemctl start radicle-policy-reconcile.service
        systemctl start radicle-httpd.service
      fi
      if test "$timer_was_active" = true; then
        systemctl start radicle-policy-reconcile.timer
      fi
      rm -rf ${lib.escapeShellArg runtimeStateRoot}
    '';
  };

  restoreVerify = pkgs.writeShellApplication {
    name = "radicle-backup-restore-verify";
    runtimeInputs = [
      backupManifest
      pkgs.coreutils
      pkgs.jq
      pkgs.openssh
      pkgs.radicle-node
    ];
    text = ''
      cleanup_restore() {
        rm -rf ${lib.escapeShellArg restoreRoot}
      }
      trap cleanup_restore EXIT

      archive="$(/run/current-system/sw/bin/borg-job-${backupJobName} list --json \
        | jq -er '.archives | max_by(.time) | .name')"
      if test -z "$archive"; then
        echo "no Radicle backup archive exists" >&2
        exit 1
      fi

      cleanup_restore
      install -d -m ${privateDirectoryMode} ${lib.escapeShellArg restoreRoot}
      (
        cd ${lib.escapeShellArg restoreRoot}
        /run/current-system/sw/bin/borg-job-${backupJobName} extract "::$archive"
      )

      restored_state=${lib.escapeShellArg restoreRoot}${stateRoot}
      restored_staging=${lib.escapeShellArg restoreRoot}${stagingRoot}
      restored_manifests=${lib.escapeShellArg restoreRoot}${manifestRoot}
      ${backupManifest}/bin/radicle-backup-manifest verify \
        "$restored_state" \
        "$restored_staging/radicle-state.b3m"
      ${backupManifest}/bin/radicle-backup-manifest verify \
        "$restored_staging" \
        "$restored_manifests/backup-inputs.b3m"

      ssh-keygen -y -f "$restored_staging/node-private-key" > "$restored_staging/derived-public-key"
      cmp "$restored_staging/derived-public-key" "$restored_staging/node-public-key"
      fingerprint="$(ssh-keygen -lf "$restored_staging/derived-public-key")"
      case "$fingerprint" in
        *" ${expectedNodeFingerprint} "*) ;;
        *)
          echo "restored Radicle key fingerprint changed" >&2
          exit 1
          ;;
      esac

      install -m ${privateKeyMode} "$restored_staging/node-private-key" "$restored_state/keys/radicle"
      install -m ${publicKeyMode} "$restored_staging/node-public-key" "$restored_state/keys/radicle.pub"
      touch "$restored_state/.gitconfig"
      restored_node_id="$(HOME="$restored_state" RAD_HOME="$restored_state" rad self --nid 2>/dev/null)"
      if test "$restored_node_id" != ${lib.escapeShellArg expectedNodeId}; then
        echo "restored Radicle node identity changed: $restored_node_id" >&2
        exit 1
      fi

      expected_repository_count="$(wc -l < "$restored_staging/repository-directories")"
      actual_repository_count="$(find "$restored_state/storage" -mindepth 1 -maxdepth 1 -type d -printf . | wc -c)"
      if test "$actual_repository_count" != "$expected_repository_count"; then
        echo "restored Radicle repository count changed" >&2
        exit 1
      fi

      printf 'archive=%s\n' "$archive"
      printf 'node_id=%s\n' "$restored_node_id"
      printf 'node_fingerprint=%s\n' ${lib.escapeShellArg expectedNodeFingerprint}
      printf 'repository_count=%s\n' "$actual_repository_count"
      printf 'restore_result=verified\n'
    '';
  };
in
{
  environment.etc."ssh/radicle-backup-known-hosts".source = knownHosts;
  environment.systemPackages = [ restoreVerify ];

  services.borgbackup.jobs.${backupJobName} = {
    paths = lib.mkForce [
      stateRoot
      stagingRoot
      manifestRoot
    ];
    exclude = lib.mkForce [ ];
    compression = lib.mkForce "auto,lz4";
    environment.BORG_RSH = lib.mkForce (
      lib.concatStringsSep " " [
        "ssh"
        "-i ${backupSshKeyPath}"
        "-o UserKnownHostsFile=/etc/ssh/radicle-backup-known-hosts"
        "-o StrictHostKeyChecking=yes"
        "-o HostKeyAlgorithms=ssh-ed25519"
        "-o IdentitiesOnly=yes"
        "-o PasswordAuthentication=no"
      ]
    );
    preHook = lib.getExe prepareBackup;
    postHook = lib.getExe cleanupBackup;
    prune.keep = lib.mkForce {
      within = "1d";
      daily = dailyRetention;
      weekly = weeklyRetention;
      monthly = 0;
    };
  };

  systemd.services.${backupUnitName}.serviceConfig = {
    BindReadOnlyPaths = [
      privateKeyPath
      publicKeyPath
      backupSshKeyPath
      backupRepoKeyPath
    ];
    CapabilityBoundingSet = "";
    ExecStartPre = lib.mkForce [ ];
    ExecStopPost = lib.mkForce [ ];
    InaccessiblePaths = [ "/run/secrets" ];
    LockPersonality = true;
    NoNewPrivileges = true;
    PrivateDevices = true;
    PrivateTmp = true;
    ProtectClock = true;
    ProtectControlGroups = true;
    ProtectHome = true;
    ProtectHostname = true;
    ProtectKernelLogs = true;
    ProtectKernelModules = true;
    ProtectKernelTunables = true;
    RemoveIPC = true;
    RestrictAddressFamilies = [
      "AF_INET"
      "AF_INET6"
      "AF_UNIX"
    ];
    RestrictNamespaces = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    UMask = "0077";
  };
}
