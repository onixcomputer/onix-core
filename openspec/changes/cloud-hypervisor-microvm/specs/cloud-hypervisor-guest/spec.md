## ADDED Requirements

### Requirement: Guest tag configures virtio kernel modules
The `cloud-hypervisor-guest` tag SHALL add virtio_pci, virtio_blk, virtio_net, and virtio_console to `boot.initrd.availableKernelModules` so the guest can access cloud-hypervisor paravirtualized devices.

#### Scenario: Guest boots with virtio devices
- **WHEN** a machine has the `cloud-hypervisor-guest` tag
- **THEN** the kernel initrd includes virtio_pci, virtio_blk, virtio_net, and virtio_console modules

### Requirement: Guest uses direct kernel boot with no bootloader
The guest configuration SHALL disable all bootloader configuration (grub, systemd-boot) since cloud-hypervisor uses direct kernel boot via `--kernel` and `--initramfs` flags.

#### Scenario: No bootloader installed
- **WHEN** a machine has the `cloud-hypervisor-guest` tag
- **THEN** `boot.loader.grub.enable` is false and no bootloader is installed to the disk image

### Requirement: Guest uses systemd-in-initrd
The guest SHALL enable `boot.initrd.systemd.enable = true` for faster boot and better error handling during early userspace.

#### Scenario: Systemd initrd active
- **WHEN** a machine has the `cloud-hypervisor-guest` tag
- **THEN** the initrd uses systemd instead of the legacy boot scripts

### Requirement: Guest disables systemd-networkd-wait-online
The guest SHALL disable `systemd-networkd-wait-online.service` to prevent boot hangs caused by upstream systemd bug [#29388](https://github.com/systemd/systemd/issues/29388).

#### Scenario: Boot does not hang on network-online.target
- **WHEN** the guest boots
- **THEN** boot completes without waiting for `systemd-networkd-wait-online.service`

### Requirement: Guest enables automatic nix store garbage collection
The guest SHALL enable `nix.gc.automatic` with aggressive settings to prevent the persistent disk image from filling up with old closures after repeated `clan machines update` deployments.

#### Scenario: Old closures cleaned up
- **WHEN** the guest has been updated multiple times
- **THEN** nix garbage collection automatically removes closures older than the configured threshold

### Requirement: Guest serial console on ttyS0
The guest SHALL configure `console=ttyS0` kernel parameter and enable a getty on ttyS0 for serial console access through cloud-hypervisor's `--serial tty` or `--console pty` options.

#### Scenario: Serial console accessible
- **WHEN** the VM is running
- **THEN** kernel output appears on the serial console and a login prompt is available on ttyS0

### Requirement: Guest uses systemd-networkd with DHCP
The guest SHALL use systemd-networkd (not NetworkManager) with DHCP on the virtio ethernet interface to obtain its IP from the host's dnsmasq server.

#### Scenario: Guest obtains IP via DHCP
- **WHEN** the guest boots on the TAP bridge
- **THEN** systemd-networkd requests a DHCP lease and receives an IP in the 172.16.0.0/24 range

### Requirement: Guest has SSH enabled for clan deploy
The guest SHALL enable openssh with root login via authorized keys so `clan machines update` can deploy over SSH.

#### Scenario: Clan deploy over SSH
- **WHEN** `clan machines update <vmname>` is run from the host
- **THEN** clan connects via SSH to the guest's IP and performs `nixos-rebuild switch`

### Requirement: Guest disables unnecessary services
The guest SHALL disable services that are broken or unnecessary in a cloud-hypervisor VM (envfs, desktop services, etc.) to reduce boot time and resource usage.

#### Scenario: Clean headless boot
- **WHEN** the guest boots
- **THEN** no desktop services, display managers, or FUSE filesystems are started

### Requirement: Guest machine registered in inventory
The guest machine SHALL be registered in `inventory/core/machines.ncl` with the `cloud-hypervisor-guest` tag, a deploy target pointing to its IP, and `x86_64-linux` system type.

#### Scenario: Machine appears in clan
- **WHEN** `clan machines list` is run
- **THEN** the cloud-hypervisor guest appears in the machine list

#### Scenario: Machine builds successfully
- **WHEN** `build <vmname>` is run
- **THEN** the NixOS configuration evaluates and builds without errors
