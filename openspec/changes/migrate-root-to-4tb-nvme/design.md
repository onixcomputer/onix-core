## Context

britton-desktop runs NixOS from a 2TB Samsung 9100 PRO NVMe (ESP + swap + root). A 4TB Samsung 9100 PRO NVMe holds a single ext4 `/data` partition. The goal is to make the 4TB drive the new root and repurpose the 2TB as `/data`.

The machine uses GRUB with EFI, disko for declarative partitioning, and clan-core for deployment. The `destroy = false` flag on both disks in disko.nix means disko won't wipe drives on rebuild — partition management during migration is manual.

## Goals / Non-Goals

**Goals:**
- Move root to the 4TB drive with zero data loss
- Machine boots from 4TB drive after migration
- 2TB drive becomes the new `/data` mount
- disko.nix reflects the new layout so future `clan machines update` runs are correct

**Non-Goals:**
- Changing filesystem type (staying with ext4)
- Switching bootloader (staying with GRUB)
- Setting up RAID or redundancy
- Migrating while the system is live on the same root (we'll use a NixOS live USB or boot from an alternate drive)

## Decisions

### Clone method: rsync over block-level dd
**Decision**: Use `rsync -aAXH --info=progress2` to copy filesystems rather than `dd`.

**Rationale**: The target drive is 4TB vs 2TB source — a block-level clone would need partition resizing afterward. rsync copies files directly into a pre-sized filesystem, handles the size difference naturally, and allows excluding pseudo-filesystems. dd would also copy the swap partition unnecessarily.

**Alternatives considered**: `dd` + `resize2fs` — more steps, slower (copies free space), risk of GPT/partition table confusion on differently-sized drives.

### Migration environment: NixOS live USB
**Decision**: Boot from a NixOS live USB to perform the migration.

**Rationale**: Can't safely rsync a running root filesystem — open files, changing state, mounted pseudo-filesystems. A live environment gives clean read access to the source and write access to the target. NixOS ISO has all needed tools (rsync, parted, mkfs, grub-install).

**Alternatives considered**: `--exclude` live paths and rsync while running — risky, inconsistent state possible.

### Partition creation: manual gdisk/parted, not disko
**Decision**: Create partitions on the 4TB target manually during migration, then update disko.nix to match.

**Rationale**: disko with `destroy = false` won't create partitions on an existing drive. The migration is a one-time operation; disko.nix just needs to describe the result for future rebuilds.

### Bootloader: grub-install to new ESP
**Decision**: Run `grub-install --target=x86_64-efi --efi-directory=/mnt/boot --boot-directory=/mnt/boot` after cloning, then `nixos-rebuild boot` from chroot to generate the correct GRUB config.

**Rationale**: Copying ESP files alone may leave stale UUIDs in grub.cfg. A fresh grub-install + config generation from the actual NixOS system ensures correct references to the new root partition UUID.

## Risks / Trade-offs

[Data loss on /data] → Back up or confirm expendable before starting. The current `/data` on the 4TB drive gets wiped during repartitioning.

[Wrong UUIDs in fstab/grub after clone] → `nixos-rebuild boot` regenerates all mount configs from disko.nix. Run it from chroot before rebooting.

[Boot order in UEFI firmware] → May need one-time BIOS change to prioritize the 4TB drive's boot entry. Not automatable.

[Machine unreachable if migration fails] → Keep the 2TB drive intact until the 4TB boots successfully. Don't reformat the 2TB until verified.

## Migration Plan

1. Back up `/data` if needed
2. Commit updated disko.nix (swap disk IDs) — don't deploy yet
3. Boot NixOS live USB
4. Partition 4TB drive: 1G ESP, 8G swap, rest ext4
5. Mount source (2TB) and target (4TB) partitions
6. rsync root and ESP contents
7. Update fstab/GRUB via chroot + `nixos-rebuild boot`
8. Reboot into 4TB drive, verify
9. Format 2TB as single ext4 `/data`
10. Run `clan machines update britton-desktop` to finalize config
