## Context

`rdma-cluster` was the only place that set `amdgpu.gttsize=126976` and `ttm.pages_limit=32505856`, and it did so with `lib.mkAfter` on `extraModprobeConfig`, which overrode the `amd-gpu` default of 26214400 pages. Live state on 2026-09-14 confirmed the override: `ttm.pages_limit` read 32505856 on both hosts, and `mem_info_gtt_total` read 126976 MiB on `aspen1`.

Installed memory differs between the two hosts: `MemTotal` is 125 GiB on `aspen1` and 62.6 GiB on `aspen2`, while both hosts claimed a 124 GiB GPU cap. On `aspen2` the kernel clamps the aperture to available memory (`mem_info_gtt_total` read 64079 MiB), so the value is inert there rather than harmful.

## Decisions

### 1. Follow the concern, not the tag history

**Choice:** Create `gpu-unified-memory` for the GTT and TTM values, and keep `rdma-cluster` for the E810.

**Rationale:** The values answer "how much system memory may the GPU map", which is an APU question and follows installed memory. `iommu=pt`, `pci=realloc`, and `pcie_aspm=off` answer "make an add-in RoCE card behave", which is an E810 question. One tag that owns both cannot be assigned honestly on a host that has one and not the other.

### 2. Preserve the values the workloads were sized against

**Choice:** Keep `amdgpu.gttsize=126976` and `ttm.pages_limit=32505856` for both hosts, moved into the new tag, and record the `aspen2` mismatch as an open decision.

**Rationale:** `aspen1` had 73 GiB of memory in use while serving inference, so lowering its cap is a behaviour change that needs a measurement, not a refactor. `aspen2` clamps the aperture to installed memory, so its value is inert. Changing either value belongs to a tuning change with inference evidence.

### 3. The RDMA tag fails closed

**Choice:** `rdma-cluster` asserts that the host inventory lists an RDMA-capable controller driver.

**Rationale:** The defect was not the tag itself but its assignment to hosts with no such hardware. An assertion turns the next such assignment into an evaluation error with a message that names the inventory file.

### 4. One hardware query, two consumers

**Choice:** `lib/rdma-hardware.nix` owns the driver list and the inventory lookup. The tag and the cluster network selector both call it.

**Rationale:** A second copy of the driver list would drift, and the two consumers must agree on what "has an RDMA controller" means. The tag fails closed; the selector also checks, so a host that keeps the tag after its controller is removed still selects the USB4 link instead of a missing interface.

## Verification results (2026-09-14)

- Evaluation on both hosts renders `amdgpu.gttsize=126976`, `ttm.pages_limit=32505856`, and `options ttm pages_limit=32505856`, and renders no `iommu=`, `pci=`, or `pcie_aspm=` parameter.
- The cluster env still renders `VLLM_CLUSTER_BACKEND=thunderbolt` and `VLLM_CLUSTER_INTERFACE=br-tbt` on both hosts.
- Both top-level closures build.
- The RDMA assertion rejects a tagged host without a controller, and the tag registry accepts the new tag.

## Risks / Trade-offs

- The aspen hosts keep a GPU cap that exceeds installed memory on `aspen2`. That is inert today and is recorded as an open decision.
- New files must be added to the git index before evaluation, because a flake source tree omits untracked files. An untracked tag file therefore evaluates as if the tag did not exist.
- `iommu=pt` removal takes effect at the next boot only. Until then the USB4 port keeps passthrough DMA, and `iommu_dma_protection` already reported `1` before and after the earlier link change.
