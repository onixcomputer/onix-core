## Context

The fleet has 5 NixOS machines on ext4, each with a single-partition disko layout (ESP + optional swap + ext4 root). No checksumming, no snapshots, no redundancy, no encryption. The two servers (`aspen1`, `aspen2`) are identical Framework Desktop AMD AI Max 300 boxes sitting on the same network — natural replication targets. The desktop (`britton-desktop`) has two NVMe drives (2TB + 4TB) that could be pooled or kept as separate datasets.

All machines use GRUB. No LUKS encryption exists anywhere — laptops are vulnerable to data theft if physically compromised. borgbackup handles offsite backups. Machines deploy via `clan machines update` over Tailscale, but ZFS migration requires physical reinstall since partition tables change.

Servers pin `linuxPackages_latest`, desktop pins `linuxPackages_6_18`. ZFS kernel module compatibility is a constraint.

Three machines already have initrd-ssh configured (`aspen1`, `aspen2`, `britton-desktop`) via the `initrd-ssh` tag, providing SSH on port 2222 in the initrd. This is the foundation for remote LUKS unlock.

## Goals / Non-Goals

**Goals:**
- LUKS2-encrypted ZFS root on all 5 x86_64 machines with checksumming and compression
- LUKS unlock via interactive passphrase on laptops, remote SSH unlock on servers/desktop
- Dataset hierarchy that separates system state from user data for targeted snapshot/restore
- Auto-scrub on all ZFS machines
- Auto-snapshots with retention policy via sanoid
- Cross-machine replication between aspen1↔aspen2 via syncoid
- Clean integration with the existing tag system and disko
- Migration runbook for each machine class (single-disk laptop, single-disk server, dual-disk desktop)

**Non-Goals:**
- ZFS native encryption (using LUKS under ZFS instead — simpler, better NixOS integration, encrypts all pool metadata)
- RAIDZ on any machine (no machine has 3+ data drives)
- Migrating `pine` (PineNote, custom aarch64 kernel), `utm-vm` (throwaway aarch64 VM), or `britton-air` (macOS)
- Replacing borgbackup — ZFS replication is local/LAN, borgbackup is offsite
- Impermanence / erase-on-boot patterns (can layer on later with ZFS snapshots but out of scope)

## Decisions

### 1. Dataset layout

**Choice:** Separate datasets for `/`, `/nix`, `/home`, `/var/log`, plus machine-specific data mounts.

**Why:** Different retention and snapshot policies per dataset. `/nix` is reproducible (no snapshots needed, high compression benefit). `/home` needs frequent snapshots with long retention. `/var/log` needs short retention. Root `/` is system state that changes on rebuild.

**Layout per machine:**
```
rpool/
├── root        → /          (mountpoint=legacy)
├── nix         → /nix       (mountpoint=legacy, compression=zstd)
├── home        → /home      (mountpoint=legacy, snapshots=frequent)
├── var-log     → /var/log   (mountpoint=legacy, snapshots=short-retention)
└── reserved    → none       (reservation=~5%, no mountpoint — free space buffer for CoW)
```

Desktop adds:
```
datapool/
└── data        → /data      (mountpoint=legacy, on 4TB drive)
```

**Alternative considered:** Single dataset for everything. Rejected because snapshot granularity matters — you don't want `/nix` bloating your snapshots with store paths that are trivially reproducible.

**Alternative considered:** ZFS native mountpoints (`mountpoint=` property) instead of legacy mounts. Rejected because disko and NixOS integrate better with `/etc/fstab` (legacy) mounts — avoids ordering issues with `zfs-mount.service`.

### 2. Pool naming

**Choice:** `rpool` for root pool, `datapool` for secondary drives.

**Why:** `rpool` is the ZFS convention for root pools. Keeps things predictable across machines.

### 3. Compression

**Choice:** `zstd` on all datasets. Override to `off` on datasets where compression hurts (none identified yet).

**Why:** `zstd` gives better compression than `lz4` with minimal CPU overhead on modern hardware. All machines have AMD CPUs with plenty of cores. The Nix store in particular compresses well (~30-40% space savings).

### 4. Swap handling

**Choice:** Keep swap as a dedicated GPT partition (zvol swap is not recommended). Laptops and desktop get 8GB swap partitions matching their current config. Servers get no swap (matching current config — they have 128GB RAM and use zram). Swap partitions are **not** inside the LUKS container — they're plain partitions. If swap encryption is needed later, a separate LUKS container or random-key swap encryption can be added.

**Why:** ZFS zvol swap can deadlock under memory pressure. A plain partition avoids this entirely. Putting swap inside the ZFS LUKS container means ZFS must be unlocked before swap activates, which complicates resume-from-hibernate. The existing zramSwap configuration from `ssd-optimization.nix` remains primary, so disk swap is rarely hit.

### 4a. LUKS encryption layer

**Choice:** LUKS2 on the ZFS partition of every target machine. The partition layout becomes: ESP (unencrypted vfat) → swap partition (unencrypted) → LUKS2 partition → ZFS pool on the opened LUKS device.

**Why LUKS under ZFS, not ZFS native encryption:**
- LUKS encrypts everything including ZFS metadata, pool structure, dataset names, and snapshot names. ZFS native encryption leaks metadata.
- LUKS is a single unlock point — one passphrase opens the entire pool. ZFS native encryption requires per-dataset key management.
- LUKS integrates with `systemd-cryptsetup` in the NixOS initrd, which already works with the `initrd-ssh` tag for remote unlock.
- disko has full LUKS2 support — the `luks` content type wraps any inner content type.
- syncoid replication works transparently — ZFS sends/receives plaintext data between already-unlocked pools. No `--raw` encrypted send complexity.

**Alternative considered:** ZFS native encryption. Rejected because it leaks dataset names and structure, requires `zfs load-key` per dataset (or key inheritance which is fragile), and `zfs send --raw` for encrypted replication is less flexible (can't incrementally replicate between pools with different keys without raw sends).

**LUKS parameters:**
- Format: LUKS2
- Cipher: `aes-xts-plain64` (hardware-accelerated on all target CPUs via AES-NI)
- Key derivation: `argon2id` (LUKS2 default, memory-hard)
- Key size: 512 bits (256-bit AES-XTS)

### 4b. LUKS unlock strategy

**Choice:** Two unlock paths depending on machine class:

1. **Laptops** (`britton-fw`, `bonsai`): Interactive passphrase prompt at the console during boot. User types passphrase on the physical keyboard. No initrd-ssh on these machines currently.

2. **Servers + Desktop** (`aspen1`, `aspen2`, `britton-desktop`): Remote unlock via SSH in initrd. These already have the `initrd-ssh` tag (SSH on port 2222 in initrd). After LUKS is added, `systemd-cryptsetup` presents the passphrase prompt over the SSH session. User SSHes to port 2222, types the passphrase, LUKS opens, ZFS imports, boot continues.

**Why:** Servers are headless — interactive console unlock requires physical access, which defeats the purpose. The initrd-ssh infrastructure already exists on these machines. Laptops always have a user present at boot.

**Future option:** Add `initrd-ssh` to laptops too, allowing remote unlock over Tailscale if the laptop is docked headless.

### 5. Kernel compatibility

**Choice:** Use `config.boot.zfs.package.latestCompatibleLinuxPackages` as the kernel for servers instead of `linuxPackages_latest`. Desktop keeps its pinned kernel if ZFS supports it, otherwise falls back to the same approach.

**Why:** `linuxPackages_latest` regularly breaks ZFS because the out-of-tree module lags behind kernel releases by days/weeks. `latestCompatibleLinuxPackages` is the NixOS-sanctioned way to track the newest kernel that ZFS actually builds against.

**Risk:** Servers currently need kernel 6.16.9+ for AMD Strix Halo unified memory. The ZFS-compatible kernel must meet this floor. If `latestCompatibleLinuxPackages` drops below 6.16.9, we pin explicitly.

### 6. Replication architecture

**Choice:** Unidirectional syncoid from `aspen2` → `aspen1`. aspen2 is the primary (has borgbackup + radicle), aspen1 is the replica.

**Why:** Both machines run identical hardware and similar workloads. aspen2 has the `backup` tag and radicle service, making it the natural primary. Bidirectional sync adds complexity without benefit — if aspen1 dies, nothing unique is lost.

**Schedule:** Every 6 hours via systemd timer. Syncs `/home` and `/data` datasets only (system datasets are reproducible via NixOS rebuild).

### 7. Snapshot policy (sanoid)

**Choice:**
| Dataset | Hourly | Daily | Weekly | Monthly |
|---------|--------|-------|--------|---------|
| `home`  | 24     | 30    | 4      | 6       |
| `var-log` | 0    | 7     | 0      | 0       |
| `root`  | 0      | 7     | 2      | 0       |
| `nix`   | 0      | 0     | 0      | 0       |

**Why:** `/home` is irreplaceable user data — aggressive retention. `/var/log` just needs a week of history for debugging. Root filesystem changes on NixOS rebuild and can be reconstructed. `/nix` is fully reproducible from the flake.

### 8. ARC memory tuning

**Choice:** Set `zfs_arc_max` to 50% of RAM on servers (64GB out of 128GB), 25% on laptops/desktop.

**Why:** Servers benefit from large caches for LLM model file reads. Laptops need RAM for desktop apps. The default (50% of total) is fine for servers but too aggressive for laptops with 32-64GB.

### 9. Boot configuration

**Choice:** Keep GRUB on all machines. No switch to systemd-boot.

**Why:** All machines already use GRUB. ZFS boot works with GRUB. Changing bootloader during a filesystem migration adds unnecessary risk.

### 10. Tag architecture

**Choice:** Single `zfs` tag in `inventory/tags/zfs.nix` for shared config (scrub, sanoid, ARC). Machine-specific disko layouts stay in `machines/<name>/disko.nix`. Replication config goes in a `zfs-replication` tag applied only to `aspen1` and `aspen2`.

**Why:** Follows the existing pattern — tags for shared behavior, machine dirs for hardware-specific config.

## Risks / Trade-offs

**[ZFS kernel module lag]** → `latestCompatibleLinuxPackages` handles this automatically. Monitor after kernel updates. If a critical kernel feature is needed (like the ttm memory params on servers), pin a specific version that's both ZFS-compatible and meets hardware requirements.

**[ARC memory pressure on laptops]** → Set `zfs_arc_max` conservatively (25% RAM). ZFS ARC is reclaimable under pressure, but applications may perceive slowness if ARC shrinks aggressively during heavy use.

**[Migration requires physical reinstall]** → No way around this. ext4→ZFS+LUKS requires repartitioning. Each machine needs: borgbackup full backup, boot from NixOS installer (USB or netboot), disko format (creates LUKS + ZFS), NixOS install, restore data from borgbackup. Plan for 1-2 hours per machine. LUKS formatting adds ~1 minute for key derivation.

**[LUKS passphrase management]** → Passphrases are set during `disko --mode disko` and must be entered at every boot. No automated unlock (that would defeat the purpose). For servers, forgetting the passphrase means physical access is required. Mitigate by storing recovery keys in a password manager and/or printing backup codes.

**[LUKS + suspend-to-disk on laptops]** → Hibernate requires the swap partition to be encrypted too (otherwise RAM contents leak to unencrypted swap). Out of scope — laptops use suspend-to-RAM, and zram handles swap pressure. If hibernate is needed later, add a LUKS-encrypted swap partition or use random-key swap encryption.

**[Desktop dual-disk: separate pools vs mirror]** → Using separate pools (rpool on 2TB, datapool on 4TB). A mirror would require matching sizes and waste 2TB of the 4TB drive. Separate pools give full capacity at the cost of no redundancy on root.

**[Syncoid network bandwidth]** → Initial sync between aspen1↔aspen2 will transfer the full dataset. Subsequent syncs are incremental (only changed blocks). On a LAN or Thunderbolt link (both machines have `thunderbolt-link` tag), this is fast.

**[Rollback: no going back to ext4 easily]** → Once ZFS is on, switching back means another reinstall. Mitigated by doing the desktop last (most complex, most to lose) after validating on the VM or a server first.

## Migration Plan

### Phase 1: Preparation (no downtime)
1. Add `zfs` tag infrastructure (tag file, contracts, disko templates with LUKS)
2. Build all 5 machine configs locally to verify ZFS+LUKS support compiles
3. Verify `latestCompatibleLinuxPackages` meets kernel floor for servers
4. Generate `networking.hostId` for each machine
5. Choose LUKS passphrases for each machine (store in password manager)
6. Verify initrd-ssh LUKS unlock works in a VM test build before touching real hardware

### Phase 2: Server migration (aspen1 first)
1. Full borgbackup of aspen1
2. Boot NixOS installer via USB or initrd-ssh
3. `disko --mode disko` to partition, create LUKS container, and create ZFS pool inside it
4. Set LUKS passphrase during disko formatting
5. `nixos-install --flake .#aspen1`
6. Reboot — verify LUKS unlock via initrd-ssh (port 2222), then ZFS import and boot
7. Restore service data from borgbackup
8. Validate: scrub, snapshot, services running, LUKS unlock on reboot
9. Repeat for aspen2
10. Configure syncoid replication aspen2→aspen1
11. Validate replication

### Phase 3: Laptop migration (bonsai first — less critical)
1. Full borgbackup of bonsai
2. Boot NixOS installer USB
3. disko with LUKS + ZFS, set passphrase
4. nixos-install
5. Reboot — verify LUKS passphrase prompt at console, then ZFS import and boot
6. Restore /home from borgbackup
7. Validate: sanoid snapshots, scrub, laptop functionality
8. Repeat for britton-fw

### Phase 4: Desktop migration (last — most complex)
1. Full borgbackup of britton-desktop
2. Boot NixOS installer USB
3. disko formats both drives (LUKS+rpool on 2TB, LUKS+datapool on 4TB)
4. Set LUKS passphrases (same or different for each drive)
5. nixos-install
6. Reboot — verify LUKS unlock via initrd-ssh for both containers, then ZFS import and boot
7. Restore /home and /data from borgbackup
8. Validate: dual-pool health, snapshots, services, LUKS unlock on reboot

### Rollback
If ZFS+LUKS causes problems on any machine: boot installer, reformat to ext4 using old disko.nix (kept in git history), reinstall, restore from borgbackup. Data safety depends entirely on borgbackup being current before migration.

## Open Questions

1. **Desktop pool topology:** Should the 4TB drive be a separate `datapool` or should both drives form a single pool with different vdevs? Separate pools is simpler but means no cross-drive redundancy for root.
2. **Sanoid vs nixos-managed snapshots:** NixOS has `services.zfs.autoSnapshot` built-in. Sanoid is more flexible. Which to use?
3. **Syncoid authentication:** How does syncoid SSH between aspen1↔aspen2? Dedicated SSH key via clan vars, or reuse existing Tailscale connectivity?
4. **ARC tuning per machine class:** Should ARC limits be in the shared `zfs` tag with per-class overrides, or in each machine's configuration.nix?
5. **LUKS passphrase policy:** Same passphrase across all machines, or unique per machine? Unique is more secure but more to remember/manage.
6. **Desktop dual-LUKS:** Should both drives on britton-desktop share the same passphrase (single prompt unlocks both) or have separate passphrases? Same is convenient, separate limits blast radius.
7. **Add initrd-ssh to laptops?** Laptops currently lack the `initrd-ssh` tag. Adding it would allow remote LUKS unlock when docked. Worth doing now or later?
