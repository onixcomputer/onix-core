let
  cargoTargetQuota = "1500G";
  gitWorkspaceQuota = "600G";
  kacheNixQuota = "64G";
  radicleBackupQuota = "256G";
  radicleBackupRecordSize = "1M";
  radicleSeedQuota = "64G";
  radicleSeedRecordSize = "128K";
in
{
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    device = "nodev";
  };
  disko.devices = {
    zpool = {
      datapool = {
        type = "zpool";
        rootFsOptions = {
          compression = "lz4";
          atime = "off";
          xattr = "sa";
          acltype = "posixacl";
        };
        datasets = {
          nix = {
            type = "zfs_fs";
            mountpoint = "/nix";
          };
          cargo-target = {
            type = "zfs_fs";
            mountpoint = "/home/brittonr/.cargo-target";
            options.quota = cargoTargetQuota;
          };
          git = {
            type = "zfs_fs";
            mountpoint = "/home/brittonr/git";
            options.quota = gitWorkspaceQuota;
            mountOptions = [
              "defaults"
              "nofail"
            ];
          };
          kache-nix = {
            type = "zfs_fs";
            mountpoint = "/var/cache/kache-nix";
            options.quota = kacheNixQuota;
            mountOptions = [
              "defaults"
              # The activation script creates this optional cache dataset on
              # already-installed hosts; a missing cache dataset must not block boot.
              "nofail"
            ];
          };
          radicle-backup = {
            type = "zfs_fs";
            mountpoint = "/var/lib/radicle-backup";
            options = {
              quota = radicleBackupQuota;
              recordsize = radicleBackupRecordSize;
            };
            mountOptions = [
              "defaults"
              "nofail"
            ];
          };
          radicle-seed = {
            type = "zfs_fs";
            mountpoint = "/var/lib/radicle";
            options = {
              quota = radicleSeedQuota;
              recordsize = radicleSeedRecordSize;
            };
            mountOptions = [
              "defaults"
              "nofail"
            ];
          };
          tmp = {
            type = "zfs_fs";
            mountpoint = "/tmp";
            options = {
              mountpoint = "legacy";
              compression = "off";
              sync = "disabled";
              quota = "250G";
            };
            mountOptions = [
              "defaults"
              "noatime"
              # /tmp is scratch space; a mount failure should not make the
              # machine drop to emergency mode during boot.
              "nofail"
            ];
          };
        };
      };
    };
    disk = {
      main = {
        device = "/dev/disk/by-id/nvme-Samsung_SSD_9100_PRO_2TB_S7YCNJ0Y202518L";
        type = "disk";
        destroy = false;
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              name = "ESP-samsung-9100";
              type = "EF00";
              size = "1G";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            swap = {
              name = "swap-samsung-9100";
              size = "8G";
              content = {
                type = "swap";
              };
            };
            root = {
              name = "root-samsung-9100";
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
      data = {
        device = "/dev/disk/by-id/nvme-Samsung_SSD_9100_PRO_4TB_S7YANJ0Y308565Y";
        type = "disk";
        destroy = false;
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "datapool";
              };
            };
          };
        };
      };
    };
  };
}
