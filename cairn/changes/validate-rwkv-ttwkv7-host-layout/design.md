## Context

Two accepted device-free boundaries now meet at an unvalidated seam. `rwkv-layer-harness` installs a 420,072-byte canonical JSON fixture containing six `[12,64]` little-endian BF16 input vectors, retained `[12,64,64]` pre-state, and expected output/post-state. ttWKV7's production host accepts `S=64`, `H=12`, pads input heads to 32 rows, uses a 32-row sequence-padded state upload, and reads a writer matrix that interleaves state rows by the real head count. Synthetic self-tests cover these formulas separately, but no consumer carries the real bytes through the exact host storage transforms.

This change remains device-free. Metalium's CPU `convert_layout` helper is permitted; `MeshDevice::create_unit_mesh`, command queues, kernel compilation, owner-service changes, runtime state directories, and physical device access are not.

## Goals and success contract

The exact goal is a deterministic cross-package proof that the accepted real-weight BF16 fixture maps losslessly into ttWKV7's production host upload/readback layouts for `G=1`, `L=1`, `S=64`, and `H=12`.

Observable completion evidence requires:

- production and validator code share one pure host-layout core for input padding, state upload, and writer indices;
- every fixture artifact has exact metadata, shape, count, lowercase hexadecimal bytes, per-artifact BLAKE3, and ordered BLAKE3 identity;
- each logical input becomes one `[32,64]` matrix with 12 real rows and 20 exact-zero rows;
- retained state becomes `[32,49152]` with the complete logical state in sequence row zero and 31 exact-zero rows;
- expected output/post-state become a `[96,768]` writer matrix with the accepted output in row zero, the exact state interleave in rows 1 through 64, and 31 exact-zero tail rows;
- Metalium tiled-NFACES output matches an independently indexed four-face oracle element-for-element and untilizes exactly;
- explicit little-endian BF16 transformed buffers and a domain-separated combined BLAKE3 are deterministic and exact;
- changed metadata, order, shape, bytes, hashes, state orientation, element counts, JSON syntax, path shape, and command suffixes fail closed;
- source checks prove the boundary branch returns before the sole device-creation statement.

False completion includes round-tripping only through the same Metalium helper, hashing only fixture metadata, using a duplicate host-layout formula that can drift from production, accepting a coherent but unpinned fixture, silently transposing state, treating padding rows as recurrent heads, checking only sampled values, invoking a device before validation, or describing host layout as ttWKV7 numerical or P150 parity.

## Functional core and imperative shell

`ttwkv7-host-layout.h` is the pure deterministic core. It accepts in-memory vectors and reviewed dimensions and returns padded input matrices, state-upload matrices, and checked writer indices. It performs no filesystem access, environment access, printing, Metalium device work, or mutation outside returned values. The production runner delegates to this core before its existing Metalium tilization and device upload. The data-movement validator delegates to the same core and supplies Metalium's CPU layout converter.

The data-movement binary remains the imperative shell. `boundary-self-test PATH` reads exactly one file, parses JSON, validates fixed authorities and BLAKE3 identities, invokes pure transformations, emits one deterministic receipt, and exits. Argument parsing rejects missing or extra values. The branch is before `MeshDevice::create_unit_mesh`; no fallback or retry exists.

## Exact host layouts

For each input artifact, logical index `head*64+dimension` is copied into row-major `[32,64]`; rows `[12,32)` are zero. The matrix is converted from `LIN_ROW_MAJOR` to `TILED_NFACES` and then rounded to Metalium BF16. Because source values are already exact BF16, re-encoding must preserve every bit.

The retained state is row-major `[Gpad, H*S*S] = [32,49152]`. Sequence row zero stores logical index `head*4096+row*64+column`; all later sequence rows are zero. It is then converted to tiled-NFACES.

The writer matrix has `C=768`, `T=1`, logical rows `T+G*S=65`, and 96 padded rows. Output index is `head*64+dimension` in row zero. Let `q=head*64+row`; state index is row `1+q/12`, column `(q%12)*64+column`. This is checked as a bijection and inverted back into `[12,64,64]`; rows `[65,96)` remain zero.

The independent tiled-NFACES oracle enumerates tile rows and columns, then four 16-by-16 faces in top-left, top-right, bottom-left, bottom-right order, then row-major elements inside each face. It does not call Metalium conversion.

## Portfolio-search registry

Search budget: four mechanism families, one pinned fixture authority, one pinned Metalium layout authority, one advisory attempt, two implementation rounds, and deterministic local validation. Allowed outcomes are `validated`, `blocked`, `exhausted`, or `user-decision-required`.

| family | mechanism | claim | state | blocker / next check |
|---|---|---|---|---|
| Device execution now | Upload the real fixture and run decode on P150 | Physical operator parity | blocked | Hardware authorization is exhausted; any device process is forbidden. |
| Rust-only layout model | Reimplement ttWKV7 storage transforms in the fixture crate | Logical compatibility without Metalium | independent | It cannot establish the installed Metalium tiled-NFACES mapping or production C++ drift. |
| Duplicate C++ consumer | Parse and transform the fixture in a standalone validator | Concrete C++ buffer receipts | audit | A duplicated padding/state formula could agree with itself while production drifts. |
| Shared host core plus independent NFACES oracle | Make production and validator share pure row-major construction, then compare Metalium conversion to a separate face-order oracle | Exact device-free real-weight host-buffer mapping | validated | Complete transforms, independent face-order comparison, inverse extraction, deterministic hashes, source checks, and adversarial fixtures pass. |

The local VibeThinker advisory request returned `fetch failed` and provides no validation evidence.

## Risks and mitigations

- **Shared code makes comparison circular**: only row-major construction is shared; tiled-NFACES indexing is independently implemented and compared element-for-element.
- **A changed fixture remains internally coherent**: exact whole-file, per-artifact, and ordered BLAKE3 authorities are pinned and checked before transformation.
- **BF16 conversion changes bits**: decoded fixture bits are re-encoded through Metalium BF16 and compared exactly.
- **State packing is accidentally transposed**: complete writer extraction reconstructs every `[head,row,column]` element; transpose and orientation mutations are negative fixtures.
- **Padding leaks values**: every input, sequence, and writer tail padding element is checked for exact zero.
- **Production and validator diverge later**: both compile against the shared pure header, and source checks reject a reintroduced duplicate formula.
- **No-device mode opens hardware**: source ordering and sandbox execution require return before the single mesh-device creation call.
- **Evidence is overstated**: receipts and reports retain explicit non-claims.

## Non-claims

This change does not establish ttWKV7 recurrence execution, compute-kernel equations, reader/writer kernel execution, repaired-reader completion, Metalium device initialization, P150 correctness, full-layer or full-model BF16 parity, token generation through ttWKV7, tt-kernel integration, serving, throughput, or latency. It does not authorize another hardware process.

## Validation evidence

The baseline ttWKV7 package `/nix/store/ld1lsrvbind6b95m7mlk87zkmzv01cv4-ttwkv7-unstable-2026-06-22`, architecture check `/nix/store/b85dmwmfg7zjlszfihpa9bwxg9k04srz-ttwkv7-architecture-check`, RWKV package `/nix/store/r0ckr9j0kh831banqnpd1xwr0cx9gh5i-rwkv-layer-harness-0.1.0`, checkpoint shape self-test, and data-movement self-test all passed before the shared-core change.

The final ttWKV7 package is `/nix/store/wqqn11pfhfxnvj0fjl8ipcxcvs2h5b51-ttwkv7-unstable-2026-06-22`. Its new validator compiles with `-Wall -Wextra -Wpedantic -Werror`; the complete historical install checks still pass. The dual-architecture kernel result remains `/nix/store/b85dmwmfg7zjlszfihpa9bwxg9k04srz-ttwkv7-architecture-check`, confirming production kernel inputs are unchanged. Final `shape-test` still reports `S=64 H=12 Hpad=32 St=2 Ht=1 C=768 chunked_units=6`, and the data-movement oracle still reports `PASS`.

The cross-package check is `/nix/store/si5fnm8bamakwyfwfqjf4km5fa945gx4-rwkv-ttwkv7-host-layout-check`. Its installed 1,783-byte `receipt.json` is byte-identical to a fresh direct validator run and has BLAKE3 `777d156d5b3ab459cd622d0cd99f62cd31c918be9ebc25292aeea7d254b0059e`. The receipt binds fixture BLAKE3 `731f44866c869300ca330f703f1adad4c3ae7ee62b832fa881a6bf4ea90211cd` and ordered logical-artifact BLAKE3 `44d91ad223079fa9ae5f6f0dc9943fc6d13cc25cb09262111ad433c7e6288494`.

The six exact transformed input-upload BLAKE3 identities in `[a,w,k,v,r,b]` order are `12038a499897e2a403b179f31a54e7201ffdf6f80402c91d24e0b4c86e5ed849`, `3e00c954d55ad0f5ab0f9f8b869d81dcb19c5bc572e9637ef6836fc76f8264cc`, `8ef11709d3f136a17ca7f5a3cf2fb91b52424eeda51d28797be429a12e5f8fa7`, `e9bea640d3c09a80143dc04be45e77935e7639e1e0f064c0009b8cbfdaba154c`, `9e64a0be9c6b753dae7ab5300f2fff33a660ef025be6e5893f13f56eaceec534`, and `c7a95d4671b51545417c5bcb930321325d1bfe431746879971bd2335500b6858`. They cover 12 total tiles. The 1,536-tile retained-state upload has BLAKE3 `a2966fb56eb97345c35c7710f222eac752d7d2f8f84eb0bf2a8e11e85ae466f7`; the 72-tile writer matrix has BLAKE3 `a4e8062724fae1002b2d7c812725caf1268466813743f3097efdc7ad25254e21`. Their domain-separated combined layout identity is `caee8424524e33f54c85145a248794d4776713a78d2bbb6dbd5f03401a4835d6`.

Every transformed element matches the independent top-left, top-right, bottom-left, bottom-right 16-by-16 face oracle before hashing. Metalium BF16 re-encoding preserves the accepted source bits, untilization reconstructs all six logical inputs and retained state exactly, every input and sequence padding element is zero, writer inverse extraction reconstructs all 768 output and 49,152 post-state elements, and all 31 writer tail rows are zero.

Fourteen malformed-fixture cases reject changed authorities, input order, state orientation, shape, artifact name, count, byte, case, ordered hash, JSON syntax, truncation, duplication, readability, and path type. Missing and suffixed command vectors also fail with status 2. Compiled pure-core controls reject invalid padding, channels, lengths, tilizer output, sequence padding, writer bounds, and non-tiled matrices. Source checks require all shared production calls, reject duplicate state/writer formulas, prove the pure header has no filesystem, environment, clock, logging, or device surface, and prove the validator has no device API surface.

The package-owned runtime closure contains 68 paths and contains no RWKV layer harness, Goose checkpoint, or safetensor path; the fixture enters only the separate cross-package check. Installed source identities are: runner BLAKE3 `e596d66bfc2bc13ac2f1a6336b1daf2f8a93d0b74b700885a1a487b95221272d` over 33,150 bytes; shared core BLAKE3 `e2281e53a976b1b9e4ae7b383ec779aa457d20d99ca127c203968c7b8171b238` over 10,016 bytes; validator BLAKE3 `51007d86043b0eec9d2bf627e1ce0b1f89976fcd35ad80def133ad0b1835865f` over 38,315 bytes.

Focused `deadnix`, `statix`, and `treefmt` checks pass after accepting treefmt's C++ formatting. Clean detached-worktree Cairn validation plus proposal, design, and tasks gates report `valid: true`, `verdict: "PASS"`, and no issues. The surviving portfolio candidate is validated. Hardware execution remains blocked by exhausted authorization; Rust-only modeling remains independent and weaker for installed Metalium layout; duplicate C++ construction was rejected by extracting the shared core. The advisory attempt returned `fetch failed` and provides no evidence. No Tenstorrent device, owner service, runtime cache, Metalium device initialization, command queue, kernel compiler, or hardware evidence path was accessed.
