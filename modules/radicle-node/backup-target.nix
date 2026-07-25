{
  config,
  lib,
  pkgs,
  ...
}:
let
  backupDataset = "datapool/radicle-backup";
  backupRoot = "/var/lib/radicle-backup";
  backupRepository = "${backupRoot}/aspen1";
  backupQuota = "256G";
  backupDirectoryMode = "0710";
  backupRepositoryMode = "0700";
  zfs = "${config.boot.zfs.package}/bin/zfs";
  findmnt = "${pkgs.util-linux}/bin/findmnt";
  repositoryConfig = config.services.borgbackup.repos.aspen1 or null;
in
{
  assertions = [
    {
      assertion = repositoryConfig != null && repositoryConfig.path == backupRepository;
      message = "Radicle backup target must expose only the reviewed Aspen1 Borg repository";
    }
  ];

  services.borgbackup.repos.aspen1.quota = backupQuota;

  system.activationScripts.radicle-backup-zfs-dataset = {
    deps = [ "users" ];
    text = ''
      install -d -m ${backupDirectoryMode} ${lib.escapeShellArg backupRoot}
      if ! ${zfs} list -H -o name ${lib.escapeShellArg backupDataset} >/dev/null 2>&1; then
        ${zfs} create \
          -o mountpoint=${lib.escapeShellArg backupRoot} \
          -o quota=${lib.escapeShellArg backupQuota} \
          ${lib.escapeShellArg backupDataset}
      else
        ${zfs} set mountpoint=${lib.escapeShellArg backupRoot} ${lib.escapeShellArg backupDataset}
        ${zfs} set quota=${lib.escapeShellArg backupQuota} ${lib.escapeShellArg backupDataset}
      fi

      ${zfs} mount ${lib.escapeShellArg backupDataset} >/dev/null 2>&1 || true
      actual_source="$(${findmnt} -no SOURCE --target ${lib.escapeShellArg backupRoot} 2>/dev/null || true)"
      if test "$actual_source" != ${lib.escapeShellArg backupDataset}; then
        echo "Radicle backup root is not mounted from ${backupDataset}" >&2
        exit 1
      fi
      chown root:borg ${lib.escapeShellArg backupRoot}
      chmod ${backupDirectoryMode} ${lib.escapeShellArg backupRoot}
    '';
  };

  systemd.services.borgbackup-repo-aspen1 = {
    after = [ "zfs-mount.service" ];
    script = lib.mkForce ''
      install -d \
        -m ${backupRepositoryMode} \
        -o ${repositoryConfig.user} \
        -g ${repositoryConfig.group} \
        ${lib.escapeShellArg backupRepository}
    '';
    serviceConfig.UMask = "0077";
    unitConfig.RequiresMountsFor = [ backupRoot ];
  };
}
