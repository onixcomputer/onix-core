## Why

Cloud Hypervisor runs lightweight VMs with minimal overhead — no QEMU baggage, virtio-native, fast boot. The existing `cloud-hypervisor-host` tag sets up TAP networking on the host but there's no way to define a cloud-hypervisor guest as a clan machine. Adding one means `clan machines update microvmname` builds the NixOS config, produces a kernel+initrd+rootfs, and pushes it to the running VM over SSH — same workflow as utm-vm or any physical machine.

## What Changes

- **New clan machine type**: A cloud-hypervisor guest defined in `machines/<name>/` with its own `configuration.nix`, registered in `inventory/core/machines.ncl` with appropriate tags.
- **New tag `cloud-hypervisor-guest`**: Configures the guest-side kernel, initrd modules (virtio-pmem, virtio-net, virtio-blk, virtio-console), serial console, and networkd for DHCP on the TAP bridge.
- **Host-side launch script**: A NixOS module or package on the host (britton-desktop) that launches cloud-hypervisor with the guest's kernel, initrd, and root filesystem. Exposed as a systemd service or wrapper script.
- **Root filesystem strategy**: Build a raw disk image (or use virtiofs/virtio-pmem) from the NixOS closure. The guest needs a persistent `/nix/store` and mutable state dirs so `nixos-rebuild switch` via SSH works for subsequent `clan machines update`.
- **Deploy target**: Guest gets an SSH server, host-side TAP networking provides connectivity. Deploy target is `root@<guest-ip>` or `root@iroh-<name>`.

## Capabilities

### New Capabilities
- `cloud-hypervisor-guest`: Guest-side NixOS configuration — kernel params, virtio modules, networkd, serial console, boot loader bypass (direct kernel boot).
- `cloud-hypervisor-launcher`: Host-side VM lifecycle — systemd service that starts cloud-hypervisor with correct kernel/initrd/rootfs paths, TAP device, memory, CPU allocation. Includes image build derivation.

### Modified Capabilities
- None. The existing `cloud-hypervisor-host` tag handles host networking and stays unchanged.

## Impact

- **New files**: `machines/<vmname>/configuration.nix`, new tag file `inventory/tags/cloud-hypervisor-guest.nix`, host launcher module or script.
- **Modified files**: `inventory/core/machines.ncl` (new machine entry), `inventory/core/contracts.ncl` (new tag registration).
- **Dependencies**: `cloud-hypervisor` package (already in nixpkgs). May need `virtiofsd` if using virtiofs for `/nix/store`.
- **Host machine**: britton-desktop already has `cloud-hypervisor-host` tag. The launcher service/script goes there.
- **Networking**: Guest uses the existing TAP bridge (172.16.0.0/24) configured by `cloud-hypervisor-host` tag. Need to handle multi-guest scenarios (multiple TAP interfaces, DHCP range expansion) if more than one microVM is desired.
