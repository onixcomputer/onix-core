# ---
# schema = "single-disk"
# [placeholders]
# mainDisk = "/dev/disk/by-id/ata-Samsung_SSD_870_EVO_1TB_S75BNL0WA31728T" 
# ---
# This file was automatically generated!
# CHANGING this configuration requires wiping and reinstalling the machine
{

  boot.loader.grub.efiSupport = true;
  boot.loader.grub.efiInstallAsRemovable = true;
  boot.loader.grub.enable = true;
  disko.devices = {
    disk = {
      main = {
        name = "main-7dda477b29ee428a92f8473024ddfee3";
        device = "/dev/disk/by-id/ata-Samsung_SSD_870_EVO_1TB_S75BNL0WA31728T";
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
