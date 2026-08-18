# Tenstorrent native runtime delta

## ADDED Requirements

### Requirement: Observed ttWKV7 boundary composes through one RWKV layer suffix

Onix SHALL preserve the exact terminal device-1 real-weight ttWKV7 boundary evidence and SHALL provide a deterministic device-free replay that composes its observed BF16 recurrence output and post-state through layer zero's second-token CPU suffix without invoking Metalium or a Tenstorrent device. r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_observed_layer_replay]

#### Scenario: Exact terminal evidence is retained without rewriting its outcome

- **GIVEN** the sole recovery session produced one complete passing ttWKV7 workload but `rwkv-lab` classified the session `unsafe` because owner HTTP health missed the runbook window
- **WHEN** the observed-layer replay validates its evidence authorities
- **THEN** it SHALL require the exact plan, terminal `unsafe` classification, safety issue, process count, workload count, success marker, device receipt, source hashes, comparison metrics, raw artifacts, and final board snapshot
- **AND** later owner health recovery SHALL NOT rewrite the terminal session classification to `passed`

#### Scenario: Shared pure cores preserve the accepted CPU path

- **GIVEN** the accepted layer implementation currently fuses WKV preparation, recurrence, normalization, gate correction, and output projection
- **WHEN** it is decomposed for observed-artifact injection
- **THEN** pure deterministic preparation and attention-finish cores SHALL be shared by the original CPU recurrence path and the replay path
- **AND** all accepted layer, token, stateful decode, fixed text, bounded prompt, framework parity, and BF16 boundary receipts SHALL remain unchanged

#### Scenario: Observed recurrence values compose through the layer suffix

- **GIVEN** the exact checkpoint, prefix `[1,2]`, layer-zero retained state, physical observed BF16 raw output, and physical observed BF16 post-state
- **WHEN** the device-free replay executes the second-token group normalization, gate correction, output projection, residual addition, FFN normalization, channel mix, and final residual addition
- **THEN** every produced value SHALL be finite
- **AND** named complete-vector deviations SHALL compare the observed hybrid attention and final-layer outputs against both the expected BF16-boundary composition and the accepted FP32 layer result
- **AND** the receipt SHALL bind complete observed and composed vectors with deterministic BLAKE3 identities rather than sampled values

#### Scenario: Changed or incomplete physical evidence fails closed

- **GIVEN** a changed receipt, session outcome, source hash, metric, marker, artifact byte, artifact size, artifact order, state orientation, checkpoint, or comparison threshold
- **WHEN** replay validation runs
- **THEN** it SHALL return nonzero before publishing a passing composition receipt
- **AND** no alternate artifact, inferred value, widened tolerance, fallback recurrence, subprocess, retry, Metalium initialization, or device access SHALL occur

#### Scenario: Replay remains a narrow hybrid claim

- **GIVEN** the observed-layer replay passes
- **WHEN** integration progress is reported
- **THEN** the claim SHALL be limited to the exact physical ttWKV7 recurrence artifacts composed through the exact CPU FP32-from-BF16 layer-zero suffix for the second token
- **AND** no complete layer wholly on device, all-layer device execution, hardware-backed token generation, serving, throughput, latency, general P150 compatibility, or new hardware authorization SHALL be inferred
