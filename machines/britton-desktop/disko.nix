{
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = false;
      efi.efiSysMountPoint = "/boot";
      grub.enable = false;
    };
  };
  disko.devices = {
    disk = {
      main = {
        device = "/dev/nvme0n1";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              type = "EF00";
              size = "500M";
              priority = 1;
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
                format = "bcachefs";
                mountpoint = "/";
                mountOptions = [
                  "compress=lz4"
                  "background_compress=zstd"
                  "str_hash=siphash"
                ];
              };
            };
          };
        };
      };
    };
  };
}
