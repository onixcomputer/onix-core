# Tenstorrent Model Performance Specification

## Purpose

Defines the `tenstorrent-model-performance` capability.

## Requirements

### Requirement: Metalium trace replay is evidence-gated

r[onix.tenstorrent.model_performance.trace_replay] A Metalium model service that enables experimental command-trace replay MUST opt in per service, MUST preserve its physical-device and mutable-state isolation, MUST prewarm validated graph shapes before dependent traffic, and MUST remain trace-enabled only when an identical fixed-input benchmark demonstrates correct output and a material warm-performance improvement beyond the declared noise tolerance.

#### Scenario: Trace replay materially improves a model service

- GIVEN a healthy single-card Metalium service with recorded fixed-input baseline evidence
- WHEN trace replay is enabled, the validated graph shape is prewarmed, and the same benchmark is repeated
- THEN the service returns successful responses with the expected output structure and token count
- AND median warm decode throughput improves beyond the declared noise tolerance
- AND service journals show no new restart, device-contention, or fatal runtime failure

#### Scenario: Trace replay is unsafe or not materially faster

- GIVEN a trace-enabled candidate service
- WHEN the repeated benchmark crashes, changes required output behavior, contends for another physical card, or fails to improve beyond the declared noise tolerance
- THEN the declarative service configuration disables trace replay
- AND the known-good isolated service remains available without an automated firmware mutation

#### Scenario: Cold trace passes are removed from normal traffic

- GIVEN a model service whose trace candidate passed the fixed-input benchmark
- WHEN the service starts after activation or reboot
- THEN a bounded readiness-aware warmup completes the eager and capture passes before dependent traffic is admitted
- AND a warmup timeout or malformed response is reported without retrying indefinitely

### Requirement: Concurrent Metalium tuning is evidence-gated

r[onix.tenstorrent.model_performance.concurrent_serving] A host-level CPU worker or placement optimization for independent Metalium model services MUST be adopted only when repeated synchronized fixed-input benchmarks preserve required output behavior and isolated throughput within the declared noise tolerance, do not transfer a material regression to either concurrent service, and materially improve the normalized concurrent-retention objective.

#### Scenario: Concurrent candidate improves the deployed services

- GIVEN two healthy Metalium services on isolated physical cards with recorded isolated and synchronized concurrent baselines
- WHEN a bounded worker-budget or CPU-placement candidate is benchmarked with identical deterministic requests
- THEN every response has the expected output structure and token count
- AND neither service materially regresses in isolated or concurrent median decode throughput
- AND normalized concurrent retention improves beyond the declared noise tolerance
- AND both services remain active without a new restart, device-contention failure, or fatal runtime error

#### Scenario: Concurrent candidate transfers or adds a regression

- GIVEN a worker-budget or CPU-placement candidate under synchronized load
- WHEN either service materially regresses, required output changes, or the normalized objective fails to improve beyond noise
- THEN the candidate is rejected or rolled back
- AND model quality, physical-card isolation, trace policy, and firmware remain unchanged

### Requirement: Managed VibeThinker benchmark matrix

r[onix.tenstorrent.model_performance.managed_benchmark] `britton-desktop` SHALL expose a manually invoked, Nix-managed VibeThinker Metalium benchmark that MUST compare physical device 0, physical device 1, and the reported P150x2 `1x2` mesh with fixed inputs and bounded case execution, MUST validate the emitted topology and measurements, MUST isolate all mutable runtime artifacts outside the source repository, and MUST restore VibeThinker plus the card-1 P150 Llama service to their individual prior active states after success or failure.

#### Scenario: Active production services are benchmarked and restored

- GIVEN VibeThinker and the card-1 P150 Llama service are active and the Q8_0 model is present
- WHEN an authorized operator starts the managed benchmark
- THEN the runner stops both device owners before acquiring either P150
- AND it runs the fixed device-0, device-1, and reported `1x2` matrix
- AND it writes validated per-case results plus a summary under its systemd-managed state directory
- AND it restarts both previously active services after the matrix completes

#### Scenario: A production service was already inactive

- GIVEN either VibeThinker or the card-1 P150 Llama service is inactive before the benchmark starts
- WHEN the managed matrix completes
- THEN the runner leaves that previously inactive service inactive
- AND it does not misrepresent an initially inactive service as restored

#### Scenario: Benchmark output is invalid or execution fails

- GIVEN one or both managed P150 services were active before the benchmark
- WHEN a benchmark command fails, times out, emits malformed measurements, or reports the wrong mesh topology
- THEN the managed benchmark exits unsuccessfully with a bounded diagnostic
- AND its cleanup path restarts each previously active managed service
- AND no successful summary replaces the previous accepted result

#### Scenario: Benchmark starts from the source repository

- GIVEN an operator invokes the managed command from an `onix-core` worktree
- WHEN TT-Metal emits cache, Inspector, watcher, or benchmark artifacts
- THEN those artifacts are written only below the benchmark's systemd-managed state, cache, and log directories
- AND the worktree receives no generated runtime directory
