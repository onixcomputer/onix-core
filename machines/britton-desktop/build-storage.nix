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
  gitWorkspaceQuota = "600G";
  kacheDataset = "datapool/kache-nix";
  kacheQuota = "64G";
  userHome = "/home/brittonr";
  staleTargetDays = 21;
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
      stale_days=${toString staleTargetDays}
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

      prune_target() {
        target_dir="$1"
        require_git_ignore="$2"

        if [ ! -f "$target_dir/CACHEDIR.TAG" ]; then
          return 0
        fi

        if [ "$require_git_ignore" = 1 ] && ! git -C "$(dirname "$target_dir")" check-ignore -q "$target_dir"; then
          return 0
        fi

        if find "$target_dir" -xdev -type f -mtime -"$stale_days" -print -quit | grep -q .; then
          return 0
        fi

        echo "cargo-target-prune: removing stale build output $target_dir"
        rm -rf --one-file-system -- "$target_dir"
      }

      while IFS= read -r -d "" target_dir; do
        prune_target "$target_dir" 1
      done < <(find "$git_root" -xdev -type d -name target -prune -print0)

      for target_dir in "$user_home"/.cargo-target-*; do
        if [ -d "$target_dir" ]; then
          prune_target "$target_dir" 0
        fi
      done
    '';
  };
in
{
  services.journald.extraConfig = ''
    SystemMaxUse=1G
    RuntimeMaxUse=512M
    MaxRetentionSec=14day
  '';

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
    description = "Weekly stale Cargo target cleanup";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
      RandomizedDelaySec = "6h";
      Unit = "cargo-target-prune.service";
    };
  };
}
