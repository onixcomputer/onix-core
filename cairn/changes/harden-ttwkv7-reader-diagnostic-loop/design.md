# Design: Harden the ttWKV7 reader diagnostic loop

## Goal and Completion Evidence

Produce a device-free validated successor diagnostic that makes invalid reader ABI vectors impossible to publish and makes one later process independently classify capture, upload, reader, tail-fill, and writer boundaries. Completion requires:

1. a pure typed 18-field reader ABI serializer with explicit chunked-partial, chunked-full, and decode fixtures;
2. negative fixtures that reject the exhausted `L=1/Lreal=1` chunked vector and mutated `L`, `Lreal`, `nc`, and instance bounds;
3. independent CB21 full-tile loopback, six input-upload controls, and one complete flat-state-upload control;
4. exact production reader cases for decode length 1, chunked `L=32/Lreal=1`, and chunked `L=32/Lreal=32`;
5. raw bf16 captures, serialized argument vectors, deterministic manifest records, and mismatch histograms by region/tile/row/face/head;
6. Blackhole and Wormhole compilation of every peer data-movement kernel;
7. package, host-closure, formatting, ShellCheck, pre-commit, and Cairn gates without device enumeration or owner mutation.

A wrapper-only pass, model agreement, aggregate mismatch count without controls, a host copy that bypasses CB21, relaxed comparison, hardware execution, or a second use of the exhausted authorization is false completion.

## Functional Core and Imperative Shell

The functional core owns typed case descriptions, ABI serialization, exact explicit fixtures, bf16 tags, source layouts, reader and writer expected layouts, mismatch classification, and deterministic manifest-line construction. These functions accept values and return values without device, filesystem, environment, or process access.

The imperative shell owns Metalium buffers/programs, environment lookup, raw artifact writes, workload sequencing, device closure, and record printing. It writes every downloaded bf16 buffer before interpretation so post-run analysis does not require another process.

## Reader ABI Contract

A named `ReaderCase` distinguishes:

| Case | Kernel argument 1 | Argument 12 | Argument 15 | Meaning |
|---|---:|---:|---:|---|
| `decode-L1` | 1 | 0 | 1 | decode token count 1; argument 12 unused |
| `chunked-partial-L1` | 32 | 1 | 1 | fixed chunk size 32, one real token |
| `chunked-full-L32` | 32 | 32 | 1 | fixed chunk size 32, all rows real |

The serializer emits exactly 18 fields from named members and dynamic addresses. Self-tests compare against independently written arrays with sentinel addresses. Mutation tests prove that the exhausted chunked vector and every critical cardinality/bound field are rejected.

## Future One-Process Record Set

A future separately authorized process runs all records after one device open:

1. `control/cb21-loopback` with full row/face/tile tags;
2. `control/input-upload-0` through `control/input-upload-5` over 32 tokens;
3. `control/state-upload` over the complete padded flat-state matrix;
4. `decode-L1/reader-capture`;
5. `chunked-partial-L1/reader-capture`;
6. `chunked-full-L32/reader-capture`;
7. `chunked/writer-scatter`;
8. `decodeL/writer-scatter`;
9. one aggregate marker.

The peer source reads complete DRAM pages into CB21; the existing capture writer drains CB21. The controls therefore validate host tilization, upload, TensorAccessor page order, CB21 synchronization, capture writes, download, and untilization without production reader logic.

## Classification Contract

- Any CB21 loopback failure yields `capture-infrastructure-invalid`.
- An input upload failure yields `input-packing-suspected`.
- A state upload failure yields `state-packing-suspected`.
- Controls passing with decode state/input failure yields `decode-reader-suspected` with region histogram.
- Chunked partial failing while chunked full passes yields `chunk-tail-fill-suspected`.
- Both production readers failing after controls pass yields `shared-reader-gather-suspected`, not proof of one primitive.
- Both writer cases passing validates only the reviewed tagged writer scatter path.
- Missing artifacts, invalid vectors, duplicate/missing records, initialization failure, or nonzero infrastructure status yields `partial-diagnostic`.

No result establishes WKV arithmetic, performance, or broad Blackhole compatibility.

## Approach Registry

| Family | Mechanism | Claim | Artifact | Gap | Next check | State |
|---|---|---|---|---|---|---|
| Typed ABI | Named reader cases serialize exact positional vectors | Prevents invalid chunk/decode vectors before device access | Explicit 18-field positive and mutation fixtures | Simpler | Make exhausted vector fail | active |
| Capture control | Full-page source feeds CB21 and capture writer | Separates capture/download from production readers | Tagged full-tile record | Simpler | Compile and self-test layouts | active |
| Upload controls | Copy complete input and state tiled buffers through CB21 | Separates host packing/page order from gather formulas | Seven exact records and raw captures | Simpler | Exact host fixtures | active |
| Reader matrix | Decode, partial chunk, and full chunk use exact production readers | Distinguishes gather from tail fill | Three typed cases | Equivalent | Activate only after controls | active |
| Raw observability | Persist raw bf16, args, and structured summaries | Enables offline diagnosis without rerun | Artifact manifest | Simpler | Package-path test | active |
| Faster retry | Patch one field and immediately rerun | Produces another low-information process | None | Unknown | Reject | falsified |
| Compute primitives | Test transpose/matmul | Locates arithmetic defects | Future suite | Stronger than current reader question | Only after readers pass | blocked |

## Search and Authorization Budget

Use five active mechanism families, one implementation round, one adversarial audit, and deterministic repository validators. Stop at validated offline readiness or an exact implementation blocker. Do not create, enumerate, initialize, or communicate with a Tenstorrent device. Any physical execution requires a new change, reviewed package/runbook, zero counters, and fresh explicit authorization.
