# GPU Unified Memory Specification

## Purpose

Define how an APU inference host sizes the memory that the GPU may map from system memory, and how the requirement for RDMA hardware is enforced for the RDMA cluster tag.

## Requirements

### Requirement: Per-host unified-memory sizing

r[onix.gpu_unified_memory.sizing] The system MUST set the GTT aperture and the TTM page limit from a per-host size, and MUST fail closed for a tagged host that has no size.

#### Scenario: Tagged host receives its memory parameters

r[onix.gpu_unified_memory.sizing.tagged]
- GIVEN a machine is tagged `gpu-unified-memory` and is listed with a GTT size
- WHEN its NixOS configuration is evaluated
- THEN `amdgpu.gttsize` and `ttm.pages_limit` carry that host's values
- AND the TTM page limit equals the GTT size in MiB multiplied by the page count that a MiB holds
- AND the modprobe option for the TTM page limit overrides the default that the `amd-gpu` tag sets

#### Scenario: Unlisted host fails closed

r[onix.gpu_unified_memory.sizing.unlisted]
- GIVEN a machine is tagged `gpu-unified-memory` but has no GTT size
- WHEN its NixOS configuration is evaluated
- THEN evaluation fails with a diagnostic that names the sizing map

### Requirement: Tag registration

r[onix.gpu_unified_memory.registry] The system MUST register `gpu-unified-memory` in the Nickel tag registry so inventory validation accepts it.

#### Scenario: Registry accepts the tag

r[onix.gpu_unified_memory.registry.accepted]
- GIVEN `gpu-unified-memory` is listed in the tag registry
- WHEN `aspen1` and `aspen2` assign the tag
- THEN Nickel machine validation accepts both hosts

### Requirement: RDMA hardware requirement

r[onix.rdma_cluster.assignment.hardware_required] The `rdma-cluster` tag MUST fail closed for a host whose hardware inventory lists no RDMA-capable network controller.

#### Scenario: Host without a controller fails evaluation

r[onix.rdma_cluster.assignment.hardware_required.absent]
- GIVEN a machine is tagged `rdma-cluster`
- AND its hardware inventory lists no RDMA-capable network controller
- WHEN its NixOS configuration is evaluated
- THEN evaluation fails with a diagnostic that names the inventory file

#### Scenario: Host with a controller is accepted

r[onix.rdma_cluster.assignment.hardware_required.present]
- GIVEN a machine is tagged `rdma-cluster`
- AND its hardware inventory lists an RDMA-capable network controller
- WHEN its NixOS configuration is evaluated
- THEN evaluation succeeds with the RDMA network configuration

### Requirement: Shared hardware query

r[onix.rdma_cluster.hardware_query] The system MUST answer "does this host have an RDMA controller" from one shared query that the RDMA tag and the cluster network selector both use.

#### Scenario: Both consumers agree

r[onix.rdma_cluster.hardware_query.shared]
- GIVEN the RDMA tag asserts the controller and the selector checks it
- WHEN the hardware inventory changes for a host
- THEN both consumers change their answer together
- AND a host without a controller selects the USB4 link instead of a missing interface

### Requirement: Validation evidence

r[onix.gpu_unified_memory.validation] The change MUST include positive and negative evidence for the rendered parameters, the selection, and the build.

#### Scenario: Rendered parameters are proven

r[onix.gpu_unified_memory.validation.rendered]
- GIVEN both hosts are tagged `gpu-unified-memory` and tagged `thunderbolt-link`
- WHEN their configurations are evaluated
- THEN the memory parameters render with the preserved values
- AND no `iommu=`, `pci=`, or `pcie_aspm=` parameter renders

#### Scenario: Selection is proven

r[onix.gpu_unified_memory.validation.selection]
- GIVEN both hosts no longer carry the `rdma-cluster` tag
- WHEN their cluster env is rendered
- THEN each selects the thunderbolt backend on the link interface

#### Scenario: Closures build

r[onix.gpu_unified_memory.validation.build]
- GIVEN the change is in the working tree
- WHEN both top-level closures are built
- THEN both builds succeed

#### Scenario: Deploy and reboot effects are recorded

r[onix.gpu_unified_memory.validation.deploy]
- GIVEN the change is deployed to both hosts
- WHEN the boot entry is inspected
- THEN it carries the new parameters
- AND the running kernel keeps the memory parameters from the previous boot until a reboot

#### Scenario: Performance is re-measured after the reboot

r[onix.gpu_unified_memory.validation.performance]
- GIVEN a host reboots with IOMMU translation active
- WHEN inference and storage performance are measured
- THEN the measurement is compared with the 124 GiB passthrough baseline before the change is accepted as complete
