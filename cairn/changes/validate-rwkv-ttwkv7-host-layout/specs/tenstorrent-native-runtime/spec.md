## ADDED Requirements

### Requirement: Real-weight RWKV-to-ttWKV7 host-layout validation
r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_host_layout] Onix MUST provide a deterministic device-free cross-package check that validates the exact pinned real-weight BF16 boundary through ttWKV7's production host input-padding, state-upload, tiled-NFACES, and writer output/state layouts without initializing a Metalium device.

#### Scenario: Production and validation share the host-layout core
- GIVEN the accepted 12-head checkpoint shape and ttWKV7 host path
- WHEN input padding, state upload, or writer indices are constructed
- THEN production and validation compile against the same pure deterministic host-layout core
- AND the core performs no filesystem, environment, process, network, clock, logging, or device operation

#### Scenario: Canonical fixture authorities are accepted
- GIVEN the package-installed real-weight boundary fixture
- WHEN boundary validation parses it
- THEN exact schema, model revision, target, dimensions, prefix, byte order, tensor order, logical shapes, counts, lowercase hexadecimal bytes, per-artifact BLAKE3, whole-file BLAKE3, and ordered BLAKE3 authorities pass
- AND every BF16 value is decoded from its explicit little-endian bit pattern without substitution or widening the transport format

#### Scenario: Real input and state uploads match Metalium layout
- GIVEN six `[12,64]` input vectors and retained `[12,64,64]` pre-state
- WHEN the shared host core pads inputs and sequence state and Metalium's CPU layout converter tilizes them
- THEN all real values and BF16 bits are preserved, all padded values are exact zero, and complete tiled buffers match an independent four-face tiled-NFACES oracle element-for-element
- AND untilizing the buffers reconstructs the exact logical tensors and padding

#### Scenario: Writer output and state layout is bijective
- GIVEN the accepted expected output and expected post-state for one sequence and one token
- WHEN the shared writer indices construct the padded `[96,768]` host matrix
- THEN complete output and state values occupy the reviewed output and interleaved state regions exactly once
- AND inverse extraction reconstructs every logical element while all tail rows remain exact zero

#### Scenario: Transformed buffer receipt is deterministic
- GIVEN the same pinned fixture and installed Metalium CPU layout authority
- WHEN the no-device boundary self-test runs repeatedly
- THEN it emits byte-identical complete transformed-buffer BLAKE3 identities and one domain-separated combined layout identity
- AND the cross-package Nix check locks the exact receipt without adding the fixture or checkpoint to ttWKV7's runtime package closure

#### Scenario: Boundary fixture or command is malformed
- GIVEN malformed JSON, a non-file path, missing or duplicate artifact, wrong metadata, wrong ABI order, wrong shape, changed byte, stale hash, uppercase or odd hexadecimal, transposed state orientation, wrong element count, truncated data, duplicated data, missing path argument, or extra command suffix
- WHEN boundary validation runs
- THEN it returns nonzero before device creation and emits no passing receipt
- AND it does not reorder, truncate, retry, fetch, substitute zero state, accept another fixture, or fall back to a hardware mode

#### Scenario: Existing boundaries remain stable
- GIVEN the new cross-package check
- WHEN package validation runs
- THEN historical ttWKV7 shape, data-movement, reader-alignment, architecture, and RWKV fixture receipts continue to pass
- AND production reader, compute, and writer kernels remain unchanged

#### Scenario: Host-layout evidence remains narrowly scoped
- GIVEN the real-weight host-layout check passes
- WHEN integration progress is reported
- THEN the claim is limited to exact device-free host buffer construction and Metalium CPU tiled-layout conversion for the pinned boundary
- AND no ttWKV7 recurrence execution, kernel correctness, P150 correctness, repaired-reader completion, generation, serving, performance, or hardware authorization is inferred
