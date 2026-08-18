## Context

The pinned `RWKV/RWKV7-Goose-World2.8-0.1B-HF` checkpoint has hidden size 768, head size 64, and head count 12. ttWKV7 already implements a 64-wide per-head recurrence, and its readers address a head as `ht = h / 32` plus `lh = h % 32`. The incompatible boundary is in host preparation: upstream computes `Ht = H / 32`, tilizes an unpadded `H x S` matrix, and computes chunked work units as `IC / 2`. For `H=12`, the first expression is zero; for any odd instance count, the last expression drops work.

The writer's state mapping is not the blocker. Let `q = h*S + i`. Its destination row group is `q / H` and column group is `q % H`; flattening those groups reconstructs `q`, so the mapping remains bijective for 12 heads. This change therefore repairs only the host shape, padding, dispatch, validation, and audit boundary and leaves reader, compute, and writer kernels unchanged.

## Goals and success contract

The exact goal is a device-free validated ttWKV7 host path that can prepare the checkpoint's `S=64`, `H=12` tensor shape without dropping heads, while retaining the accepted default 32-head diagnostic behavior. Completion evidence requires:

- an argument-free host self-test for `S=64`, `H=12` that exits before device creation;
- exact 32-row head padding with all 12 real rows preserved and all 20 padding rows zero;
- `Ht=1`, `St=2`, and six two-instance chunked units for one sequence;
- ceiling work grouping for an odd negative-control instance count;
- strict rejection of malformed, zero, unsupported, excessive, or suffixed shape requests before device creation;
- installed patched source plus positive and adversarial source checks;
- unchanged historical fixed diagnostic command vectors and passing package/architecture checks.

False completion includes compiling without exercising layout conversion, changing only a displayed head count, padding values without changing the buffer tile count, using floor division while special-casing 12, allowing `atoi` coercion, opening a device in self-test mode, altering production kernels, changing the fixed diagnostic wrapper, or representing device-free shape preparation as P150 execution or numerical parity.

## Functional core and imperative shell

Pure host helpers own checked ceiling division, shape derivation, strict positive-integer parsing, padded native-input construction, output-state index mapping, and self-test comparisons. `main` remains the imperative shell: it selects mode, reports diagnostics, and creates one Metalium device only after mode, argument, and shape validation. `shape-test` returns from the pure path before the device-creation statement.

The production upload matrix uses `Hpad = ceil(H/32)*32` rows. Real heads occupy rows `[0,H)` and rows `[H,Hpad)` are exact zero. Buffer sizing uses `Ht = Hpad/32`, while work dispatch uses only `IC = G*H`; padded rows are storage only and never become recurrent instances. Chunked work units use `ceil(IC/2)` so a final single instance remains assigned.

The explicit test/benchmark suffix is `[S] [H]`; omitted values retain upstream defaults `64` and `32`. Only supported 64-wide WKV heads are accepted in this rung. Parsing is exact decimal positive-integer parsing with bounded conversion, not partial or sign-coercing `atoi` behavior.

## Portfolio-search registry

Search budget: four mechanism families, one pinned upstream source authority, one local advisory attempt, two implementation rounds, and deterministic local validation. Allowed outcomes are `validated`, `blocked`, `exhausted`, or `user-decision-required`.

| family | mechanism | claim | state | blocker / next check |
|---|---|---|---|---|
| Serving wrapper first | Build a tt-kernel streaming shell around current ttWKV7 | End-to-end serving progress | blocked | Current host cannot represent 12 heads; a wrapper would preserve the wrong ABI. |
| Kernel rewrite | Change readers/compute/writer for the checkpoint shape | Full operator-shape support | falsified | Readers and writer already parameterize real heads; changing kernels adds risk without addressing host floor division. |
| Host shape repair | Pad host input rows, use ceiling layout/work counts, and audit without a device | Exact checkpoint-shape preparation | validated | Compiled host, deterministic no-device self-test, unchanged defaults, and adversarial source/argument mutations pass. |
| Real-weight operator fixture | Feed checkpoint-derived WKV vectors through the repaired host ABI | Numerical bridge to ttWKV7 | independent | This is the next rung after host shape preparation; it requires a canonical BF16 boundary artifact and remains outside this change. |

The local VibeThinker advisory request returned `fetch failed` and contributes no evidence.

## Risks and mitigations

- **Padding becomes computation**: work instance count remains `G*H`; tests distinguish real and padded rows.
- **A shape helper hides integer overflow**: checked multiplication and bounded integer conversion fail before allocation or device creation.
- **The default diagnostic changes accidentally**: Nix checks retain the exact fixed wrapper vector and assert default shape output.
- **The self-test accidentally opens hardware**: mode dispatch returns before the sole `MeshDevice::create_unit_mesh` call; source checks enforce ordering and the Nix sandbox executes the self-test.
- **A partial chunked group is dropped**: ceiling grouping is tested with both the 12-head checkpoint and an odd instance control.
- **Source checks validate only prose**: the compiled binary must execute Metalium's CPU layout conversion and exact round-trip checks; source mutation fixtures provide complementary structural evidence.
- **Device-free evidence is overstated**: non-claims explicitly exclude kernel execution, numerical parity, physical reader completion, serving, and performance.

## Non-claims

This change does not establish ttWKV7 numerical agreement with the checkpoint, kernel execution, P150 correctness, repaired-reader completion, Metalium runtime initialization, tt-kernel integration, token generation through ttWKV7, serving behavior, throughput, or latency. It does not authorize another hardware process.

## Validation evidence

The pre-change baseline package `/nix/store/9ci0570g2yh2cc5m8li1qw8bq4gp0fa4-ttwkv7-unstable-2026-06-22` built before host-core edits. The final package `/nix/store/ld1lsrvbind6b95m7mlk87zkmzv01cv4-ttwkv7-unstable-2026-06-22` compiles the patched host against pinned TT-Metalium and passes the complete existing package install checks. Production reader, compute, and writer kernels are byte-unchanged by this change; the existing dual-architecture check remains `/nix/store/b85dmwmfg7zjlszfihpa9bwxg9k04srz-ttwkv7-architecture-check`.

Two independent invocations of the final package's `wkv7 shape-test` are byte-identical. The exact 90-byte output is `ttWKV7 checkpoint shape self-test: PASS S=64 H=12 Hpad=32 St=2 Ht=1 C=768 chunked_units=6\n`, with BLAKE3 `6dc76b13a7389dc14d6263703033fc5a1943fa722021b7a33efbc6505edd7f43`. The compiled self-test round-trips Metalium's CPU tiled-NFACES conversion, checks all 12 real rows and 20 zero padding rows, verifies the writer-state index bijection, preserves default `S=64`, `H=32`, rejects malformed parsers and unsupported shapes, retains the odd thirteenth instance in a clamped final group, and returns before the sole device-creation statement.

The package installs the exact patched `wkv7_runner.cpp` as a 33,303-byte source artifact with BLAKE3 `bf5f3fe360a62335517f598ba5eca983bbb2ef73ca0e33686a9341ab68842182`. Install checks reject floor head-tile division, unpadded tilization, floor two-instance grouping, unclamped final-group ends, additional device creation, coercing parsers, malformed workload counts, zero or unsupported shapes, missing shape partners, and unexpected suffixes. The historical diagnostic wrapper still dispatches exactly `test all 1 1` and does not receive the optional shape suffix.

Focused `deadnix`, `statix`, and `treefmt` checks pass. Clean detached-worktree Cairn validation and proposal, design, and tasks gates report `valid: true`, `verdict: "PASS"`, and no issues. The surviving portfolio candidate is the host shape repair. Serving-first remains blocked by the previously incompatible host ABI; a kernel rewrite was falsified as unnecessary for the shape boundary; and the real-weight BF16 WKV fixture remains the next independent rung. The advisory model returned `fetch failed` and contributes no evidence. Cairn sync added the accepted requirement with receipt `4867e2d12a0bf9546228f8d983c4cd10ee5ad13e8c4185dbc739a74570ab8e8e`. No Tenstorrent device, owner service, runtime cache, Inspector process, Metalium device initialization, or ttWKV7 kernel process was accessed.
