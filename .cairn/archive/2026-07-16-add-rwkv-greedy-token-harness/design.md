# Design: Real-weight RWKV-7 greedy-token harness

## Success Contract

The exact goal is a deterministic CPU FP32 execution of the pinned BF16 RWKV-7 checkpoint through all twelve layers for the fixed prefix `[BOS=1, EOS=2]`, followed by final model normalization, the untied language-model head, and one greedy token selection.

Observable completion evidence is:

- exact reviewed names, BF16 dtypes, shapes, and orientations are accepted for every layer, layer-1-through-11 value LoRA, final norm, and LM head;
- each layer owns distinct attention-previous, channel-previous, matrix, and oracle state carried from BOS to EOS;
- layer 0 establishes token-local `v_first`, while layers 1 through 11 interpolate their projected value toward that same token's `v_first` using the reviewed value LoRA;
- production and scalar-oracle WKV recurrence agree within the named FP32 tolerance at every layer and token;
- final normalization and the untied `[65536, 768]` LM head produce finite logits;
- production argmax and a separately structured direct BF16-row scalar head oracle agree on token ID and logit within tolerance;
- two executions emit byte-identical receipts with locked BLAKE3 fingerprints and top-two evidence; and
- positive and negative tests reject reset state, missing or misplaced `v_first`, wrong LoRA activation, transposed head orientation, malformed schema, non-finite values, wrong digests, caller arguments, and execution primitives.

False completion includes stopping after layer zero, sharing one state across layers, resetting between prefix tokens, reusing `v_first` across tokens, omitting value interpolation, treating the embedding table as a tied head, reporting an argmax without finite full logits, decoding text without a pinned tokenizer contract, or contacting hardware. Excluded outputs are sampling, multi-token decoding, text generation, P150 parity, ttWKV7 parity, repaired-reader completion, latency, throughput, and general RWKV correctness.

Audit risks are tensor orientation, layer-indexed optional tensors, recurrent-state ownership, token-versus-layer lifetime of `v_first`, pre-normalization only at layer zero, final normalization after layer eleven, untied head selection, FP32 reduction determinism, and a correlated oracle that silently repeats the production mistake.

The source budget is three exact authorities: the pinned checkpoint `config.json`, FLA v0.3.0 `RWKV7Attention`, and FLA v0.3.0 `RWKV7Block`/`RWKV7Model`/`RWKV7ForCausalLM`. Retrieval is bounded to those known URLs and the checkpoint schema. The tool budget permits Rust/Nix/Cairn validation and one advisory review; the advisory endpoint failed before returning evidence, so it is not counted as support. The implementation and adversarial-audit budget is two rounds. Allowed terminal outcomes are `validated`, `blocked`, `exhausted`, or `user-decision-required`.

## Approach Registry

| Family | Mechanism | Claim | Artifact and discriminating check | Gap | State |
|---|---|---|---|---|---|
| shared-core extension | Generalize the accepted Rust layer core to indexed layer weights and per-layer state, preserving the existing binary | Reuses already tested equations while adding only missing model composition | Existing layer receipt remains byte-identical; all-layer receipt locks new evidence | simpler | active |
| duplicate full-model runner | Copy equations into a new standalone crate | Isolates the new binary from existing behavior | Compare duplicated source and receipts | equivalent | rejected: duplicate logic raises drift risk |
| external framework oracle | Run FLA/PyTorch as the full-model oracle | Could compare end-to-end logits against upstream framework execution | Exact reproducible Python/CUDA-free environment and arithmetic policy | unknown | blocked: dynamic framework path violates the bounded package and would not be an independent equation source |
| scalar head audit | Decode the LM head as a production matrix but independently scan raw BF16 rows for top one | Detects wrong head orientation, row selection, or argmax | Production/direct-oracle token and logit equality plus transposed negative fixture | simpler | active |
| recurrence audit | Keep matrix update and scalar contracted update separately structured for all layers | Detects decay-axis, rank-update, outer-product, and readout mistakes | Per-layer/per-token maximum deviations and existing orientation negatives | simpler | active |

The surviving construction is the shared pure core plus scalar head and recurrence audits. These checks are correlated because they execute in one Rust process, but they use distinct data representations and loop structures. They do not establish framework-level numerical parity.

## Functional Core and Shell

The core consumes checkpoint bytes and an expected digest, validates schema, computes deterministic vectors and receipts, and returns values or explicit errors. Layer execution is split into pure weight loading, one-layer transition, prefix composition, final normalization, head projection, direct head audit, and receipt classification. The existing and new binaries remain thin shells that accept no arguments, require an embedded regular Nix-store checkpoint, read it once, invoke the appropriate pure core, and serialize JSON.

## Model Composition

For each fixed prefix token, the embedding row enters layer zero. Layer zero applies its unique pre-norm, then every layer applies attention norm, time mix, WKV7, gate correction, attention residual, FFN norm, channel mix, and FFN residual. Every layer updates only its own carried state. Layer zero's projected value becomes `v_first` for that token. For later layers:

`v = v_projected + sigmoid(v_lora(x_v)) * (v_first - v_projected)`

The token-local `v_first` is discarded after layer eleven and recomputed by layer zero for the next token. After EOS exits layer eleven, `model.norm` is applied. The untied `lm_head.weight` is decoded as `[vocabulary, hidden]`; each row dot final hidden is one token logit. Greedy selection is deterministic maximum logit with lowest token index winning exact ties. The runner-up and margin are retained as evidence.

## Adversarial Audit

The audit must attempt to falsify the candidate with state reset, state sharing, cross-token `v_first` reuse, missing value interpolation, sigmoid omission, embedding/head substitution, head transposition, wrong final norm placement, malformed optional layer tensors, non-finite vectors, and caller-controlled execution. A passing test count alone is not completion. Acceptance requires the exact real checkpoint, locked output identities, independent head agreement, clean package checks, and Cairn validation.

## Claim Boundary

A validated receipt establishes only this exact checkpoint, fixed prefix, CPU FP32-from-BF16 implementation, all-layer state transitions, final logits, and one token ID. It does not establish decoded text, execution of the generated token as a third recurrent step, sampling, multi-token generation, FLA bit parity, official-runtime parity, ttWKV7 integration, Tenstorrent numerical correctness, reader completion, or performance.

## Validation Evidence

The final package and install check pass at `/nix/store/y7m41z4n2ldcj6p8dgc17lxbbhj5jqjm-rwkv-layer-harness-0.1.0`. The existing layer-zero fingerprints remain accepted unchanged. Thirteen Rust tests, formatting, and Clippy with warnings denied cover manual recurrence, carried-versus-reset state, decay orientation, normalization, matrix orientation, digest mismatch, dtype/shape rejection, interpolation bounds and orientation, deterministic top-two ties, non-finite and undersized ranking, direct BF16 head rows versus transposed shape, incomplete layer inventory, and stable fingerprints.

Two exact-checkpoint executions produce byte-identical token receipts. For prefix `[1, 2]`, the selected token is `2` with logit `2.8641083`; runner-up token `33` has logit `0.89640886`, giving margin `1.9676995`. The final-hidden fingerprint is `af8775318ae4b28af27709dbe1052a8ffcd5bc58f3ae209dea0913801b334f70`, the 65,536-logit fingerprint is `31e5a4c2f979966c1a8ac72b3af8daa16db0f61d33297f7aadea4196816b9662`, and the twelve-layer final recurrent-state fingerprint is `7edee48128b2bb3f9f874e9cbc491d44a2af7f5bb19c53a595ff0bc8eed108fe`. Maximum recurrence state and output deviations are `1.9073486e-6` and `2.861023e-6`, below the `1e-5` tolerance. Production and direct BF16-row head audits agree exactly on the top two and their logits.

The authority lens used the pinned configuration and exact FLA v0.3.0 attention/model wiring. The schema lens required every indexed tensor through the Nix-fixed checkpoint. The adversarial lens retained distinct recurrence loop structures and distinct decoded-matrix versus raw-BF16-row head paths, while negative tests target the named false-completion cases. These lenses are correlated within one Rust implementation and therefore do not establish framework parity. All three declared authority sources and both implementation/audit rounds were used. The optional advisory review failed before returning evidence and contributed no support. Focused `deadnix`, `statix`, and `treefmt` checks pass; clean detached-worktree Cairn validation and proposal, design, and tasks gates report `valid: true` with no issues. Cairn sync executed the unblocked semantic merge with receipt `c29f5e8460c305b90ae9f822ff1036a3b3f8a24e719a4f152ca795b51820b57e`. No hardware, owner service, Metalium runtime, or ttWKV7 process was accessed.
