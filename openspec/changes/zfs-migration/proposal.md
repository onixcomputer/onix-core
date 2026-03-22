## Why

Every machine in the fleet runs ext4 on plain GPT partitions with no checksumming, no snapshots, no filesystem-level redundancy, and no disk encryption. The desktop has two NVMe drives that could be mirrored but aren't. The servers (aspen1, aspen2) run LLM workloads with large model files that can't be verified against bit rot. Laptops carry sensitive data on unencrypted disks — a stolen Framework laptop means full data exposure. Backups go through borgbackup but there's no way to do cheap incremental replication between the two identical server boxes. ZFS + LUKS solves all of this — checksumming, snapshots, native compression, send/receive replication, and full-disk encryption — with 20+ years of production use and first-class NixOS/disko support.

## What Changes

- Replace ext4 root filesystems with LUKS-encrypted ZFS pools on 5 machines: `britton-desktop`, `britton-fw`, `bonsai`, `aspen1`, `aspen2`
- Add LUKS2 encryption on the ZFS partition of every target machine, with ZFS pools created on top of the unlocked LUKS device
- Add ZFS dataset layout with separate datasets for `/`, `/nix`, `/home`, `/var/log`, and machine-specific data paths
- Add `networking.hostId` to each machine (ZFS requirement for pool import)
- Add automatic ZFS scrubbing and snapshot services
- Add ZFS send/receive replication between `aspen1` and `aspen2`
- Add a `zfs` tag for shared ZFS configuration (auto-scrub, snapshot policy, ARC tuning)
- Create a ZFS-specific disko template for single-disk and multi-disk layouts with LUKS
- Integrate LUKS unlock with existing initrd-ssh infrastructure on `aspen1`, `aspen2`, and `britton-desktop` for remote unlock
- Configure interactive LUKS passphrase prompts on laptops (`britton-fw`, `bonsai`) at boot
- Adjust kernel configuration: `aspen1`/`aspen2` use `linuxPackages_latest` and `britton-desktop` uses `linuxPackages_6_18` — both need ZFS module compatibility verification
- Keep `pine`, `utm-vm`, and `britton-air` on their current filesystems (PineNote has a custom kernel, the VM is minimal, macOS isn't relevant)
- Keep borgbackup operational — ZFS snapshots complement it, don't replace it

## Capabilities

### New Capabilities

- `zfs-disko-layouts`: Disko-based ZFS pool and dataset definitions for single-disk (laptops, servers) and multi-disk (desktop) machines, including ESP, swap, LUKS encryption layer, and dataset hierarchy
- `zfs-base-config`: Shared ZFS NixOS configuration via a `zfs` tag — hostId management, auto-scrub, ARC tuning, kernel compatibility, boot support
- `zfs-snapshots`: Automated ZFS snapshot policy using sanoid — retention rules per dataset, integration with the existing tag system
- `zfs-replication`: ZFS send/receive replication between aspen1 and aspen2 using syncoid, running on a schedule via systemd timers
- `luks-encryption`: LUKS2 full-disk encryption on all ZFS machines — passphrase-based unlock on laptops, initrd-ssh remote unlock on servers/desktop, disko integration, clan vars for LUKS key management
- `zfs-migration-runbook`: Per-machine migration procedure — backup, reinstall, restore workflow since ext4→ZFS+LUKS requires a fresh partition table

### Modified Capabilities

_(none — no existing specs are affected)_

## Impact

- **Disk layouts**: Every disko.nix for the 5 target machines gets rewritten. Destructive — requires reinstall.
- **Boot configuration**: GRUB stays but needs `boot.supportedFilesystems = ["zfs"]` and ZFS-specific options.
- **Kernel packages**: `linuxPackages_latest` on servers may lag behind ZFS module builds. May need to pin to `linuxPackages_6_x` or use `zfs.latestCompatibleLinuxPackages`.
- **Tags**: New `zfs` tag added to `inventory/core/machines.ncl` for the 5 target machines. New tag file at `inventory/tags/zfs.nix`.
- **Contracts**: `contracts.ncl` needs the `zfs` tag added to the valid tag list.
- **Secrets**: LUKS passphrase/keyfile management via clan vars. Machines with `initrd-ssh` (aspen1, aspen2, britton-desktop) get remote unlock capability. Laptops use interactive passphrase at boot.
- **Initrd**: The existing `initrd-ssh.nix` tag already provides SSH in initrd on port 2222. LUKS unlock integrates with this — `systemd-cryptsetup` prompts via SSH. Laptops without initrd-ssh get the standard console passphrase prompt.
- **Backup**: borgbackup continues unchanged. ZFS snapshots give local point-in-time recovery; syncoid gives cross-machine replication. Neither replaces offsite borgbackup.
- **Deployment**: Each machine migration is a physical reinstall — can't be done via `clan machines update`. Requires physical or initrd-ssh access, borgbackup restore of /home and service data.
