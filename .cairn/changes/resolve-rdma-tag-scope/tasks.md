## Phase 1: Split the tag

- [x] [serial] Add `gpu-unified-memory` with per-host GTT and TTM values and a fail-closed size assertion. r[onix.gpu_unified_memory.sizing]
- [x] [serial] Remove the Strix Halo memory parameters from `rdma-cluster` and keep the E810 PCIe parameters there. r[onix.gpu_unified_memory.sizing]
- [x] [serial] Register `gpu-unified-memory` in the Nickel tag registry and assign it to `aspen1` and `aspen2`. r[onix.gpu_unified_memory.registry]

## Phase 2: Fail closed on hardware

- [x] [serial] Assert an RDMA-capable controller in `rdma-cluster`. r[onix.rdma_cluster.assignment.hardware_required]
- [x] [parallel] Move the inventory query into `lib/rdma-hardware.nix` and use it from the tag and the cluster selector. r[onix.rdma_cluster.hardware_query]

## Phase 3: Verification

- [x] [serial] Evaluate both hosts and confirm the rendered kernel parameters keep the memory values and drop the E810 PCIe parameters. r[onix.gpu_unified_memory.validation.rendered]
- [x] [serial] Confirm both hosts still select the USB4 link for cluster traffic. r[onix.gpu_unified_memory.validation.selection]
- [x] [serial] Build both top-level closures. r[onix.gpu_unified_memory.validation.build]
- [x] [serial] Deploy both hosts and confirm the boot entry carries the new parameters while the running kernel keeps the memory values. r[onix.gpu_unified_memory.validation.deploy]
- [ ] [serial] Re-measure inference performance after the next reboot, when IOMMU translation is active for GPU and NVMe DMA. r[onix.gpu_unified_memory.validation.performance]
