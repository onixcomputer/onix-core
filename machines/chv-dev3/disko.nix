# Disk layout for cloud-hypervisor guest.
# Single ext4 partition on virtio-blk /dev/vda — no ESP, no bootloader.
# GPT partition table required: cloud-hypervisor disables writes to sector 0
# on raw images, so the filesystem must start at an offset (partition 1).
{
  disko.devices.disk.main = {
    device = "/dev/vda";
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
}
