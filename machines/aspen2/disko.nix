# ---
# schema = "single-disk"
# [placeholders]
# mainDisk = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_2TB_S7KHNU0YA15603E"
# ---
# This file was automatically generated!
# CHANGING this configuration requires wiping and reinstalling the machine

{

  boot = {
    loader = {
      grub = {
        efiSupport = true;
        efiInstallAsRemovable = true;
        enable = true;
      };
    };
  };
  disko.devices = {
    disk = {
      main = {
        name = "main-aspen2";
        device = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_2TB_S7KHNU0YA15603E";
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
