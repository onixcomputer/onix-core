## Why

The native llama.cpp Metalium runtime can generate with VibeThinker-3B, but its experimental `1x2` mesh path replicates work and reduces measured decode throughput from about 20.2 tokens/s on Blackhole device 0 to about 2.0 tokens/s on the linked mesh. The existing `llamacpp-server` service cannot select the pinned Metalium package or express its mandatory CPU KV-cache boundary, so the validated fast path is not deployable declaratively.

## What Changes

- Add a Metalium backend to the schema-driven `llamacpp-server` service, including explicit Blackhole device selection.
- Enforce Metalium's current runtime boundaries: CPU KV cache, no flash attention, unquantized F16 KV storage, tracing disabled, and no llama.cpp mesh aggregation.
- Move `britton-desktop` VibeThinker serving to the pinned Q8_0 model on Blackhole device 0 with the measured batch configuration.
- Preserve the system-wide P150x2 descriptor for native TT-NN and TT-Metal workloads; only the latency-oriented llama.cpp service avoids the experimental mesh execution path.

## Impact

- **Files**: `modules/llamacpp-server/{default.nix,schema.ncl}`, `inventory/services/services.ncl`, and this Cairn change package
- **Testing**: positive and negative module evaluation, `britton-desktop` service evaluation, formatting, pre-commit, Cairn gates/validation, and an OpenAI-compatible Metalium generation smoke test
