# Tenstorrent Model Performance Delta

## ADDED Requirements

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
