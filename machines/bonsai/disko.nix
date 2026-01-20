# ---
# schema = "single-disk"
# [placeholders]
# mainDisk = "/dev/disk/by-id/REPLACE_WITH_ACTUAL_DISK_ID"
# ---
# This file was automatically generated!
# CHANGING this configuration requires wiping and reinstalling the machine
#
# TODO: Update mainDisk placeholder above with actual disk ID from:
#   ls -la /dev/disk/by-id/ | grep -E 'nvme|sd|vd'
{

  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
    enable = true;
  };
  disko.devices = {
    disk = {
      main = {
        name = "main-bonsai";
        device = "/dev/disk/by-id/REPLACE_WITH_ACTUAL_DISK_ID";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            "boot" = {
              size = "1M";
              type = "EF02"; # for grub MBR
              priority = 1;
            };
            ESP = {
              type = "EF00";
              size = "500M";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            root = {
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
    };
  };
}
