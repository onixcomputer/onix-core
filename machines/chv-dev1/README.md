# chv-dev1 — Cloud Hypervisor Guest VM

x86_64-linux NixOS guest running on britton-desktop via cloud-hypervisor.
Direct kernel boot, virtio I/O, systemd-networkd DHCP on TAP bridge.

## Network

- IP: `172.16.0.10` (DHCP reservation via dnsmasq)
- Gateway: `172.16.0.1` (host TAP endpoint)
- DNS: `1.1.1.1`, `8.8.8.8` (DHCP option)
- MAC: `52:54:00:c0:ff:01`
- TAP: `tap-chv-dev1` on host

## Lifecycle

```bash
# Start/stop/restart
systemctl start cloud-hypervisor-chv-dev1
systemctl stop cloud-hypervisor-chv-dev1   # ACPI power button, clean shutdown
systemctl restart cloud-hypervisor-chv-dev1

# Deploy config changes (builds on britton-desktop, pushes to guest)
clan machines update chv-dev1

# After kernel/initrd changes, restart the VM to pick up new paths
systemctl restart cloud-hypervisor-chv-dev1
```

## Bootstrap (first time only)

```bash
# Build the guest toplevel
TOPLEVEL=$(nix build .#nixosConfigurations.chv-dev1.config.system.build.toplevel --no-link --print-out-paths)

# Run bootstrap (creates disk image, formats, installs NixOS)
sudo bash modules/cloud-hypervisor-vm/bootstrap.sh chv-dev1

# Start the VM
sudo systemctl start cloud-hypervisor-chv-dev1
```

The bootstrap script creates a 40GB GPT-partitioned ext4 disk image at
`/var/lib/cloud-hypervisor/chv-dev1.img` and runs `nixos-install`.

**Important**: The bootstrap generates `/etc/machine-id` after install.
Without it, systemd-networkd's DHCPv4 client fails with ENOENT.

## Serial Console

The VM serial console goes to systemd journal:
```bash
journalctl -u cloud-hypervisor-chv-dev1 -f
```

For interactive access, temporarily change `--serial tty` to `--serial pty`
in the module, redeploy, and connect:
```bash
ch-remote --api-socket /run/cloud-hypervisor-chv-dev1.sock info | jq .config.serial.file
# Returns e.g. /dev/pts/11
screen /dev/pts/11
```

## Disk Resize

```bash
systemctl stop cloud-hypervisor-chv-dev1
truncate -s 80G /var/lib/cloud-hypervisor/chv-dev1.img
LOOP=$(losetup --find --show -P /var/lib/cloud-hypervisor/chv-dev1.img)
sgdisk -e $LOOP           # move backup GPT to end
sgdisk -d 1 -n 1:0:0 -c 1:disk-main-root -t 1:8300 $LOOP
partprobe $LOOP; sleep 1
e2fsck -f ${LOOP}p1
resize2fs ${LOOP}p1
losetup -d $LOOP
systemctl start cloud-hypervisor-chv-dev1
```

## Specs

- 4 vCPUs, 4096 MiB RAM, zram swap
- virtio-blk (4-queue), virtio-net (8-queue / 4 pairs)
- seccomp sandbox, hardware watchdog
- Nix GC: daily, delete older than 7d
