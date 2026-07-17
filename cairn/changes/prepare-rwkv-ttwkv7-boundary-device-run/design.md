## Context

The accepted fixture contains six little-endian BF16 `[12,64]` vectors in `[a,w,k,v,r,b]` order, retained `[12,64,64]` pre-state, expected `[12,64]` output, and expected `[12,64,64]` post-state. Device-free checks already prove exact host padding/tilization, writer extraction, decode runtime vectors, and production reader source-page/face mapping. The existing production runner launches the correct decode reader, compute, and writer kernels, but it generates random values, performs one untimed launch plus repeated timing launches, and reports aggregate PCC/NMSE only.

This change prepares but does not execute the next physical rung. `MeshDevice::create_unit_mesh` remains reachable only from an explicit fixture device mode or the historical test/bench modes. No command that reaches it may run during implementation or validation. The prior device authorization remains exhausted.

## Goals and success contract

The goal is a hardware-ready, fail-closed `G=1`, `L=1`, `S=64`, `H=12` boundary path that consumes only the accepted fixture, executes exactly one future workload through the existing production path, preserves complete BF16 evidence, and applies criteria fixed before hardware observation.

Observable completion evidence requires:

- one strict pure fixture core accepts only the exact 420,072-byte fixture and all accepted whole-file, ordered-artifact, shape, order, byte, and per-artifact identities;
- production fixture mode uses the same input padding, state upload, decode ABI, kernel creation, core partition, and writer extraction as historical `wkv7` execution rather than a copied hardware implementation;
- the fixture path launches DecodeL with exactly `G=1`, `L=1`, `S=64`, `H=12`, initializes the writer buffer deterministically, and enqueues exactly one workload with no warmup, benchmark loop, retry, fallback, or alternate kernel;
- complete raw writer, extracted output, and extracted post-state BF16 artifacts are written before a deterministic receipt and manifest;
- the receipt binds fixture/source/runtime-vector identities, artifact byte counts and BLAKE3 values, finite PCC/NMSE/max-absolute diagnostics, exact-bit mismatch counts, the preset output/state NMSE ceilings, and explicit non-claims;
- passing requires complete artifacts, finite metrics, and both output and state NMSE below the inherited pre-hardware `L=1` ceiling of `6e-2`; thresholds cannot be supplied by the caller or changed after observation;
- a separate fixture-bearing package fixes the executable vector and installs a typed `rwkv-lab` single-process plan without adding fixture, checkpoint, layer-harness, safetensor, PyTorch, or additional Python paths to ordinary ttWKV7;
- no-device self-tests prove parsing, host preparation, expected extraction, comparison, receipt construction, wrapper preflight, plan validity, deterministic replay, and malformed-input rejection without opening a device;
- all historical package, host-layout, decode-reader, shape, data-movement, and architecture checks remain successful and production kernels remain unchanged.

False completion includes running random data, sampling outputs, hashing only aggregate metrics, launching more than once, using a standalone copy of production setup, allowing caller-selected fixtures/thresholds/kernel/shape/device, accepting a coherent but unpinned fixture, creating a device in self-test or preflight, embedding the fixture into ordinary ttWKV7, or calling the prepared path physical correctness.

## Functional core and imperative shell

A pure boundary-fixture core owns exact parsing, artifact identities, reviewed dimensions, comparison metrics, threshold evaluation, artifact metadata, and deterministic receipt construction over in-memory bytes and vectors. It performs no filesystem, environment, process, device, clock, logging, or network operation. Positive and negative tests exercise this core without mocks.

The production runner remains the imperative device shell. Its shared execution function accepts reviewed input/state vectors and an explicit execution policy. Historical test/bench callers retain their random-data and benchmark behavior. Fixture mode supplies accepted vectors, requests one enqueue, initializes output storage, reads the complete writer buffer, delegates extraction and comparison to pure helpers, and writes fixed artifacts through a thin filesystem shell.

A dedicated wrapper is a second thin shell: `self-test` and `validate-runtime` are device-free; `probe` rejects arguments and validates exact device/runtime state before invoking the fixed fixture path. A separate immutable package supplies the exact fixture and typed plan. No active run root, execution lock, owner isolation, or authorization is created by this change.

## Decisions

### Decision: Extend the existing production execution path

**Choice:** Parameterize production execution with reviewed inputs and an explicit one-shot policy, then add strict fixture mode.

**Rationale:** This shares kernel creation, circular buffers, runtime arguments, core partitioning, launch, readback, and writer extraction. It minimizes drift and makes the future result relevant to the production path.

### Decision: Keep fixture authority in a separate package

**Choice:** Ordinary ttWKV7 accepts a fixture path but does not carry fixture bytes. A separate package copies only the accepted fixture, fixes the wrapper vector, and carries the plan.

**Rationale:** Hardware preparation can depend on real evidence without adding the checkpoint or fixture to ttWKV7's normal runtime closure.

### Decision: Preserve raw evidence and use predeclared aggregate criteria

**Choice:** Preserve the full writer matrix plus exact extracted output and post-state BF16 bytes. Report PCC, NMSE, maximum absolute error, and exact-bit mismatches. Pass only when output and state NMSE are finite and below `6e-2`.

**Rationale:** Raw bytes permit later independent audit. The ceiling is inherited from the existing reviewed `L=1` production acceptance function and is fixed before device observation; it is not claimed as exact parity.

## Portfolio-search registry

Search budget: three architecture families, one accepted fixture authority, one installed production-runner authority, one advisory review, two implementation rounds, and deterministic local checks. Serial source lenses are correlated; the advisory model is non-authoritative. Allowed outcomes are `validated`, `blocked`, `exhausted`, or `user-decision-required`.

| family | mechanism | claim | state | blocker / next check |
|---|---|---|---|---|
| Shared production fixture mode | Parameterize existing execution and feed exact retained-state fixture | Future hardware result traverses the production host/kernel path | validated | Complete exact-fixture, one-shot-source, artifact, wrapper, plan, closure, and no-device checks pass. |
| Standalone boundary executable | Duplicate runner setup in a dedicated program | Isolated fixture launch | rejected | Duplication can drift from production kernel/CB/runtime setup and weakens relevance. |
| Existing random diagnostic | Run `wkv7 test decodeL 1 1 64 12` unchanged | Repaired kernel smoke and random numerical signal | rejected | Does not bind the accepted fixture or preserve complete raw evidence. |
| Immediate hardware run | Execute before harness completion | Fast physical signal | blocked | Prior authorization is exhausted and evidence/criteria are not yet packaged. |

The advisory review ranked shared production fixture mode above a standalone executable and random orchestration. Its suggestions are not validation evidence.

## Risks / Trade-offs

- **Production regression from refactoring:** preserve historical callers and outputs, compile with warnings denied, run all existing checks, and source-check unchanged kernel identities.
- **Fixture parser duplicates accepted authority:** use one new pure parser for the device path and lock it against the same whole-file, ordered, shape, order, byte, and artifact identities; malformed fixtures fail before device creation.
- **One-shot path accidentally benchmarks or retries:** represent launch count as a reviewed policy, assert fixture launch count is exactly one, and reject timing-loop reachability in fixture source checks.
- **Writer tail contains stale data:** zero-initialize the complete writer buffer before launch and preserve the complete raw writer artifact; meaningful output/state extraction remains separately checked.
- **Aggregate tolerance hides local defects:** preserve every BF16 result, exact-bit mismatch counts, max absolute errors, PCC, and NMSE. Passing remains a bounded tolerance claim only.
- **Prepared code is mistaken for authorization:** package, plan, and receipt state explicitly say not run; this change performs no device access and creates no execution lock.
- **Fixture leaks into ordinary closure:** closure checks reject the layer harness, checkpoint, safetensor, boundary fixture, and PyTorch from ordinary ttWKV7, and require its existing 68-path closure and Metalium Python identity to remain unchanged.

## Non-claims

This change does not establish reader completion, BRISC or NoC behavior, circular-buffer initialization, compute or writer execution, numerical P150 correctness, exact BF16 parity, full-layer or full-model parity, generation, serving, throughput, or latency. It does not authorize or perform another hardware process.

## Validation evidence

The pre-change baseline passed with ttWKV7 package `/nix/store/z1j611i6c60rklwrzlilsa61ivjlnkxv-ttwkv7-unstable-2026-06-22`, decode-reader check `/nix/store/76y7srnjm6xj69dhc6gda4ijk52g5n33-rwkv-ttwkv7-decode-reader-check`, host-layout check `/nix/store/6hpdc5isg0nmv03pixhcfnpyhzmpgr6f-rwkv-ttwkv7-host-layout-check`, architecture check `/nix/store/b85dmwmfg7zjlszfihpa9bwxg9k04srz-ttwkv7-architecture-check`, checkpoint-shape `PASS`, and synthetic data-movement `PASS`.

The final ordinary package is `/nix/store/5alwcj7ff65s1zg6q475akwayafmh0bz-ttwkv7-unstable-2026-06-22`. The separate fixture-bearing package is `/nix/store/jnn1h441vnxjaqfw35yabvsaznvvq6dg-rwkv-ttwkv7-boundary-device-0.1.0`. The readiness check is `/nix/store/ww8flxsnynczyk7k0s94awyk06mia5a9-rwkv-ttwkv7-boundary-device-check`.

The 343-byte self-test receipt is deterministic with BLAKE3 `c1b6b14a04acb3aca238a2ae77854a22701d70da1ffcc2e9efee9f852048d6e8`. It binds fixture BLAKE3 `731f44866c869300ca330f703f1adad4c3ae7ee62b832fa881a6bf4ea90211cd`, ordered artifact BLAKE3 `44d91ad223079fa9ae5f6f0dc9943fc6d13cc25cb09262111ad433c7e6288494`, fixed NMSE ceiling `0.06`, `device_initialized: false`, and `workload_enqueue_count: 0`.

The pure core validates the complete fixture before parsing alternate metadata, all six input artifact identities, retained pre-state, expected output, expected post-state, shapes, orders, counts, lowercase hexadecimal, finite BF16 values, and ordered hashing. It compares every one of 768 output and 49,152 post-state BF16 values. Positive exact comparison, zero-result rejection, non-finite rejection, wrong-length rejection, and immediately-below/equal/immediately-above threshold controls pass. Equality and excess at `0.06` reject.

Fixture mode requires DecodeL, `G=1`, `L=1`, `S=64`, `H=12`, one-shot policy, and complete capture. It shares production input padding, state upload, circular buffers, kernel creation, decode ABI, core partition, workload, and writer extraction. The full 96-by-768 writer buffer is zero-initialized before the sole workload and future readback preserves 147,456 writer bytes, 1,536 output bytes, and 98,304 post-state bytes. The receipt records all actual per-core reader/compute/writer vectors, complete artifacts, PCC, NMSE, maximum absolute errors, exact-bit mismatches, thresholds, source identities, and a domain-separated combined identity that includes comparison metrics.

The fixed wrapper accepts only `self-test`, `validate-runtime`, or argument-free `probe`; fake-runtime checks prove `probe` maps exactly to `boundary-run FIXTURE LOGS/rwkv-boundary-device`. Missing, wrong, relative, store, or non-loopback runtime state rejects. Changed and truncated fixtures reject. A malformed `boundary-run` and an exact fixture paired with a forbidden `/nix/store` artifact root both reject before artifact-root creation or device initialization. No valid `boundary-run` is invoked by any check.

The typed plan ID is `bdbc6834b6ba3da6e1404858697a01d68d1f58734401d81f4a0f0d2999a5b239`. Its 2,548-byte receipt has BLAKE3 `f67d0ec34a6b67f3a887d1c9c57134d165f6f74fb811b65aecda89068bdd5e89` and fixes physical device 1, package/executable/kernel/owner paths, one process, 900-second timeout, 10-second kill grace, 1,200-second rollback, complete artifact roles, restoration requirements, success marker, and non-claims. The deterministic 901-byte initial classification has BLAKE3 `a7169162e27db4a98b6b3cca834f1e601739ccd7c7398ad49ccd32bc09f38190`, outcome `not_run`, no safety issues, no success claim, and an unconsumed process budget.

The 529-byte readiness receipt has BLAKE3 `4d63d2a74d6e0e05d5512294bfbd657870f96f0167c60dc2041aacacdd40f09f`. It locks ordinary closure cardinality 68, boundary closure cardinality 118, fixture identity, and self-test/plan/not-run receipt identities. Ordinary ttWKV7 retains exactly its pre-existing Metalium Python path `/nix/store/l9k0anq0z7zz81zcwy035jfwap9ga6rl-python3-3.13.13`; neither closure adds a layer harness, checkpoint, safetensor, PyTorch, or torch-equation path.

Installed source identities are runner BLAKE3 `29ecf61ab7333b4fabcf3ea2d13855bd0280a6dad5d695d749c2a1f3430dc370` over 59,059 bytes and pure boundary core BLAKE3 `e644934c561be74c852e6e223f8a25e2564e1cdeda165c2a7570efa378de8b20` over 24,653 bytes. The fixed wrapper BLAKE3 is `560e9bcb15be11ff7c82ef1ed2cf5da25d9ef1ce46f9f142e2558bc16ce07043` over 3,708 bytes; installed typed plan BLAKE3 is `9a421012b0bdb9d8ab988e04406303ead3546e247eafbd18e7575f816e1b8595` over 2,701 bytes.

Production kernels remain byte-identical: decode reader `221a9e9cb987902e99e4e50bfe5dce2d9f44a5252720b5d3dcbd13fbadb85fca`, decode compute `bbda1f84aa2fcef7a946de76e0a0a03202e068c822f54b80c9cab5f4e13e35d0`, and writer `80ecf2f848144aa1a693f6b3b854542d2fd752bed8c83d9cbce31bd16e261b74`. Historical decode-reader `/nix/store/360la0zgb3f9wb2f8dmkjy17qdl7w3lq-rwkv-ttwkv7-decode-reader-check`, host-layout `/nix/store/1yk29inrvfwvm9xs4ny7r8jsxls15zpj-rwkv-ttwkv7-host-layout-check`, checkpoint-shape, synthetic data-movement, and architecture `/nix/store/b85dmwmfg7zjlszfihpa9bwxg9k04srz-ttwkv7-architecture-check` checks pass.

Full `pre-commit run --all-files` passes. Clean detached-worktree Cairn validation and proposal/design/tasks gates report `valid: true`, `verdict: "PASS"`, and no issues. The advisory audit raised strict-fixture and no-hardware-execution observations that are intended boundaries, not defects; its useful threshold-edge concern produced adjacent below/equal/above controls. Deterministic repository checks remain authoritative. No Tenstorrent device, owner service, runtime cache, Metalium device initialization, command queue, kernel execution, execution lock, or hardware evidence path was accessed.
