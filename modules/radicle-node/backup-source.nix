{
  config,
  lib,
  pkgs,
  ...
}:
let
  backupJobName = "britton-desktop";
  sshHostKeys = import ../../lib/ssh-host-keys.nix { inherit lib; };
  backupUnitName = "borgbackup-job-${backupJobName}";
  backupCredentialDirectory = "/run/credentials/${backupUnitName}.service";
  borgRuntimeDirectoryName = "radicle-backup-borg";
  borgRuntimeRoot = "/run/${borgRuntimeDirectoryName}";
  stateRoot = "/var/lib/radicle";
  sourceMount = "/run/radicle-backup-source";
  stagingRoot = "/run/radicle-backup-input";
  manifestRoot = "/run/radicle-backup-manifests";
  runtimeStateRoot = "/run/radicle-backup-state";
  restoreRoot = "/var/lib/radicle-restore-check";
  restoreBorgRuntimeRoot = "/run/radicle-backup-restore-borg";
  expectedNodeId = "z6MkfpHAyrqSqhpiSGayy6AjB6L5UWkKLvsZvLh5hYD7XSu8";
  expectedNodeFingerprint = "SHA256:zwNJTV2uBfWYcFXeFJs+eAfatqahgK8KKe+4gdGkOSE";
  privatePilotStorageDirectory = "z3t9ykR1HfG9UkyKoQQg5ikkzrTxg";
  privatePilotDelegate = "z6MksnXbFoE8zkCkGWhHc8zuxpnEUhrJHv2KECRV4GSv9gkx";
  expectedPrivatePilotCommit = "ff4ff027817465b1bb04251a8a98db42cc610b0c";
  expectedPrivatePilotIdentityRevision = "cb3f6273f35ff437e58f15332d48f25b06c4b9cc";
  expectedPrivatePilotSigrefs = "ad1b6d032b69a4b81910b2fc98f8707b9ff268fb";
  expectedPrivatePilotSourceBlake3 = "514904bdcf5f23b0813c567efbc8b6732248de94482037a58011bfff3fc26853";
  targetAddress = "100.110.43.11";
  targetHostKey = sshHostKeys.requirePublicKey backupJobName;
  privateKeyMode = "0400";
  publicKeyMode = "0444";
  radiclePrivateCredential = "radicle-node-private";
  borgSshCredential = "borg-ssh";
  borgRepoKeyCredential = "borg-repokey";
  privateDirectoryMode = "0700";
  dailyRetention = 7;
  weeklyRetention = 4;

  identityFiles = config.clan.core.vars.generators.radicle-node-radicle-forge-bootstrap.files;
  privateKeyPath = identityFiles.node-private-key.path;
  publicKeyPath = identityFiles.node-public-key.path;
  nodeConfigPath = config.services.radicle.configFile;
  backupSshKeyPath = config.clan.core.vars.generators.borgbackup.files."borgbackup.ssh".path;
  backupRepoKeyPath = config.clan.core.vars.generators.borgbackup.files."borgbackup.repokey".path;
  backupManifest = import ./backup-manifest.nix { inherit pkgs; };
  knownHosts = pkgs.writeText "radicle-backup-known-hosts" ''
    ${targetAddress} ${targetHostKey}
  '';
  backupRsh = lib.concatStringsSep " " [
    "ssh"
    "-i ${backupCredentialDirectory}/${borgSshCredential}"
    "-o UserKnownHostsFile=/etc/ssh/radicle-backup-known-hosts"
    "-o StrictHostKeyChecking=yes"
    "-o HostKeyAlgorithms=ssh-ed25519"
    "-o IdentitiesOnly=yes"
    "-o PasswordAuthentication=no"
  ];
  backupPassCommand = ''cat "${backupCredentialDirectory}/${borgRepoKeyCredential}"'';
  restoreRsh = lib.concatStringsSep " " [
    "ssh"
    "-i ${backupSshKeyPath}"
    "-o UserKnownHostsFile=/etc/ssh/radicle-backup-known-hosts"
    "-o StrictHostKeyChecking=yes"
    "-o HostKeyAlgorithms=ssh-ed25519"
    "-o IdentitiesOnly=yes"
    "-o PasswordAuthentication=no"
  ];

  repositoryPreflight = pkgs.writeShellApplication {
    name = "radicle-backup-repository-preflight";
    runtimeInputs = [
      config.services.borgbackup.package
      pkgs.openssh
    ];
    text = ''
      export BORG_REPO=${lib.escapeShellArg "borg@${targetAddress}:."}
      export BORG_RSH=${lib.escapeShellArg backupRsh}
      export BORG_PASSCOMMAND=${lib.escapeShellArg backupPassCommand}
      if borg list >/dev/null 2>&1; then
        exit 0
      fi

      probe_root=${lib.escapeShellArg "${borgRuntimeRoot}/preflight"}
      mkdir -p "$probe_root"
      if borg create ::radicle-backup-preflight "$probe_root"; then
        borg list >/dev/null
        exit 0
      fi

      borg init --encryption repokey
      borg create ::radicle-backup-preflight "$probe_root"
      borg list >/dev/null
    '';
  };

  prepareBackup = pkgs.writeShellApplication {
    name = "radicle-backup-prepare";
    runtimeInputs = [
      backupManifest
      pkgs.coreutils
      pkgs.diffutils
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

      node_id=${lib.escapeShellArg expectedNodeId}

      systemctl stop radicle-policy-reconcile.timer
      systemctl stop radicle-httpd.service
      systemctl stop radicle-node.service

      rm -rf ${lib.escapeShellArg stagingRoot} ${lib.escapeShellArg manifestRoot}
      install -d -m ${privateDirectoryMode} ${lib.escapeShellArg stagingRoot}
      install -d -m ${privateDirectoryMode} ${lib.escapeShellArg manifestRoot}
      install -m ${privateKeyMode} ${lib.escapeShellArg "${backupCredentialDirectory}/${radiclePrivateCredential}"} ${lib.escapeShellArg stagingRoot}/node-private-key
      install -m ${publicKeyMode} ${lib.escapeShellArg publicKeyPath} ${lib.escapeShellArg stagingRoot}/node-public-key
      install -m ${publicKeyMode} ${lib.escapeShellArg nodeConfigPath} ${lib.escapeShellArg stagingRoot}/node-config.json

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

      find ${lib.escapeShellArg sourceMount}/storage -mindepth 1 -maxdepth 1 -type d -printf '%f\n' \
        | LC_ALL=C sort > ${lib.escapeShellArg stagingRoot}/repository-directories

      ${backupManifest}/bin/radicle-backup-manifest create \
        ${lib.escapeShellArg sourceMount} \
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
      config.services.borgbackup.package
      pkgs.b3sum
      pkgs.coreutils
      pkgs.diffutils
      pkgs.gitMinimal
      pkgs.jq
      pkgs.openssh
      pkgs.radicle-node
    ];
    text = ''
      cleanup_restore() {
        rm -rf \
          ${lib.escapeShellArg restoreRoot} \
          ${lib.escapeShellArg restoreBorgRuntimeRoot}
      }
      trap cleanup_restore EXIT
      cleanup_restore
      install -d -m ${privateDirectoryMode} ${lib.escapeShellArg restoreBorgRuntimeRoot}

      export BORG_BASE_DIR=${lib.escapeShellArg restoreBorgRuntimeRoot}
      export BORG_CACHE_DIR=${lib.escapeShellArg "${restoreBorgRuntimeRoot}/cache"}
      export BORG_CONFIG_DIR=${lib.escapeShellArg "${restoreBorgRuntimeRoot}/config"}
      export BORG_KEYS_DIR=${lib.escapeShellArg "${restoreBorgRuntimeRoot}/keys"}
      export BORG_SECURITY_DIR=${lib.escapeShellArg "${restoreBorgRuntimeRoot}/security"}
      export BORG_RELOCATED_REPO_ACCESS_IS_OK=yes
      export BORG_REPO=${lib.escapeShellArg "borg@${targetAddress}:."}
      export BORG_RSH=${lib.escapeShellArg restoreRsh}
      export BORG_PASSCOMMAND=${lib.escapeShellArg "cat ${backupRepoKeyPath}"}
      archive="$(borg list --json | jq -er '.archives | max_by(.time) | .name')"
      if test -z "$archive"; then
        echo "no Radicle backup archive exists" >&2
        exit 1
      fi

      rm -rf ${lib.escapeShellArg restoreRoot}
      install -d -m ${privateDirectoryMode} ${lib.escapeShellArg restoreRoot}
      (
        cd ${lib.escapeShellArg restoreRoot}
        borg extract "::$archive"
      )

      restored_state=${lib.escapeShellArg restoreRoot}${sourceMount}
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
      install -m ${publicKeyMode} "$restored_staging/node-config.json" "$restored_state/config.json"
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

      restored_private_repository="$restored_state/storage/${privatePilotStorageDirectory}"
      if ! test -d "$restored_private_repository"; then
        echo "restored private pilot repository is absent" >&2
        exit 1
      fi
      restored_private_commit="$(git -c safe.directory="$restored_private_repository" -C "$restored_private_repository" rev-parse refs/heads/main)"
      restored_private_delegate_commit="$(git -c safe.directory="$restored_private_repository" -C "$restored_private_repository" rev-parse refs/namespaces/${privatePilotDelegate}/refs/heads/main)"
      restored_private_identity="$(git -c safe.directory="$restored_private_repository" -C "$restored_private_repository" rev-parse refs/rad/id)"
      restored_private_sigrefs="$(git -c safe.directory="$restored_private_repository" -C "$restored_private_repository" rev-parse refs/namespaces/${privatePilotDelegate}/refs/rad/sigrefs)"
      if test "$restored_private_commit" != ${lib.escapeShellArg expectedPrivatePilotCommit} \
        || test "$restored_private_delegate_commit" != ${lib.escapeShellArg expectedPrivatePilotCommit} \
        || test "$restored_private_identity" != ${lib.escapeShellArg expectedPrivatePilotIdentityRevision} \
        || test "$restored_private_sigrefs" != ${lib.escapeShellArg expectedPrivatePilotSigrefs}; then
        echo "restored private pilot identity, signed refs, or commit changed" >&2
        exit 1
      fi
      restored_private_source_blake3="$(
        git -c safe.directory="$restored_private_repository" -C "$restored_private_repository" \
          archive --format=tar refs/heads/main \
          | b3sum \
          | cut -d ' ' -f 1
      )"
      if test "$restored_private_source_blake3" != ${lib.escapeShellArg expectedPrivatePilotSourceBlake3}; then
        echo "restored private pilot source identity changed" >&2
        exit 1
      fi

      printf 'archive=%s\n' "$archive"
      printf 'node_id=%s\n' "$restored_node_id"
      printf 'node_fingerprint=%s\n' ${lib.escapeShellArg expectedNodeFingerprint}
      printf 'repository_count=%s\n' "$actual_repository_count"
      printf 'private_commit=%s\n' "$restored_private_commit"
      printf 'private_identity_revision=%s\n' "$restored_private_identity"
      printf 'private_sigrefs=%s\n' "$restored_private_sigrefs"
      printf 'private_source_blake3=%s\n' "$restored_private_source_blake3"
      printf 'restore_result=verified\n'
    '';
  };
in
{
  environment.etc."ssh/radicle-backup-known-hosts".source = knownHosts;
  environment.systemPackages = [ restoreVerify ];

  services.borgbackup.jobs.${backupJobName} = {
    paths = lib.mkForce [
      sourceMount
      stagingRoot
      manifestRoot
    ];
    exclude = lib.mkForce [ ];
    compression = lib.mkForce "auto,lz4";
    environment = {
      BORG_BASE_DIR = borgRuntimeRoot;
      BORG_CACHE_DIR = "${borgRuntimeRoot}/cache";
      BORG_CONFIG_DIR = "${borgRuntimeRoot}/config";
      BORG_KEYS_DIR = "${borgRuntimeRoot}/keys";
      BORG_RSH = lib.mkForce backupRsh;
      BORG_SECURITY_DIR = "${borgRuntimeRoot}/security";
    };
    encryption.passCommand = lib.mkForce backupPassCommand;
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
    AmbientCapabilities = [ "CAP_DAC_READ_SEARCH" ];
    BindReadOnlyPaths = [ "${stateRoot}:${sourceMount}" ];
    CapabilityBoundingSet = [ "CAP_DAC_READ_SEARCH" ];
    ExecStartPre = lib.mkForce [ (lib.getExe repositoryPreflight) ];
    ExecStopPost = lib.mkForce [ ];
    InaccessiblePaths = [
      "/run/secrets"
      "/var/lib"
    ];
    LoadCredential = [
      "${radiclePrivateCredential}:${privateKeyPath}"
      "${borgSshCredential}:${backupSshKeyPath}"
      "${borgRepoKeyCredential}:${backupRepoKeyPath}"
    ];
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
    RuntimeDirectory = borgRuntimeDirectoryName;
    RuntimeDirectoryMode = privateDirectoryMode;
    UMask = "0077";
  };
}
