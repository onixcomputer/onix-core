# ---
# schema = "single-disk"
# [placeholders]
# mainDisk = "/dev/disk/by-id/nvme-WD_PC_SN740_SDDPNQE-2T00_251517805135"
# ---
# WD PC SN740 2TB NVMe SSD
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
        device = "/dev/disk/by-id/nvme-WD_PC_SN740_SDDPNQE-2T00_251517805135";
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
