## ADDED Requirements

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
