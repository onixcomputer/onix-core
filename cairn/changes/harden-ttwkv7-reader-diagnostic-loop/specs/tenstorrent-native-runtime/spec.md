# Tenstorrent Native Runtime Delta

## ADDED Requirements

### Requirement: ttWKV7 high-information reader diagnostic loop

r[onix.tenstorrent.native_runtime.ttwkv7.reader_diagnostic_loop] Onix MUST validate every production-reader runtime vector and diagnostic control without a device, MUST independently distinguish CB21 capture and host upload packing from production reader behavior, and MUST preserve raw exact artifacts sufficient for offline classification after one separately authorized process.

#### Scenario: Reader ABI vectors are validated without hardware
- GIVEN named decode, chunked-partial, and chunked-full reader cases with sentinel addresses
- WHEN the pure serializer emits each positional runtime vector
- THEN each vector matches an independently specified 18-field fixture
- AND the exhausted chunked `L=1/Lreal=1` vector plus mutations of chunk size, real length, chunk count, or instance bounds are rejected

#### Scenario: Capture and upload controls are independent
- GIVEN deterministic full-tile, input, and padded flat-state tags
- WHEN device-free oracles and architecture compilation validate the control workloads
- THEN CB21 loopback, all six input uploads, and complete state upload have exact expected layouts
- AND no production reader, writer, or compute kernel participates in those controls

#### Scenario: Reader cases cover tail and full chunks
- GIVEN the exact pinned decode and chunked production readers
- WHEN the future diagnostic case set is constructed
- THEN decode uses `L=1`, chunked partial uses `L=32/Lreal=1`, and chunked full uses `L=32/Lreal=32`
- AND every case fixes `nc=1` and instances `[0,32)`

#### Scenario: One process is observable offline
- GIVEN a downloaded control, reader, or writer buffer
- WHEN the imperative shell records evidence
- THEN it writes raw bf16 data and the exact serialized runtime vector under the reviewed log root before comparison
- AND deterministic records report mismatches by applicable region, tile, row, face, and head

#### Scenario: Controls or artifacts are incomplete
- GIVEN an invalid runtime vector, failed control, artifact-write error, missing or duplicate record, or incomplete output
- WHEN evidence is classified
- THEN production reader corruption is not inferred
- AND the result remains terminal for that authorization without retry or broader compatibility claims
