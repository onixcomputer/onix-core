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

## Offline Implementation Evidence

Baseline package `/nix/store/1x99jci2lnw034h9xyg6ijm6cb7h6d7m-ttwkv7-unstable-2026-06-22` and architecture check `/nix/store/mwjvhhblizaascqjdxprzkxdqsxn5vqg-ttwkv7-architecture-check` passed before core changes. The hardened result is package `/nix/store/l5a5lkkwn7wcp2hvr8c3m5zp4wfyg36y-ttwkv7-unstable-2026-06-22`, binaries `/nix/store/0gils0dmv1mkpk86izbaf866kid5w3fs-ttwkv7-binaries-unstable-2026-06-22`, kernels `/nix/store/bag2glrys891mvg2pifn8q4iqjd0qm25-ttwkv7-kernels-unstable-2026-06-22`, architecture check `/nix/store/2fpka4z9wfi4z5r4pkjdi00mpva6bpzl-ttwkv7-architecture-check`, and host closure `/nix/store/gfqfx3b5c43a6iawjhv9s4nizxl8ycha-nixos-system-britton-desktop-26.11.20260629.7a1a647`.

The pure self-test passes exact ABI fixtures, rejects the exhausted vector and critical mutations, validates all three reader layouts, validates the complete six-input and 4096-tile state packing, and retains positive/negative writer checks. A separate no-device artifact self-test writes and inspects raw bf16, argument, result, and manifest artifacts; a file root fails. Package validation also invokes internal probe mode with `TT_METAL_LOGS_PATH` absent and proves it fails at artifact preparation before `MeshDevice::create`. The new CB21 source peer compiles as BRISC for pinned Blackhole and Wormhole alongside the NCRISC capture writer and existing CB16 source peer. Package, package-check, architecture, host-closure, Bash, ShellCheck, treefmt, `git diff --check`, Cairn, and pre-commit gates pass.

## Adversarial Audit

Structural AST inspection finds exactly six `CreateKernel` sites: the control function uses only the CB21 source peer and capture writer, the reader function uses one selected production reader plus capture writer, and the writer function uses the CB16 source peer plus production writer. No compute kernel is created. The thirteen future records are compile-time counted and each control/reader/writer download carries producer and consumer vectors.

The first audit found a real evidence-order defect: comparisons were computed before raw captures were persisted. The imperative shell now writes the raw bf16 buffer and both runtime vectors immediately after download and before any untilization or comparison, then appends the summary. Artifact-root failure still occurs before device creation. Reader case invariants and the complete-state tile bound are compile-time and runtime checked.

A secondary advisory suggested count, bounds, and state-size checks, which are present. Suggestions to use production kernels inside controls or perform a positive device test were rejected because they would destroy control independence or cross the authorization boundary. Remaining uncertainty is physical scheduling and P150 behavior only; no owner mutation, device enumeration, runbook preparation, or physical process occurred. The device-1 owner remains active/running with `Result=success`, `NRestarts=0`, and HTTP 200.

## Search and Authorization Budget

Use five active mechanism families, one implementation round, one adversarial audit, and deterministic repository validators. Stop at validated offline readiness or an exact implementation blocker. Do not create, enumerate, initialize, or communicate with a Tenstorrent device. Any physical execution requires a new change, reviewed package/runbook, zero counters, and fresh explicit authorization.
