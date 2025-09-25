# ---
# schema = "hybrid-boot"
# [placeholders]
# bootDisk = "/dev/disk/by-id/usb-DELL_IDSDM_012345678901-0:0"
# mainDisk = "/dev/disk/by-id/nvme-Samsung_SSD_990_EVO_Plus_4TB_S7U8NJ0Y727452J"
# ---
# Hybrid configuration: IDSDM for /boot, NVMe for root
{

  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
    enable = true;
    device = "nodev"; # Don't install to MBR, use EFI only
  };
  disko.devices = {
    disk = {
      # IDSDM for boot partition only
      idsdm = {
        name = "idsdm-boot";
        device = "/dev/disk/by-id/usb-DELL_IDSDM_012345678901-0:0";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              type = "EF00";
              size = "14G"; # Use most of IDSDM for /boot
              priority = 1;
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
          };
        };
      };
      # NVMe for root filesystem
      nvme = {
        name = "nvme-root";
        device = "/dev/disk/by-id/nvme-Samsung_SSD_990_EVO_Plus_4TB_S7U8NJ0Y727452J";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
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
