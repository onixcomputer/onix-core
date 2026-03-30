{
  host = {
    guestMachine = { type = "string", description = "Name of the guest clan machine" },
    cpus = { type = "number", default = 2, description = "Number of vCPUs for the guest" },
    memory = { type = "number", default = 2048, description = "RAM in MiB for the guest" },
    diskPath = { type = "string", description = "Path to the raw ext4 disk image on the host" },
    diskSize = { type = "string", default = "40G", description = "Disk image size (bootstrap only)" },
    tapInterface = { type = "string", description = "TAP interface name for the guest" },
    macAddress = { type = "string", description = "MAC address for the guest virtio-net device" },
    guestIp = { type = "string", description = "Static IP for DHCP reservation" },
  },
}
