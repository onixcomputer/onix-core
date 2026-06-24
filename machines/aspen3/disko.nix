let
  mainDisk = "/dev/disk/by-id/nvme-WD_PC_SN5000S_SDEQTSJ-1T00-1002_25466C400776";
  biosBootPartitionSize = "1M";
  efiSystemPartitionSize = "1G";
  rootPoolName = "zroot";
  remainingDiskSize = "100%";
  grubConfigurationLimit = 10;
  primaryPartitionPriority = 1;
  zfsAshift = "12";
in
{
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    device = "nodev";
    configurationLimit = grubConfigurationLimit;
  };

  disko.devices = {
    disk.main = {
      name = "main-aspen3";
      device = mainDisk;
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            size = biosBootPartitionSize;
            type = "EF02";
            priority = primaryPartitionPriority;
          };
          ESP = {
            size = efiSystemPartitionSize;
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          zfs = {
            size = remainingDiskSize;
            content = {
              type = "zfs";
              pool = rootPoolName;
            };
          };
        };
      };
    };

    zpool.${rootPoolName} = {
      type = "zpool";
      options = {
        ashift = zfsAshift;
        autotrim = "on";
      };
      rootFsOptions = {
        mountpoint = "none";
        compression = "zstd";
        atime = "off";
        xattr = "sa";
        acltype = "posixacl";
        "com.sun:auto-snapshot" = "false";
      };
      datasets = {
        root = {
          type = "zfs_fs";
          mountpoint = "/";
          options.mountpoint = "legacy";
        };
        nix = {
          type = "zfs_fs";
          mountpoint = "/nix";
          options.mountpoint = "legacy";
        };
        home = {
          type = "zfs_fs";
          mountpoint = "/home";
          options = {
            mountpoint = "legacy";
            "com.sun:auto-snapshot" = "true";
          };
        };
      };
    };
  };
}
