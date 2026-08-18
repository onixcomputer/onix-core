## Context

VibeThinker-3B is a 3.09B-parameter Qwen2 model with 36 layers, two KV heads, and a 131072-token training context. The pinned Metalium fork requires `--no-kv-offload`; attempting Q8_0 KV storage fails context creation, and enabling flash attention cannot repair that unsupported cache placement.

Bounded local measurements used identical Q8_0 weights, 64 prompt tokens, 32 generated tokens, three repetitions, batch/ubatch 512, F16 CPU KV cache, and tracing off unless named otherwise:

- Blackhole device 0: about 20.2 decode tokens/s.
- Blackhole `1x2` mesh: about 2.0 decode tokens/s.
- Blackhole device 1: about 7.0 decode tokens/s; this card is connected at PCIe Gen5 x4 rather than device 0's Gen5 x8.
- Device 0 with trace capture: about 7.7 decode tokens/s.
- Device 0 with Q4_K_M weights: about 6.0 decode tokens/s.

The actual `llama-server` OpenAI path on device 0 sustained 20.9, 21.7, and 21.6 decode tokens/s across three requests after model warmup. The old mesh smoke test sustained about 1.9 tokens/s.

Deployed production evidence on 2026-07-14 confirmed:

- `/health` returned `{"status":"ok"}` after the NixOS switch.
- The service opened only `METALIUM0`, reported Blackhole device ID 0 with 32595 MiB, and did not expose the 1x2 llama.cpp mesh backend.
- The first OpenAI-compatible request decoded 64 tokens at 18.80 tokens/s; a warm request decoded 64 tokens at 22.08 tokens/s.
- The generated unit retained `GGML_METALIUM_DEVICE_ID=0`, `GGML_METALIUM_TRACE=0`, and `UnsetEnvironment=GGML_METALIUM_MESH_SHAPE`.

## Decisions

### Decision: Serve latency-sensitive requests on device 0

**Choice:** Set `GGML_METALIUM_DEVICE_ID=0` and explicitly remove `GGML_METALIUM_MESH_SHAPE` from the service environment.

**Rationale:** This is the only tested configuration that preserves the backend's approximately 20 tokens/s decode path. The current mesh implementation exposes one logical backend and replicates operations rather than providing useful tensor parallelism.

### Decision: Keep Q8_0 weights and F16 CPU KV cache

**Choice:** Retain `VibeThinker-3B.Q8_0.gguf`, pass `--no-kv-offload`, and omit cache quantization overrides.

**Rationale:** Q8_0 maps to the backend's BFP8 path and measured more than three times faster than Q4_K_M. Q8_0 CPU KV configuration failed context creation, while the default F16 CPU cache passed both benchmark and server generation.

### Decision: Keep experimental acceleration switches off

**Choice:** Set `GGML_METALIUM_TRACE=0`, reject flash attention for Metalium service configurations, and leave the graph compiler and program cache enabled at their defaults.

**Rationale:** Trace capture reduced single-card Q8_0 decode throughput by more than half. Flash attention is unavailable with the mandatory CPU KV cache. The graph compiler and program cache provide the stable fused path used by the successful measurements.

### Decision: Preserve the physical P150x2 topology independently

**Choice:** Keep `TT_MESH_GRAPH_DESC_PATH` and the `p150_x2` descriptor in the Tenstorrent host tag.

**Rationale:** TT-NN, TT-Metal, and future vLLM work still require correct physical topology. Avoiding llama.cpp mesh aggregation is an application-level performance choice, not a reclassification of the hardware.

## Risks / Trade-offs

- The Metalium backend is experimental and currently requires Nix-side Blackhole compatibility patches.
- Firmware 18.8.0 forces single-ERISC compatibility mode; the packaged 19.11.0 update remains a separate manual operation.
- Device 1 remains available but is not added as a replica until concurrent independent-device ownership is validated.
- F16 CPU KV cache consumes more host memory than Q8_0 KV storage, but the latter currently fails Metalium context creation.
