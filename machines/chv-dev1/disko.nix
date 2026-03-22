# Filesystem for cloud-hypervisor guest.
# Raw ext4 on /dev/vda — no partition table, no bootloader.
# Cloud-hypervisor presents the disk image directly as a virtio-blk device.
{
  fileSystems."/" = {
    device = "/dev/vda";
    fsType = "ext4";
  };
}
