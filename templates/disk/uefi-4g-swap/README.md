---
description = "UEFI with 4GB swap for heavy workloads (systemd-boot)"
---
# UEFI 4GB Swap Template

Custom template for systems needing extra swap space for compilation or data processing

### Disk Overview

- Device: `{{mainDisk}}`

### Partitions

1. EFI System Partition (ESP)
   - Size: `1G`
   - Filesystem: `vfat`
   - Mount Point: `/boot`

2. Swap Partition
   - Size: `4G`
   - Type: Linux swap

3. Root Partition
   - Size: Remaining disk space
   - Filesystem: `ext4`
   - Mount Point: `/`

### Notes

- Large swap for comfortable hibernation on 4GB+ RAM systems
- Extra ESP space (1G) for multiple kernels
- Custom template from infra repository
