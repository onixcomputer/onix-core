## Context

`rdma-cluster` was the only place that set `amdgpu.gttsize=126976` and `ttm.pages_limit=32505856`, and it did so with `lib.mkAfter` on `extraModprobeConfig`, which overrode the `amd-gpu` default of 26214400 pages. Live state on 2026-09-14 confirmed the override: `ttm.pages_limit` read 32505856 on both hosts, and `mem_info_gtt_total` read 126976 MiB on `aspen1`.

Installed memory differs between the two hosts: `MemTotal` is 125 GiB on `aspen1` and 62.6 GiB on `aspen2`, while both hosts claimed a 124 GiB GPU cap. On `aspen2` the kernel clamps the aperture to available memory (`mem_info_gtt_total` read 64079 MiB), so the value is inert there rather than harmful.

## Decisions

### 1. Follow the concern, not the tag history

**Choice:** Create `gpu-unified-memory` for the GTT and TTM values, and keep `rdma-cluster` for the E810.

**Rationale:** The values answer "how much system memory may the GPU map", which is an APU question and follows installed memory. `iommu=pt`, `pci=realloc`, and `pcie_aspm=off` answer "make an add-in RoCE card behave", which is an E810 question. One tag that owns both cannot be assigned honestly on a host that has one and not the other.

### 2. Size the aperture from installed memory

**Choice:** Each host entry states its installed memory, and the tag computes the aperture as three quarters of it (a quarter stays with the OS and CPU workloads). `aspen1` therefore renders 96 GiB of aperture and 25165824 TTM pages, and `aspen2` renders 48 GiB and 12582912 pages.

**Rationale:** A copied value is what produced the defect: both hosts claimed a 124 GiB cap, which exceeds the 64 GiB that `aspen2` has installed and leaves about 4 GiB to the OS on `aspen1`. A reserve stated once, in a divisor, keeps the relationship visible and reviewable for the next host added to the tag.

**Evidence for the values:** `MemTotal` reads 125 GiB on `aspen1` and 62.6 GiB on `aspen2`. The hardware inventory holds one memory device per host (32 GiB and 64 GiB), so it cannot supply the installed total and the entries state it directly. `aspen1` had 73 GiB in use while serving inference, which the 96 GiB aperture still covers.

**Deferred measurement:** the change reaches the kernel at the next boot. Inference throughput must be compared against the current 124 GiB passthrough baseline after that boot, because a smaller aperture can refuse an allocation that previously succeeded.

### 3. The RDMA tag fails closed

**Choice:** `rdma-cluster` asserts that the host inventory lists an RDMA-capable controller driver.

**Rationale:** The defect was not the tag itself but its assignment to hosts with no such hardware. An assertion turns the next such assignment into an evaluation error with a message that names the inventory file.

### 4. One hardware query, two consumers

**Choice:** `lib/rdma-hardware.nix` owns the driver list and the inventory lookup. The tag and the cluster network selector both call it.

**Rationale:** A second copy of the driver list would drift, and the two consumers must agree on what "has an RDMA controller" means. The tag fails closed; the selector also checks, so a host that keeps the tag after its controller is removed still selects the USB4 link instead of a missing interface.

## Verification results (2026-09-14)

- Evaluation on both hosts renders `amdgpu.gttsize=98304`, `ttm.pages_limit=25165824`, and `options ttm pages_limit=25165824` on `aspen1`, and `49152`/`12582912` on `aspen2`. Neither host renders an `iommu=`, `pci=`, or `pcie_aspm=` parameter.
- The boot entry carries the new values (`/run/current-system/kernel-params`), while the running kernel keeps `iommu=pt` and the 126976 MiB aperture until the next reboot.
- The cluster env still renders `VLLM_CLUSTER_BACKEND=thunderbolt` and `VLLM_CLUSTER_INTERFACE=br-tbt` on both hosts.
- Both top-level closures build.
- The RDMA assertion rejects a tagged host without a controller, and the tag registry accepts the new tag.

## Risks / Trade-offs

- The aspen hosts keep a GPU cap that exceeds installed memory on `aspen2`. That is inert today and is recorded as an open decision.
- New files must be added to the git index before evaluation, because a flake source tree omits untracked files. An untracked tag file therefore evaluates as if the tag did not exist.
- `iommu=pt` removal takes effect at the next boot only. Until then the USB4 port keeps passthrough DMA, and `iommu_dma_protection` already reported `1` before and after the earlier link change.
