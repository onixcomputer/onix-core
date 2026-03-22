## ADDED Requirements

### Requirement: LUKS initrd integration
All ZFS machines SHALL configure `boot.initrd.luks.devices` for their LUKS containers so that `systemd-cryptsetup` handles unlock during early boot, before ZFS pool import.

#### Scenario: Initrd LUKS device registration
- **WHEN** the NixOS configuration builds for a ZFS machine
- **THEN** `boot.initrd.luks.devices.cryptroot` is defined with the correct underlying device UUID

#### Scenario: Desktop dual-LUKS initrd
- **WHEN** britton-desktop builds
- **THEN** both `boot.initrd.luks.devices.cryptroot` and `boot.initrd.luks.devices.cryptdata` are defined

### Requirement: Interactive passphrase unlock on laptops
Laptops (britton-fw, bonsai) SHALL prompt for the LUKS passphrase on the physical console during boot. The prompt SHALL appear after GRUB loads the kernel/initrd and before ZFS pool import.

#### Scenario: Laptop cold boot
- **WHEN** britton-fw powers on and GRUB loads the kernel
- **THEN** the initrd displays a passphrase prompt on the console, and boot proceeds only after the correct passphrase is entered

#### Scenario: Wrong passphrase on laptop
- **WHEN** the user enters an incorrect passphrase
- **THEN** the prompt re-appears (up to 3 attempts before dropping to emergency shell)

### Requirement: Remote SSH unlock on servers and desktop
Machines with the `initrd-ssh` tag (aspen1, aspen2, britton-desktop) SHALL support LUKS unlock via SSH in the initrd. The existing initrd-ssh infrastructure (port 2222, clan vars host keys) SHALL be reused.

#### Scenario: Remote server unlock
- **WHEN** aspen1 boots and reaches the initrd
- **THEN** SSH is available on port 2222, and connecting to it presents the `systemd-cryptsetup` passphrase prompt which unlocks LUKS and allows boot to continue

#### Scenario: Remote desktop unlock
- **WHEN** britton-desktop boots and reaches the initrd
- **THEN** SSH on port 2222 accepts the passphrase for both `cryptroot` and `cryptdata` LUKS containers

#### Scenario: Unlock over Tailscale
- **WHEN** a server needs LUKS unlock and Tailscale is not yet running (pre-boot)
- **THEN** the initrd network stack provides a DHCP or static IP on the physical interface, and SSH is reachable on the LAN at port 2222

### Requirement: Boot continues after LUKS unlock
After all LUKS containers are unlocked, the boot process SHALL automatically import ZFS pools and continue to multi-user target without further manual intervention.

#### Scenario: Automated ZFS import after unlock
- **WHEN** the LUKS passphrase is accepted and `/dev/mapper/cryptroot` appears
- **THEN** `zpool import rpool` happens automatically, datasets are mounted, and the system reaches the login prompt

### Requirement: LUKS keyslot management
Each LUKS container SHALL have at least one passphrase keyslot. A second keyslot MAY be added later for a recovery key or hardware token (YubiKey). The disko configuration SHALL create the first keyslot during formatting.

#### Scenario: Passphrase set during disko
- **WHEN** `disko --mode disko` runs and creates the LUKS partition
- **THEN** the user is prompted to set the LUKS passphrase, which is stored in keyslot 0

#### Scenario: Recovery key addition (future)
- **WHEN** an admin runs `cryptsetup luksAddKey /dev/disk/by-partlabel/<partition>`
- **THEN** a second keyslot is added without affecting the primary passphrase

### Requirement: LUKS container in fstab/crypttab
The NixOS configuration SHALL generate `/etc/crypttab` entries (via `boot.initrd.luks.devices`) for all LUKS containers, ensuring they are opened at boot and closed at shutdown.

#### Scenario: Crypttab generation
- **WHEN** `nixos-rebuild switch` runs
- **THEN** `/etc/crypttab` contains entries for `cryptroot` (and `cryptdata` on desktop) mapping to the correct partition UUIDs

### Requirement: LUKS does not encrypt swap
Swap partitions SHALL remain outside the LUKS container. They are unencrypted plain partitions. This avoids ZFS deadlock issues and simplifies the boot sequence.

#### Scenario: Swap partition independence
- **WHEN** the system boots and LUKS has not yet been unlocked
- **THEN** the swap partition is already available (it does not depend on LUKS)

### Requirement: No automated LUKS unlock
LUKS containers SHALL NOT use keyfiles, TPM auto-unlock, or Clevis/Tang for automated unlock. Every boot SHALL require a human to enter the passphrase (interactively or via SSH).

#### Scenario: Reboot requires human intervention
- **WHEN** a machine reboots (planned or crash)
- **THEN** it waits at the LUKS passphrase prompt until a human provides the passphrase — it does not auto-unlock
