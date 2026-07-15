## Phase 1: Reproducible evidence

- [x] [serial] Add a functional-core Rust benchmark harness with positive and negative self-tests for fixed-input isolated and synchronized concurrent measurements. r[onix.tenstorrent.model_performance.concurrent_serving]
- [x] [serial] Record five-run isolated and concurrent baselines plus non-mutating CPU, PCIe, service-thread, and runtime evidence. r[onix.tenstorrent.model_performance.concurrent_serving]

## Phase 2: Bounded candidate search

- [x] [serial] Test explicit llama.cpp worker budgets against the declared Pareto-safe acceptance rule and roll back any regression. r[onix.tenstorrent.model_performance.concurrent_serving]
- [x] [serial] Test disjoint CCD-aware service placement, or the justified combined final candidate, and retain only validated settings. r[onix.tenstorrent.model_performance.concurrent_serving]

## Phase 3: Verification

- [x] [serial] Add focused positive/negative Nix checks and operator guidance for the validated boundary, or record that all candidates were falsified. r[onix.tenstorrent.model_performance.concurrent_serving]
- [ ] [serial] Run the complete host build, deploy, repeat isolated/concurrent benchmarks, audit journals and restarts, then sync and archive with checked evidence or an exact bounded blocker. r[onix.tenstorrent.model_performance.concurrent_serving]
