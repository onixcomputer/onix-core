## ADDED Requirements

### Requirement: Partition layout on 4TB target drive
The 4TB NVMe (`nvme-Samsung_SSD_9100_PRO_4TB_S7YANJ0Y308565Y`) SHALL be repartitioned with a GPT table containing: 1G ESP (EF00, vfat), 8G swap, and the remaining space as ext4 root.

#### Scenario: Fresh partition table on 4TB drive
- **WHEN** the migration partition step runs against the 4TB drive
- **THEN** the drive has exactly three partitions: a 1G vfat ESP, an 8G swap, and an ext4 root consuming the rest of the disk

### Requirement: Data cloned from 2TB to 4TB
The root filesystem contents from the 2TB NVMe SHALL be copied to the 4TB NVMe's root partition preserving ownership, permissions, timestamps, extended attributes, and hard links.

#### Scenario: Filesystem copy completes without data loss
- **WHEN** the clone step finishes
- **THEN** every file and directory from the 2TB root partition exists on the 4TB root partition with identical content, ownership, permissions, and timestamps

#### Scenario: ESP contents copied
- **WHEN** the clone step finishes
- **THEN** the 4TB ESP contains the same bootloader files as the 2TB ESP

### Requirement: Bootloader installed on new ESP
GRUB SHALL be installed to the 4TB drive's ESP so the machine boots from the 4TB drive without manual BIOS intervention (beyond a one-time boot-order change if needed).

#### Scenario: GRUB installed and bootable
- **WHEN** the machine is powered on with boot priority set to the 4TB NVMe
- **THEN** GRUB loads from the 4TB ESP and boots NixOS from the 4TB root partition

### Requirement: Disko config updated
`machines/britton-desktop/disko.nix` SHALL swap the disk IDs so `main` references the 4TB NVMe and `data` references the 2TB NVMe. The `data` disk partition layout SHALL be a single ext4 partition using 100% of the disk.

#### Scenario: Disko main points to 4TB
- **WHEN** `disko.nix` is evaluated
- **THEN** `disko.devices.disk.main.device` equals `/dev/disk/by-id/nvme-Samsung_SSD_9100_PRO_4TB_S7YANJ0Y308565Y`

#### Scenario: Disko data points to 2TB
- **WHEN** `disko.nix` is evaluated
- **THEN** `disko.devices.disk.data.device` equals `/dev/disk/by-id/nvme-Samsung_SSD_9100_PRO_2TB_S7YCNJ0Y202518L`

### Requirement: Old 2TB drive repurposed as data
After migration and verification, the 2TB NVMe SHALL be reformatted as a single ext4 partition mounted at `/data`.

#### Scenario: 2TB reformatted
- **WHEN** the repurpose step completes
- **THEN** the 2TB drive has a single ext4 partition mounted at `/data`

### Requirement: Data backup before destructive steps
Any existing contents on `/data` (the current 4TB mount) SHALL be backed up or confirmed expendable before the 4TB drive is repartitioned.

#### Scenario: User confirms data disposition
- **WHEN** the migration procedure begins
- **THEN** the operator has either backed up `/data` contents or confirmed they can be discarded
