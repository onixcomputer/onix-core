# Tenstorrent Native Runtime Delta

## ADDED Requirements

### Requirement: ttWKV7 one-shot constant-tile measurement
r[onix.tenstorrent.native_runtime.ttwkv7.constant_tile_measurement] An authorized ttWKV7 constant-tile measurement MUST bind one exact package output, immutable kernel target, isolated physical device, explicit writable runtime state, owner-restoration trap, hard timeout, and invocation count before executing probe mode, and MUST treat the first process result as exhausting the change's hardware budget.

#### Scenario: Offline review does not consume authorization
- GIVEN an exact reviewed package and proposed runtime-state paths
- WHEN package checks, architecture compilation, path capture, and runtime preflight execute
- THEN no Tenstorrent device is created by those checks
- AND the physical invocation count remains zero

#### Scenario: Owner isolation precedes the one invocation
- GIVEN device 1 has an active owning service before the reviewed run
- WHEN the physical probe phase begins
- THEN the prior active state is recorded and the owner is stopped
- AND probe mode does not execute unless the owner is proven inactive

#### Scenario: First process result exhausts the budget
- GIVEN owner isolation succeeded and the exact package, runtime state, device selection, and timeout match the reviewed change
- WHEN probe mode is invoked
- THEN the invocation count changes from zero to one before process execution
- AND success, mask mismatch, initialization failure, signal, or timeout terminates the physical search without retry

#### Scenario: Prior owner state is restored
- GIVEN the owner service was active before isolation
- WHEN the probe exits for any ordinary process status or the orchestration shell terminates
- THEN an exit trap attempts to restart the owner exactly once
- AND post-run service, endpoint, and board-health evidence is retained

#### Scenario: Measurement remains narrowly scoped
- GIVEN the fourteen reviewed masks pass exactly or any terminal failure occurs
- WHEN the outcome is documented
- THEN the claim is limited to the exact package, kernel target, selected P150, patterns, and lengths
- AND no full-WKV correctness, decode correctness, performance, or general P150 compatibility is inferred
