# Design: Real-weight RWKV-7 layer harness

## Goal and Success Contract

Run two fixed checkpoint tokens through layer zero entirely on the CPU and produce a deterministic receipt that binds the checkpoint, tensor schema, recurrence inputs, carried state, and layer output. Success requires:

- exact checkpoint revision, SHA-256 fetch hash, and independently reported BLAKE3 content hash;
- exact BF16 tensor names and shapes for the 768-wide, 12-head, 64-channel, 3072-intermediate layer;
- BOS then EOS execution so the second step exercises decay and the rank-one state update from nonzero state;
- a host recurrence cross-check whose maximum absolute deviation stays within a named FP32 tolerance;
- finite layer output and state plus stable BLAKE3 fingerprints; and
- positive and negative Rust and Nix checks without a Tenstorrent device.

Loading only a header, running only the zero-state first token, accepting a shape-compatible wrong tensor, emitting a fingerprint without model digest validation, invoking Python/FLA/Torch dynamically, accessing Metalium, or claiming a generated token is false completion.

## Authorities and Equations

The checkpoint is `RWKV/RWKV7-Goose-World2.8-0.1B-HF` revision `d81965cb4e1a9f96696b4f70b84212b8f2e43216`, with SHA-256 SRI `sha256-uWqL3CHhX3HgyVZT3MO+ieVkthmtUHPJ7b+9B/eElFM=` and BLAKE3 `905f82048a64b881f9267117a398feb8a8a92bcc5233666bf67904e0d899d0e5`. Its config fixes 12 layers, hidden width 768, head width 64, intermediate width 3072, and vocabulary 65536.

The layer composition follows FLA v0.3.0's checkpoint names and block wiring, while the recurrence follows BlinkDL's NumPy reference and the pinned ttWKV7 CPU oracle:

`S_t = S_{t-1} · diag(w_t) + (S_{t-1} · a_t) · b_t^T + v_t · k_t^T`

`o_t = S_t · r_t`

For FLA-formatted RWKV-7 inputs, `w = exp(-exp(-0.5) * sigmoid(w_lora))`, `a = -normalize(k_raw * k_k)`, and `b = normalize(k_raw * k_k) * sigmoid(a_lora)`. The adjusted key is `k_raw * (1 + (sigmoid(a_lora) - 1) * k_a)`.

## Functional Core and Imperative Shell

`pkgs/rwkv-layer-harness/src/lib.rs` owns pure shape validation, BF16-to-FP32 tensor conversion helpers, layer normalization, group normalization, matrix-vector products, time mixing, recurrence, gate correction, channel mixing, receipt statistics, and canonical FP32 BLAKE3 fingerprints. It performs no filesystem, environment, process, device, or clock I/O.

`src/main.rs` is a thin shell. Nix embeds one immutable checkpoint path and expected BLAKE3 digest at compile time. The shell reads that regular Nix-store file, verifies the digest, deserializes safetensors, extracts only the required embedding rows and layer-zero tensors, calls the core, and prints JSON. It accepts no model path, token, layer, device, command, or suffix.

## Numerical Boundary

All BF16 checkpoint values are decoded exactly and all arithmetic is CPU FP32. This is a deterministic host reference, not a bitwise prediction of FLA BF16 kernels or Tenstorrent BF16 tiles. The recurrence is evaluated twice: once through the production matrix update and once through a separately structured scalar oracle over the same two real token steps. The receipt reports their maximum absolute state and output deviations.

The harness fingerprints canonical little-endian FP32 bytes for each second-token recurrence vector, final state, and final layer output. It also reports element counts, minimum, maximum, mean, L2 norm, and finite status. Negative fixtures reject wrong dtype, transposed shapes, duplicate/missing tensor names, checkpoint digest drift, non-finite values, and recurrence-oracle divergence.

## Portfolio Search

| Family | Mechanism | State | Evidence or blocker |
|---|---|---|---|
| Rust CPU layer reference | Decode pinned safetensors and directly implement the reviewed equations | selected | No dynamic runtime, GPU, Python, or hardware dependency; exact checkpoint schema is testable. |
| FLA execution | Load the Hugging Face remote model and execute FLA/Triton | rejected | FLA v0.3.0 warns that its RWKV implementation may be buggy, requires dynamic Python/Torch/Triton, and its recurrent kernel is not a device-free CPU oracle. |
| Header-only adapter | Validate tensor names and shapes without arithmetic | falsified | Does not establish layer composition, recurrence state carry, matrix orientation, or finite real-weight outputs. |
| Full model generation | Run all layers and sample a token | deferred | Stronger than the current rung and would obscure whether failures originate in checkpoint adaptation, one layer, logits, or tokenization. |

## Adversarial Audit

- The first token alone cannot exercise decay or rank update, so the harness requires BOS followed by EOS and fingerprints only after state carry.
- Safetensors shape equality is checked before every extraction; no implicit transpose or broadcast is accepted.
- The checkpoint's Nix SHA-256 and runtime BLAKE3 serve different purposes and are both retained.
- The CLI has no arbitrary file argument and no process-spawn, `/dev/tenstorrent`, Metalium, owner-control, or retry path.
- Stable fingerprints are regression evidence for this CPU FP32 implementation, not independent physical correctness.
- FLA's own warning is retained as a claim boundary rather than suppressed.

## Validation Budget and Stop Conditions

Primary sources are bounded to the pinned checkpoint metadata, BlinkDL's RWKV-7 NumPy/reference equations, FLA v0.3.0 checkpoint wiring, and ttWKV7's pinned CPU oracle. Validation is limited to Rust unit tests, checkpoint fetch/digest checks, one CPU layer integration run, Nix package checks, formatting, and Cairn gates. Hardware access is excluded.

The slice terminates as `validated` when the real-weight receipt and all negative checks pass, `blocked` on an exact checkpoint/schema/tool mismatch, or `exhausted` if the recurrence cross-check cannot discriminate an orientation error. Full-model and physical correctness are not allowed outcomes.

## Validation Evidence

The final package and install check pass at `/nix/store/4611r3nd278hrccw39qfj9iyz3psmqmq-rwkv-layer-harness-0.1.0`. The Nix fixed-output fetch and runtime BLAKE3 verification bind the 382,111,072-byte checkpoint. Nine Rust unit tests plus formatting and Clippy with warnings denied cover manual recurrence values, state carry, transposed decay, normalization, matrix orientation, digest mismatch, dtype/shape rejection, non-finite rejection, and stable fingerprints.

Two package invocations produce byte-identical receipts. The second-token WKV input fingerprints are `r=6e5391b0a6ddd727c0a5359b18676bd5d3dfd3fcc69f088da9fb15bba69934e3`, `w=34cbe8c4586627577d9a51d49db1b6a2106b50f616ae5983593b0c4196488b33`, `k=5a8b7ce512d92fb71038218c03441012ad096e990749aa7020c94ae9ed9cd176`, `v=5aeeebb2d8d1d7f83b82df3fc1a810c4191ff297cae604d010001640ded69650`, `a=7f43c153e6a3b25b1dc0d8aef8707aafb7a8983d49e22f42917ae0663c10cd51`, and `b=1aebc84d2384d3d3550aa9f4a123912ecad1ae43c6f127bcdc1207fbafb2b88e`. The final state fingerprint is `63718d8139e7a70770d8ca7b0663faca0d87ea3d5b99a45a5d895a827cec868f`; the final layer output fingerprint is `cca5dded173404e19115bc749f25aab0c26200282a739bb3da98923d2d9a8e26`. Maximum production/oracle deviations are `1.4901161e-8` for state and `2.9802322e-8` for output, below the `1e-5` FP32 tolerance. Focused `deadnix`, `statix`, and `treefmt` checks pass; clean detached-worktree Cairn validation and proposal, design, and tasks gates report `valid: true` with no issues. Cairn sync executed the unblocked semantic merge with receipt `58f89255fafc17b5af6d0ac8571295ab16ed990b16d291e94f3686648235ff7a`. No Tenstorrent device, owner service, Metalium runtime, or ttWKV7 process was accessed.
