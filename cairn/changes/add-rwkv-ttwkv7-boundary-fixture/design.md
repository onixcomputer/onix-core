## Context

The accepted Rust core already computes layer-zero token-local vectors `r`, `w`, `k`, `v`, `a`, and `b`, carries a `[head,row,column]` matrix state, and cross-checks the recurrence through separately structured matrix and scalar loops. The accepted ttWKV7 host shape is `S=64`, `H=12`, `Hpad=32`, `St=2`, `Ht=1`, and `C=768`. What is missing is a canonical artifact at that boundary.

The fixture uses layer zero's second model-config token because its pre-state is nonzero after processing token ID `1`; this discriminates retained state from a reset while preserving the already accepted `[1,2]` diagnostic. It captures the raw recurrence output before group normalization, gate correction, and output projection, because ttWKV7 implements only the WKV recurrence.

## Goals and success contract

The exact goal is a complete, deterministic, device-free BF16 artifact that binds real checkpoint-derived layer-zero WKV inputs and retained state to the accepted ttWKV7 shape and recurrence ABI. Completion requires:

- the exact pinned checkpoint identity and model-config prefix `[1,2]`;
- layer index zero, head size 64, head count 12, hidden size 768, and state size 49,152;
- six complete 768-element WKV input artifacts in ttWKV7 host order `[a,w,k,v,r,b]`;
- one complete retained pre-state, expected raw output, and expected post-state artifact;
- exact little-endian BF16 bytes encoded losslessly as lowercase hexadecimal;
- per-artifact byte counts and BLAKE3 identities plus one ordered combined BLAKE3 identity;
- expected output/post-state recomputed from BF16-decoded boundary values through matrix and scalar oracles within the accepted recurrence tolerance;
- byte-identical repeated fixture output and a package-installed canonical copy;
- positive and negative tests for shape, order, mutation, non-finite input, and argument rejection;
- unchanged historical receipt evidence and clean Rust/Nix/Cairn checks.

False completion includes emitting only statistics or hashes without complete bytes; reusing post-state as pre-state; publishing the projected attention output instead of raw WKV output; keeping FP32 values while labeling them BF16; using native-endian serialization; sorting tensor names instead of preserving ABI order; computing expected output from unquantized values; accepting a changed byte under the same combined identity; invoking ttWKV7 or hardware; or claiming kernel parity from a CPU artifact.

## Functional core and imperative shell

The pure Rust core captures the second-token boundary, validates dimensions and finite values, quantizes each value through `half::bf16`, serializes each BF16 bit pattern explicitly with `to_le_bytes`, builds complete artifact receipts, computes the ordered combined BLAKE3 identity, decodes the quantized values back to FP32, and runs both recurrence oracles. It returns one serializable receipt without filesystem, environment, process, network, or device access.

The thin `rwkv-ttwkv7-fixture` shell embeds only the pinned Nix-store checkpoint at build time, rejects every argument, invokes the core, and writes one JSON document to stdout. Nix owns repeated execution and installs the resulting canonical JSON under `share/rwkv-layer-harness/`.

## ABI contract

- Shape: one sequence, one token, 12 real heads, 64 elements per head.
- Vector logical order: `[head,dimension]` flattened head-major.
- State logical order: `[head,row,column]` flattened head-major and row-major within a head.
- ttWKV7 host buffer order: `a`, `w`, `k`, `v`, `r`, `b`.
- Scalar format: IEEE bfloat16 bit patterns serialized little-endian.
- Expected output order: `[head,row]` flattened head-major.
- Expected post-state order: identical to pre-state.
- Arithmetic: BF16 boundary values decoded to FP32; recurrence accumulation remains CPU FP32.

The artifact does not pre-tilize Metalium tiles. The accepted host shape core owns padded tiled-NFACES conversion, and keeping the boundary logical avoids binding fixture bytes to one transport layout before the host consumes them.

## Portfolio-search registry

Search budget: four mechanism families, the pinned checkpoint and accepted ttWKV7 source authorities, one advisory attempt already exhausted, two implementation rounds, and deterministic local validation. Allowed outcomes are `validated`, `blocked`, `exhausted`, or `user-decision-required`.

| family | mechanism | claim | state | blocker / next check |
|---|---|---|---|---|
| Synthetic ttWKV7 vectors | Reuse upstream random operator inputs | Operator test coverage | falsified | Does not bind the real checkpoint or retained model state. |
| FP32 model dump | Publish the existing Rust vectors and state | Model-bound recurrence input | blocked | ttWKV7 host storage is BF16; quantization and exact transport bytes remain unspecified. |
| Real BF16 logical boundary | Quantize checkpoint-derived retained-state inputs, publish complete bytes, and recompute CPU expectations | Canonical input for the next ttWKV7 integration rung | validated | Complete artifacts, independent recurrence, determinism, package ownership, and adversarial mutations pass. |
| Immediate Metalium execution | Launch the fixture through ttWKV7 | Physical numerical comparison | blocked | The previous single hardware authorization is exhausted; no process is permitted. |

## Risks and mitigations

- **Wrong recurrence layer is captured**: the artifact explicitly names raw WKV output and excludes group normalization/projection.
- **State reset is hidden**: the pre-state is captured immediately before token ID `2` and must have a nonzero fingerprint distinct from zero state.
- **BF16 encoding depends on host endianness**: bit patterns use explicit little-endian byte conversion.
- **ABI order drifts**: a fixed six-name array is serialized in operator order and negative tests reject reordering.
- **Large JSON is mistaken for a summary**: exact byte counts and hexadecimal lengths are validated for every artifact.
- **Matrix and scalar loops share an orientation error**: existing wrong-decay-axis tests remain, and the BF16 boundary runs both separately structured recurrences.
- **Historical receipts drift during capture refactoring**: existing Nix install checks remain exact and run unchanged.
- **Device-free evidence is overstated**: explicit non-claims exclude ttWKV7 execution, Metalium parity, P150 correctness, and performance.

## Non-claims

This artifact does not establish ttWKV7 numerical parity, kernel execution, Metalium initialization, P150 correctness, repaired-reader completion, full-layer BF16 parity, full-model BF16 parity, token generation through ttWKV7, tt-kernel integration, serving behavior, throughput, or latency. It does not authorize another hardware process.

## Validation evidence

The pre-change baseline passed 26 positive and negative Rust tests and built `/nix/store/3rzxs7zzrghqps2f5d8kfjalqqwxb66n-rwkv-layer-harness-0.1.0`. The final package `/nix/store/r0ckr9j0kh831banqnpd1xwr0cx9gh5i-rwkv-layer-harness-0.1.0` passes 28 Rust tests, formatting, Clippy with warnings denied, complete positive/negative install checks, and every historical fixed receipt assertion. The separate framework check remains passing at `/nix/store/yr5na9dkp2zlw1hv3h4fvvwrax1458i1-rwkv-layer-harness-torch-equation-parity`.

The package installs `share/rwkv-layer-harness/ttwkv7-boundary.json`. Two fresh argument-free executions and the installed artifact are byte-identical. The canonical JSON is 420,072 bytes with BLAKE3 `731f44866c869300ca330f703f1adad4c3ae7ee62b832fa881a6bf4ea90211cd`; its ordered artifact identity, which also binds names and logical shapes, is `44d91ad223079fa9ae5f6f0dc9943fc6d13cc25cb09262111ad433c7e6288494`.

The six 768-element, 1,536-byte input artifacts in host order `[a,w,k,v,r,b]` have BLAKE3 identities `2f2bec8195c8fca1027cdb8ef9421921643cc97db9404efe84b5139432096f89`, `e549e829df1f6a05c9e8cbbc0b1e08d078196de57731f54a16cfcc4c9849a0ee`, `4b0248fce75e5ff0d462be2edee6c16c1f2e2f68f1b9f5dbf696e9b3d1f7699b`, `813277dddaee3ee19e87ede402bd65fa0393073c9fb86fb12096d1531676c68f`, `63a08981b8cf0c852cc273e1626ab8aa77d19b141746f729af7cf269de41893d`, and `ad9f5a87a3dcfd04aebef24e0faebdfae30ec06d27369d2ff77fef90c9d38f66`. The 49,152-element retained pre-state and expected post-state are each 98,304 bytes with BLAKE3 `be643f1302ec76ea76ada70b24a830a3398bc463a39915226c61fcf8f67b52cd` and `c76c943bab4cda028b5edae8393919ae3f93f35b79b6a02648d4617e21b414d6`. The 768-element expected raw output is 1,536 bytes with BLAKE3 `9af55cd740a0534c91e6656da5e0fca63386e06ded01d183157d07cba6ea50e8`.

The FP32 source pre-state, raw output, and post-state fingerprints are `3dc1ff13a5ebff20cb32cc43727ec6cbbd1bd6ba828c3f6b60a1acbd193ed30f`, `5b882f55afc0afb4aa98b243708ce506b895c60b9aee83aea225a4b2e11b30e5`, and the previously accepted `63718d8139e7a70770d8ca7b0663faca0d87ea3d5b99a45a5d895a827cec868f`. The quantized retained pre-state maximum absolute value is `1.2421875`, proving it is not zero state.

Maximum input and pre-state BF16 quantization deviations are `0.00641346` and `0.0017508864`. BF16-boundary expected raw output and post-state differ from the unquantized source calculation by `0.00065533817` and `0.0021299124`; these are reported effects, not parity tolerances. Separately structured matrix and scalar recurrence results over the BF16-decoded boundary differ by only `3.7252903e-9` for output and `2.9802322e-8` for state, below `1e-5`.

Negative tests reject non-finite values, empty or changed shapes, wrong element counts, odd or uppercase hexadecimal, changed bytes under stale artifact hashes, changed artifact order, and argument suffixes. Nix checks require all nine complete hexadecimal artifacts and exact identities. Focused `deadnix`, `statix`, and `treefmt` checks pass. Clean detached-worktree Cairn validation plus proposal, design, and tasks gates report `valid: true`, `verdict: "PASS"`, and no issues. No Tenstorrent device, owner service, Metalium runtime, ttWKV7 process, or hardware evidence path was accessed.
