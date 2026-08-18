# Design: Diagnose ttWKV7 Blackhole data movement

## Goal and Completion Evidence

Produce a device-free validated diagnostic that can later distinguish reader/upload and writer/scatter corruption from WKV arithmetic in exactly one device process. Offline completion requires:

1. deterministic bf16 tags and pure expected-layout functions for every captured reader tile and every scattered output element;
2. positive self-tests plus negative row/column transpose, tile permutation, duplicate/drop, wrong scatter, and sentinel-overwrite fixtures;
3. exact use of the pinned `wkv7_reader.cpp`, `wkv7_decodeL_reader.cpp`, and `wkv7_writer.cpp` with no WKV compute kernel;
4. architecture-neutral capture/source kernels compiled by the pinned Blackhole and Wormhole data-movement toolchains;
5. one immutable production wrapper that accepts no probe suffix and requires exact device-1 visibility plus reviewed writable cache/log and loopback Inspector state;
6. package, dual-architecture, host-closure, formatting, ShellCheck, pre-commit, and Cairn gates without enumerating or initializing hardware.

Compilation alone, a host-only copy that bypasses the production kernels, a compute passthrough that can confound data movement, probabilistic metrics, relaxed comparison, model agreement, or a second physical process are false completion.

## Functional Core and Imperative Shell

The pure core generates representable bf16 tags, materializes native input and flat-strip state layouts, predicts each reader stream, materializes writer source tiles, predicts the complete destination matrix including sentinels, and returns structured exact comparisons. It has no device, filesystem, environment, or process dependency and is exercised by plain self-test assertions with positive and negative fixtures.

The imperative shell creates one mesh device only in `probe` mode, uploads buffers, runs four bounded workloads on one core, downloads results, invokes the pure comparators, closes the device, and prints one exact record for each phase/path. The package wrapper owns runtime-state validation and immutable dispatch.

## Device Workloads

### Reader capture

For `G=1`, `H=32`, `S=64`, and `L=1`, run each unmodified production reader on instances `[0,32)`. A minimal RISCV-1 capture writer drains circular buffer 21 and writes every produced tile contiguously. The decode stream is expected as state then six input tensors per instance; the chunked stream is expected as six input tensors then state. Input tags cover both head faces and both dimension tiles. State tags cover every head, row, and column through the exact flat-strip sub-page gather.

### Writer scatter

A minimal RISCV-0 source reader streams tagged output and state tiles into circular buffer 16 in the exact cadence expected by the unmodified production writer. Run decode (`NB=1`, `tpc=1`) and chunked (`NB=2`, `tpc=32`) writer configurations separately. Compare the complete untilized destination matrix: token row 0, every interleaved final-state element, and untouched sentinel rows.

Neither workload creates a compute kernel, so a mismatch cannot be attributed to transpose, matmul, SFPU, or a passthrough pack/unpack operation.

## Approach Registry

| Family | Mechanism | Claim | Artifact | Gap | Next check | State |
|---|---|---|---|---|---|---|
| Split reader/writer capture | Drain exact readers directly and feed exact writer directly through data-movement peers | Separately tests upload/gather and scatter/extraction without WKV math | Four exact tagged records | Simpler | Seek separate authorization only after all offline gates | validated offline |
| Compute passthrough | Bridge reader CB21 to writer CB16 with tile copy/pack | Tests a monolithic path | Additional compute kernel | Adds a copy/pack confound | None unless split design is impossible | falsified |
| Host buffer loopback | Upload and download contiguous pages | Tests Metalium buffer APIs only | Generic DRAM copy | Bypasses production layouts | Keep only as infrastructure control if needed | independent |
| Primitive microprobe | Test transpose/matmul/broadcast operations | Tests common compute primitives | Future finite primitive suite | Larger than data movement | Activate only if all four data records pass | blocked |
| Stage snapshots/debug tools | Export internal WKV intermediates or use DPRINT/Watcher | Finds first arithmetic divergence | Future instrumented kernels | More invasive and source-build sensitive | Defer until smaller discriminators pass | blocked |

## Offline Implementation Evidence

Package `/nix/store/1x99jci2lnw034h9xyg6ijm6cb7h6d7m-ttwkv7-unstable-2026-06-22` uses binaries `/nix/store/83bj1r3dvccfkzd8wajy7gk1fffc7k0w-ttwkv7-binaries-unstable-2026-06-22` and kernels `/nix/store/nzcin5jx404z35hq71nz5154ca9qx9y6-ttwkv7-kernels-unstable-2026-06-22`. Its production `wkv7-data-movement` command passes the pure self-test and exact device-1 runtime preflight without device enumeration. Missing/wrong visibility, unsafe cache/log paths, invalid Inspector addresses, invalid modes, suffixes, hostile/unset `out`, mutable placeholders, and altered exec counts fail package checks.

The architecture derivation `/nix/store/mwjvhhblizaascqjdxprzkxdqsxn5vqg-ttwkv7-architecture-check` compiles the source reader as BRISC and capture writer as NCRISC for pinned Blackhole and Wormhole configurations in addition to the existing compute checks. The complete package check and host closure `/nix/store/4zznb6ysmk0ljil90zjpb83x34zvsbhx-nixos-system-britton-desktop-26.11.20260629.7a1a647` pass. ShellCheck, Bash syntax, tree formatting, `git diff --check`, and Cairn validation/gates pass without hardware. After the exact implementation was fast-forwarded into the primary checkout, pre-commit passed deadnix, statix, and treefmt while preserving unrelated user changes.

## Adversarial Audit

Static package checks require exactly four `CreateKernel` sites, the exact production reader/writer source paths, CB21 and CB16, and no `ComputeConfig`. Stream arithmetic is fixed at 32 instances: each reader emits 16 tiles for 512 captured tiles, and each writer source emits six tiles for 192 source tiles. Decode input comparisons deliberately ignore unwritten rows while checking row 0 exactly; chunked comparisons additionally require every neutral tail row. All state tiles and the entire 96-by-2048 writer destination, including sentinel rows 65 through 95, are exact.

The first audit found positive-oracle coupling: an expected stream materialized from itself could pass without checking source builders. Self-tests now independently anchor native input offsets, flat-strip state offsets and padded sentinels, writer source cadence, destination scatter coordinates, output edges, and tile counts. Negative drop/duplicate fixtures remove or append complete tiles rather than one element. Row/column, tile permutation, wrong-scatter, and sentinel corruption remain independently rejected.

One advisory-model request failed at transport and supplied no evidence; it was not retried or treated as validation. Residual uncertainty is physical only: offline compilation cannot establish runtime scheduling, CB liveness, or numerical transfer on the selected P150. Those are exactly the claims reserved for a later single authorized process.

## Authorized Zero-State Boundary

The authorized evidence root is `/var/tmp/ttwkv7-data-movement-20260716T205921Z`, mode `0700`, with separate writable cache and log directories and Inspector address `127.0.0.1:43135`. Strict loopback SSH trust resolves to `SHA256:0vd1vzTWrAONyquNKjwnsGY7a5bY2NJlvFamtxy/akY`. The executable runbook pins the active system, package, kernel tree, owner helper, physical device 1, exact `probe` exec line, owner restoration trap, and a five-minute root-systemd rollback timer.

A preparation-only exact-line check initially failed because the manual check searched for backslash-escaped quote characters. It did not execute the runbook, stop the owner, arm the real rollback, or invoke ttWKV7; counters remained `0,0,0`. The corrected literal wrapper check, runtime preflight, owner-control validation, strict root SSH check, owner HTTP 200 check, and free-port check passed. A disposable root-systemd timer targeting only `true` armed and disarmed successfully without owner mutation. The owner remained active/running with zero restarts and HTTP 200. This preparation failure is retained in the evidence root and does not expand or consume the one-process authorization.

## Terminal Authorized Result

Exactly one process ran from clean commit `00965bc07acdb5722561317095e78c2f8da4695c` with counters `1,1,1`. It emitted exactly four records and one aggregate marker:

- `chunked/reader-capture`: 450896 mismatches, first mismatch 32, expected 0, actual `-4.7387116e-38`;
- `decodeL/reader-capture`: 71680 mismatches, first mismatch 32, expected `-0.2734375`, actual `-3`;
- `chunked/writer-scatter`: zero mismatches;
- `decodeL/writer-scatter`: zero mismatches;
- aggregate `data-movement device probe: FAIL`, diagnostic status 1.

Post-run source audit found that the probe supplied `kTokenCount=1` as runtime argument 1 to both readers. The pinned chunked reader defines argument 1 as the on-device chunk size `L=cl`, always 32, and separately defines argument 12 as `Lreal`; the reviewed probe therefore ran chunked with invalid `L=1, Lreal=1`. This explains why its first row could match while expected neutral tail rows did not, and it invalidates the chunked reader record as evidence about the production vector. DecodeL correctly uses token count 1 and retains a real exact mismatch, but the exhausted process cannot distinguish production-reader behavior from the diagnostic's host state packing or capture boundary. Both exact production-writer configurations passed and narrowly validate the reviewed tagged writer scatter/extraction path.

The aggregate classification is `partial-diagnostic`, not `reader-layout-suspected`: one required reader record used an invalid runtime vector. No finite primitive suite is activated. Any corrected reader diagnostic requires a new Cairn change, package, runbook, zero-state boundary, and explicit authorization; this process must not be retried.

Restoration succeeded independently of the nonzero diagnostic: restore, restored-health, and rollback-disarm statuses are zero; the rollback units are absent/inactive; the owner is active/running with `Result=success`, `NRestarts=0`, and HTTP 200; Inspector port 43135 is free. Both boards retain healthy DRAM, zero uncorrectable GDDR errors, zero thermal trips, and advancing heartbeats. Retained runtime warnings remain limited to the known power-state `Invalid argument`, compatible single-erisc fallback, absent motherboard mapping, read-only optional fabric exports, and denied shared-memory statistics.

Evidence is rooted at `/var/tmp/ttwkv7-data-movement-20260716T205921Z`. `diagnostic.log` hashes to `blake3-ZSf+bTDmeVa7DppVDYG+B9FWOiTgoti/+Wimwdkoiwk=` and `classification.txt` hashes to `blake3-ZQsclVHJ7Z/6IlGwgo6Bk+WIHEu/fLV1Fh/lu+3tQoI=`.

## Classification Contract

A later authorized process must emit exactly one record for each of `chunked/reader-capture`, `decodeL/reader-capture`, `chunked/writer-scatter`, and `decodeL/writer-scatter`, plus one aggregate marker and raw status. Exact zero mismatches in all four yields `data-movement-validated` and activates a finite common-primitive microprobe. Reader-only failures yield `reader-layout-suspected`; writer failures yield `writer-layout-suspected`; mixed failures yield `data-movement-mixed`; incomplete output yields `partial-diagnostic`. Initialization, timeout, isolation, or orchestration blockers remain terminal and do not authorize retry.

These labels apply only to the reviewed package, exact tags/layouts, selected P150 device 1, and fixed shape. Passing does not establish WKV correctness or broad Blackhole support.

## Search Budget and Authorization Boundary

Primary authority is the pinned ttWKV7 revision, pinned TT-Metalium 0.74 source, and retained cross-kernel evidence. Use five mechanism families, one implementation round, one adversarial review, and deterministic repository validators. Stop at validated offline readiness, a bounded implementation blocker, or a new explicit hardware authorization boundary.

The instruction `do it` authorized implementation of the selected diagnostic, not a then-unreviewed physical launch. After reviewing the exact package and four-record contract, the user supplied the exact authorization `Authorize exactly one device-1 data-movement diagnostic process.` The authorization is bound only to package `/nix/store/1x99jci2lnw034h9xyg6ijm6cb7h6d7m-ttwkv7-unstable-2026-06-22`, device 1, one invocation of `wkv7-data-movement probe`, and executable `run-one-shot.sh`. Any preflight, isolation, initialization, timeout, incomplete output, diagnostic failure, or restoration failure consumes this boundary and forbids retry or an alternate command.
