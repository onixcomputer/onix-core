## Why

The britton-desktop root filesystem lives on a 2TB Samsung 9100 PRO NVMe while a 4TB Samsung 9100 PRO sits underutilized as a `/data` mount. Moving root to the 4TB drive doubles available system storage and frees the 2TB drive for repurposing or as a dedicated data/scratch disk.

## What Changes

- Clone the live root, swap, and ESP partitions from the 2TB NVMe to the 4TB NVMe using a block-level or filesystem-aware copy.
- Repartition the 4TB drive: 1G ESP, 8G swap, remainder as root (~3.6TB usable).
- Update `machines/britton-desktop/disko.nix` so `main` points to the 4TB drive (`nvme-Samsung_SSD_9100_PRO_4TB_S7YANJ0Y308565Y`) and `data` points to the 2TB drive (`nvme-Samsung_SSD_9100_PRO_2TB_S7YCNJ0Y202518L`).
- Reinstall GRUB on the new ESP so the machine boots from the 4TB drive.
- Reformat the old 2TB drive as a single ext4 data partition.

## Capabilities

### New Capabilities
- `nvme-migration`: Procedure and disko config for migrating britton-desktop root from the 2TB NVMe to the 4TB NVMe, including partition layout, data cloning, bootloader reinstall, and old-drive repurposing.

### Modified Capabilities

None — no existing specs are affected.

## Impact

- `machines/britton-desktop/disko.nix` — disk IDs swap between `main` and `data` roles, partition layout changes on both drives.
- Requires downtime or a live-environment session for the physical clone step.
- GRUB config regenerates automatically from disko on next `clan machines update`, but the initial bootloader install on the new ESP must happen during the migration.
- `/data` contents need to be backed up or migrated before the old 2TB drive is reformatted.
