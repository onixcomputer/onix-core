# PineNote Community Edition Partition Layout
#
# This disko config recreates the Community Edition partition layout.
# U-Boot bootmenu expects:
#   - bootmenu_1 = Boot OS1 (part 5) = partition 5 = os1
#   - bootmenu_2 = Boot OS2 (part 6) = partition 6 = os2
#
# CRITICAL: The waveform partition contains device-unique e-ink calibration data.
# It is backed up in vars/per-machine/pine/pinenote-waveform/ but should NOT be
# reformatted during normal operations.
#
# Boot process: U-Boot -> sysboot -> /boot/extlinux/extlinux.conf on os2
# pinenote-nixos expects: ext4 partition labeled "nixos"
#
# Layout:
#   Part 1: uboot     - 64 MB  - U-Boot bootloader (preserve)
#   Part 2: waveform  -  2 MB  - E-ink waveform data (CRITICAL - preserve)
#   Part 3: uboot_env -  1 MB  - U-Boot environment (preserve)
#   Part 4: logo      - 64 MB  - Boot splash (can overwrite)
#   Part 5: os1       - 15 GB  - Debian/recovery OS
#   Part 6: os2       - 15 GB  - NixOS (labeled "nixos")
#   Part 7: data      - rest   - Shared user data
{
  disko.devices = {
    disk.main = {
      device = "/dev/mmcblk0";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          # Partition 1: U-Boot bootloader
          # Priority ensures correct ordering
          uboot = {
            priority = 1;
            size = "64M";
            type = "8300"; # Linux filesystem (raw, no format)
            # No content = preserve existing data / don't format
          };

          # Partition 2: Waveform data (CRITICAL - device unique)
          waveform = {
            priority = 2;
            size = "2M";
            type = "8300";
            # No content = preserve existing data
          };

          # Partition 3: U-Boot environment
          uboot_env = {
            priority = 3;
            size = "1M";
            type = "8300";
            # No content = preserve existing data
          };

          # Partition 4: Boot logo/splash
          logo = {
            priority = 4;
            size = "64M";
            type = "8300";
            # No content - can be used for boot assets if needed
          };

          # Partition 5: OS1 - Debian/recovery (keep for dual-boot)
          os1 = {
            priority = 5;
            size = "15G";
            type = "8300";
            content = {
              type = "filesystem";
              format = "ext4";
              extraArgs = [
                "-L"
                "os1"
              ];
              # Not mounted - reserved for Debian/recovery
            };
          };

          # Partition 6: OS2 - NixOS (this is where we boot from)
          # U-Boot bootmenu_2 boots from this partition
          os2 = {
            priority = 6;
            size = "15G";
            type = "8300";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
              extraArgs = [
                "-L"
                "nixos" # pinenote-nixos expects this label
              ];
            };
          };

          # Partition 7: Shared data partition
          data = {
            priority = 7;
            size = "100%"; # Use remaining space
            type = "8300";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/data";
              extraArgs = [
                "-L"
                "data"
              ];
            };
          };
        };
      };
    };
  };
}
