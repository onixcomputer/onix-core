## Phase 1: Model the tag

- [x] [serial] Add an `rdma-cluster` tag module for Intel E810/RoCE host readiness. r[onix.rdma_cluster.tag]
- [x] [serial] Register `rdma-cluster` in the Nickel tag registry. r[onix.rdma_cluster.registry]
- [x] [serial] Apply the tag to `aspen1` and `aspen2`. r[onix.rdma_cluster.assignment]

## Phase 2: Add runtime network selection

- [x] [serial] Add a `vllm-cluster-network` tag that exports the selected Ray/vLLM/RCCL network environment. r[onix.rdma_cluster.vllm_selector]
- [x] [serial] Register and assign `vllm-cluster-network` to `aspen1` and `aspen2`. r[onix.rdma_cluster.registry] r[onix.rdma_cluster.assignment]
- [x] [serial] Verify RDMA-preferred rendering, Thunderbolt fallback rendering, and fail-closed selector assertions. r[onix.rdma_cluster.vllm_selector] r[onix.rdma_cluster.validation]

## Phase 3: Preserve evidence and validation

- [x] [serial] Add the upstream toolbox guide to README references. r[onix.rdma_cluster.reference]
- [x] [serial] Run Cairn validation, tag-registry sync, and Nix evaluation for the tagged Aspen hosts. r[onix.rdma_cluster.validation]
