# Tenstorrent Native Runtime Delta

## ADDED Requirements

### Requirement: ttWKV7 executable one-shot boundary
r[onix.tenstorrent.native_runtime.ttwkv7.constant_tile_measurement.executable_runbook] A newly authorized ttWKV7 measurement MUST use a fresh runbook committed with executable mode, MUST prove direct launchability before owner isolation, MUST preserve independently timed and exit-trap restoration, and MUST consume at most one exact probe process result without interpreter fallback or retry.

#### Scenario: Executable mode is reviewed before launch
- GIVEN a fresh committed one-shot runbook and zero invocation count
- WHEN offline review completes
- THEN filesystem launchability and Git mode `100755` are proven
- AND direct negative execution reaches the runbook's argument rejection path

#### Scenario: Launchability regression fails closed
- GIVEN the committed runbook lacks executable mode or direct invocation fails before its argument guard
- WHEN the orchestration boundary is reached
- THEN no owner isolation or probe invocation occurs
- AND the change terminates without interpreter fallback, chmod repair, or retry

#### Scenario: Production wrapper target is immutable and executable
- GIVEN the composed package's device probe wrapper
- WHEN offline launchability validation inspects its exec target
- THEN the target is an existing absolute immutable executable
- AND validation rejects an unexpanded runtime `$out` reference or a fake-only target check

#### Scenario: Rollback precedes owner isolation
- GIVEN the owner is active and healthy and all launchability checks pass
- WHEN the authorized physical phase begins
- THEN the named independent rollback timer is active before owner isolation
- AND the exit trap retains ordinary immediate restoration

#### Scenario: One process exhausts authorization
- GIVEN exact metadata, isolation, device ownership, and runtime state are proven
- WHEN probe mode starts
- THEN invocation count changes from zero to one immediately before the process
- AND every process result terminates the physical search without retry

#### Scenario: Exact evidence bounds compatibility claims
- GIVEN any terminal probe result
- WHEN evidence is classified
- THEN validated success requires fourteen unique exact comparisons plus the final pass marker
- AND no full-WKV, decode, performance, or general P150 compatibility claim is inferred
