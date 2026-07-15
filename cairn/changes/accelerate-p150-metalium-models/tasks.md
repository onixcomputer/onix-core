## Phase 1: Bounded trace experiment

- [ ] [serial] Record fixed cold and warm baseline evidence for both services and add positive/negative evaluation assertions for the per-service trace boundary. r[onix.tenstorrent.model_performance.trace_replay]
- [ ] [serial] Enable trace replay for Supra only, deploy the evaluated configuration, and verify service/device isolation before benchmarking. r[onix.tenstorrent.model_performance.trace_replay]
- [ ] [serial] Run repeated identical Supra requests; retain tracing only if output checks pass and median warm throughput clears `minimumMaterialThroughputGainPercent`, otherwise roll it back. r[onix.tenstorrent.model_performance.trace_replay]
- [ ] [serial] If Supra validates, repeat the isolated rollout and deterministic benchmark for VibeThinker. r[onix.tenstorrent.model_performance.trace_replay]

## Phase 2: Production warmup and closeout

- [ ] [serial] Add service-specific readiness and trace-capture warmup for every validated trace-enabled model, including timeout/failure coverage that cannot block the known-good server indefinitely. r[onix.tenstorrent.model_performance.trace_replay]
- [ ] [serial] Run focused Nix checks, Cairn validation/gates, runtime health checks, and final before/after benchmarks; sync and archive only with checked evidence or an exact bounded blocker. r[onix.tenstorrent.model_performance.trace_replay]
