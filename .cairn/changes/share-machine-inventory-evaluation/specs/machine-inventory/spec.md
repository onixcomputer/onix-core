## ADDED Requirements

### Requirement: Share machine inventory evaluation

r[onix.inventory.machine_evaluation.shared] Direct Nix consumers of the core machine registry MUST share one contract-validated raw machine value within a flake evaluation. Existing Nickel-local imports remain independent.

#### Scenario: Multiple inventory consumers

- GIVEN one evaluation requests Clan inventory, machine-library queries, tag arguments, and checks for multiple platforms
- WHEN those consumers require core machine definitions
- THEN they reuse the same lazy value without independently invoking the Nickel evaluator for that registry

### Requirement: Preserve inventory behavior

r[onix.inventory.machine_evaluation.preserved] Sharing MUST preserve raw machine fields, names, tag membership, the Clan projection, platform check membership, and generated machine configuration.

#### Scenario: Raw and projected machine data

- GIVEN the unchanged Nickel registry
- WHEN the raw definitions and Clan inventory are evaluated
- THEN raw definitions retain system and addresses
- AND only the Clan projection removes those tooling-only fields
- AND names, tags, deployment targets, and generated configuration remain unchanged

### Requirement: Measure the optimization

r[onix.inventory.machine_evaluation.measured] Performance evidence MUST compare fresh evaluator processes using the same workload and disabled evaluation caching, retain repeated timings and output hashes, and distinguish metadata evaluation from full builds.

#### Scenario: Repeated metadata benchmark

- GIVEN the same supported-platform metadata query before and after the change
- WHEN repeated fresh processes evaluate it after a separate warm-up
- THEN their outputs match
- AND retained wall-clock and CPU timings quantify the observed improvement without claiming a full-build speedup
