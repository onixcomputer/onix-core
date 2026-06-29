# rdma-cluster Specification

## Purpose

Define declarative host readiness for a two-node AMD Strix Halo RDMA inference cluster using Intel E810 RoCE v2 networking.

## Requirements

### Requirement: Host RDMA tag

r[onix.rdma_cluster.tag] The system MUST provide an `rdma-cluster` tag that prepares a tagged NixOS host for Intel E810 RoCE v2 operation.

#### Scenario: RDMA host tools and drivers are configured

r[onix.rdma_cluster.tag.host_ready]
- GIVEN a machine is tagged `rdma-cluster`
- WHEN its NixOS configuration is evaluated
- THEN Intel E810 Ethernet and RDMA kernel modules are requested
- AND RDMA userspace and link-verification tools are installed
- AND RDMA device nodes are assigned to an `rdma` access group

#### Scenario: Strix Halo memory tuning is configured

r[onix.rdma_cluster.tag.memory_tuning]
- GIVEN a machine is tagged `rdma-cluster`
- WHEN its boot configuration is evaluated
- THEN the Strix Halo GTT size and TTM page-limit parameters from the reference guide are present
- AND IOMMU pass-through, PCI BAR reallocation, and PCIe ASPM disablement are present

### Requirement: Static two-node RDMA network

r[onix.rdma_cluster.assignment] The system MUST assign the RDMA direct-link network only to hosts with explicit static address mappings.

#### Scenario: Aspen pair receives RDMA addresses

r[onix.rdma_cluster.assignment.aspen_pair]
- GIVEN `aspen1` and `aspen2` are tagged `rdma-cluster`
- WHEN their NixOS network configuration is evaluated
- THEN `aspen1` receives `192.168.100.1/30` on `rdma0`
- AND `aspen2` receives `192.168.100.2/30` on `rdma0`
- AND the `rdma0` interface is trusted by the firewall

#### Scenario: Unknown host fails closed

r[onix.rdma_cluster.assignment.unknown_host]
- GIVEN a host without a static RDMA address mapping is tagged `rdma-cluster`
- WHEN its NixOS configuration is evaluated
- THEN evaluation fails with a diagnostic directing the operator to add a mapping before assigning the tag

### Requirement: Tag registry consistency

r[onix.rdma_cluster.registry] The system MUST register `rdma-cluster` and `vllm-cluster-network` in the Nickel tag registry so machine inventory validation accepts them and tag-sync checks require their `.nix` files.

#### Scenario: Registered tags can be assigned

r[onix.rdma_cluster.registry.valid]
- GIVEN `rdma-cluster` and `vllm-cluster-network` are present in `inventory/core/contracts.ncl`
- WHEN `inventory/core/machines.ncl` assigns the tags to the Aspen pair
- THEN Nickel machine validation accepts the tags

### Requirement: vLLM cluster network selector

r[onix.rdma_cluster.vllm_selector] The system MUST provide a `vllm-cluster-network` tag that exports the selected Ray/vLLM/RCCL network environment for tagged cluster hosts.

#### Scenario: RDMA is preferred when available

r[onix.rdma_cluster.vllm_selector.rdma_preferred]
- GIVEN a host has both `rdma-cluster` and `vllm-cluster-network`
- WHEN its NixOS configuration renders `/etc/vllm-cluster/network.env`
- THEN `VLLM_CLUSTER_BACKEND` is `rdma`
- AND `VLLM_CLUSTER_INTERFACE` is `rdma0`
- AND `NCCL_SOCKET_IFNAME` targets `rdma0`

#### Scenario: Thunderbolt fallback is selected without RDMA

r[onix.rdma_cluster.vllm_selector.thunderbolt_fallback]
- GIVEN a host has `thunderbolt-link` and `vllm-cluster-network` but not `rdma-cluster`
- WHEN its NixOS configuration renders `/etc/vllm-cluster/network.env`
- THEN `VLLM_CLUSTER_BACKEND` is `thunderbolt`
- AND `VLLM_CLUSTER_INTERFACE` is `br-tbt`
- AND `NCCL_IB_DISABLE` disables RDMA transport

#### Scenario: Selector fails without a backing network

r[onix.rdma_cluster.vllm_selector.no_backing_network]
- GIVEN a host has `vllm-cluster-network` but neither `rdma-cluster` nor `thunderbolt-link`
- WHEN its NixOS configuration is evaluated
- THEN evaluation fails with a diagnostic directing the operator to add one backing network tag

### Requirement: Upstream reference is recorded

r[onix.rdma_cluster.reference] The system MUST record the upstream AMD Strix Halo RDMA toolbox guide as a project reference.

#### Scenario: README reference includes upstream guide

r[onix.rdma_cluster.reference.readme]
- GIVEN the RDMA tag is based on the upstream toolbox guide
- WHEN a maintainer inspects `README.md`
- THEN the guide repository is listed under `## References`

### Requirement: Positive and negative validation

r[onix.rdma_cluster.validation] The system MUST include validation evidence for the accepted Aspen assignment, the selected env rendering, Thunderbolt fallback, and fail-closed guards.

#### Scenario: Aspen assignment validates

r[onix.rdma_cluster.validation.positive]
- GIVEN the Aspen pair is tagged `rdma-cluster` and `vllm-cluster-network`
- WHEN focused Nix evaluation checks run for both machines
- THEN both configurations evaluate successfully
- AND the rendered cluster env points at the expected selected interface

#### Scenario: Missing mapping guard remains active

r[onix.rdma_cluster.validation.negative]
- GIVEN the `rdma-cluster` tag has a closed static address map
- WHEN the tag module is inspected or evaluated outside the mapped hosts
- THEN the missing-address assertion remains present

#### Scenario: Selector fallback and failure checks pass

r[onix.rdma_cluster.validation.selector]
- GIVEN focused evaluations exercise RDMA-preferred, Thunderbolt-only, and no-backing-network selector cases
- WHEN those evaluations run
- THEN RDMA-preferred and Thunderbolt-only cases render the expected env values
- AND the no-backing-network case fails with the expected diagnostic
