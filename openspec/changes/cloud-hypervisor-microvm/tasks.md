## 1. Guest Tag and Machine Registration

- [x] 1.1 Add `cloud-hypervisor-guest` to the tag registry in `inventory/core/contracts.ncl`
- [x] 1.2 Create `inventory/tags/cloud-hypervisor-guest.nix` — virtio kernel modules (virtio_pci, virtio_blk, virtio_net, virtio_console), systemd-in-initrd, serial console (ttyS0), systemd-networkd DHCP, no bootloader, disable envfs, disable systemd-networkd-wait-online, enable nix GC automatic
- [x] 1.3 Create `machines/chv-dev1/configuration.nix` — hostName, hostPlatform x86_64-linux, SSH, users, stateVersion
- [x] 1.4 Create `machines/chv-dev1/disko.nix` — single ext4 partition on /dev/vda (no ESP, no bootloader)
- [x] 1.5 Register the machine in `inventory/core/machines.ncl` with `cloud-hypervisor-guest` and `minimal-docs` tags, deploy target `root@172.16.0.2`
- [x] 1.6 Verify the machine builds: `build chv-dev1` ✓ (toplevel: /nix/store/hz1wihazbsg97hsi1pcwz3fng61bk7sr-nixos-system-chv-dev1-...)

## 2. Host Launcher Module

- [x] 2.1 Create `modules/cloud-hypervisor-vm/default.nix` — clan service module with `host` role, perInstance pattern
- [x] 2.2 Define instance settings: guestMachine, cpus, memory, diskPath, tapInterface, macAddress, guestIp
- [x] 2.3 Generate systemd service with ExecStart (cloud-hypervisor direct kernel boot), ExecStop (API socket power-button), ExecStopPost (TAP cleanup), multi-queue, seccomp, watchdog
- [x] 2.4 Resolve kernel/initrd/init paths from `self.nixosConfigurations.${guestMachine}.config.system.build`
- [x] 2.5 Generate dnsmasq DHCP reservation via `services.dnsmasq.settings.dhcp-host`
- [x] 2.6 Register the module in `modules/default.nix`

## 3. Service Instance and Host Integration

- [x] 3.1 Add `chv-dev1` instance in `inventory/services/services.ncl` targeting britton-desktop with host role
- [x] 3.2 Register `cloud-hypervisor-vm` in `inventory/services/contracts.ncl` module registry
- [x] 3.3 Verify britton-desktop builds with the new service ✓ (toplevel: /nix/store/lph4x684qig6d6dpk9hxbix155ir660c-nixos-system-britton-desktop-...)

## 4. Bootstrap Script

- [x] 4.1 Write bootstrap script `modules/cloud-hypervisor-vm/bootstrap.sh`: creates raw disk image, formats ext4, nixos-install, copies SSH host keys
- [ ] 4.2 (skipped — bootstrap.sh is run directly, not packaged)
- [x] 4.3 Bootstrap tested: disk image created, VM boots to NixOS login prompt on serial console ✓
  - ISSUE: guest networking not working — zero packets on TAP, DHCP never happens
  - VM boots fully (SSH daemon started, serial getty running)
  - Needs serial console debugging to check networkd/interface state inside guest

## 5. Networking Cleanup

- [x] 5.1 Refactored `cloud-hypervisor-host.nix`: legacy tap0 for RedoxOS (172.16.0.2), DHCP range expanded to .2-.254, bind-dynamic for per-VM taps
- [x] 5.2 RedoxOS legacy reservation preserved (`52:54:00:12:34:56,172.16.0.2`), chv-dev1 uses .10 to avoid conflict

## 6. End-to-End Validation

- [x] 6.1 Boot the VM via `systemctl start cloud-hypervisor-chv-dev1` on britton-desktop ✓
- [ ] 6.2 Verify graceful shutdown via `systemctl stop` — confirm API socket power-button is used, no dirty ext4 flags
- [ ] 6.3 SSH into the guest at 172.16.0.2 from the host
- [ ] 6.4 Run `clan machines update <vmname>` and verify it deploys successfully
- [x] 6.5 Generate clan vars for the new machine: `clan vars generate chv-dev1` ✓
- [ ] 6.6 Verify nix GC runs automatically inside the guest and reclaims old closures
- [ ] 6.7 Document the workflow in a README or comment in the machine's configuration.nix
