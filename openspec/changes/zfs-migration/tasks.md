## 1. Tag Infrastructure

- [ ] 1.1 Add `zfs` and `zfs-replication` to the valid tag list in `inventory/core/contracts.ncl`
- [ ] 1.2 Create `inventory/tags/zfs.nix` with shared ZFS config: `boot.supportedFilesystems`, auto-scrub, sanoid snapshot policy, ARC memory limit (parameterized by machine class)
- [ ] 1.3 Create `inventory/tags/zfs-replication.nix` with syncoid service config (aspen2→aspen1 over Tailscale)
- [ ] 1.4 Add `zfs` tag to all 5 target machines in `inventory/core/machines.ncl`
- [ ] 1.5 Add `zfs-replication` tag to aspen1 and aspen2 in `inventory/core/machines.ncl`

## 2. Host IDs

- [ ] 2.1 Generate unique 8-character hex `networking.hostId` for each of the 5 target machines
- [ ] 2.2 Add `networking.hostId` to each machine's `configuration.nix`

## 3. Kernel Compatibility

- [ ] 3.1 Switch aspen1 and aspen2 from `linuxPackages_latest` to `config.boot.zfs.package.latestCompatibleLinuxPackages` in their `configuration.nix`
- [ ] 3.2 Add an assertion that the resolved kernel version is >= 6.16.9 for Strix Halo unified memory support
- [ ] 3.3 Verify britton-desktop's pinned `linuxPackages_6_18` is ZFS-compatible; if not, switch to `latestCompatibleLinuxPackages`

## 4. Disko Layouts — Servers (Single-Disk, LUKS, No Swap)

- [ ] 4.1 Rewrite `machines/aspen1/disko.nix`: GPT → 500MB ESP (vfat) → LUKS2 partition (`cryptroot`) → ZFS `rpool` with datasets (root, nix, home, var-log, reserved)
- [ ] 4.2 Rewrite `machines/aspen2/disko.nix`: same layout as aspen1 with aspen2's disk by-id path
- [ ] 4.3 Set pool-level `compression=zstd`, all datasets `mountpoint=legacy`, reserved dataset with 5% reservation

## 5. Disko Layouts — Laptops (Single-Disk, LUKS, Swap)

- [ ] 5.1 Rewrite `machines/britton-fw/disko.nix`: GPT → 1GB ESP → 8GB swap → LUKS2 partition (`cryptroot`) → ZFS `rpool` with datasets
- [ ] 5.2 Rewrite `machines/bonsai/disko.nix`: same layout as britton-fw with bonsai's disk by-id path
- [ ] 5.3 Set pool-level `compression=zstd`, all datasets `mountpoint=legacy`, reserved dataset with 5% reservation

## 6. Disko Layout — Desktop (Dual-Disk, Dual-LUKS)

- [ ] 6.1 Rewrite `machines/britton-desktop/disko.nix`: Drive 1 (2TB Samsung 9100): GPT → 1GB ESP → 8GB swap → LUKS2 (`cryptroot`) → ZFS `rpool` with datasets
- [ ] 6.2 Add Drive 2 (4TB Samsung 9100): GPT → LUKS2 (`cryptdata`) → ZFS `datapool` with `data` dataset mounted at `/data`
- [ ] 6.3 Set pool-level `compression=zstd` on both pools, all datasets `mountpoint=legacy`

## 7. LUKS Boot Integration

- [ ] 7.1 Add `boot.initrd.luks.devices.cryptroot` to the `zfs` tag referencing the LUKS partition by UUID (or configure per-machine in disko output)
- [ ] 7.2 Add `boot.initrd.luks.devices.cryptdata` in britton-desktop's `configuration.nix` for the second drive
- [ ] 7.3 Verify initrd-ssh LUKS unlock flow works on machines with the `initrd-ssh` tag (aspen1, aspen2, britton-desktop) — SSH to port 2222, enter passphrase, boot continues
- [ ] 7.4 Verify console passphrase prompt works on laptops without `initrd-ssh` (britton-fw, bonsai)

## 8. Sanoid Snapshot Policy

- [ ] 8.1 Add sanoid configuration to `inventory/tags/zfs.nix` with per-dataset retention: home (24h/30d/4w/6m), root (7d/2w), var-log (7d), nix (none)
- [ ] 8.2 Add `datapool/data` snapshot policy for britton-desktop (24h/30d/4w/6m) in its `configuration.nix`

## 9. Syncoid Replication

- [ ] 9.1 Create clan vars generator for syncoid SSH key pair on aspen2 (`clan.core.vars.generators.syncoid-replication`)
- [ ] 9.2 Add syncoid public key to authorized_keys on aspen1 for a dedicated syncoid receive user
- [ ] 9.3 Configure syncoid systemd service and timer in `inventory/tags/zfs-replication.nix`: replicate `rpool/home` from aspen2 to aspen1 via `iroh-aspen1` every 6 hours
- [ ] 9.4 Configure ZFS delegation on aspen1 to allow the syncoid receive user to create datasets/snapshots

## 10. Build Verification

- [ ] 10.1 Run `build aspen1` and `build aspen2` — verify LUKS+ZFS+sanoid+syncoid configs compile
- [ ] 10.2 Run `build britton-fw` and `build bonsai` — verify LUKS+ZFS+sanoid configs compile
- [ ] 10.3 Run `build britton-desktop` — verify dual-LUKS+dual-ZFS+sanoid config compiles
- [ ] 10.4 Run `nix fmt` and `validate` to pass pre-commit checks

## 11. Migration — aspen1 (Server 1)

- [ ] 11.1 Record LUKS passphrase for aspen1 in password manager
- [ ] 11.2 Run full borgbackup of aspen1, verify with `borg list`
- [ ] 11.3 Boot NixOS installer USB on aspen1
- [ ] 11.4 Run `disko --mode disko --flake .#aspen1` — set LUKS passphrase when prompted
- [ ] 11.5 Run `nixos-install --flake .#aspen1 --no-root-password`
- [ ] 11.6 Reboot, verify LUKS unlock via initrd-ssh (port 2222), verify ZFS pool imports and system reaches login
- [ ] 11.7 Restore service data from borgbackup
- [ ] 11.8 Validate: `zpool status`, `zpool scrub rpool`, `systemctl --failed`, borgbackup test run

## 12. Migration — aspen2 (Server 2)

- [ ] 12.1 Record LUKS passphrase for aspen2 in password manager
- [ ] 12.2 Run full borgbackup of aspen2, verify with `borg list`
- [ ] 12.3 Boot NixOS installer USB on aspen2
- [ ] 12.4 Run `disko --mode disko --flake .#aspen2` — set LUKS passphrase when prompted
- [ ] 12.5 Run `nixos-install --flake .#aspen2 --no-root-password`
- [ ] 12.6 Reboot, verify LUKS unlock via initrd-ssh, verify ZFS pool imports and system boots
- [ ] 12.7 Restore service data from borgbackup
- [ ] 12.8 Validate: `zpool status`, `zpool scrub rpool`, `systemctl --failed`, borgbackup test run
- [ ] 12.9 Start syncoid replication (aspen2→aspen1), verify initial full send completes
- [ ] 12.10 Wait 6 hours, verify incremental replication runs automatically

## 13. Migration — bonsai (Laptop 2)

- [ ] 13.1 Record LUKS passphrase for bonsai in password manager
- [ ] 13.2 Run full borgbackup of bonsai, verify with `borg list`
- [ ] 13.3 Boot NixOS installer USB on bonsai
- [ ] 13.4 Run `disko --mode disko --flake .#bonsai` — set LUKS passphrase when prompted
- [ ] 13.5 Run `nixos-install --flake .#bonsai --no-root-password`
- [ ] 13.6 Reboot, verify LUKS passphrase prompt on console, verify ZFS pool imports and system boots
- [ ] 13.7 Restore /home from borgbackup
- [ ] 13.8 Validate: `zpool status`, sanoid snapshots appear within 1 hour, `systemctl --failed`, laptop suspend/resume works

## 14. Migration — britton-fw (Laptop 1)

- [ ] 14.1 Record LUKS passphrase for britton-fw in password manager
- [ ] 14.2 Run full borgbackup of britton-fw, verify with `borg list`
- [ ] 14.3 Boot NixOS installer USB on britton-fw
- [ ] 14.4 Run `disko --mode disko --flake .#britton-fw` — set LUKS passphrase when prompted
- [ ] 14.5 Run `nixos-install --flake .#britton-fw --no-root-password`
- [ ] 14.6 Reboot, verify LUKS passphrase prompt on console, verify ZFS pool imports and system boots
- [ ] 14.7 Restore /home from borgbackup
- [ ] 14.8 Validate: `zpool status`, sanoid snapshots, `systemctl --failed`, fingerprint reader works, laptop suspend/resume works

## 15. Migration — britton-desktop (Desktop)

- [ ] 15.1 Record LUKS passphrases for britton-desktop (both drives) in password manager
- [ ] 15.2 Run full borgbackup of britton-desktop (including /data), verify with `borg list`
- [ ] 15.3 Boot NixOS installer USB on britton-desktop
- [ ] 15.4 Run `disko --mode disko --flake .#britton-desktop` — set LUKS passphrases for both drives
- [ ] 15.5 Run `nixos-install --flake .#britton-desktop --no-root-password`
- [ ] 15.6 Reboot, verify LUKS unlock via initrd-ssh for both `cryptroot` and `cryptdata`, verify both ZFS pools import
- [ ] 15.7 Restore /home and /data from borgbackup
- [ ] 15.8 Validate: `zpool status rpool`, `zpool status datapool`, sanoid snapshots on both pools, `systemctl --failed`, DisplayLink works, GPU passthrough works

## 16. Post-Migration Cleanup

- [ ] 16.1 Verify borgbackup runs successfully on all 5 machines against the new LUKS+ZFS filesystems
- [ ] 16.2 Verify syncoid replication has completed at least 2 incremental cycles between aspen2→aspen1
- [ ] 16.3 Run `zpool scrub` on all pools across all machines, verify zero checksum errors
- [ ] 16.4 Commit all disko.nix, configuration.nix, tag, and contract changes to git
- [ ] 16.5 Update CLAUDE.md to document LUKS+ZFS architecture and LUKS unlock procedures
