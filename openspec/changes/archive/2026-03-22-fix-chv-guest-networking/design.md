## Context

cloud-hypervisor guest chv-dev1 boots to multi-user.target with all services green, SSH daemon listening, serial console responsive — but sends zero packets on the TAP interface. The host sees no RX traffic on `tap-chv-dev1` whatsoever.

The existing setup:
- **Host**: `cloud-hypervisor-vm` clan service on britton-desktop creates TAP with `ip tuntap add mode tap multi_queue vnet_hdr`, assigns 172.16.0.1/24, launches CH with `--net tap=tap-chv-dev1,mac=52:54:00:c0:ff:01,num_queues=8`
- **Guest**: `cloud-hypervisor-guest` tag enables systemd-networkd with `DHCP=yes` on `Name=ens*` match
- **DHCP**: dnsmasq on host in `bind-dynamic` mode with reservation `52:54:00:c0:ff:01,172.16.0.10`

Comparison with microvm.nix (the working reference implementation):
- microvm.nix uses identical TAP flags (`vnet_hdr multi_queue`) and net args (`tap=<id>,mac=<mac>,num_queues=<2*vcpu>`)
- microvm.nix always **deletes+recreates** the TAP, not creates-if-missing
- microvm.nix tests use **static IPs**, never systemd-networkd DHCP — so DHCP over virtio-net/TAP is comparatively untested upstream
- microvm.nix doesn't set any special carrier handling or ActivationPolicy

## Goals / Non-Goals

**Goals:**
- Diagnose the exact failure point (interface state, networkd behavior, DHCP client status, packet flow)
- Fix guest networking so DHCP works end-to-end (guest → TAP → dnsmasq → response → guest gets IP)
- Harden configurations so the fix is robust against timing races, interface naming changes, TAP state leftovers
- Complete the 5 remaining validation tasks from the parent change (6.2-6.7)

**Non-Goals:**
- Switching to static IP assignment (DHCP is the correct architecture for multi-VM scaling)
- Replacing dnsmasq (it's already running and serves the legacy RedoxOS TAP)
- virtiofs/9p share setup (separate concern)
- Rearchitecting to use microvm.nix framework (we want clan-native integration)

## Decisions

### 1. Diagnostic approach: serial console via systemd journal + PTY

cloud-hypervisor with `--serial tty` connects the guest serial console to the VMM process's stdout/stderr. Since the service runs under systemd, serial output appears in `journalctl -u cloud-hypervisor-chv-dev1`. For input, we need the console PTY.

**Approach**: Write a diagnostic script that:
1. Reads current journal output for boot log analysis
2. Uses `ch-remote --api-socket <sock> console` or echoes commands into the serial PTY
3. Alternatively, use `cloud-hypervisor --serial pty` instead of `--serial tty` to get a PTY device path for interactive access

The diagnostic commands to run inside the guest:
- `ip link show` — check interface flags (UP, LOWER_UP, NO-CARRIER)
- `ip addr show` — check if DHCP assigned anything
- `networkctl` — overall networkd status
- `networkctl status ens2` — detailed interface state, matched .network file
- `journalctl -u systemd-networkd -n 50` — networkd logs
- `ls /etc/systemd/network/` — verify .network files deployed
- `cat /proc/net/dev` — kernel-level packet counters (TX/RX)

### 2. Network match: `Driver=virtio_net` instead of `Name=ens*`

**Choice**: Match by kernel driver name, not by predictable network interface name.

**Why**: The interface name depends on PCI slot assignment in cloud-hypervisor's device model. Currently `ens2` but could change if devices are reordered, additional devices added, or cloud-hypervisor changes its PCI topology. `Driver=virtio_net` matches regardless of naming scheme.

**Alternative**: `Type=ether` — too broad, would match any Ethernet device if one were added. `Name=en*` — still naming-dependent. `Virtualization=vm` — matches all VM interfaces, not just virtio.

### 3. TAP lifecycle: always delete+recreate

**Choice**: Match microvm.nix's pattern — always delete the TAP if it exists, then create fresh.

**Why**: A stale TAP from a previous (crashed) run might have different flags (missing `multi_queue`, wrong `vnet_hdr` state). The current `create-if-missing` pattern preserves stale TAPs. cloud-hypervisor's ioctl to open a multi_queue TAP fails if the TAP wasn't created with `multi_queue`.

```bash
# Delete stale TAP if it exists
if [ -e /sys/class/net/${tapInterface} ]; then
  ip link delete ${tapInterface}
fi
# Fresh create with correct flags
ip tuntap add dev ${tapInterface} mode tap multi_queue vnet_hdr
ip link set ${tapInterface} up
ip addr add 172.16.0.1/24 dev ${tapInterface}
```

### 4. Carrier handling: `ConfigureWithoutCarrier=yes`

**Choice**: Add `ConfigureWithoutCarrier=yes` to the guest .network file.

**Why**: There's a potential timing race — the TAP on the host is UP, but the virtio-net device inside the guest might not report carrier until cloud-hypervisor fully initializes all queue pairs. systemd-networkd waits for carrier before starting DHCP. With `ConfigureWithoutCarrier=yes`, networkd starts DHCP immediately and retries until the link is ready.

### 5. Explicit `ActivationPolicy=up` in .network

**Choice**: Add `ActivationPolicy=up` to force networkd to bring the interface administratively UP.

**Why**: Without explicit activation policy, networkd respects the interface's current admin state. If the interface starts DOWN and carrier detection prevents automatic UP, DHCP never triggers. `ActivationPolicy=up` makes networkd unconditionally set IFF_UP.

### 6. dnsmasq timing: ensure dnsmasq sees the TAP

**Choice**: Send SIGHUP to dnsmasq after creating the TAP in ExecStartPre.

**Why**: dnsmasq's `bind-dynamic` mode uses inotify on `/proc/net/if_inet6` and periodic rescans (every ~1s) to detect new interfaces. There's a small window where the TAP is created, the VM boots, and the first DHCP discover arrives before dnsmasq notices the interface. SIGHUP forces an immediate interface rescan.

**Alternative**: Add `ExecStartPost` that restarts dnsmasq — too heavy, disrupts other VMs. Systemd dependency ordering (`After=dnsmasq`) already exists transitively but doesn't cover dynamically-created interfaces.

### 7. Multi-queue: keep current `2*vcpu` for net, test with single queue first

**Choice**: First test with `num_queues=2` (single queue pair, no multi_queue) to isolate whether multi-queue is the root cause. If single-queue works, incrementally add multi-queue back.

**Why**: Multi-queue is a performance optimization, not a correctness requirement. Eliminating it during diagnosis narrows the problem space.

## Risks / Trade-offs

- **[Diagnosis might reveal a different root cause]** → The design covers the most likely causes based on research. If diagnosis reveals something unexpected (e.g., a cloud-hypervisor bug, kernel version incompatibility), the fix tasks will need adjustment. The diagnostic phase explicitly runs before the fix phase.
- **[ConfigureWithoutCarrier can cause DHCP storms]** → If the interface never gets carrier, the DHCP client retries indefinitely. Mitigation: this is a VM on a local TAP — the only traffic is between guest and host. Even with retries, the impact is negligible.
- **[dnsmasq SIGHUP is a blunt instrument]** → SIGHUP causes dnsmasq to re-read its config and rescan interfaces. During the rescan, there's a brief window where existing leases might be disrupted. Mitigation: the rescan is fast (<10ms) and existing leases persist in dnsmasq's in-memory database through SIGHUP.
- **[Driver=virtio_net match won't work if module isn't loaded]** → If udev hasn't loaded virtio_net by the time networkd starts its initial scan, the Driver field is empty. Mitigation: networkd watches for netlink events and re-evaluates matches when interfaces appear. The module loads during early boot (virtio PCI enumeration happens before networkd).

## Open Questions

- Is the zero-packet issue caused by the guest (interface not UP, DHCP not sending) or the host (TAP not properly connected to CH)? Serial diagnostics will determine this.
- Does cloud-hypervisor correctly handle the TAP when `num_queues` > 2 on existing (externally-created) TAPs? Source code review suggests yes, but runtime confirmation needed.
