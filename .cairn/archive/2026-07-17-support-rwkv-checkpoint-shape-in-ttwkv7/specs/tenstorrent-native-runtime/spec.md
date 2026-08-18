## ADDED Requirements

### Requirement: ttWKV7 pinned-checkpoint host shape
r[onix.tenstorrent.native_runtime.ttwkv7.checkpoint_shape] The packaged ttWKV7 host MUST derive padded input storage and work dispatch for the pinned checkpoint's 64-wide, 12-head WKV shape with ceiling tile and group counts, MUST reject invalid shape requests before device creation, and MUST provide a deterministic argument-free device-free shape self-test while preserving the historical 64-wide, 32-head diagnostic default.

#### Scenario: Checkpoint shape self-test passes without a device
- GIVEN the reviewed checkpoint shape `S=64`, `H=12`, one sequence, one token, 32-row tiles, and two-instance chunked groups
- WHEN the argument-free shape self-test runs
- THEN host input preparation uses one padded head-tile row containing 12 exact real rows followed by 20 exact zero rows
- AND it reports two head-dimension tiles, one head-tile row, 768 channels, and six chunked work units without creating a Metalium device

#### Scenario: Odd instance count retains the final instance
- GIVEN a valid host shape whose sequence and head counts produce an odd recurrent-instance count
- WHEN chunked work units are derived
- THEN ceiling division assigns a final partial two-instance group
- AND no real head is omitted or replaced by a padded storage row

#### Scenario: Explicit checkpoint shape reaches launch preparation
- GIVEN mode `test` or `bench`, valid kernel and workload arguments, and explicit suffix `64 12`
- WHEN the host validates arguments and prepares native input storage
- THEN head-tile rows and buffer sizes derive from a 32-row padded head dimension
- AND recurrent work count derives only from the 12 real heads

#### Scenario: Shape request is invalid
- GIVEN a missing shape partner, malformed decimal, sign, zero, unsupported head size, overflow, unexpected suffix, or invalid workload count
- WHEN host argument and shape validation runs
- THEN the command returns nonzero with a specific diagnostic before device creation or allocation
- AND it does not coerce the value, fall back to defaults, retry, or invoke another command

#### Scenario: Historical diagnostic default remains stable
- GIVEN no explicit shape suffix and the fixed packaged diagnostic wrapper
- WHEN default host arguments and wrapper source are inspected
- THEN the host retains head size 64 and head count 32
- AND the diagnostic wrapper retains exactly `test all 1 1` with no caller-controlled suffix

#### Scenario: Host shape source regresses
- GIVEN installed patched host source with floor head-tile division, unpadded tilization, floor chunked grouping, or device creation before self-test return
- WHEN package source validation runs
- THEN publication fails deterministically
- AND no hardware result, numerical parity, repaired-reader completion, or compatibility claim is inferred

#### Scenario: Shape evidence remains narrowly scoped
- GIVEN the checkpoint-shape package and self-test pass
- WHEN integration progress is reported
- THEN the claim is limited to device-free host storage, indexing, validation, and dispatch preparation for `S=64`, `H=12`
- AND no ttWKV7 numerical parity, kernel execution, P150 correctness, serving behavior, performance, or new hardware authorization is inferred
