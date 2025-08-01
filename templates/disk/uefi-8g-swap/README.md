---
description = "UEFI with 8GB swap for heavy workloads (GRUB)"
---

# UEFI 8GB Swap Template

Custom template for systems needing extra swap space for compilation or data processing

### Disk Overview

- Device: `{{mainDisk}}`

### Partitions

1. EFI System Partition (ESP)

   - Size: `1G`
   - Filesystem: `vfat`
   - Mount Point: `/boot`

1. Swap Partition

   - Size: `8G`
   - Type: Linux swap

1. Root Partition

   - Size: Remaining disk space
   - Filesystem: `ext4`
   - Mount Point: `/`

### Notes

- Extra ESP space (1G) for multiple kernels
