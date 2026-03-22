## ADDED Requirements

### Requirement: ZFS tag in inventory
A `zfs` tag SHALL be added to `contracts.ncl` and `machines.ncl`, applied to all 5 target machines (britton-fw, bonsai, aspen1, aspen2, britton-desktop). A corresponding `inventory/tags/zfs.nix` SHALL provide shared ZFS NixOS configuration.

#### Scenario: Tag application
- **WHEN** a machine has the `zfs` tag in machines.ncl
- **THEN** the ZFS tag configuration is applied during `clan machines update`

### Requirement: Unique hostId per machine
Each ZFS machine SHALL have a `networking.hostId` set to a unique 8-character hex string. This is required by ZFS for pool import safety.

#### Scenario: Pool import protection
- **WHEN** a ZFS pool disk is moved to a different machine
- **THEN** ZFS refuses to import the pool because the hostId doesn't match, preventing accidental data corruption

#### Scenario: hostId persistence
- **WHEN** the machine rebuilds via `nixos-rebuild switch`
- **THEN** the hostId remains the same (defined in machine configuration.nix, not generated at runtime)

### Requirement: ZFS kernel module support
The ZFS tag SHALL set `boot.supportedFilesystems = ["zfs"]` to ensure the ZFS kernel module and userspace tools are available in the initrd and running system.

#### Scenario: ZFS tools available
- **WHEN** a machine with the zfs tag boots
- **THEN** `zpool`, `zfs`, `zdb` commands are available in the system PATH

### Requirement: Auto-scrub
The ZFS tag SHALL enable automatic pool scrubbing via `services.zfs.autoScrub` on a weekly schedule for all pools.

#### Scenario: Weekly scrub execution
- **WHEN** one week passes since the last scrub
- **THEN** `systemctl status zfs-scrub-rpool.timer` shows the scrub ran and `zpool status` shows no checksum errors (or reports them if found)

### Requirement: ARC memory limits
The ZFS tag SHALL set `boot.kernelParams` with `zfs.zfs_arc_max` appropriate to the machine class: 50% of RAM for servers, 25% for laptops/desktops.

#### Scenario: Server ARC sizing
- **WHEN** aspen1 or aspen2 boots (128GB RAM)
- **THEN** `cat /sys/module/zfs/parameters/zfs_arc_max` shows approximately 64GB

#### Scenario: Laptop ARC sizing
- **WHEN** britton-fw or bonsai boots
- **THEN** `cat /sys/module/zfs/parameters/zfs_arc_max` shows approximately 25% of installed RAM

### Requirement: Kernel compatibility for servers
Servers (aspen1, aspen2) SHALL use `config.boot.zfs.package.latestCompatibleLinuxPackages` instead of `linuxPackages_latest`, with a minimum kernel version floor of 6.16.9 for AMD Strix Halo unified memory support.

#### Scenario: ZFS-compatible kernel on servers
- **WHEN** aspen1 or aspen2 builds
- **THEN** the kernel version is the latest that ZFS supports AND is >= 6.16.9

#### Scenario: Kernel floor violation
- **WHEN** `latestCompatibleLinuxPackages` resolves to a kernel below 6.16.9
- **THEN** the build fails with an assertion error indicating the kernel is too old for Strix Halo support (or a manual pin overrides it)
