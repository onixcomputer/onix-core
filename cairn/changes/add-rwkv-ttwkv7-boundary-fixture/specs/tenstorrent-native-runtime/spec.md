## ADDED Requirements

### Requirement: Real-weight RWKV-to-ttWKV7 BF16 boundary fixture
r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_boundary_fixture] Onix MUST provide a deterministic device-free artifact that binds the pinned checkpoint's retained layer-zero second-token WKV inputs and pre-state to complete little-endian BF16 bytes in ttWKV7 host order, recomputes raw expected output and post-state from the BF16 boundary through independent CPU recurrence paths, and emits exact BLAKE3-bound evidence without invoking Metalium or a Tenstorrent device.

#### Scenario: Retained real-weight boundary is captured
- GIVEN the exact pinned checkpoint, zero initial state, and model-config prefix `[1,2]`
- WHEN layer zero processes the second token
- THEN the fixture captures the nonzero retained pre-state immediately before token ID `2`
- AND it captures complete `r`, `w`, `k`, `v`, `a`, and `b` vectors plus raw recurrence output and post-state before group normalization or output projection

#### Scenario: ttWKV7 BF16 artifacts are encoded
- GIVEN 12 heads, head size 64, hidden size 768, and a 49,152-element retained state
- WHEN the boundary encoder runs
- THEN it emits all six 768-element vectors in fixed host order `[a,w,k,v,r,b]`, one retained pre-state, one 768-element expected output, and one expected post-state
- AND every artifact contains complete lowercase hexadecimal little-endian BF16 bytes, exact element and byte counts, and a BLAKE3 identity

#### Scenario: BF16 expected recurrence passes
- GIVEN the encoded vectors and pre-state decoded exactly from their BF16 bit patterns into FP32
- WHEN separately structured matrix and scalar recurrence implementations execute
- THEN complete expected raw-output and post-state tensors agree within the named recurrence tolerance
- AND the encoded expected artifacts derive from the BF16-boundary matrix result rather than the unquantized checkpoint calculation

#### Scenario: Boundary input is malformed or changed
- GIVEN a missing tensor, wrong ABI order, wrong shape, wrong byte count, non-finite source value, odd hexadecimal length, changed BF16 byte, changed state orientation, or changed combined identity
- WHEN boundary validation runs
- THEN it returns nonzero and publishes no passing artifact
- AND it does not reorder tensors, substitute zero state, fall back to FP32 transport, widen tolerance, invoke ttWKV7, or retry

#### Scenario: Fixture is deterministic and package-owned
- GIVEN the same pinned checkpoint, prefix, layer, BF16 policy, ABI order, and recurrence policy
- WHEN the argument-free fixture runs repeatedly
- THEN it emits byte-identical complete JSON and ordered combined BLAKE3 identity
- AND the package-installed canonical fixture matches stdout exactly while every caller argument is rejected

#### Scenario: Historical references remain stable
- GIVEN the boundary capture refactors shared layer-zero execution
- WHEN package validation runs
- THEN all accepted layer, greedy-token, stateful-decode, fixed-text, bounded-prompt, and framework comparison evidence remains unchanged
- AND no historical claim is widened to BF16 full-layer or ttWKV7 parity

#### Scenario: Boundary evidence remains narrowly scoped
- GIVEN the real-weight BF16 boundary fixture passes
- WHEN integration progress is reported
- THEN the claim is limited to exact logical BF16 transport bytes and CPU FP32 recurrence expectations for layer zero's second token
- AND no ttWKV7 execution, Metalium parity, P150 correctness, repaired-reader completion, token generation, serving behavior, performance, or new hardware authorization is inferred
