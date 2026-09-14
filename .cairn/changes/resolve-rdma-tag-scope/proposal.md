## Why

Both `aspen1` and `aspen2` carried the `rdma-cluster` tag, but neither host has an RDMA controller: their only network controller is a Realtek RTL8126. The tag therefore promised RoCE v2 hardware that does not exist, and it also carried the Strix Halo unified-memory tuning, `iommu=pt`, `pci=realloc`, and `pcie_aspm=off`. That bundle hid two separate concerns behind one tag name, and it applied an E810-era IOMMU passthrough mode to a physical USB4 port.

The memory tuning in the tag also contradicted the repository's own documentation: `amd-gpu` documents 100 GB of TTM pages on a 128 GiB host, while `rdma-cluster` overrode it to 124 GiB, leaving about 4 GiB for the OS.

## What Changes

- Split the tag. `gpu-unified-memory` owns the per-host GTT aperture and TTM page limit. `rdma-cluster` keeps the E810 modules, addresses, groups, udev rules, and PCIe parameters.
- `rdma-cluster` now fails closed: it asserts that the host hardware inventory lists an RDMA-capable network controller.
- Move the hardware-inventory query into `lib/rdma-hardware.nix` so the tag and the cluster network selector share one driver list.
- Replace `rdma-cluster` with `gpu-unified-memory` in the `aspen1` and `aspen2` tag lists.
- Register the new tag in the Nickel tag registry.

## Impact

- **Files**: `lib/rdma-hardware.nix`, `inventory/tags/gpu-unified-memory.nix`, `inventory/tags/rdma-cluster.nix`, `inventory/tags/vllm-cluster-network.nix`, `inventory/core/contracts.ncl`, `inventory/core/machines.ncl`, and the `thunderbolt-link` specification delta.
- **Risk**: The aspen hosts lose `iommu=pt`, `pci=realloc`, and `pcie_aspm=off` at the next boot, and the IOMMU returns to its default translation mode. GPU and NVMe DMA performance must be re-measured after that boot.
- **Non-goals**: Do not remove the `rdma-cluster` tag itself, because a host that gains an E810 still needs it. Do not reboot the hosts in this change.
- **Tuning change**: the tag now derives the aperture as three quarters of each host's installed memory, so `aspen1` moves from a 124 GiB to a 96 GiB aperture and `aspen2` from an over-RAM 124 GiB to 48 GiB. Both reach the kernel at the next boot and need a post-reboot performance comparison.
- **Testing**: Nix evaluation of both hosts for the rendered kernel parameters and the segment env, a top-level closure build for both hosts, and a deploy that verifies the live boot entry and the unchanged memory parameters.
- **Spec supersession**: the accepted `rdma-cluster` specification still documents memory tuning under the RDMA tag (`tag.memory_tuning`). That requirement is superseded by `r[onix.gpu_unified_memory.sizing]` and needs a delta before the spec is archived.
