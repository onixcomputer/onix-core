# Filesystem for cloud-hypervisor guest.
# Raw ext4 on /dev/vda — no partition table, no bootloader.
# Cloud-hypervisor presents the disk image directly as a virtio-blk device.
{
  fileSystems."/" = {
    device = "/dev/vda";
    fsType = "ext4";
    options = [
      "rw"
      "noatime"
      # Disable barriers — cloud-hypervisor's virtio-blk rejects writes to
      # sector 0 which breaks ext4's journal barrier writes.
      "nobarrier"
    ];
  };
}
