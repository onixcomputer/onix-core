# Corrected Trellis bounded verified-logic primitive discovery report (FINAL TEXT)

**Status:** Read-only discovery / correction. No primitive has been implemented or verified. `findings.md` is preserved unchanged; this is the corrected report replacing the attempt-002 findings. All candidates below are UNVERIFIED proposals, and I explicitly retract/demote those that do not survive review.

---

## Method and scope correction

- Read `context.json` (limit 30): role `primitives`, scope = current Trellis corpus, baseline verified 11146 / errors 0 / trusted boundaries 15.
- Read `docs/module-index.md` header and relevant rows; `docs/proof-gap-sites.tsv` (17 rows, all permanent trust boundaries are crypto/hash/version/codec bridges — none in bounded retry/dedup/quota logic).
- **Honest correction re: source reads:** The 002 tool transcript did NOT actually read `vote_tally.rs`, `bitfield.rs`, `eviction.rs`, or `tiered_rate_limit.rs` despite the report citing them as direct source review. Those citations were not direct source review and must not be treated as such. I have directly read the modules actually cited in the corrected analysis below.
- Direct source reads for this correction: `src/retry.rs`, `src/job_retry.rs`, `src/fenced_attempt/model.rs`, `src/job_idempotency.rs`, `src/seq_set.rs`, `src/ring_buffer.rs`, `src/ucan_replay_admission.rs`, `src/rate_limit.rs`, `src/quota.rs`, `src/metric_window.rs`.
- Grep of `docs/module-index.md` and `src` confirmed: no `bounded_retry_context`/`attempt_context`/`dedup_window`/`recent_keys`/`admission_window`/`carryover_quota` modules. I do **not** infer absence from module spelling alone; I rely on the actual contracts read above.

---

## Disposition of original candidates

### Candidate 1 — Bounded guided retry with attempt-context overflow: DEMOTED / REJECTED as a new primitive

**Source observations (verified):**
- `src/retry.rs`: `should_retry_spec(attempt, max_attempts, is_retryable) = is_retryable && attempt < max_attempts` (lines 24-26); `should_retry` (lines 30-34) ensures equality; `never_retries_exhausted` (lines 44-47). Stateless scalar decision; no carried context, no overflow.
- `src/job_retry.rs`: `is_retryable_error_spec(error_code)` transient range [100,200) (lines 20-22); `attempts_remaining_spec(attempts, max_attempts)` (lines 38-44); `is_cooldown_elapsed_spec(...)` (lines 65-70). Scalar only, no bounded context.
- `src/fenced_attempt/model.rs`: `MAX_EVENTS = 4_096` (line 4), `EPOCH_LIMIT = u64::MAX` (line 5) — bounded event history for phase/epoch linkage and rejection preservation, **not** retry guidance or attempt-context overflow.

**Why it fails the review (objection 1):** The proposed gate reads only `ctx.len()`, `attempt_no`, `max_attempts`, `is_retryable`. It never reads `outcome`, `context_hash`, or history contents, so the claim that the decision is "guided" by the bounded attempt context is **unsupported**. It is `retry.should_retry` plus a bounded append. I did not identify any genuinely missing history-dependent invariant (I will not fabricate one). Without a history-dependent invariant, this is composition of `retry.should_retry` + a bounded append/overflow sequence, and no existing contract states "on context overflow, reject and leave context unchanged" for retry — but a single missing policy statement does not establish a new essential invariant.

**Disposition:** Rejected as a new primitive. The bounded-context-with-overflow piece alone is compositional (bounded sequence + scalar retry gate); the "guided by history" claim is false.

### Candidate 2 — Bounded FIFO dedup/admission window with overflow: REJECTED as a new primitive

**Source observations (verified, closest exact APIs):**
- `src/job_idempotency.rs:18-25` `is_consumed_spec`/`is_consumed`: exact u64-token membership over a consumed `Seq<u64>`; `:51-64` `try_execute_spec`/`try_execute`: fresh → `(true,true)`, already-consumed → `(false,false)`; **caller responsible for appending the consumed token**.
- `src/seq_set.rs:21-28` `is_member_spec`: exact membership; `:572-582` `all_distinct_spec`: no element appears twice.
- `src/ring_buffer.rs:86-124`: bounded u64 `push` (returns `false` if full, count unchanged) and `pop` (returns `None` if empty). Note: `push` rejects on full; it does **not** evict.
- `src/ucan_replay_admission.rs:1-7, 42-48, 80-85`: fail-closed aggregation of caller-supplied replay outcomes; non-empty transcript with no failed outcome accepts.

**Why it fails the review (objection 2):** Bounded FIFO dedup = composition of `ring_buffer` (bounded FIFO, push-reject-on-full) + membership (`job_idempotency`/`seq_set`) + caller append. The overflow policy ("either evict or reject") is a **policy choice**, not an invariant; `ring_buffer.push` already embodies reject-on-full, and evict-oldest is `pop`+`push`. `ucan_replay_admission` already provides fail-closed aggregation of caller outcomes. Simple admission + cap is not automatically a new essential invariant. Finite-window duplicate detection is also distinct from durable exactly-once (no durable storage, crash recovery, or nonce provenance here — those remain caller boundaries).

**Disposition:** Rejected as a new primitive. It is a wrapper/composition, not a new essential invariant. I will not pick an overflow policy or claim novelty for it.

### Candidate 3 — Bounded carryover quota with overflow loss: RETRACTED

**Source observations (verified):**
- `src/rate_limit.rs:20-30` `tokens_after_refill_spec = min(tokens + elapsed_ms*rate_per_sec/1000, burst)` — exact capped arithmetic; choosing `elapsed_ms=1000` and `rate_per_sec=unused` gives the claimed capped-carry arithmetic.
- `src/rate_limit.rs:104-117` `try_consume_spec`/`try_consume`: rejects unchanged when `tokens < cost`, otherwise deducts.
- `src/quota.rs:21-23, 49-51` `quota_remaining_spec`/`quota_allows_spec`: fixed-limit consume/release, no carry cap, no overflow loss.

**Concrete counterexample (objection 3):** `limit=100`, `carry_cap=10`, `used=100`, `carry=10`, `request=1` → `available = 100-100+10 = 10` → `Admitted` → `used' = 101`, violating required `used <= limit 100`. Also `carry_idle` re-credits the same unused capacity repeatedly without a period transition. Merely renaming refill "carryover" does not prove novelty.

**Disposition:** Retracted. `rate_limit` already provides the exact capped-carry arithmetic and `try_consume` already rejects-unchanged/deducts-credit. No distinct justified semantics survive.

---

## Corrected shortlist

**Zero candidates survive this review as new essential bounded verified-logic primitives.** All three original candidates are disposed of above (1 rejected, 2 rejected, 3 retracted). I have not manufactured replacement candidates to satisfy a count, per the role contract. No replacement has been substantiated with a genuine non-composable invariant.

This is scoped to the three candidates under review and their closest actual APIs; it is not a comprehensive claim about all 625 modules in the corpus.

---

## What would be required for any future bounded primitive to be admitted

For any future proposal (including a re-scoped version of candidate 1 or 2), a production-Verus admission must establish, at minimum:

1. **Exact novel contract** — a spec that is not satisfied by composition of existing modules, with a stated invariant that no existing module enforces.
2. **Finite bounded model** — explicit capacity bound, state shape, and the invariant (e.g. `len <= CAP`, `used <= limit`, `carry <= carry_cap`) with overflow behavior.
3. **Success / rejection / overflow behavior** — one unambiguous overflow policy (not "either/or"), and `state' == state` on every rejection (unchanged-on-rejection).
4. **Distinction from durable exactly-once** — finite-window detection vs. durable storage/crash recovery boundaries must be explicit.
5. **Proof obligations** — Verus `ensures` for each branch, invariant preservation, overflow-loss accounting, byte-identical unchanged-on-rejection, and boundary/counterexample tests (e.g. the limit=100/carry_cap=10 case above).
6. **No new assumptions/external bodies/weakened contracts** — per context.json constraints.

None of the three candidates currently meets bar 1 (genuine non-composable invariant). I make no Verus acceptance claim; actual production Verus proof is the sole arbiter.
