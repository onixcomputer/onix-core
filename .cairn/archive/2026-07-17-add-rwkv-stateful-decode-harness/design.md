# Design: Stateful RWKV-7 decode harness

## Success Contract

The exact goal is a deterministic device-free decode that starts from zero model state, executes a fixed BOS seed, greedily selects three token IDs, and feeds the first two selected IDs back as the next recurrent inputs while retaining distinct state for all twelve layers.

Observable completion evidence is:

- one pure token-transition function consumes an explicit prior model state and returns a new state plus final layer output;
- the incremental path executes input IDs `[BOS, generated_0, generated_1]` without resetting or sharing layer state;
- after every step, a separate replay path starts from zero and executes the complete processed input prefix;
- incremental and replay paths agree within named tolerances for final normalized hidden values, full logits, all recurrent states, top-two ranking, and direct BF16-row head audit;
- after the seed step, retained-state hidden values differ from a same-token zero-state control by more than a named floor, rejecting reset-equivalent execution;
- selected token IDs, their next-step use, EOS observations, state/logit fingerprints, replay and reset-control deviations, exact budget, checkpoint identity, and non-claims appear in a byte-stable receipt; and
- positive and negative tests reject incomplete state, reset-vs-carried equivalence assumptions, wrong input chaining, replay disagreement, malformed rankings, caller arguments, and execution primitives.

False completion includes generating three IDs without feeding them back, replaying from zero while claiming retained-state execution, updating only WKV matrices while dropping attention or channel history, sharing one layer state, stopping before the fixed diagnostic budget, hiding EOS continuation, comparing only token IDs, or contacting hardware. Excluded outputs are decoded text, tokenizer correctness, normal EOS stop behavior, sampling, unbounded generation, framework parity, ttWKV7 parity, P150 correctness, repaired-reader completion, and performance.

Audit risks are state ownership, immutable-versus-mutating transition semantics, processed-prefix ordering, token embedding selection, EOS policy ambiguity, cumulative oracle tolerances, replay circularity, and accidental changes to accepted layer and one-token receipts.

The authority budget reuses the pinned checkpoint configuration and exact FLA v0.3.0 cache/model wiring already recorded by the accepted greedy-token change. Retrieval is limited to those accepted artifacts and current code. The implementation budget is one retained-state construction plus one replay mechanism; the audit budget is one adversarial pass. Allowed terminal outcomes are `validated`, `blocked`, `exhausted`, or `user-decision-required`.

## Approach Registry

| Family | Mechanism | Claim | Discriminating artifact | Gap | State |
|---|---|---|---|---|---|
| explicit state transition | Pure `state + token -> state + hidden` transition reused by incremental execution | Selected tokens are actually consumed with retained state | Per-step input/output chain and state fingerprints | simpler | active |
| zero-state replay | Recompute each processed prefix from a fresh state | Incremental cache composition matches complete-prefix execution | Hidden, state, logits, and ranking deviations per step | simpler | active |
| same-token reset control | Execute only the current token from zero state | Retained state has an observable effect after the seed | Named minimum hidden divergence for non-seed steps | simpler | active |
| repeated full replay only | Recompute prefixes and report their last token | Produces the same IDs without maintaining state | No independent retained-state artifact | equivalent | rejected: false completion |
| external framework cache oracle | Compare against FLA/PyTorch cache execution | Could add framework-level parity | Reproducible dynamic framework and arithmetic contract | unknown | blocked: outside this bounded package and not required for state-composition proof |

The surviving candidate combines explicit retained state with zero-state replay. The mechanisms are correlated because both reuse the same one-token layer equations, but they differ in state lifetime and composition. Exact agreement validates cache composition only, not the equations against an external framework.

## Functional Core and Shell

`ModelExecutionState` owns all twelve `LayerState` values, twelve scalar-oracle matrices, and cumulative per-layer deviations. `run_model_token` takes model weights, one embedding, and a prior state by value, then returns the next state and final layer output. Sequence and replay helpers are folds over that pure transition. Head evaluation consumes final layer output and immutable normalization/head weights. The binary shell only validates its embedded Nix-store checkpoint, reads bytes, invokes the pure decode function, and writes JSON.

## Decode Policy

The diagnostic seed is exactly BOS token ID `1`. The generated-step budget is exactly three. Step zero executes BOS and selects `generated_0`; step one executes `generated_0` and selects `generated_1`; step two executes `generated_1` and selects `generated_2`. The final selected token is intentionally not executed. EOS is recorded but does not shorten this diagnostic budget; continuing after EOS is an explicit state-transition probe and must not be represented as normal language-model stopping behavior.

For each step, replay starts from zero state and processes every input ID seen by the incremental path through that step. It must agree on final hidden values, flattened recurrent matrices, logits, top two IDs/logits, recurrence-oracle bounds, and direct BF16 head audit. A second zero-state control processes only the current input token: it must match the seed step and diverge above the named floor on later retained-state steps. BLAKE3 fingerprints bind every exact vector used for reporting.

## Adversarial Audit

Attempt to falsify the candidate by resetting state before a selected token, swapping processed-token order, feeding the previous input instead of the selected output, dropping attention/channel history while keeping matrices, sharing layer slots, shortening at EOS, perturbing replay output, making retained execution reset-equivalent, transposing the head, or changing accepted one-token fingerprints. Deterministic real-checkpoint identities, replay equality, retained/reset divergence, and negative fixtures are acceptance evidence; test count or plausible token IDs are not.

## Claim Boundary

A validated receipt establishes only exact CPU FP32-from-BF16 stateful token-ID transitions for the pinned checkpoint, fixed BOS seed, and three-step diagnostic policy. It does not establish text, tokenizer mapping, normal EOS stopping, sampling, arbitrary prompts, long-context stability, framework parity, device execution, ttWKV7 integration, P150 correctness, reader completion, or performance.

## Validation Evidence

The final package and install check pass at `/nix/store/q7nwvwx2ysyr56dyw1idjacv1h42hxxh-rwkv-layer-harness-0.1.0`. Accepted layer-zero and one-token receipts remain unchanged. Seventeen Rust tests, formatting, and Clippy with warnings denied cover recurrence values and orientation, normalization, digest/schema failures, cross-layer value interpolation, head ranking/orientation, model inventory, explicit state shape, generated-input chaining, replay tolerance, retained/reset discrimination, non-finite values, and stable fingerprints.

Two exact-checkpoint executions produce byte-identical decode receipts. The processed IDs and generated IDs are both `[1, 1, 1]`, but retained state changes the generated logits from `0.04493069` to `6.9543834` to `6.486726`. The three final-hidden fingerprints are `04f6971c67f2fb45e3e8d26164a872b6e7d4d8ba847f26ec170fcd347df6e89f`, `812728ef2bd878f91df9d2ede34aebdffa19fc83c25319d8cf24d1b041bfa30a`, and `401b9ad0f87cfc436fc53fe3d1e977c6aaba1546582e9f07daf46549730ed7ab`. The corresponding logit fingerprints are `762581cfa10ae11cde207349bd844e59fdaceca5c9288db937928c4f356c3263`, `3daaa9712bb4851e5fcccdc6d2b7644c9c29b495c7ece0f483e97cddf782be9d`, and `ccb66a0dde8fc0490872092dce9aa3b778a3b1d5ce0bb1d256d130ec7a423917`. Recurrent-state fingerprints are `e61647dfa4e341599f939181919100509c652797050b76b4f2f80ada7134a591`, `15658cb672bb56cec6132e4b72463a5966db26fdc471ca631b3a308112bf76a2`, and `56ab5c6de04f5e359a7d26390ce36b0c7551ef41dbcb998373ab4c2f0f344ecb`.

Incremental versus zero-state full-prefix replay deviations are exactly zero for hidden values, logits, and recurrent matrices at every step. The minimum post-seed retained-versus-same-token-reset hidden deviation is `32.84725`, above the `1e-4` floor. Maximum recurrence state and output deviations are `1.9073486e-6` and `9.536743e-7`, below the `1e-5` tolerance. No EOS was selected. The authority, retained-state, replay, and reset-control lenses all survive the adversarial checks; they remain correlated through the shared layer equations and do not establish framework parity. The advisory model returned unreadable output and contributed no evidence. Focused `deadnix`, `statix`, and `treefmt` checks pass; clean detached-worktree Cairn validation and proposal, design, and tasks gates report `valid: true` with no issues. Cairn sync executed the unblocked semantic merge with receipt `975db1a57007d4ce41068631eb8be0ef6b957ae7cf51d1d487392b5896264d5a`. No hardware, owner service, Metalium runtime, or ttWKV7 process was accessed.
