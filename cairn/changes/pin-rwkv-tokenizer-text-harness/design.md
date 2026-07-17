## Context

The pinned checkpoint and full-model CPU core are accepted, and the three-step fixed-ID decoder proves state retention and exact replay. Its old constants `1` and `2` come from `config.json`, not from the tokenizer or generation override. Inspection at model revision `d81965cb4e1a9f96696b4f70b84212b8f2e43216` proves three conflicting contracts: model-config BOS/EOS IDs `1/2`; tokenizer special BOS ID `0`, tokenizer EOS text `"\n\n"` at ordinary byte-vocabulary ID `261`, Hugging Face wrapper EOS added-special ID `65,530`, and generation-config BOS/EOS IDs `0/0`. Vocabulary IDs `1` and `2` are raw bytes `0x00` and `0x01`.

## Success Contract

The change is complete only when:

- all seven tokenizer/model/generation authority artifacts are immutable Nix inputs with fixed SHA-256 and checked runtime BLAKE3 identities;
- the pure Rust tokenizer accepts exactly 65,529 contiguous vocabulary rows numbered `1` through `65,529`, plus the configured added special ID `0`;
- longest-prefix encoding and exact byte decoding agree with the pinned upstream reference on ASCII, multibyte Unicode, overlapping-token, control-byte, BOS, and EOS fixtures;
- old `[1, 2]` and ID-`1` evidence remains numerically unchanged and labels those IDs specifically as model-config BOS/EOS rather than tokenizer-wrapper or generation IDs;
- an argument-free harness reproduces exact wrapper chat IDs including BOS `0` and wrapper EOS `65,530`, generates within a named budget, stops normally at generation-config EOS ID `0`, records ordinary byte EOS ID `261` separately, and emits byte-identical token, byte, UTF-8 text, recurrent-state, replay, and authority receipts; and
- no process, Metalium runtime, owner service, or Tenstorrent device is accessed.

False completion includes plausible text without artifact identity, successful parsing of only selected rows, a tokenizer library with mutable defaults, decode-only mapping without longest-prefix encoding, changing old numeric evidence, collapsing the three conflicting BOS/EOS authorities into one, continuing past generation-config EOS, or representing CPU text as framework/P150 correctness.

## Retrieval and Validation Budget

Use one model API response and the seven known revision-pinned artifact URLs. Compare one bounded fixture portfolio against the pinned upstream Python reference. Run one baseline Rust suite, focused final Rust/Nix checks, and one clean detached-worktree Cairn gate set. Advisory output is non-authoritative and optional. Terminal outcomes are validated, blocked by exact authority/tool evidence, or exhausted after these bounded checks.

## Approach Registry

| family | mechanism | claim | artifact | gap_strength | state |
|---|---|---|---|---|---|
| artifact authority | revision-pinned Nix fetches plus runtime BLAKE3 | exact tokenizer/model/generation inputs are immutable | seven digest-bound files | simpler | active |
| tokenizer construction | validated Python-literal vocabulary parser plus byte trie | Rust implements upstream longest-prefix behavior | pure parser/trie and malformed fixtures | equivalent | active |
| independent parity | pinned upstream tokenizer on fixed diverse fixtures | implementation agrees outside its own code path | token-ID fixture receipt | equivalent | active |
| model integration | fixed chat-template prefix, retained state, greedy budget, EOS stop | tokenizer IDs feed the accepted model core and generated IDs decode | argument-free text receipt | equivalent | active |
| adversarial audit | semantic relabel, replay, malformed authority, reset and EOS controls | old false labels and likely shortcuts fail closed | negative tests and exact receipt assertions | stronger | audit |

The parity and integration lenses share upstream artifacts but use different implementations. They are not treated as fully independent numerical-model authorities.

## Decisions

### Decision: Preserve old numeric evidence while correcting its semantic labels

**Choice:** Rename old constants and receipt fields to model-config seed/stop terminology. Keep token IDs, arithmetic, vectors, logits, and BLAKE3 fingerprints unchanged, while recording tokenizer and generation IDs separately in the new receipt.

**Rationale:** The evidence remains valuable and exactly follows `config.json`. Recomputing it with generation overrides would erase the accepted regression boundary, while calling one authority universally canonical would hide the repository conflict.

### Decision: Implement the reviewed byte trie directly

**Choice:** Parse the exact upstream vocabulary into unique token bytes and use greedy longest-prefix matching, with no general tokenizer dependency.

**Rationale:** The upstream algorithm is small, byte-oriented, and checkpoint-specific. A direct pure core keeps mutable library defaults and subprocesses outside the runtime boundary and permits exhaustive schema validation.

### Decision: Separate added special ID zero from vocabulary rows

**Choice:** Model ID `0` as the configured special end-of-text token, rows `1..=65_529` as the byte vocabulary, ordinary byte encoding of EOS text as ID `261`, and the Hugging Face wrapper's re-registered EOS special as ID `65,530`.

**Rationale:** The source vocabulary deliberately omits ID zero, while `PreTrainedTokenizer` adds EOS after the highest byte-vocabulary ID. Collapsing either special ID into the ordinary trie would make wrapper tokenization and decoding incorrect.

### Decision: Use one immutable chat prompt and a hard generation budget

**Choice:** Apply the exact configured template to one fixed user message, reproduce wrapper BOS ID `0` and wrapper EOS ID `65,530` in the prompt, run a small named greedy-token budget, stop immediately on generation-config EOS ID `0`, record ordinary byte EOS ID `261` as metadata rather than a stop override, and reject invalid final UTF-8.

**Rationale:** This establishes the first prompt-to-text path while keeping runtime and claims bounded. Arbitrary prompt CLI input and sampling remain later work.

## Adversarial Audit

Attempt to falsify the candidate with missing and duplicate IDs, duplicate token bytes, wrong declared byte lengths, malformed Python escapes, noncontiguous rows, altered tokenizer/model/generation config, BOS inserted as ordinary bytes, wrapper EOS `65,530` replaced by ordinary byte ID `261`, model/tokenizer-wrapper/generation EOS contracts collapsed together, shortest-prefix tokenization, invalid token IDs, invalid generated UTF-8, failure to stop on generation-config EOS, reset state, stale generated inputs, replay mismatch, changed historical vector fingerprints, or a source path containing subprocess/device primitives.

## Risks / Trade-offs

- Python literal syntax in the vocabulary requires a deliberately narrow parser. Exhaustive parsing of the pinned file plus malformed fixtures bounds the supported grammar; this is not a general Python evaluator.
- A short deterministic completion may be low quality because the checkpoint is only 0.1B parameters. The claim is pipeline correctness for one exact prompt, not linguistic quality.
- Upstream-reference tokenizer parity does not establish framework numerical parity for the model.
- Token bytes can split UTF-8 code points. The receipt accumulates bytes across generated tokens and validates only the final bounded output string.

## Validation Evidence

The seven authority files are pinned at the checkpoint revision by Nix SHA-256 and runtime BLAKE3. Exhaustive parsing accepts exactly 65,529 contiguous byte-vocabulary rows (`1..=65,529`) and independently exposes model-config IDs `1/2`, tokenizer BOS `0`, ordinary byte EOS `261`, Hugging Face wrapper EOS `65,530`, and generation-config IDs `0/0`.

The pinned upstream Python implementation validates the independent fixture portfolio: empty input `[]`; ordinary EOS `[261]`; overlapping `aaaa` `[24364]`; ASCII `hello` `[34550]`; Unicode `RWKV λ 世界` `[1413,1184,5044,33,10267,14610]`; controls `00 01 ff` `[1,2,256]`; and byte prompt `[24281,59,3880,261,5585,41693,59]`. The complete pinned Hugging Face wrapper renders `<|rwkv_tokenizer_end_of_text|>User: Hi\n\nAssistant:` and returns `[0,24281,59,3880,65530,5585,41693,59]`, proving that wrapper special-token extraction differs from the inner byte trie. Rust reproduces each exact ID list and byte round trip.

The final package `/nix/store/aikf7s14rfkikf7fpphgmgmmf8v2pyhs-rwkv-layer-harness-0.1.0` passes 22 Rust tests, formatting, Clippy with warnings denied, and Nix positive/negative install checks. Historical layer, greedy-token, and fixed-ID stateful fingerprints remain locked and unchanged. The new argument-free harness is byte-repeatable. Its prompt-ID BLAKE3 is `f5a4ecffc7fe3f4205d095934a95d00ed5a633a02d8f6153fa9cc240c4488778`; generated IDs `[3880,45,308]` have BLAKE3 `e714e3dc953afc6b24fb83aa0e972af26ec6a3145414a371894c4f1fb505fe0c`; exact bytes `2048692c2049` decode to ` Hi, I`; and the budget, not EOS, stops the run.

Per-step generated logits are `7.5499983`, `9.128329`, and `6.486315`. Final-hidden fingerprints are `222a0718f72e1324673a043a6d9d9b3c5a7281457f481e7eae2c48e992165787`, `4448243fad8b4b6e99cda3d36051c1c51a3c04e3b15981e7e91f9dfa638aea63`, and `7b38e06b121655b31f405426c530a86983ac0fe406a5f92ae37489da1140372f`. Corresponding recurrent-state fingerprints are `842a6494a5eb01be12800aaf157054b7f87bce6753f96e83bbe8afcc5271344a`, `b2b4f4efbf5e5ca66006760a5bceba3709c9063fdb817ccba6a989868ce1f9bb`, and `a5de08fbd73c84cedc1032bb29f64f31c2c984d886c4928acdfc318253c0faec`.

Incremental versus full-prefix replay deviations are exactly zero for final hidden values and recurrent matrices. Minimum retained-versus-reset hidden divergence is `21.653366`. Maximum scalar-oracle state and output deviations are both `2.861023e-6`, below `1e-5`. The artifact, byte-trie, wrapper-parity, model-integration, and adversarial-conflict lenses are validated for this bounded claim, though they share the pinned repository and do not establish framework model parity. Advisory review failed with `fetch failed` and contributes no evidence. Focused `deadnix`, `statix`, and `treefmt` checks pass; clean detached-worktree Cairn validation and proposal, design, and tasks gates report `valid: true` with no issues. No hardware, owner service, Metalium runtime, or ttWKV7 process was accessed.
