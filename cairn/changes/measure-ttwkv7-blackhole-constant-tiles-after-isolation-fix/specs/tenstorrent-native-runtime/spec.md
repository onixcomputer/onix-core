# Tenstorrent Native Runtime Delta

## ADDED Requirements

### Requirement: ttWKV7 independently restored one-shot measurement
r[onix.tenstorrent.native_runtime.ttwkv7.constant_tile_measurement.timed_restore] An authorized ttWKV7 constant-tile measurement MUST arm an independently surviving timed owner restoration before isolation, MUST preserve ordinary exit-trap restoration, MUST bind one exact package, kernel, device, runtime state, timeout, and invocation count, and MUST treat the first probe process result as exhausting the change's hardware budget.

#### Scenario: Offline review preserves authorization
- GIVEN an exact package, owner-control helper, rollback command, and proposed runtime state
- WHEN lifecycle gates, package checks, architecture compilation, shell review, and runtime preflight execute
- THEN no Tenstorrent device is created by those checks
- AND the physical invocation count remains zero

#### Scenario: Rollback must arm before isolation
- GIVEN the owner service is active and healthy
- WHEN the authorized physical phase begins
- THEN the named independent rollback timer is armed and proven active before owner isolation
- AND failure to arm the timer prevents owner stop and probe invocation

#### Scenario: Ordinary or abrupt orchestration loss restores ownership
- GIVEN the owner was active before successful isolation
- WHEN the probe exits normally, fails, times out, or the orchestration process terminates
- THEN the exit trap attempts immediate restoration when it runs
- AND the independent timer remains able to start the exact owner unit if the trap does not run

#### Scenario: First process result exhausts the budget
- GIVEN isolation succeeded and all exact metadata still matches
- WHEN probe mode is invoked
- THEN the invocation count changes from zero to one immediately before execution
- AND success, mismatch, initialization failure, signal, or timeout terminates the physical search without retry

#### Scenario: Exact output limits the claim
- GIVEN the probe returns any terminal result
- WHEN evidence is classified
- THEN validation requires all fourteen exact comparisons and the final pass marker
- AND no full-WKV correctness, performance, decode correctness, or general P150 compatibility is inferred
