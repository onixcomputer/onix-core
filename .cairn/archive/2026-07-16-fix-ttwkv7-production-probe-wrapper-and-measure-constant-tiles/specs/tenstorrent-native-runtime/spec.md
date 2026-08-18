## ADDED Requirements

### Requirement: ttWKV7 immutable production probe wrapper
r[onix.tenstorrent.native_runtime.ttwkv7.production_probe_wrapper] The composed ttWKV7 package MUST embed an existing absolute immutable probe-runtime executable at build time, MUST NOT resolve its target from a caller-controlled runtime `out` variable, and MUST validate production dispatch without creating a Tenstorrent device.

#### Scenario: Production dispatch ignores caller output state
- GIVEN the composed package's actual probe wrapper and pinned no-device self-test
- WHEN package validation runs with `out` absent and with `out` set to a hostile nonexistent path
- THEN both executions reach and pass the immutable production probe self-test
- AND neither execution initializes a Tenstorrent device

#### Scenario: Embedded target is exact and executable
- GIVEN the generated production probe wrapper
- WHEN package validation inspects its dispatch statement
- THEN the embedded target is an absolute path under the composed package's Nix store output
- AND the target exists and is executable

#### Scenario: Probe mode is preserved across runtime validation
- GIVEN the production wrapper receives `probe` plus zero or more forwarded probe arguments
- WHEN runtime-state validation succeeds and dispatch occurs
- THEN the immutable runtime binary receives `probe` as its first mode argument
- AND package validation rejects dropping, duplicating, or reordering that mode

#### Scenario: Runtime output expansion regresses
- GIVEN a candidate production wrapper containing an unexpanded `$out` target or validation that exercises only a fake probe
- WHEN package validation runs
- THEN validation fails before publication
- AND no hardware authorization or compatibility claim is inferred

### Requirement: ttWKV7 post-wrapper-repair one-shot measurement
r[onix.tenstorrent.native_runtime.ttwkv7.constant_tile_measurement.wrapper_repair] A newly authorized post-repair ttWKV7 measurement MUST bind the verified immutable production wrapper, exact package and kernels, isolated device 1, explicit writable runtime state, independently timed and exit-trap restoration, and zero invocation count before consuming exactly one probe process result without fallback or retry.

#### Scenario: Repaired wrapper is proven before isolation
- GIVEN a fresh package output and committed executable runbook
- WHEN device-free review completes
- THEN the production wrapper's immutable target, no-device dispatch, runbook mode, exact metadata, runtime state, and rollback mechanism all pass
- AND invocation, service-stop, and rollback-arm counts remain zero

#### Scenario: One repaired process exhausts authorization
- GIVEN the rollback timer is active, the prior owner is isolated, device 1 has no open owner, and exact metadata still matches
- WHEN the runbook changes invocation count from zero to one and directly invokes probe mode
- THEN the first status, mismatch, initialization failure, signal, or timeout terminates physical search
- AND no alternate target, direct runtime-binary command, interpreter fallback, or retry executes

#### Scenario: Exact constant masks pass
- GIVEN the sole repaired process reaches all exact comparisons
- WHEN evidence is classified
- THEN success requires fourteen unique `mismatches=0 PASS` records covering seven patterns at lengths 1 and 32
- AND the process returns zero with `constant-tile device probe: PASS`

#### Scenario: Terminal evidence restores and bounds claims
- GIVEN the sole repaired process returns any terminal result
- WHEN the runbook exits
- THEN ordinary restoration and independent rollback state are classified with service, endpoint, container, and board evidence
- AND no full-WKV, decode, performance, or general P150 compatibility claim is inferred
