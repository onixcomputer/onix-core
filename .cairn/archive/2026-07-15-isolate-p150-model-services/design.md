## Context

The deployed host has two separate Blackhole P150 cards exposed as `/dev/tenstorrent/0` and `/dev/tenstorrent/1`. VibeThinker currently runs through Metalium on card 0, while Supra-Router-51M runs through CUDA.

The official TT-Metal report `Programming_Mesh_of_Devices_with_TT-NN.md`, section 2.3, specifies that concurrent processes on different cards MUST set `TT_VISIBLE_DEVICES` to physical PCIe device IDs and MUST use unique `TT_METAL_CACHE` paths. Filtering remaps each process's visible hardware to logical device 0.

A controlled concurrent test established:

- VibeThinker process: `TT_VISIBLE_DEVICES=0`, logical `GGML_METALIUM_DEVICE_ID=0`.
- Supra process: `TT_VISIBLE_DEVICES=1`, logical `GGML_METALIUM_DEVICE_ID=0`.
- Supra UMD log: local logical chip `{0}` mapped to physical PCIe device `[1]`.
- Concurrent VibeThinker request: HTTP 200, 17.60 decode tokens/s for the bounded 64-token probe.
- Concurrent Supra request: HTTP 200, correct routing schema, 31.65 decode tokens/s, 2.55 seconds end-to-end.
- Isolated single-card Supra before concurrent load: 37.61 decode tokens/s, 2.08 seconds end-to-end.
- Existing CUDA Supra baseline: 687.72 decode tokens/s, 0.14 seconds end-to-end.

The Tenstorrent deployment is therefore a resource-placement decision that frees the NVIDIA GPU; it is not a Supra latency optimization.

## Decisions

### Decision: Partition by physical PCIe visibility

**Choice:** Treat the configured `metaliumDeviceId` as the physical `/dev/tenstorrent/<id>` selector, export it through `TT_VISIBLE_DEVICES`, and always set `GGML_METALIUM_DEVICE_ID=0` inside the filtered process.

**Rationale:** TT-Metal remaps a filtered process to zero-based logical IDs. This avoids cross-process `CHIP_IN_USE` contention and follows the official single-host multiprocess contract.

### Decision: Isolate mutable runtime state

**Choice:** Assign each service a cache under its state directory, a logs directory under its state directory, and a distinct inspector RPC address.

**Rationale:** TT-Metal explicitly requires unique compilation caches. Separate logs prevent the large generated inspector artifacts seen during ad hoc runs from colliding or entering the repository. Distinct inspector ports remove the otherwise harmless `127.0.0.1:50051` bind collision.

### Decision: Keep both services single-card

**Choice:** Run VibeThinker on physical card 0 and Supra-Router-51M on physical card 1 without `GGML_METALIUM_MESH_SHAPE` or `TT_MESH_GRAPH_DESC_PATH` in either process.

**Rationale:** The experimental llama.cpp P150x2 path replicated work and was slower for both models. The global P150x2 descriptor remains available for TT-NN and explicitly mesh-aware applications.

### Decision: Preserve the Supra API endpoint

**Choice:** Keep Supra on port 13306 with its existing model path, alias, deterministic temperature, and service name while replacing only the acceleration backend and Metalium-specific arguments.

**Rationale:** Existing local routing clients continue working without endpoint migration.

## Risks / Trade-offs

- Supra drops from about 688 CUDA decode tokens/s to about 32–38 Metalium decode tokens/s, but typical routing output remains around 56 tokens and completes in roughly 2–3 seconds.
- Both Metalium processes still use experimental llama.cpp support and CPU KV cache.
- Firmware 18.8.0.0 remains in supported single-ERISC compatibility mode.
- Inspector RPC addresses are diagnostic surfaces only and remain bound to loopback.
