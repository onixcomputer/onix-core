{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
let
  gib = 1024 * 1024 * 1024;
  pool = "zroot";
  userName = "brittonr";
  userHome = "/home/brittonr";
  zfsPackage = config.boot.zfs.package;

  # Britton's 2026-11-19 sizes for the 952 GiB pool. Reservations come out of
  # free space, so raise them only after freeing space elsewhere.
  agentsReservationGib = 40;
  nixHeadroomGib = 20;
  rootHeadroomGib = 15;
  emergencyReserveGib = 10;
  cacheQuotaGib = 120;
  cargoTargetQuotaGib = 64;
  homeRefquotaGib = 650;

  staleTargetDays = 21;
  staleRootDays = 14;
  codexStagingMinutes = 24 * 60;

  migrateUnit = "aspen3-storage-migrate";
  markerDir = "/var/lib/aspen3-storage/migrated";
  agentsDataset = "${pool}/agents";
  reserveDataset = "${pool}/reserved";

  # r[impl onix.aspen3.storage.disposable]
  # r[impl onix.aspen3.storage.agents]
  # Home directories that leave zroot/home for their own datasets. Cargo
  # output and caches are capped and never snapshotted; the AI tooling state
  # (omp, Claude, and herdr's and underclass's config and state) shares one
  # reservation and keeps the home snapshot policy.
  movedDirectories = [
    {
      name = "cargo-target";
      dataset = "${pool}/cargo-target";
      path = "${userHome}/.cargo-target";
      quotaGib = cargoTargetQuotaGib;
      snapshots = false;
    }
    {
      name = "cache";
      dataset = "${pool}/cache";
      path = "${userHome}/.cache";
      quotaGib = cacheQuotaGib;
      snapshots = false;
    }
    {
      name = "omp";
      dataset = "${agentsDataset}/omp";
      path = "${userHome}/.omp";
    }
    {
      name = "claude";
      dataset = "${agentsDataset}/claude";
      path = "${userHome}/.claude";
    }
    {
      name = "config";
      dataset = "${agentsDataset}/config";
      path = "${userHome}/.config";
    }
    {
      name = "state";
      dataset = "${agentsDataset}/state";
      path = "${userHome}/.local/state";
    }
  ];

  gibString = n: "${toString n}G";
  gibBytes = n: toString (n * gib);
  datasetName = dataset: lib.removePrefix "${pool}/" dataset;
  snapshotFlag = enabled: if enabled then "true" else "false";

  # r[impl onix.aspen3.storage.migration]
  migrator = pkgs.writeShellApplication {
    name = migrateUnit;
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.gawk
      pkgs.gnugrep
      pkgs.systemd
      pkgs.util-linux
      zfsPackage
    ];
    text = ''
      marker_dir=${lib.escapeShellArg markerDir}
      stage_root=/run/${migrateUnit}
      agents_dataset=${lib.escapeShellArg agentsDataset}
      agents_reservation=${gibBytes agentsReservationGib}
      declare -A dataset_of path_of
      ${lib.concatMapStrings (directory: ''
        dataset_of[${directory.name}]=${lib.escapeShellArg directory.dataset}
        path_of[${directory.name}]=${lib.escapeShellArg directory.path}
      '') movedDirectories}
      names=(${
        lib.concatMapStringsSep " " (directory: lib.escapeShellArg directory.name) movedDirectories
      })

      log() { echo "${migrateUnit}: $*"; }

      # PIDs with a file, working directory, root or mapping under $1.
      holders() {
        local dir=$1 proc link
        for proc in /proc/[0-9]*; do
          for link in "$proc"/cwd "$proc"/root "$proc"/fd/*; do
            link=$(readlink "$link" 2>/dev/null) || continue
            case $link in
              "$dir" | "$dir"/*)
                printf '%s ' "''${proc#/proc/}"
                continue 2
                ;;
            esac
          done
          if grep -qsF -- " $dir/" "$proc/maps"; then
            printf '%s ' "''${proc#/proc/}"
          fi
        done
      }

      # "<entries> <regular-file bytes>" of a tree on one file system. A file
      # that vanishes mid-scan changes the count, which fails the comparison.
      summary() {
        { find "$1" -xdev -printf '%y %s\n' 2>/dev/null || true; } |
          awk '{ n++; if ($1 == "f") b += $2 } END { printf "%d %d\n", n, b }'
      }

      # Copy one directory onto its dataset, check the copy, then record the
      # marker and keep the original beside it as <path>.pre-zfs. Every step
      # is checked explicitly: a live run calls this from an `if`, where
      # errexit does not apply. A failure before the marker leaves the
      # original in place and its mount skipped.
      migrate() (
        name=$1
        dataset=''${dataset_of[$name]}
        path=''${path_of[$name]}
        marker=$marker_dir/$name
        stage=$stage_root/$name
        started=$SECONDS

        [ -e "$marker" ] && exit 0
        if ! zfs list -H -o name "$dataset" >/dev/null 2>&1; then
          log "$name: $dataset does not exist; $path stays on /home"
          exit 1
        fi
        if mountpoint -q "$path"; then
          log "$name: $path is already a mount point; nothing moved"
          exit 1
        fi
        if [ -e "$path.pre-zfs" ]; then
          log "$name: $path.pre-zfs exists; move it away before migrating"
          exit 1
        fi
        busy=$(holders "$path")
        if [ -n "$busy" ]; then
          log "$name: $path is in use by PIDs $busy; nothing moved"
          exit 1
        fi

        if [ -d "$path" ]; then
          owner=$(stat -c %u:%g "$path")
          mode=$(stat -c %a "$path")
        else
          owner=$(stat -c %u:%g "$(dirname "$path")")
          mode=700
        fi

        if ! mkdir -p "$stage"; then
          log "$name: could not create $stage"
          exit 1
        fi
        trap 'if mountpoint -q "$stage"; then umount "$stage"; fi' EXIT
        if ! mount -t zfs "$dataset" "$stage" ||
          [ "$(findmnt -n -o SOURCE --mountpoint "$stage")" != "$dataset" ]; then
          log "$name: could not mount $dataset at $stage"
          exit 1
        fi
        # Without a marker, anything on the dataset is left from an
        # interrupted attempt.
        if ! find "$stage" -mindepth 1 -maxdepth 1 -exec rm -rf --one-file-system -- {} +; then
          log "$name: could not empty $dataset"
          exit 1
        fi

        want="0 0"
        if [ -d "$path" ]; then
          if ! cp -a -x --reflink=auto -- "$path/." "$stage/"; then
            log "$name: copying $path failed; it stays on /home"
            exit 1
          fi
          want=$(summary "$path")
          got=$(summary "$stage")
          busy=$(holders "$path")
          if [ "$want" != "$got" ] || [ -n "$busy" ]; then
            log "$name: copy check failed (source $want, copy $got, in use by ''${busy:-nothing}); $path stays on /home"
            exit 1
          fi
        fi
        if ! chown "$owner" "$stage" || ! chmod "$mode" "$stage" || ! umount "$stage"; then
          log "$name: could not finish $dataset; $path stays on /home"
          exit 1
        fi

        # The marker comes first: if the boot stops after it, the verified
        # copy mounts over the original instead of the original disappearing.
        if ! mkdir -p "$marker_dir" ||
          ! printf '%s %s %s\n' "$(date -u +%FT%TZ)" "$dataset" "$want" >"$marker"; then
          log "$name: could not write $marker; $path stays on /home"
          exit 1
        fi
        kept="no original existed"
        if [ -d "$path" ]; then
          if mv -T -- "$path" "$path.pre-zfs"; then
            kept="the original is $path.pre-zfs"
          else
            kept="could not rename $path, so the dataset mounts over it"
          fi
        fi
        if ! install -d -o "''${owner%:*}" -g "''${owner#*:}" -m "$mode" -- "$path"; then
          log "$name: could not create the mount point $path"
          exit 1
        fi
        log "$name: moved $path (entries and bytes: $want) to $dataset in $((SECONDS - started))s; $kept"
      )

      if [ "$(findmnt -n -o SOURCE --mountpoint /home || true)" != ${lib.escapeShellArg "${pool}/home"} ]; then
        log "/home is not mounted from ${pool}/home; nothing moves"
        exit 0
      fi

      status=0
      if [ "$#" -eq 0 ]; then
        state=$(systemctl is-system-running 2>/dev/null || true)
        case $state in
          initializing | starting) ;;
          *)
            log "the system is $state; directories move only during boot, before anything uses them"
            exit 0
            ;;
        esac
        pids=()
        for name in "''${names[@]}"; do
          migrate "$name" &
          pids+=("$!")
        done
        for pid in "''${pids[@]}"; do
          wait "$pid" || status=1
        done
      else
        # Live run for named directories nothing holds open.
        for name in "$@"; do
          if [ -z "''${path_of[$name]+set}" ]; then
            log "unknown directory $name"
            status=1
          elif migrate "$name"; then
            systemctl start "$(systemd-escape --path --suffix=mount "''${path_of[$name]}")" || status=1
          else
            status=1
          fi
        done
      fi

      if [ -e "$marker_dir/omp" ] &&
        [ "$(zfs get -Hp -o value reservation "$agents_dataset")" != "$agents_reservation" ]; then
        zfs set reservation="$agents_reservation" "$agents_dataset" ||
          log "could not reserve ${gibString agentsReservationGib} for $agents_dataset"
      fi
      exit "$status"
    '';
  };

  # r[impl onix.aspen3.storage.properties]
  # ZFS keeps dataset properties across reinstalls of the configuration, and
  # disko only applies them when it creates a pool. Activation therefore
  # creates missing datasets and re-applies the properties on every switch.
  zfsProperties = pkgs.writeShellApplication {
    name = "aspen3-storage-zfs-properties";
    runtimeInputs = [
      pkgs.gawk
      zfsPackage
    ];
    text = ''
      gib=${toString gib}
      warn() { echo "aspen3-storage: $*" >&2; }
      exists() { zfs list -H -o name "$1" >/dev/null 2>&1; }

      create() {
        local dataset=$1
        shift
        exists "$dataset" || zfs create "$@" "$dataset" || warn "could not create $dataset"
      }

      # set_property DATASET PROPERTY VALUE (bytes for sizes)
      set_property() {
        exists "$1" || return 0
        [ "$(zfs get -Hp -o value "$2" "$1")" = "$3" ] && return 0
        zfs set "$2=$3" "$1" || warn "could not set $2=$3 on $1"
      }

      # Reserve HEADROOM bytes above what DATASET uses now, rounded up to GiB.
      reserve_headroom() {
        local used
        exists "$1" || return 0
        used=$(zfs get -Hp -o value usedbydataset,usedbysnapshots,usedbychildren "$1" | awk '{ s += $1 } END { printf "%d", s }')
        set_property "$1" reservation "$(((used + $2 + gib - 1) / gib * gib))"
      }

      create ${agentsDataset} -o mountpoint=none -o canmount=off -o com.sun:auto-snapshot=true
      ${lib.concatMapStrings (directory: ''
        create ${directory.dataset} -o mountpoint=legacy${
          lib.optionalString (
            directory ? snapshots
          ) " -o com.sun:auto-snapshot=${snapshotFlag directory.snapshots}"
        }${lib.optionalString (directory ? quotaGib) " -o quota=${gibString directory.quotaGib}"}
      '') movedDirectories}
      create ${reserveDataset} -o mountpoint=none -o canmount=off

      ${lib.concatMapStrings (directory: ''
        ${lib.optionalString (
          directory ? quotaGib
        ) "set_property ${directory.dataset} quota ${gibBytes directory.quotaGib}"}
        ${lib.optionalString (
          directory ? snapshots
        ) "set_property ${directory.dataset} com.sun:auto-snapshot ${snapshotFlag directory.snapshots}"}
      '') movedDirectories}
      set_property ${agentsDataset} com.sun:auto-snapshot true
      # The AI tooling reservation starts once omp's state lives on its dataset.
      if [ -e ${markerDir}/omp ]; then
        set_property ${agentsDataset} reservation ${gibBytes agentsReservationGib}
      fi
      set_property ${reserveDataset} refreservation ${gibBytes emergencyReserveGib}
      set_property ${pool}/home refquota ${gibBytes homeRefquotaGib}
      reserve_headroom ${pool}/nix ${gibBytes nixHeadroomGib}
      reserve_headroom ${pool}/root ${gibBytes rootHeadroomGib}
    '';
  };

  # r[impl onix.aspen3.storage.cargo_cleanup]
  # The britton-desktop cleanup rules (CACHEDIR.TAG, Git-ignored, 21 idle
  # days, no active build), plus idle profile directories of the shared target.
  cargoTargetPruner = pkgs.writeShellApplication {
    name = "prune-stale-cargo-targets";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      git
      procps
      util-linux
    ];
    text = ''
      git_root=${lib.escapeShellArg "${userHome}/git"}
      user_home=${lib.escapeShellArg userHome}
      shared_target=${lib.escapeShellArg "${userHome}/.cargo-target"}
      stale_days=${toString staleTargetDays}
      lock_file="$user_home/.local/state/cargo-target-prune.lock"

      mkdir -p "$(dirname "$lock_file")"
      exec 9>"$lock_file"
      if ! flock -n 9; then
        echo "cargo-target-prune: another prune is active"
        exit 0
      fi

      if pgrep -u ${userName} -x cargo >/dev/null || pgrep -u ${userName} -x rustc >/dev/null; then
        echo "cargo-target-prune: skipped because a Cargo build is active"
        exit 0
      fi

      idle() { [ -z "$(find "$1" -xdev -type f -mtime -"$stale_days" -print -quit)" ]; }
      remove() {
        echo "cargo-target-prune: removing stale build output $1"
        rm -rf --one-file-system -- "$1"
      }

      while IFS= read -r -d "" target_dir; do
        [ -f "$target_dir/CACHEDIR.TAG" ] || continue
        git -C "$(dirname "$target_dir")" check-ignore -q "$target_dir" || continue
        if idle "$target_dir"; then remove "$target_dir"; fi
      done < <(find "$git_root" -xdev -type d -name target -prune -print0)

      for target_dir in "$user_home"/.cargo-target-*; do
        [ -f "$target_dir/CACHEDIR.TAG" ] || continue
        if idle "$target_dir"; then remove "$target_dir"; fi
      done

      if [ -f "$shared_target/CACHEDIR.TAG" ]; then
        for profile_dir in "$shared_target"/*/; do
          profile_dir=''${profile_dir%/}
          [ -d "$profile_dir" ] || continue
          if idle "$profile_dir"; then remove "$profile_dir"; fi
        done
      fi
    '';
  };

  # r[impl onix.aspen3.storage.garbage]
  storageCleanup = pkgs.writeShellApplication {
    name = "aspen3-storage-cleanup";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
    ];
    text = ''
      codex_staging=${lib.escapeShellArg "${userHome}/.codex/.tmp/bundled-marketplaces"}
      stale_root_days=${toString staleRootDays}

      # Codex leaves a read-only staging copy of its bundled plugins at every
      # start; only root can remove them.
      if [ -d "$codex_staging" ]; then
        find "$codex_staging" -mindepth 1 -maxdepth 1 -type d -name 'openai-bundled.staging-*' \
          -mmin +${toString codexStagingMinutes} -print0 |
          while IFS= read -r -d "" staging; do
            echo "storage-cleanup: removing Codex staging copy $staging"
            rm -rf --one-file-system -- "$staging"
          done
      fi

      # Build-result links in scratch locations keep their closures alive
      # until someone deletes them.
      for auto_root in /nix/var/nix/gcroots/auto/*; do
        root=$(readlink "$auto_root") || continue
        case $root in
          /tmp/* | /var/tmp/* | /dev/shm/* | ${lib.escapeShellArg userHome}/.cache/* | ${lib.escapeShellArg userHome}/scratch/*) ;;
          *) continue ;;
        esac
        [ -L "$root" ] || continue
        case $(readlink "$root") in
          /nix/store/*) ;;
          *) continue ;;
        esac
        if [ -n "$(find "$root" -maxdepth 0 -mtime +"$stale_root_days" -print)" ]; then
          echo "storage-cleanup: removing GC root $root"
          rm -f -- "$root"
        fi
      done
    '';
  };

  lowPriority = {
    Nice = 19;
    IOSchedulingClass = "idle";
  };
in
{
  disko.devices.zpool.${pool}.datasets = {
    agents = {
      type = "zfs_fs";
      options = {
        mountpoint = "none";
        canmount = "off";
        reservation = gibString agentsReservationGib;
        "com.sun:auto-snapshot" = "true";
      };
    };
    reserved = {
      type = "zfs_fs";
      options = {
        mountpoint = "none";
        canmount = "off";
        refreservation = gibString emergencyReserveGib;
      };
    };
  }
  // lib.listToAttrs (
    map (
      directory:
      lib.nameValuePair (datasetName directory.dataset) {
        type = "zfs_fs";
        mountpoint = directory.path;
        options = {
          mountpoint = "legacy";
        }
        // lib.optionalAttrs (directory ? quotaGib) { quota = gibString directory.quotaGib; }
        // lib.optionalAttrs (directory ? snapshots) {
          "com.sun:auto-snapshot" = snapshotFlag directory.snapshots;
        };
        # Ordered before local-fs.target like a required mount, but a
        # missing dataset must not stop the boot.
        mountOptions = [
          "defaults"
          "nofail"
          "x-systemd.before=local-fs.target"
          "x-systemd.after=${migrateUnit}.service"
        ];
      }
    ) movedDirectories
  );

  environment.systemPackages = [ migrator ];

  # r[impl onix.aspen3.storage.reservations]
  system.activationScripts.aspen3-storage-zfs = ''
    ${lib.getExe zfsProperties} || echo "aspen3-storage: ZFS properties were not applied" >&2
  '';

  systemd = {
    # A directory mounts only after its contents are on the dataset, so a
    # switch never hides a live directory under an empty mount.
    units = lib.listToAttrs (
      map (
        directory:
        lib.nameValuePair "${utils.escapeSystemdPath directory.path}.mount" {
          overrideStrategy = "asDropin";
          text = ''
            [Unit]
            ConditionPathExists=${markerDir}/${directory.name}
          '';
        }
      ) movedDirectories
    );

    services = {
      ${migrateUnit} = {
        description = "Move aspen3 home directories onto their ZFS datasets before anything uses them";
        wantedBy = [ "local-fs.target" ];
        after = [ "zfs-import.target" ];
        before = [
          "local-fs.target"
          "shutdown.target"
        ];
        conflicts = [ "shutdown.target" ];
        unitConfig = {
          DefaultDependencies = false;
          RequiresMountsFor = [
            userHome
            markerDir
          ];
        };
        restartIfChanged = false;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = lib.getExe migrator;
          TimeoutStartSec = "45min";
        };
      };

      cargo-target-prune = {
        description = "Remove inactive Cargo target directories";
        unitConfig.ConditionPathIsDirectory = "${userHome}/git";
        serviceConfig = lowPriority // {
          Type = "oneshot";
          User = userName;
          ExecStart = lib.getExe cargoTargetPruner;
        };
      };

      aspen3-storage-cleanup = {
        description = "Remove stale Codex staging copies and scratch GC roots";
        serviceConfig = lowPriority // {
          Type = "oneshot";
          ExecStart = lib.getExe storageCleanup;
        };
      };
    };

    timers = {
      cargo-target-prune = {
        description = "Weekly stale Cargo target cleanup";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "weekly";
          Persistent = true;
          RandomizedDelaySec = "6h";
        };
      };

      aspen3-storage-cleanup = {
        description = "Daily Codex staging and scratch GC root cleanup";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
      };
    };
  };
}
