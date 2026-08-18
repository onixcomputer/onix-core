## Phase 1: Package and module support

- [x] [serial] Build `llamacpp-rocm-rpc` with libibverbs/RDMA RPC support. r[onix.lemonade.cluster_rpc.package]
- [x] [serial] Extend the Lemonade schema with opt-in RPC client and worker settings. r[onix.lemonade.cluster_rpc.schema]
- [x] [serial] Render `--rpc` worker endpoints into Lemonade llama.cpp args when client mode is enabled. r[onix.lemonade.cluster_rpc.client]
- [x] [serial] Add a managed `lemonade-rpc-worker.service` for worker mode. r[onix.lemonade.cluster_rpc.worker]
- [x] [serial] Expose cluster-network metadata for modules that need selected fast-link addresses. r[onix.lemonade.cluster_rpc.network]

## Phase 2: Aspen wiring

- [x] [serial] Configure `aspen1` as the Lemonade RPC client/head. r[onix.lemonade.cluster_rpc.aspen]
- [x] [serial] Configure `aspen2` as a Lemonade RPC worker. r[onix.lemonade.cluster_rpc.aspen]

## Phase 3: Validation

- [x] [serial] Run positive checks for package build, Aspen eval, rendered head `--rpc` args, and worker service. r[onix.lemonade.cluster_rpc.validation]
- [x] [serial] Run negative checks for client-without-endpoints, duplicate manual `--rpc`, and worker-without-bind-address. r[onix.lemonade.cluster_rpc.validation]
- [x] [serial] Run Cairn validation. r[onix.lemonade.cluster_rpc.validation]
