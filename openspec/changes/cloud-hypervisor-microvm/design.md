## Context

The infra already runs a UTM-based aarch64 VM (`utm-vm`) as a full clan machine — it has `machines/utm-vm/configuration.nix`, a disko layout, and deploys via `clan machines update utm-vm` over SSH. The host side (TAP networking, dnsmasq DHCP, NAT) is handled by the `cloud-hypervisor-host` tag on britton-desktop. What's missing is the guest definition and the glue that builds a bootable image and launches it.

Cloud Hypervisor does direct kernel boot (no bootloader). It needs a Linux kernel, initrd, and a root filesystem. NixOS already produces all three via its standard build infrastructure — `config.system.build.kernel`, `config.system.build.initialRamdisk`, `config.system.build.toplevel`. The root filesystem is the tricky part: we need a persistent disk image with `/nix/store` populated and mutable state dirs (`/etc`, `/var`) so `nixos-rebuild switch` works over SSH for subsequent updates.

## Goals / Non-Goals

**Goals:**
- Define a cloud-hypervisor guest as a standard clan machine: `clan machines update <name>` builds and deploys.
- Guest boots via direct kernel boot (kernel + initrd from NixOS build).
- Persistent root disk image so state survives reboots and `nixos-rebuild switch` works.
- Host-side systemd service to manage VM lifecycle (start/stop/restart).
- Guest reachable over the existing TAP bridge (172.16.0.0/24) via SSH.
- Multiple guests possible (each with own TAP interface and IP).

**Non-Goals:**
- Live migration or HA — this is a dev workstation, not a cloud.
- PCI passthrough or GPU access inside the guest.
- Replacing the microvm.nix project — we're building the minimal integration needed for clan-managed VMs.
- UEFI boot — direct kernel boot is simpler and faster.
- virtiofs or 9p — keep it simple with a raw disk image. Can add later.
- Automated initial image creation (first boot) — the first disk image is created manually or via a one-shot script, then `clan machines update` handles all subsequent updates over SSH.

## Decisions

### 1. Root filesystem: persistent raw disk image

**Choice**: ext4 raw disk image on the host, attached as a virtio-blk device.

**Alternatives considered**:
- *virtiofs*: No persistent state between reboots unless combined with a host directory. Adds virtiofsd daemon complexity. `nixos-rebuild switch` needs writable `/nix/store`.
- *virtio-pmem with rootfs squashfs*: Read-only root with overlay — breaks `nixos-rebuild switch` which writes to `/nix/store` directly.
- *qcow2*: Cloud Hypervisor supports it but raw is simpler, and we don't need snapshots or thin provisioning.

ext4 on raw disk gives us a standard NixOS root that `nixos-rebuild switch` writes to without surprises. The image is created once, then clan deploys over SSH like any other machine.

### 2. Direct kernel boot (no bootloader)

**Choice**: Pass `--kernel` and `--initramfs` to cloud-hypervisor from the host's nix store. The host reads the guest's NixOS closure to find the kernel and initrd paths.

**Critical detail**: Cloud Hypervisor on x86_64 requires the **uncompressed** kernel ELF (`vmlinux`), not `bzImage`. The path is `${config.boot.kernelPackages.kernel.dev}/vmlinux` (from the `.dev` output of the kernel package). On aarch64, the compressed `Image` works. microvm.nix handles this distinction in its runner.

The guest's `configuration.nix` disables the bootloader entirely. Kernel command line is passed via `--cmdline` with `root=/dev/vda init=<toplevel>/init console=ttyS0`. The `init=` path must be the full nix store path to the guest's specific `system.build.toplevel` — it changes on every build, so the host service resolves it dynamically.

After `clan machines update`, the guest has a new system profile in `/nix/store` but the running kernel/initrd don't change until the VM is restarted. The host service must be restarted to pick up new kernel/initrd paths. For non-kernel updates, `nixos-rebuild switch` inside the guest activates the new system without a reboot (same as physical machines).

### 3. Host launcher as a clan service module with "host" role

**Choice**: A new clan service module `cloud-hypervisor-vm` with a single `host` role. Each instance represents one VM. The instance settings define VM parameters (name, memory, CPUs, disk path, TAP interface, MAC address).

The module generates:
- A systemd service `cloud-hypervisor-<vmname>.service` that runs cloud-hypervisor with the right args.
- Graceful shutdown via the API socket (`curl --unix-socket ... -X PUT .../vm.power-button`) in `ExecStop`, avoiding SIGKILL and preventing data loss on the ext4 image.
- A `ch-launch-<vmname>` wrapper script for manual use.

**Alternatives considered**:
- *Tag-based*: A tag per VM is awkward — tags are reusable across machines, but each VM config is unique.
- *Plain NixOS module in machine config*: Works but doesn't integrate with clan's service instance model.
- *Flake app*: Loses systemd lifecycle management.

### 4. Guest tag: `cloud-hypervisor-guest`

**Choice**: A tag file that configures the guest-side NixOS:
- virtio kernel modules (virtio_pci, virtio_blk, virtio_net, virtio_console)
- systemd-in-initrd (`boot.initrd.systemd.enable = true`) for faster boot and better error handling
- systemd-networkd with DHCP on the virtio NIC
- Disable `systemd-networkd-wait-online.service` — upstream systemd bug [#29388](https://github.com/systemd/systemd/issues/29388) causes hangs in VMs
- serial console on ttyS0
- No bootloader (boot.loader.grub.enable = false, etc.)
- No unnecessary services (envfs disabled, no desktop packages)
- Automatic nix store GC to prevent the persistent disk image from filling up

Applied to the guest machine entry in `machines.ncl`.

### 4a. Cloud Hypervisor hardening flags

The host service always passes `--seccomp true` (seccomp sandbox) and `--watchdog` (hardware watchdog). These are low-cost security and reliability defaults that microvm.nix enables unconditionally.

### 4b. Multi-queue virtio for multi-vCPU guests

When the VM has more than 1 vCPU, the host service sets `num_queues=<vcpu>` on disk devices and `num_queues=<2*vcpu>` on network devices (rx + tx per vCPU). TAP interfaces are created with `vnet_hdr` mode for virtio-net checksum offloading, and `multi_queue` when vcpu > 1.

### 5. Initial image bootstrap

**Choice**: A nix derivation or script that:
1. Creates a raw disk image (e.g., 20GB)
2. Formats it ext4
3. Mounts it in a build environment
4. Runs `nixos-install --root /mnt --system <toplevel>` to populate `/nix/store` and create the initial system
5. Produces the image file

This runs once. After that, `clan machines update` deploys over SSH.

### 6. Networking: per-VM TAP with static DHCP reservations

**Choice**: Extend the existing `cloud-hypervisor-host` tag pattern. Each VM gets:
- A dedicated TAP interface (`tap-<vmname>`)
- A MAC address
- A dnsmasq DHCP reservation mapping MAC → IP

The host tag already does this for a single guest (tap0, 172.16.0.2). For multiple VMs, the clan service instance on the host creates additional TAP interfaces and dnsmasq config snippets.

### 7. Deploy target

**Choice**: Guest SSH is reachable at its DHCP-assigned IP on the TAP bridge. Deploy target in `machines.ncl` uses `root@172.16.0.X` or an iroh-ssh hostname if the guest gets an iroh-ssh instance.

For the first VM, reuse the existing 172.16.0.2 assignment.

## Risks / Trade-offs

- **[Kernel update requires VM restart]** → Direct kernel boot means the host controls which kernel runs. After a `clan machines update` that changes the kernel, the VM must be restarted. Document this; optionally add a post-deploy hook that restarts the VM service if the kernel path changed.
- **[Disk image size management]** → Fixed-size raw image. If the guest's `/nix/store` grows past the image size, builds fail. Mitigation: start with 40GB, enable `nix.gc.automatic` in the guest tag with aggressive settings (e.g., delete older than 7d), document resize procedure (`truncate` + `resize2fs`).
- **[First boot chicken-and-egg]** → The guest needs SSH keys before the first `clan machines update` can reach it. The bootstrap image must include the guest's SSH host key (from clan vars) and the deployer's authorized key. The bootstrap script handles this.
- **[TAP interface ordering]** → Multiple TAP interfaces need stable naming. Using `tap-<vmname>` naming convention avoids conflicts.
- **[Host disk I/O]** → Raw disk image on the host's filesystem. SSD-backed, so performance is adequate for dev use. Not suitable for heavy I/O workloads.
- **[Ungraceful shutdown = data loss]** → Without proper `ExecStop` using the API socket power-button endpoint, systemd sends SIGKILL. The ext4 image could be left dirty. Mitigated by the API-socket-based graceful shutdown plus a `TimeoutStopSec` long enough for the guest to flush (30s).
- **[No rollback mechanism]** → Unlike microvm.nix's runner-as-a-package with `current`/`booted` symlink dance, we don't have atomic deployment or rollback. Acceptable for v1 — the guest's NixOS generations provide rollback within the VM itself.
