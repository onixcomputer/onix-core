## Context

`aspen1` and `aspen2` are Framework Desktop AMD Ryzen AI MAX+ 395 systems with the existing `amd-gpu` and `thunderbolt-link` tags. The upstream guide targets the same Strix Halo class and an Intel E810 direct RoCE v2 link, but it is written as imperative Fedora setup.

On NixOS, the reusable shape is a machine tag under `inventory/tags/` plus registration in `inventory/core/contracts.ncl`. The tag can prepare the host for RDMA and distributed inference while leaving toolbox/container orchestration to separate service work.

## Decisions

### 1. Add a host-readiness tag, not a vLLM service

**Choice:** Create `rdma-cluster` as a NixOS tag that configures the host kernel, RDMA device access, and the direct cluster network.

**Rationale:** The guide mixes host prerequisites with toolbox and Ray/vLLM runtime steps. The durable Onix boundary today is host capability; service orchestration can evolve later without blocking RDMA link readiness.

### 2. Scope static addressing to the Aspen pair

**Choice:** Assign `aspen1` to `192.168.100.1/30` and `aspen2` to `192.168.100.2/30` on a renamed `rdma0` interface, and fail evaluation if the tag is placed on a host without an address mapping.

**Rationale:** Silent no-op tags are easy to misread as configured. A closed address map catches accidental assignment while keeping the two-node guide topology explicit.

### 3. Match Intel E810 by the `ice` driver

**Choice:** Use a systemd `.link` match on `Driver=ice` and rename the matched interface to `rdma0`.

**Rationale:** Interface names vary by PCI topology. Matching the Intel Ethernet driver is more portable for the one-port E810 topology described by the guide. Hosts with multiple `ice` ports must refine the match before using this tag.

### 4. Keep Thunderbolt fallback intact

**Choice:** Do not remove `thunderbolt-link` from the Aspen machines.

**Rationale:** The upstream guide explicitly documents Thunderbolt networking as an alternative path. The existing Onix tag remains useful when RDMA hardware is absent or being debugged.

### 5. Export a selected cluster network for runtime tools

**Choice:** Add `vllm-cluster-network` as a separate tag that writes `/etc/vllm-cluster/network.env` and installs `vllm-cluster-env`. The selector prefers `rdma0` when `rdma-cluster` is present and falls back to `br-tbt` when only `thunderbolt-link` is present.

**Rationale:** Ray/vLLM/RCCL need consistent interface and node-IP environment variables, but the actual server lifecycle still belongs to the toolbox or a future service. A small env-file boundary lets manual toolbox use and future services consume the same selected network without coupling the host tag to process supervision.

## Risks / Trade-offs

- The `ice` driver match is intentionally simple and assumes one Intel E810 port per tagged host.
- The guide's larger Strix Halo GTT/TTM settings are more aggressive than the existing generic `amd-gpu` default; this tag should stay limited to the RDMA inference pair until runtime memory behavior is proven.
- `perftest` is not available in the current Onix/nixpkgs package set, so the tag installs `rdma-core`, `qperf`, `ethtool`, `iproute2`, and `pciutils` for host verification.
- The selector can only choose from declared Nix tags; it cannot detect at evaluation time whether the physical RDMA cable is actually present.
