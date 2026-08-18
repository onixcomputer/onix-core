## Context

Lemonade 10.2.0 launches llama.cpp through `lemonade-router` and reads managed `config.json`, `user_models.json`, and `recipe_options.json` from `/var/lib/lemonade`. The current module already points the ROCm backend at `pkgs.llamacpp-rocm-rpc`, but it does not start `llama-rpc-server` or pass `--rpc` endpoints to the head process.

The `vllm-cluster-network` tag renders a selected fast-link view for the Aspen pair. Although named for vLLM, the data is also useful for Lemonade because llama.cpp RPC uses ordinary `host:port` endpoints and can auto-negotiate RDMA when the binary is built with libibverbs and the selected endpoint is reachable over RoCE.

## Decisions

### 1. Use llama.cpp RPC instead of vLLM/Ray inside Lemonade

**Choice:** Add Lemonade support around `llama-rpc-server` and llama.cpp's `--rpc` client flag.

**Rationale:** Lemonade's deployed backend is llama.cpp, not vLLM. llama.cpp RPC is the integration surface available in the packaged backend, so it is the smallest viable Lemonade-specific cluster path.

### 2. Make client and worker independent toggles

**Choice:** Expose separate `clusterRpcClient` and `clusterRpcWorker` booleans instead of a single mutually exclusive mode.

**Rationale:** This lets an operator keep a Lemonade API on a worker host while also exposing its accelerator as an RPC worker. That is operationally flexible, but the user must avoid conflicting heavy loads.

### 3. Derive endpoints from cluster-network metadata when possible

**Choice:** If `clusterRpcWorkers` is empty, the client derives endpoints from `config.onix.vllmClusterNetwork.workerAddresses` and `clusterRpcPort`.

**Rationale:** The Aspen topology should not duplicate addresses in the Lemonade inventory. Explicit endpoints remain available for non-Aspen or manually routed clusters.

### 4. Fail closed for unsafe or incomplete RPC config

**Choice:** RPC client mode must render at least one worker endpoint and must not be combined with a manually supplied `--rpc` in `extraArgs`. RPC worker mode must have a concrete bind address from `clusterRpcBindHost` or the cluster-network tag.

**Rationale:** Silent local-only fallback would make operators believe clustering is active when it is not. Duplicate `--rpc` flags are ambiguous. Binding to `0.0.0.0` by default would expose an insecure experimental protocol.

### 5. Enable RDMA in the package, but rely on runtime negotiation

**Choice:** Add `rdma-core` to `llamacpp-rocm-rpc` and force `GGML_RPC_RDMA=ON`; do not add transport-specific command-line flags.

**Rationale:** Upstream llama.cpp RPC negotiates RDMA automatically when both endpoints support it and the network address resolves to a RoCE-capable path. Thunderbolt remains a TCP path without changing Lemonade settings.

## Risks / Trade-offs

- Upstream documents llama.cpp RPC as proof-of-concept and insecure on untrusted networks.
- `clusterRpcWorker = true` can contend with a local Lemonade API on the same host if both are serving at once.
- RDMA negotiation depends on runtime device/GID discovery and must be validated on hardware after deploy.
