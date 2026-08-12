{ dgxDiskById, ... }:
let
  efiPartitionSize = "512M";
  remainingDiskSize = "100%";
in
{
  disko.devices.disk.main = {
    device = dgxDiskById;
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = efiPartitionSize;
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
          };
        };
        root = {
          size = remainingDiskSize;
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;
}
