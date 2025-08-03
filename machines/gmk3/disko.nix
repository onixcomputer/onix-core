# ---
# schema = "single-disk"
# [placeholders]
# mainDisk = "/dev/disk/by-id/nvme-TWSC_TSC3AN512E6-F2T60S_TTSMA253SX08789"
# ---
# This file was automatically generated!
# CHANGING this configuration requires wiping and reinstalling the machine
{

  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
    enable = true;
  };
  disko.devices = {
    disk = {
      main = {
        name = "main-3ac1539b591f4c7a97d57b657f04ca8c";
        device = "/dev/disk/by-id/nvme-TWSC_TSC3AN512E6-F2T60S_TTSMA253SX08789";
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
