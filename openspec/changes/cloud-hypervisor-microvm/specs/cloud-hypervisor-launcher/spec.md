## ADDED Requirements

### Requirement: Host systemd service runs cloud-hypervisor
The host SHALL have a systemd service `cloud-hypervisor-<vmname>.service` that launches cloud-hypervisor with the guest's kernel, initrd, root disk image, and configured resources (CPUs, memory).

#### Scenario: VM starts via systemd
- **WHEN** `systemctl start cloud-hypervisor-<vmname>` is run on the host
- **THEN** cloud-hypervisor starts with the correct kernel, initrd, disk, and network configuration

#### Scenario: VM stops gracefully via systemd
- **WHEN** `systemctl stop cloud-hypervisor-<vmname>` is run on the host
- **THEN** the service sends an ACPI power button event via `curl --unix-socket <socket> -X PUT http://localhost/api/v1/vm.power-button`, waits for the guest to shut down gracefully, and the process exits

#### Scenario: VM stop timeout
- **WHEN** `systemctl stop` is run and the guest does not shut down within `TimeoutStopSec` (30s)
- **THEN** systemd sends SIGKILL to the cloud-hypervisor process

#### Scenario: VM auto-starts on boot
- **WHEN** the host boots and the service is enabled
- **THEN** the VM starts automatically

### Requirement: Host creates per-VM TAP interface
The host service SHALL create a TAP interface named `tap-<vmname>` before launching cloud-hypervisor, with the interface added to the host's bridge/NAT configuration.

#### Scenario: TAP interface created on service start
- **WHEN** the VM service starts
- **THEN** a TAP interface `tap-<vmname>` exists and is up with an IP on the 172.16.0.0/24 subnet

#### Scenario: TAP interface cleaned up on service stop
- **WHEN** the VM service stops
- **THEN** the TAP interface is removed

### Requirement: Host provides DHCP reservation for guest
The host SHALL configure dnsmasq with a DHCP reservation mapping the guest's MAC address to a static IP within the 172.16.0.0/24 range.

#### Scenario: Guest gets reserved IP
- **WHEN** the guest sends a DHCP request with its configured MAC address
- **THEN** dnsmasq responds with the reserved IP address

### Requirement: Kernel and initrd paths resolved from guest NixOS closure
The host service SHALL determine the kernel and initrd paths by reading the guest machine's NixOS system closure from the local nix store (built by `clan machines update` or `nix build`). On x86_64, cloud-hypervisor requires the uncompressed kernel ELF (`vmlinux` from `kernel.dev`), not `bzImage`.

#### Scenario: Kernel path from toplevel on x86_64
- **WHEN** the host service starts for an x86_64 guest
- **THEN** it uses `${kernel.dev}/vmlinux` (uncompressed ELF) and `<toplevel>/initrd`

### Requirement: Init path resolved dynamically
The kernel cmdline `init=` parameter SHALL use the full nix store path to the guest's `system.build.toplevel` init script. This path changes on every build, so the host service MUST resolve it from the current toplevel derivation at service start time.

#### Scenario: Init path matches built system
- **WHEN** the VM starts after a guest config rebuild
- **THEN** the `--cmdline` includes `init=/nix/store/<hash>-nixos-system-<name>-.../init`

### Requirement: Root disk image exists at configured path
The host service SHALL use a raw ext4 disk image at a configurable path as the guest's root filesystem via virtio-blk.

#### Scenario: Disk image attached
- **WHEN** the VM starts
- **THEN** cloud-hypervisor presents the disk image as `/dev/vda` to the guest

#### Scenario: Disk image missing
- **WHEN** the VM service starts and the disk image does not exist
- **THEN** the service fails with a clear error message

### Requirement: Bootstrap script creates initial disk image
A bootstrap script or derivation SHALL create the initial raw disk image with a populated NixOS system, including SSH host keys and authorized deployer keys.

#### Scenario: First-time image creation
- **WHEN** the bootstrap script runs with a target machine name
- **THEN** it produces a raw ext4 disk image with the guest's NixOS system installed and SSH accessible

#### Scenario: Subsequent updates via clan
- **WHEN** `clan machines update <vmname>` runs after bootstrap
- **THEN** the guest's NixOS system is updated in-place over SSH without rebuilding the disk image

### Requirement: VM resource configuration
The host service SHALL accept configuration for CPU count, memory size, and disk path per VM instance.

#### Scenario: Custom resources
- **WHEN** the VM instance is configured with 4 CPUs and 4096MB RAM
- **THEN** cloud-hypervisor launches with `--cpus boot=4 --memory size=4096M`

### Requirement: Security hardening flags enabled
The host service SHALL pass `--seccomp true` (seccomp sandbox) and `--watchdog` (hardware watchdog) to cloud-hypervisor unconditionally.

#### Scenario: Seccomp and watchdog active
- **WHEN** the VM starts
- **THEN** cloud-hypervisor runs with seccomp filtering and watchdog enabled

### Requirement: Multi-queue virtio for multi-vCPU guests
When the VM has more than 1 vCPU, the host service SHALL configure multi-queue on disk devices (`num_queues=<vcpu>`) and network devices (`num_queues=<2*vcpu>`).

#### Scenario: Single vCPU
- **WHEN** the VM is configured with 1 vCPU
- **THEN** no multi-queue flags are added

#### Scenario: Multiple vCPUs
- **WHEN** the VM is configured with 4 vCPUs
- **THEN** disk devices get `num_queues=4` and net devices get `num_queues=8`

### Requirement: TAP interfaces created with vnet_hdr
The host SHALL create TAP interfaces with `vnet_hdr` mode for virtio-net checksum offloading, and additionally with `multi_queue` when the guest has more than 1 vCPU.

#### Scenario: TAP with vnet_hdr
- **WHEN** a TAP interface is created for a VM
- **THEN** `ip tuntap add ... mode tap vnet_hdr` is used

### Requirement: Cloud-hypervisor API socket exposed
The host service SHALL expose the cloud-hypervisor HTTP API socket at a predictable path (`/run/cloud-hypervisor-<vmname>.sock`) for runtime VM management (reboot, resize, etc.).

#### Scenario: API socket available
- **WHEN** the VM is running
- **THEN** `ch-remote --api-socket /run/cloud-hypervisor-<vmname>.sock info` returns VM status
