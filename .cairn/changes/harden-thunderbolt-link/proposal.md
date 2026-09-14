## Why

The USB4/Thunderbolt link between `aspen1` and `aspen2` trains correctly at USB4 Gen 3x2, but the deployed configuration treats it as a trusted network and cannot repair itself:

- `networking.firewall.trustedInterfaces = [ "br-tbt" ]` accepts every packet from the link, so any device that is plugged into a USB4 port reaches every service that listens on `0.0.0.0` (on `aspen2`: `sshd`, Grafana, Loki, node-exporter, resolved LLMNR).
- `net.ipv4.ip_forward = 1` is set and NixOS does not filter forwarding by default, so the link is a potential transit path from the USB4 port to the LAN and the tailnet.
- The recovery service scrapes `journalctl -k` for driver log strings and never verifies that the link works again.
- `/etc/vllm-cluster/network.env` selects the RDMA backend (`rdma0`) on both hosts, but neither host has an RDMA controller. The selected interface does not exist, so the 40 Gb/s link carries no cluster traffic at all.

## What Changes

- Replace blanket trust with an address allow-list: only the peers in `tbAddresses` may reach local services over the link, and no packet is forwarded to or from the link.
- Add a dedicated early nftables table (`priority -180`) so the allow-list cannot be widened by a port opened for another interface.
- Replace the log-scraping recovery service with a guard that verifies carrier, address, MTU, and peer reachability, then repairs a wedged XDomain DMA path with a bounded link cycle and a cooldown.
- Trigger the guard from the kernel's own `TUNNEL_EVENT` udev events plus a timer, instead of matching log text.
- Enforce the per-interface hardening sysctls and the MTU from the guard so they survive drift.
- Select the cluster backend from the hardware inventory, so a host without an RDMA controller falls back to the USB4 link instead of a nonexistent interface.

## Impact

- **Files**: `inventory/tags/thunderbolt-link.nix`, `inventory/tags/vllm-cluster-network.nix`, `inventory/services/prometheus-rules.ncl`, `.cairn/specs/thunderbolt-link/`.
- **Risk**: Services that knowingly relied on the link being fully trusted stop answering non-peer sources. No deployed service uses the link today (verified: no unit, `/etc` file, or Prometheus target references `10.10.10.0/28`).
- **Non-goals**: Do not change the USB4 module parameters (`clx`, `e2e`, `dma_credits`, `asym_threshold`), which need a module reload that cannot be recovered without physical access. Do not change the `rdma-cluster` kernel parameters (`iommu=pt`, `pcie_aspm=off`, `pci=realloc`), which need a reboot and a performance review. Do not add MAC pinning.
- **Testing**: nftables ruleset evaluation, guard positive and negative runs on both hosts, a foreign-source firewall test, a transit test, and a link-bounce recovery test.
