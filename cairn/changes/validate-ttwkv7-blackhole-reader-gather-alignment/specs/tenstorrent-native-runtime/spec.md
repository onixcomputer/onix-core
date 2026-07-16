# Delta: Tenstorrent native runtime

## ADDED Requirements

### Requirement: Exact one-process aligned-reader validation

r[onix.tenstorrent.native_runtime.ttwkv7.reader_alignment_validation] Onix MUST validate the corrected ttWKV7 Blackhole reader gathers with one fresh immutable device-1 process, complete controls and raw artifacts, independent owner restoration, and terminal no-retry classification.

#### Scenario: Corrected boundary is prepared
- GIVEN the committed package, kernel closure, executable runbook, strict trust, run root, free port, and zero counters
- WHEN preparation validates the boundary
- THEN exact paths, wrapper vector, authorization scope, absent attempt lock, and healthy owner match
- AND no device is contacted before fresh authorization

#### Scenario: Sole process compares the corrected readers
- GIVEN exact authorization and successful independent owner isolation
- WHEN the atomic attempt and invocation counters change from zero to one
- THEN one timeout-bounded wrapper process runs CB21, six input, state, three reader, and two writer records
- AND every downloaded result preserves raw bf16 and both runtime vectors before comparison

#### Scenario: Corrected readers pass
- GIVEN thirteen complete unique records and process status zero
- WHEN every control, reader, and writer reports zero mismatches and the aggregate reports PASS
- THEN the result is `validated-aligned-reader-data-movement` for the exact reviewed boundary
- AND no WKV arithmetic, performance, or broad P150 claim is inferred

#### Scenario: Any result is terminal
- GIVEN a mismatch, missing artifact, invalid vector, nonzero status, infrastructure failure, or unhealthy restoration
- WHEN classification runs
- THEN the result is narrow, BLAKE3-hashed, and terminal
- AND no retry, fallback, suffix, alternate command, or direct-runtime invocation is permitted
