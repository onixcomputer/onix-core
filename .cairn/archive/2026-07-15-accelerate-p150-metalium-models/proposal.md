## Why

The two Blackhole P150 services are healthy but leave avoidable latency in the experimental llama.cpp Metalium path. A fixed warm baseline on 2026-07-15 measured about 22 decode tokens/s for VibeThinker-3B and 89 decode tokens/s for Supra-Router-51M, while the backend ships an opt-in capture/replay path intended to remove repeated host dispatch. Firmware mutation, mesh aggregation, lower-quality quantization, and unsupported inference-server migrations must not be mistaken for validated improvements.

## What Changes

- Add an evidence-gated rollout for Metalium trace replay, starting with the smaller Supra router and expanding to VibeThinker only after deterministic before/after measurements pass.
- Prewarm validated trace shapes before normal traffic so compilation and capture do not consume the first user requests.
- Preserve physical-card isolation, model output behavior, API endpoints, CPU KV cache, and the manual firmware boundary.
- Record negative-path rollback criteria so crashes, output drift, regressions within the declared noise tolerance, or device contention leave tracing disabled.

## Impact

- **Files**: `machines/britton-desktop/configuration.nix`, `inventory/services/services.ncl`, focused flake checks, Tenstorrent operator documentation, and this Cairn change package
- **Testing**: Cairn gates, focused Nix evaluation checks, service health/journal inspection, identical fixed-input warm benchmarks, output comparison, and post-deploy restart/error checks
