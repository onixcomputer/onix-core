## ADDED Requirements

### Requirement: Pre-migration backup verification
Before migrating any machine, a full borgbackup SHALL be completed and verified. The migration procedure SHALL NOT proceed without confirming the backup exists and contains `/home` and any machine-specific data paths.

#### Scenario: Backup verification before server migration
- **WHEN** preparing to migrate aspen1
- **THEN** `borg list` shows a recent backup archive containing `/home` and service data directories

#### Scenario: Backup verification before desktop migration
- **WHEN** preparing to migrate britton-desktop
- **THEN** `borg list` shows a recent backup archive containing `/home` and `/data`

### Requirement: Migration order
Machines SHALL be migrated in this order: aspen1, aspen2, bonsai, britton-fw, britton-desktop. Servers first (least user-facing disruption, validates LUKS+ZFS config including remote unlock), then the secondary laptop, then the primary laptop, then the desktop (most complex, dual-disk, dual-LUKS).

#### Scenario: Server-first validation
- **WHEN** aspen1 migration completes
- **THEN** ZFS pool health, scrub, sanoid snapshots, and LUKS remote unlock via initrd-ssh are validated before proceeding to aspen2

#### Scenario: Desktop migrated last
- **WHEN** all other machines are on LUKS+ZFS and stable
- **THEN** britton-desktop migration proceeds with confidence from prior machine validations

### Requirement: NixOS installer boot
Each migration SHALL boot the target machine from a NixOS installer (USB or network boot). The installer SHALL have ZFS and cryptsetup support, and access to the onix-core flake.

#### Scenario: USB installer boot
- **WHEN** the machine boots from NixOS installer USB
- **THEN** `zpool`, `zfs`, and `cryptsetup` commands are available, and the flake repo can be cloned or mounted

### Requirement: Disko partition, encrypt, and format
The migration SHALL use `disko --mode disko --flake .#<machine-name>` to partition, create LUKS containers, and create ZFS pools/datasets on the target disk(s). This destroys all existing data on the disk. The user SHALL be prompted to set the LUKS passphrase during this step.

#### Scenario: Disko formats single-disk server with LUKS
- **WHEN** `disko --mode disko --flake .#aspen1` runs
- **THEN** the existing ext4 partitions are destroyed, GPT is created with ESP + LUKS2 partition, the LUKS container is opened as `/dev/mapper/cryptroot`, and `rpool` with all datasets is created inside it

#### Scenario: Disko formats dual-disk desktop with LUKS
- **WHEN** `disko --mode disko --flake .#britton-desktop` runs
- **THEN** both drives get LUKS2 partitions, opened as `/dev/mapper/cryptroot` and `/dev/mapper/cryptdata`, with `rpool` and `datapool` created inside them

### Requirement: NixOS install from flake
After disko formatting, `nixos-install --flake .#<machine-name> --no-root-password` SHALL install the system from the onix-core flake.

#### Scenario: Flake-based install
- **WHEN** `nixos-install --flake .#aspen1 --no-root-password` completes
- **THEN** the machine boots into the configured NixOS system with LUKS-encrypted ZFS root

### Requirement: First reboot LUKS unlock verification
After NixOS install, the first reboot SHALL verify that LUKS unlock works correctly — via console passphrase on laptops, via initrd-ssh on servers/desktop.

#### Scenario: Server first-boot remote unlock
- **WHEN** aspen1 reboots after nixos-install
- **THEN** SSH on port 2222 is reachable, passphrase entry unlocks LUKS, ZFS imports, and the system reaches multi-user target

#### Scenario: Laptop first-boot console unlock
- **WHEN** bonsai reboots after nixos-install
- **THEN** the console displays a LUKS passphrase prompt, correct entry unlocks LUKS, ZFS imports, and the system reaches the login prompt

### Requirement: Data restoration from borgbackup
After NixOS install and successful LUKS unlock verification, `/home` and machine-specific data paths SHALL be restored from the most recent borgbackup archive.

#### Scenario: Home directory restore
- **WHEN** `borg extract` restores `/home` on the newly installed machine
- **THEN** user home directories contain their previous files, dotfiles, and application state

#### Scenario: Desktop data restore
- **WHEN** britton-desktop restores from borgbackup
- **THEN** both `/home` (from rpool) and `/data` (from datapool) contain their previous contents

### Requirement: Post-migration validation
After each migration, the following SHALL be verified: LUKS unlock works on reboot, ZFS pool health (`zpool status`), scrub passes clean, sanoid creates snapshots, all systemd services start, SSH access works, borgbackup runs successfully against the new filesystem.

#### Scenario: Pool health check
- **WHEN** migration completes and machine reboots (with LUKS unlock)
- **THEN** `zpool status rpool` shows ONLINE state with no errors

#### Scenario: LUKS unlock on second reboot
- **WHEN** the machine reboots a second time after migration
- **THEN** LUKS unlock succeeds via the same method (console or SSH) confirming the configuration is persistent

#### Scenario: Sanoid operational
- **WHEN** one hour passes after migration
- **THEN** `zfs list -t snapshot` shows at least one sanoid-created snapshot for `rpool/home`

#### Scenario: Services healthy
- **WHEN** the machine has booted on LUKS+ZFS
- **THEN** `systemctl --failed` shows no failed units related to storage, mount, LUKS, or ZFS

### Requirement: LUKS passphrase documentation
The LUKS passphrase for each machine SHALL be recorded in the team's password manager before migration begins. The migration SHALL NOT proceed without confirming the passphrase is stored.

#### Scenario: Passphrase recorded
- **WHEN** preparing to migrate any machine
- **THEN** the chosen LUKS passphrase is stored in the password manager under a clear entry name identifying the machine
