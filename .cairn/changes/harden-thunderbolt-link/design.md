## Context

The link is the only fast path between the two Strix Halo hosts: both machines have a single 5 GbE Realtek RTL8126 controller and no RDMA controller, while the USB4 link runs at Gen 3x2. Measured on 2026-09-14:

| Property | Value | Evidence |
| --- | --- | --- |
| Link generation | 4 (USB4 Gen 3x2) | `/sys/bus/thunderbolt/devices/0-0/generation` |
| Lanes and speed | 2 rx / 2 tx lanes, 20.0 Gb/s per lane | `/sys/bus/thunderbolt/devices/0-2/{rx,tx}_{lanes,speed}` |
| Interface MTU | 65520 of maxmtu 65522 | `ip -d link show thunderbolt0` |
| TCP throughput | 9.6–10.3 Gb/s, independent of MTU (1500/9000/65520), stream count (1 or 8), and direction | `iperf3` over `br-tbt` |
| Round-trip time | 0.06–0.36 ms | `ping -c 20` over `br-tbt` |

The throughput ceiling is inside the driver, not in the host configuration:

- `thunderbolt-net` splits every packet into frames with a 4084-byte payload (`TBNET_MAX_PAYLOAD_SIZE`), so a 65520-byte packet becomes 17 frames and the MTU cannot change the per-frame cost. Throughput is pinned at the same bytes per second for every MTU, which rules out per-packet cost.
- The driver owns one Tx ring and one Rx ring per service with a single spinlock, and sets `TBNET_THROTTLING` (128 µs) as the ring interrupt interval. Measured interrupt rate under load is 7.6 k/s, which is exactly the throttling ceiling.
- The sender is not CPU-bound: the busiest CPU accumulated 1.5 s of 8 s during a four-stream transfer.
- The software bridge is not the bottleneck: throughput and RTT are identical with the address on `thunderbolt0` and with the bridge in place.

Two candidate knobs were tested or rejected:

- `e2e=0` (USB4NET end-to-end flow control) changed nothing: 9.72–10.3 Gb/s before and after, on both hosts, with clean ping and no receive errors.
- `clx=0` (disable lane low-power states) and `dma_credits` are read-only module parameters (`-r--r--r--`). Applying them needs a full `thunderbolt` module reload, and neither host exposes `usb4_port*/offline`, so a link that fails to retrain would need physical access. That change is deferred to an operator decision.

## Decisions

### 1. Denial early, grants in the NixOS firewall

**Choice:** A dedicated `inet` table hooks `input` and `forward` at priority `-180` and only *denies*: it drops IPv4 from any source that is not a configured peer, drops IPv6, and drops forwarded packets that enter or leave the link. The peer grant lives in `networking.firewall.extraInputRules` on the same interface set and source set.

**Rationale:** `networking.firewall.extraInputRules` is appended after the per-interface and per-port accepts, so a *drop* rule there cannot take access away from a port that another module opened, and NixOS accepts ICMP echo requests globally before that point. A chain in a separate table at a lower priority number is the only place where the denial is authoritative.

The first implementation also granted peer access from that early table. Deployment showed that this grant was not effective: TCP connections from the peer to ports that the host firewall does not otherwise allow still failed, while a peer connection to an already-allowed port succeeded. An `accept` verdict in one table's base chain does not stop another table's base chain at the same hook, which is why the grant must live in the chain that owns the port policy. The measured result after the split: peer TCP to an arbitrary port succeeds, a non-peer source in the same subnet times out, and the deny counter records the drop.

`networking.firewall.interfaces."br-tbt"` was rejected because it grants access per port; Ray and NCCL open ephemeral ports, so per-port grants cannot express the cluster's traffic.

### 2. No transit in either direction

**Choice:** Drop forwarded packets that enter or leave the link.

**Rationale:** `net.ipv4.ip_forward = 1` is set by Docker and NixOS does not filter forwarding by default. The tailscale `ts-forward` chain accepts anything that leaves through `tailscale0`, so before this change a device on the USB4 link could reach the entire tailnet. Nothing routes over the link, so the drops carry no traffic cost.

### 3. Verify, then repair, with a cooldown

**Choice:** A single guard script verifies carrier, address, MTU, and peer reachability. It repairs only when the link carries traffic badly, never when the cable is gone, and it refuses a second repair within a cooldown window.

**Rationale:** The previous service matched four kernel log strings with `journalctl -k -f`. Log text is not an interface, and the service never checked whether its bounce worked. The kernel does publish a supported signal: `TUNNEL_EVENT` with `deactivated`, `activated`, `low bandwidth`, and `insufficient bandwidth` for the XDomain DMA tunnel, which was observed on both hosts while bouncing the net device. A timer covers silent breakage that produces no event.

A link with no carrier is reported and left alone: no host-side action can repair a missing cable, and the carrier state already alerts through `NetworkInterfaceDown`. A link that is up but unusable after a repair is a failed unit, which the existing `SystemdServiceFailed` alert reports.

### 4. The guard also enforces the link parameters

**Choice:** The guard re-applies the per-interface sysctls (`accept_redirects`, `send_redirects`, `accept_source_route`) and the member and bridge MTU on every run.

**Rationale:** `boot.kernel.sysctl` runs before `systemd-networkd` creates the bridge, so per-interface keys there either fail at boot or do not stick. The guard already owns the link's runtime state and runs after networkd on boot, on every tunnel event, and every 15 minutes.

### 5. Cluster selection follows the hardware inventory

**Choice:** `vllm-cluster-network` selects the RDMA backend only when the RDMA network tag is present *and* the machine's `facter.json` lists an RDMA-capable network controller driver. Otherwise it selects the USB4 link and emits an evaluation warning.

**Rationale:** `aspen1` and `aspen2` are tagged `rdma-cluster` but their inventory lists only an `r8169` controller. The rendered `/etc/vllm-cluster/network.env` therefore named an interface that does not exist, which silently disabled the cluster fast path. Selection from a recorded hardware fact is deterministic, testable by evaluation, and needs no runtime probing.

### 6. MAC pinning and `iommu=pt` are out of scope

**Choice:** Do not pin the peer MAC; do not remove `iommu=pt`.

**Rationale:** The peer's `thunderbolt0` MAC is derived from the host router UUID, so pinning it would break silently if a controller or NVM identity changed. Address admission already removes the "any device gets everything" exposure.

`iommu=pt` comes from the `rdma-cluster` tag and leaves the IOMMU in passthrough mode for devices that use the default domain, which weakens DMA protection for a physical USB4 port. Removing it changes kernel parameters for hardware that is present (GPU, NVMe), needs a reboot, and needs a performance review of the inference workloads. `iommu_dma_protection` reads `1` on both hosts, but the source of the 7.2 kernel is not available locally, so this report does not claim which protection is active. This is recorded as an operator decision, not fixed here.

## Verification results (2026-09-14, aspen1 and aspen2)

- `nft list table inet thunderbolt-link` on both hosts shows the deny and forward rules; `systemctl is-active thunderbolt-link-guard.timer` is active and the guard unit is not failed.
- Peer access: `nc -z 10.10.10.2 5201` from `10.10.10.1` succeeds on a port that the host firewall does not otherwise open; `curl http://10.10.10.2:9100/` returns 200.
- Denial: `curl --interface 10.10.10.9` to the peer times out (exit 28) and the non-peer IPv4 counter increases.
- No transit: a route for a tailnet address through the link produced 100% packet loss and the forward counter increased.
- Guard: a healthy run reports the link as healthy and leaves it alone; a member down run reports "no carrier" and exits 0 without a bounce; a fault-injected unhealthy run bounced the member once, reported that the link was still unhealthy, and the next run inside the cooldown did not bounce again.
- Trigger: bouncing a member produced guard runs from the kernel `TUNNEL_EVENT` uevents without any timer help.
- Performance after the change: 9.72 Gb/s one stream, 9.71 Gb/s eight streams, 10.0 Gb/s reverse, and 0.088/0.330/0.638 ms RTT (min/avg/max). The pre-change baseline was 9.6-10.3 Gb/s and 0.06-0.36 ms, so there is no regression.
- Cluster selection: `/etc/vllm-cluster/network.env` on both hosts now reports `VLLM_CLUSTER_BACKEND=thunderbolt`, `VLLM_CLUSTER_INTERFACE=br-tbt`, and `NCCL_SOCKET_IFNAME=br-tbt`.

## Operator decisions left open

- `aspen1` left the tailnet during the first deploy of this change because its Tailscale node key expired on 2026-09-11 and the stored auth key is rejected (`invalid key: API key does not exist`). `celld.service` on `aspen1` then fails because it binds the missing tailnet address. Restoring the node needs a fresh auth key from the operator; this change does not touch Tailscale. `aspen2`'s node key is valid until 2027-03-05 and it stayed online.
- The deploy path used here is `nixos-rebuild --target-host`, because `clan machines update` cannot evaluate this flake on the target (a GitHub-SSH `builtins.fetchGit` input is not reachable from the target and `--upload-inputs` does not cover it).
- Neither host has an RDMA controller, yet both carry the `rdma-cluster` tag, which also supplies the Strix Halo memory kernel parameters and `iommu=pt`. Removing `iommu=pt` would restore DMA translation for the USB4 port, but it needs a reboot and a performance review of the inference workloads.

## Risks / Trade-offs

- A peer address that is not in `tbAddresses` loses access. Adding a third host to the link means adding it to the map.
- The guard's cooldown delays a second repair by up to 5 minutes after a partial recovery. A failing cluster link that flips faster than the cooldown is reported as a failed unit rather than repaired in a loop.
- `TUNNEL_EVENT` matching is per event name. If a future kernel renames an event, the timer still covers verification.

## Verification

- `nix eval` renders the nftables table, the guard derivation, and the cluster env for `aspen1` and `aspen2`.
- Positive guard run: the unit reports a healthy link with the peer answering.
- Negative guard runs: no repair while healthy; no repair without carrier; a bounce of the peer's member interface is repaired by the guard and logged.
- Firewall: a connection from the peer address succeeds, a connection from a non-peer address in the same subnet is dropped and increments the drop counter, and a transit attempt to a tailnet address is dropped and increments the forward counter.
- Throughput and RTT are re-measured after the change to confirm no regression.
