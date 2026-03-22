## 1. Preparation

- [ ] 1.1 Back up `/data` contents from the 4TB drive (or confirm expendable)
- [ ] 1.2 Update `machines/britton-desktop/disko.nix` — swap disk IDs so `main` points to 4TB and `data` points to 2TB
- [ ] 1.3 Commit the disko.nix change (do not deploy yet)
- [ ] 1.4 Download NixOS minimal ISO and write to USB stick

## 2. Boot Live Environment

- [ ] 2.1 Boot britton-desktop from NixOS live USB
- [ ] 2.2 Identify both NVMe drives (`lsblk`, verify by-id symlinks match expected serials)

## 3. Partition 4TB Target Drive

- [ ] 3.1 Wipe existing partition table on 4TB drive (`sgdisk --zap-all`)
- [ ] 3.2 Create GPT partition table with: 1G ESP (EF00), 8G Linux swap (8200), remainder Linux filesystem (8300)
- [ ] 3.3 Format ESP as vfat (`mkfs.vfat -F32`), swap (`mkswap`), root as ext4 (`mkfs.ext4`)

## 4. Clone Filesystems

- [ ] 4.1 Mount 2TB source root and 4TB target root under `/mnt`
- [ ] 4.2 rsync root filesystem: `rsync -aAXH --info=progress2 --exclude={/dev,/proc,/sys,/tmp,/run,/mnt,/media,/lost+found} /mnt/source/ /mnt/target/`
- [ ] 4.3 Mount source and target ESP partitions, rsync ESP contents
- [ ] 4.4 Verify file counts and spot-check critical paths (`/etc/nixos`, `/nix/store` samples)

## 5. Bootloader and Config

- [ ] 5.1 Bind-mount `/dev`, `/proc`, `/sys`, `/run` into the target root
- [ ] 5.2 Mount target ESP at `/mnt/target/boot`
- [ ] 5.3 Chroot into target root and run `grub-install --target=x86_64-efi --efi-directory=/boot --boot-directory=/boot`
- [ ] 5.4 Run `nixos-rebuild boot` from chroot to regenerate GRUB config with correct UUIDs

## 6. Verify Boot from 4TB

- [ ] 6.1 Reboot, enter UEFI firmware and set 4TB NVMe as first boot device
- [ ] 6.2 Confirm GRUB loads and NixOS boots from 4TB root partition
- [ ] 6.3 Verify mounts: root on 4TB, no references to 2TB in active mounts (except possibly old `/data`)
- [ ] 6.4 Run basic smoke tests: networking, login, services running

## 7. Repurpose 2TB Drive

- [ ] 7.1 Wipe 2TB partition table (`sgdisk --zap-all`)
- [ ] 7.2 Create single GPT partition using 100% of disk, format as ext4
- [ ] 7.3 Mount at `/data`, verify read/write access

## 8. Finalize Configuration

- [ ] 8.1 Run `clan machines update britton-desktop` to apply the committed disko.nix with correct disk IDs
- [ ] 8.2 Reboot and confirm clean boot with both drives in final roles
- [ ] 8.3 Restore backed-up `/data` contents if applicable
