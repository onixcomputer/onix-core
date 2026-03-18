{
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    device = "nodev";
  };
  disko.devices = {
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
            data = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/data";
              };
            };
          };
        };
      };
    };
  };
}
