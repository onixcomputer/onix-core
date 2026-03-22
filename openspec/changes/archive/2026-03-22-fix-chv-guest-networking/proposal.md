## Why

The cloud-hypervisor-microvm change (22/27 tasks complete) is blocked on guest networking. chv-dev1 boots to multi-user with all services green and SSH listening, but sends zero packets on the TAP interface. No DHCP traffic leaves the guest despite systemd-networkd running, the virtio-net interface (ens2) existing, and matching .network files being deployed. Without working networking, the VM can't be reached via SSH and `clan machines update chv-dev1` can't deploy.

## What Changes

- Add serial console access tooling to run diagnostics inside the guest (ip link, networkctl, journalctl) without SSH
- Fix the root cause of zero-packet networking based on diagnostic findings (likely: networkd not administratively bringing the interface UP, carrier detection issue, or virtio-net queue mismatch)
- Harden the guest and host networking configuration against known failure modes found during research:
  - Switch .network file match from `Name=ens*` to `Driver=virtio_net` (name-independent, covers enp* variants)
  - Add `ConfigureWithoutCarrier=yes` to handle TAP carrier timing
  - Always delete+recreate TAP in ExecStartPre (match microvm.nix behavior, prevent stale TAP properties)
- Complete the 5 remaining validation tasks from the parent change (graceful shutdown, SSH access, clan deploy, GC verification, documentation)

## Capabilities

### New Capabilities
- `chv-serial-diagnostics`: Serial console access and diagnostic workflow for cloud-hypervisor guests — send commands to the guest via the PTY exposed by `--serial tty`, parse output
- `chv-guest-networking`: Working virtio-net + systemd-networkd + dnsmasq DHCP path from guest through TAP to host, with hardened configuration

### Modified Capabilities
- `cloud-hypervisor-launcher`: Host-side TAP creation changed to delete+recreate pattern; dnsmasq timing dependency added
- `cloud-hypervisor-guest`: networkd .network file match criteria and carrier handling updated

## Impact

- `modules/cloud-hypervisor-vm/default.nix` — ExecStartPre TAP logic, possible dnsmasq dependency ordering
- `inventory/tags/cloud-hypervisor-guest.nix` — networkd .network match config, carrier settings
- `machines/chv-dev1/` — may need kernel module or boot param adjustments depending on diagnosis
- Unblocks SSH deploy target `root@172.16.0.10` and `clan machines update chv-dev1`
