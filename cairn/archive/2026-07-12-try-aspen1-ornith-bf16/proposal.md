## Why

`aspen1` has enough live memory and disk headroom to attempt the official 69.38 GB Ornith 1.0 35B BF16 GGUF. The current 35B Q4_K_M endpoint is healthy, but a BF16 trial can determine whether higher precision improves the local coding model without guessing from artifact size alone.

## What Changes

- Register and pull `user.Ornith-1.0-35B-BF16` on `aspen1`.
- Keep the live-validated 35B Q4_K_M model available as the rollback target.
- Deploy the model registry change and accept BF16 only after a live response and resource-health probe.

## Impact

- **Files**: `inventory/services/services.ncl` and this Cairn change package
- **Risk**: BF16 may exhaust unified GPU memory, fail in the current llama.cpp runtime, or expose the same artifact-family defect observed in Q8.
- **Testing**: Nickel contract export, Aspen1 system evaluation/deploy, model-download status, positive BF16 inference, negative failure inspection, memory health, Q4 fallback inference, and Cairn validation/gates.
