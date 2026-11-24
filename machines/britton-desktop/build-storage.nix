{
  config,
  lib,
  pkgs,
  ...
}:
let
  cargoTargetDataset = "datapool/cargo-target";
  cargoTargetQuota = "1500G";
  gitDataset = "datapool/git";
  gitRoot = "/home/brittonr/git";
  gitWorkspaceQuota = "800G";
  kacheDataset = "datapool/kache-nix";
  kacheQuota = "128G";
  userHome = "/home/brittonr";
  staleTargetDays = 7;
  staleWorktreeTargetDays = 3;
  zfs = "${config.boot.zfs.package}/bin/zfs";

  cargoTargetPruner = pkgs.writeShellApplication {
    name = "prune-stale-cargo-targets";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      git
      gnugrep
      procps
      util-linux
    ];
    text = ''
      set -eu

      git_root=${lib.escapeShellArg gitRoot}
      user_home=${lib.escapeShellArg userHome}
      shared_target="$user_home/.cargo-target"
      stale_days=${toString staleTargetDays}
      stale_worktree_days=${toString staleWorktreeTargetDays}
      lock_file="$user_home/.local/state/cargo-target-prune.lock"

      mkdir -p "$(dirname "$lock_file")"
      exec 9>"$lock_file"
      if ! flock -n 9; then
        echo "cargo-target-prune: another prune is active"
        exit 0
      fi

      if pgrep -u brittonr -x cargo >/dev/null || pgrep -u brittonr -x rustc >/dev/null; then
        echo "cargo-target-prune: skipped because a Cargo build is active"
        exit 0
      fi

      idle() {
        ! find "$1" -xdev -type f -mtime -"$2" -print -quit | grep -q .
      }

      remove_dir() {
        echo "cargo-target-prune: removing stale build output $1"
        rm -rf --one-file-system -- "$1"
      }

      prune_target() {
        target_dir="$1"
        require_git_ignore="$2"
        max_days="$3"

        if [ ! -f "$target_dir/CACHEDIR.TAG" ]; then
          return 0
        fi

        if [ "$require_git_ignore" = 1 ] && ! git -C "$(dirname "$target_dir")" check-ignore -q "$target_dir"; then
          return 0
        fi

        if ! idle "$target_dir" "$max_days"; then
          return 0
        fi

        remove_dir "$target_dir"
      }

      while IFS= read -r -d "" target_dir; do
        prune_target "$target_dir" 1 "$stale_days"
      done < <(find "$git_root" -xdev -type d -name target -prune -print0)

      for target_dir in "$user_home"/.cargo-target-*; do
        if [ -d "$target_dir" ]; then
          prune_target "$target_dir" 0 "$stale_days"
        fi
      done

      for worktree_root in "$user_home/.gemini/antigravity-cli/worktrees" "$user_home/.herdr/worktrees"; do
        if [ -d "$worktree_root" ]; then
          while IFS= read -r -d "" target_dir; do
            prune_target "$target_dir" 0 "$stale_worktree_days"
          done < <(find "$worktree_root" -xdev -type d -name target -prune -print0)
        fi
      done

      if [ -f "$shared_target/CACHEDIR.TAG" ]; then
        for entry in "$shared_target"/*/; do
          entry=''${entry%/}
          [ -d "$entry" ] || continue
          case "$(basename "$entry")" in
            producer-work | repo-targets | worktrees)
              for child in "$entry"/*/; do
                child=''${child%/}
                [ -d "$child" ] || continue
                if idle "$child" "$stale_days"; then
                  remove_dir "$child"
                fi
              done
              ;;
            *)
              if idle "$entry" "$stale_days"; then
                remove_dir "$entry"
              fi
              ;;
          esac
        done
      fi
    '';
  };
in
{
  services.journald.settings.Journal = {
    SystemMaxUse = "1G";
    RuntimeMaxUse = "512M";
    MaxRetentionSec = "14day";
  };

  system.activationScripts.build-storage-zfs-properties = ''
    if ${zfs} list -H -o name ${lib.escapeShellArg gitDataset} >/dev/null 2>&1; then
      current_mountpoint="$(${zfs} get -H -o value mountpoint ${lib.escapeShellArg gitDataset})"
      if [ "$current_mountpoint" != ${lib.escapeShellArg gitRoot} ]; then
        ${zfs} set mountpoint=${lib.escapeShellArg gitRoot} ${lib.escapeShellArg gitDataset}
      fi
      ${zfs} set quota=${gitWorkspaceQuota} ${lib.escapeShellArg gitDataset}
    fi
    if ${zfs} list -H -o name ${lib.escapeShellArg cargoTargetDataset} >/dev/null 2>&1; then
      ${zfs} set quota=${cargoTargetQuota} ${lib.escapeShellArg cargoTargetDataset}
    fi
    if ${zfs} list -H -o name ${lib.escapeShellArg kacheDataset} >/dev/null 2>&1; then
      ${zfs} set quota=${kacheQuota} ${lib.escapeShellArg kacheDataset}
    fi
  '';

  systemd.services.cargo-target-prune = {
    description = "Remove inactive Cargo target directories from build storage";
    unitConfig.ConditionPathIsMountPoint = gitRoot;
    serviceConfig = {
      Type = "oneshot";
      User = "brittonr";
      ExecStart = lib.getExe cargoTargetPruner;
      Nice = 19;
      IOSchedulingClass = "idle";
    };
  };

  systemd.timers.cargo-target-prune = {
    description = "Daily stale Cargo target cleanup";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "2h";
      Unit = "cargo-target-prune.service";
    };
  };
}
