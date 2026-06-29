## Why

The Aspen pair now has declarative fast-link selection for RDMA or Thunderbolt, but Lemonade still runs each host independently. Lemonade's current backend is llama.cpp, and the packaged `llamacpp-rocm-rpc` build already enables llama.cpp RPC support. That gives us a narrower integration path than a full vLLM/Ray service: run `llama-rpc-server` on worker hosts and pass `--rpc host:port` to Lemonade's managed `llama-server` on a head host.

## What Changes

- Extend the Lemonade module with opt-in llama.cpp RPC client and worker settings.
- Let the head derive worker endpoints from the existing cluster-network tag when explicit endpoints are not provided.
- Add a managed `lemonade-rpc-worker.service` for worker hosts.
- Build the ROCm llama.cpp package with libibverbs so RPC can auto-negotiate RDMA on RoCE links while still falling back to TCP over Thunderbolt.
- Configure `aspen1` as the Lemonade RPC client/head and `aspen2` as an RPC worker.

## Impact

- **Scope**: Lemonade module schema/rendering, the local ROCm llama.cpp package, and Aspen Lemonade service inventory.
- **Risk**: llama.cpp RPC is marked experimental and insecure upstream; it must only bind to trusted cluster links.
- **Non-goals**: Do not replace Lemonade with vLLM/Ray; do not force all Lemonade instances into a cluster by default.
- **Testing**: Validate Cairn artifacts, build the RPC-capable package, evaluate Aspen Lemonade config, verify rendered `--rpc` args and worker service, and run negative assertions for unsafe/missing RPC endpoints.
