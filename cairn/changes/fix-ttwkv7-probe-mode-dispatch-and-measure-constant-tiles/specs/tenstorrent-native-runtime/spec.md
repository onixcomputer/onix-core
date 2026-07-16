## ADDED Requirements

### Requirement: ttWKV7 exact probe-mode dispatch
r[onix.tenstorrent.native_runtime.ttwkv7.probe_mode_dispatch] After successful runtime-state validation, the composed ttWKV7 wrapper MUST execute its immutable probe runtime with `probe` as the first mode argument and MUST preserve every forwarded suffix argument exactly once and in order without creating a Tenstorrent device during package validation.

#### Scenario: Probe mode has no forwarded suffix
- GIVEN the production wrapper receives only `probe` and valid explicit runtime state
- WHEN a no-device dispatch target records its arguments
- THEN its complete argument vector is exactly one element equal to `probe`
- AND no Tenstorrent device is initialized

#### Scenario: Probe mode has a forwarded suffix
- GIVEN the production wrapper receives `probe` followed by a sentinel argument
- WHEN a no-device dispatch target records its arguments
- THEN its complete argument vector is exactly `probe` followed by the sentinel
- AND the mode is not dropped, duplicated, or reordered

#### Scenario: Production dispatch is inspected independently
- GIVEN the composed package's actual wrapper and immutable runtime executable
- WHEN package validation inspects production dispatch and runs the pinned no-device self-test
- THEN the probe branch contains the exact immutable target plus literal `probe` mode
- AND validation does not rely only on the fake target or caller-controlled `out`

### Requirement: ttWKV7 post-probe-mode-repair one-shot measurement
r[onix.tenstorrent.native_runtime.ttwkv7.constant_tile_measurement.probe_mode_repair] A newly authorized post-dispatch-repair measurement MUST bind the verified production argument vector, exact package and kernels, isolated device 1, explicit writable runtime state, independent timed restoration, exit-trap restoration, and zero invocation count before consuming exactly one probe process result without fallback or retry.

#### Scenario: Dispatch and restoration pass before isolation
- GIVEN a fresh package output, executable runbook, and zero invocation count
- WHEN device-free review completes
- THEN exact production dispatch, immutable paths, runtime state, runbook mode, owner control, root SSH, and rollback rehearsal all pass
- AND service-stop and rollback-arm counts remain zero

#### Scenario: One process exhausts authorization
- GIVEN rollback is active, the prior owner is isolated, device 1 has no open owner, and exact metadata still matches
- WHEN invocation count changes from zero to one and the runbook starts probe mode
- THEN the first status, mismatch, initialization failure, signal, or timeout terminates physical search
- AND no direct runtime-binary fallback, alternate command, or retry executes

#### Scenario: All exact masks pass
- GIVEN the sole process reaches all constant-tile comparisons
- WHEN evidence is classified
- THEN success requires fourteen unique `mismatches=0 PASS` records for seven patterns at lengths 1 and 32
- AND process status is zero with `constant-tile device probe: PASS`

#### Scenario: Terminal evidence restores and limits claims
- GIVEN the sole process returns any terminal result
- WHEN orchestration exits
- THEN service, endpoint, container, rollback, and board evidence classify restoration
- AND no full-WKV, decode, performance, or general P150 compatibility claim is inferred
