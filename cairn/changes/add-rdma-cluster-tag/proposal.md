## Why

The linked AMD Strix Halo RDMA guide describes the host-side prerequisites we want on the Aspen Strix Halo pair: Intel E810 RoCE v2 support, jumbo-frame static cluster networking, RDMA userspace tools, and unified-memory kernel tuning for distributed vLLM experiments.

Keeping those steps as manual Fedora commands makes the cluster hard to reproduce. `onix-core` already uses machine tags for reusable host capabilities, so this should become a declarative tag that can be assigned to the relevant machines.

## What Changes

- Add an `rdma-cluster` NixOS tag for Intel E810/RoCE host readiness.
- Register the tag in the Nickel machine tag contract and apply it to `aspen1` and `aspen2`.
- Configure the tag to load Intel/RDMA kernel modules, use the guide's Strix Halo memory kernel parameters, assign static `/30` RDMA addresses on `rdma0`, trust that interface in the firewall, and install RDMA verification tools.
- Add a `vllm-cluster-network` selector tag that exports Ray/vLLM/RCCL interface variables, preferring `rdma0` when available and falling back to the existing Thunderbolt `br-tbt` link.
- Record the upstream toolbox guide as a README reference.

## Impact

- **Scope**: `aspen1` and `aspen2` host networking/kernel configuration plus sourceable cluster-network environment metadata.
- **Risk**: The tag renames the first Intel `ice` interface to `rdma0` on tagged hosts; hosts with multiple `ice` ports will need a more specific match before assignment.
- **Non-goals**: Do not package or run the upstream toolbox scripts; do not auto-launch Ray/vLLM; do not replace the existing Thunderbolt fallback tag.
- **Testing**: Validate Cairn artifacts, tag registry sync, Nix evaluation for both tagged Aspen systems, RDMA-preferred env rendering, Thunderbolt fallback rendering, and selector fail-closed assertions.
