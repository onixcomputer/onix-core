# Trellis bounded verified-logic primitive discovery report

**Status:** Read-only discovery. No primitive has been implemented or verified. All candidates below are UNVERIFIED proposals, labeled observation / hypothesis / UNVERIFIED proposal as applicable. This report is advisory and does not claim Verus acceptance.

## Method and scope

- Read `context.json` (limit 30) — confirms role `primitives`, scope = current Trellis corpus, baseline verified 11146 / errors 0 / trusted boundaries 15.
- Read `docs/module-index.md` header (lines 1-9) — 625 public modules, 591 requirement-covered; labels are facts, not strength scores.
- Read `docs/module-scope.md` (lines 25-195) — coverage boundaries for arithmetic/DS, Raft, concurrency, financial, memory, storage, R1CS, Nix/Nickel, cross-module composition.
- Read `docs/proof-gap-sites.tsv` (17 rows) — permanent trusted boundaries are all crypto/hash/version/codec bridges, none in bounded retry/dedup/quota logic.
- Bounded source reads of closest existing modules and narrow greps for `dedup|recent|window|admission|overflow|carry|guided|rate_limit|backpressure|drop|evict` in `docs/module-index.md` and `src`.

No `src` edits were made. Only `findings.md` is written.

---

## Ranked shortlist of three NEW bounded verified-logic primitives

### Candidate 1 (rank 1): Bounded guided retry with attempt-context overflow

**Missing contract (UNVERIFIED proposal).** A retry admission that carries a *bounded attempt context* (fixed-capacity sequence of attempt records) across attempts, decides whether to retry *guided* by that context, and on *context overflow* (context full) transitions to a terminal/rejected state rather than growing unbounded. On any rejection, the context must be unchanged. The existing `retry`/`job_retry` decide only from scalars (attempt count, retryable flag, cooldown) and carry no bounded context.

**Closest existing source + contracts (observations, cited):**
- `src/retry.rs`: `should_retry_spec(attempt, max_attempts, is_retryable)` = `is_retryable && attempt < max_attempts` (lines 24-26); `should_retry` (lines 30-34) ensures equality; `never_retries_exhausted` (lines 44-47) requires `attempt >= max_attempts`. Stateless scalar decision; no carried context, no overflow.
- `src/job_retry.rs`: `is_retryable_error_spec(error_code)` = transient range [100,200) (lines 20-22); `attempts_remaining_spec(attempts, max_attempts)` (lines 38-44); `is_cooldown_elapsed_spec(now, last_attempt_time, cooldown_ms)` using int arithmetic to avoid overflow (lines 65-70). Still scalar, no bounded attempt-context history.
- `src/fenced_attempt/model.rs`: `MAX_EVENTS = 4_096` (line 4), `EPOCH_LIMIT = u64::MAX` (line 5) — phase/epoch/event linkage admission with a bounded event history, but it governs phase transitions and rejection preservation, not retry guidance or attempt-context overflow.

**Why composition is insufficient (hypothesis).** Composing `retry.should_retry` + `job_retry.attempts_remaining` + `fenced_attempt` still yields no bounded *carried attempt context* with an overflow transition and unchanged-on-rejection semantics. `fenced_attempt` bounds events but does not expose a retry decision guided by a bounded attempt record sequence; `retry`/`job_retry` have no context field at all. No existing contract states "on context overflow, reject and leave context unchanged."

**Finite model (UNVERIFIED proposal).**
- `MAX_ATTEMPT_CTX = 8` attempt records.
- Record = `{attempt_no: u64, outcome: u8 in {SUCCESS=0, RETRY=1, FAIL=2}, context_hash: u64}`.
- State = bounded sequence `ctx: Seq<Record>` with `ctx.len() <= MAX_ATTEMPT_CTX`.
- `guided_retry_admit(ctx, attempt_no, outcome, is_retryable, max_attempts)`:
  - Success/failure appended only if `ctx.len() < MAX_ATTEMPT_CTX` and `should_retry_spec(attempt_no, max_attempts, is_retryable)`; returns `Updated` with `ctx' = ctx.push(record)`, `ctx'.len() == ctx.len()+1`.
  - If `ctx.len() == MAX_ATTEMPT_CTX` (overflow) → returns `RejectedOverflow`, `ctx' == ctx` (unchanged-on-rejection).
  - If `!should_retry_spec(...)` → returns `RejectedTerminal`, `ctx' == ctx`.
- Overflow behavior: 9th record is rejected; context never exceeds 8; no unbounded growth.

**Plausible consumer (hypothesis, not documented demand):** job/worker retry supervisors that must bound per-attempt diagnostic context and avoid unbounded memory growth on retry loops.

**Independent future admission steps (scoped, not implemented):**
1. Verus spec + impl of `guided_retry_admit` with `ensures` for `Updated`/`RejectedOverflow`/`RejectedTerminal` and `ctx' == ctx` on both rejections.
2. Proofs: `ctx.len() <= MAX_ATTEMPT_CTX` invariant preserved; overflow rejection leaves context byte-identical; retry guidance refines `retry.should_retry_spec` when context has room.
3. Small counterexample/boundary exploration: `ctx.len() == 8` with a retryable, non-exhausted attempt must still reject with context unchanged; `ctx.len() == 7` with `attempt >= max_attempts` must reject terminal, unchanged.
4. External assumptions: none beyond Verus machine integers (u64) — no crypto, clock, storage, or network.

**Duplicate rejected:** `retry` + `job_retry` + `fenced_attempt` composition. Cited above; they lack bounded carried context and overflow-reject-unchanged semantics, so they do not establish this contract.

---

### Candidate 2 (rank 2): Bounded idempotency/dedup admission window with overflow

**Missing contract (UNVERIFIED proposal).** A bounded fixed-capacity window of recently-seen keys admitting a new key, rejecting a duplicate (unchanged), and on overflow either evicting the oldest (FIFO) or rejecting the new key, with unchanged-on-rejection. This is a general bounded dedup admission primitive, distinct from cache-line eviction.

**Closest existing source + contracts (observations, cited):**
- `src/vote_tally.rs`: idempotent vote recording (`record_vote_idempotent`, lines 237-238) but over an unbounded server set, no bounded window, no overflow eviction.
- `src/bitfield.rs`: `insert_idempotent` / `clear_idempotent` (lines 277-341) over a fixed-width bitfield, not a general key dedup window.
- `src/eviction.rs` / `src/eviction_score.rs`: `should_evict` iff `count >= capacity` (requirements.md `r[eviction.should-evict]`, lines 1098-1100), `find_lru`, `evictable_count` saturating sub (requirements.md lines 1114-1115) — cache-line eviction, not a general bounded key-dedup admission window with key identity and duplicate rejection.
- `src/fenced_attempt`: `event-idempotence` evidence exists (proof-evidence-bundle.json lines 626-630) but within phase/epoch linkage, not a standalone bounded dedup window.

No `dedup_window`, `recent_keys`, or `admission_window` module exists (grep of `src` for `dedup_window|recent_keys|admission_window` found none).

**Why composition is insufficient (hypothesis).** `eviction.should_evict` gives a count>=capacity decision but has no key identity, no duplicate detection, and no unchanged-on-rejection for a dedup window. `vote_tally` idempotence is unbounded. No existing contract states "admit new key, reject duplicate unchanged, on overflow evict oldest (or reject new), bounded capacity."

**Finite model (UNVERIFIED proposal).**
- `MAX_DEDUP_KEYS = 64`.
- State = bounded FIFO sequence `keys: Seq<u64>`, `keys.len() <= 64`, no duplicates.
- `dedup_admit(keys, k)`:
  - If `k ∈ keys` → `RejectedDuplicate`, `keys' == keys` (unchanged-on-rejection).
  - Else if `keys.len() < 64` → `Admitted`, `keys' = keys.push(k)`.
  - Else (`keys.len() == 64`, overflow) → choose policy P (FIFO evict oldest): `AdmittedEvicted`, `keys' = drop_first(keys).push(k)`; or reject-new variant: `RejectedOverflow`, `keys' == keys`.
- Overflow behavior: capacity 64 hard bound; duplicate leaves state unchanged.

**Plausible consumer (hypothesis, not documented demand):** message/deduplication gateways, idempotency-key admission, request dedup windows.

**Independent future admission steps (scoped, not implemented):**
1. Verus spec/impl of `dedup_admit` with membership spec and `ensures keys' == keys` on duplicate/overflow-reject.
2. Proofs: `keys.len() <= 64`; no-duplicate invariant preserved; FIFO eviction preserves order of retained keys.
3. Boundary exploration: duplicate at full capacity (unchanged); new key at capacity (evict oldest or reject); empty window admit.
4. External assumptions: none (pure bounded sequence over u64).

**Duplicate rejected:** `eviction`/`eviction_score`. They decide eviction by count and LRU for cache lines; they do not model key identity, duplicate rejection, or a general dedup admission window (requirements.md `r[eviction.should-evict]` lines 1098-1100 is count-based only).

---

### Candidate 3 (rank 3): Bounded carryover quota with overflow loss

**Missing contract (UNVERIFIED proposal).** A quota with a fixed limit where *unused capacity can carry forward* up to a carry cap, and *excess unused capacity beyond the cap is lost (overflow loss)*; consumption is admitted only within limit plus available carry, and on rejection `(used, carry)` is unchanged. Distinct from `quota` (fixed limit consume/release roundtrip, no carryover) and `rate_limit`/`tiered_rate_limit` (time-based refill, no carryover cap with overflow loss).

**Closest existing source + contracts (observations, cited):**
- `src/quota.rs`: `quota_remaining_spec(limit, used)` = saturating at 0 (lines 21-23); `quota_allows_spec(limit, used, request)` = `used + request <= limit` (lines 49-51), implemented overflow-safe (lines 55-64); consume/release roundtrip conservation. Fixed limit, no carry cap, no overflow loss.
- `src/rate_limit.rs`: `tokens_after_refill_spec` = time-based refill capped at burst (lines 22-31); time-based, no carryover cap with overflow loss.
- `src/tiered_rate_limit.rs`: tiered rate limiting (index line 540) — also time-based refill.

No `carryover_quota` or `carry_quota` module exists (grep of `src` for `carryover|carry_forward|unused_capacity` found only unrelated `consensus_fast_path::carry_forward`).

**Why composition is insufficient (hypothesis).** `quota.consume`/`release` roundtrips within a fixed limit and never carries unused capacity forward; `rate_limit` refills by time. Neither defines a carry cap with overflow loss of unused capacity, nor an admission decision whose rejection leaves `(used, carry)` unchanged. Composing them does not yield "carry forward up to cap, excess lost."

**Finite model (UNVERIFIED proposal).**
- `limit`, `carry_cap` constants (e.g. `limit = 100`, `carry_cap = 10`).
- State = `(used: u64, carry: u64)` with `used <= limit`, `carry <= carry_cap`.
- `carry_consume(used, carry, request)`:
  - Available = `limit - used + carry` (computed in int/u128 to avoid overflow).
  - If `request <= available` → `Admitted`, `used' = used + request`, `carry' = carry` (carry not consumed by default), unchanged-on-success bounded.
  - Else → `Rejected`, `(used', carry') == (used, carry)` (unchanged-on-rejection).
- `carry_idle(used, carry)` (unused capacity carried, excess lost): `carry' = min(carry + (limit - used), carry_cap)`; overflow loss = `carry + (limit - used) - carry'` dropped; `used` unchanged.
- Overflow behavior: carry hard-capped at `carry_cap`; excess beyond cap is lost, not stored; rejection leaves state unchanged.

**Plausible consumer (hypothesis, not documented demand):** bounded credit/token systems with carryover allowances and overflow loss (e.g., API credit buckets with bounded rollover).

**Independent future admission steps (scoped, not implemented):**
1. Verus spec/impl of `carry_consume` and `carry_idle` with `ensures` for admitted/rejected and unchanged-on-rejection; `carry <= carry_cap` invariant.
2. Proofs: `used <= limit` preserved; carry never exceeds `carry_cap`; overflow loss amount computed exactly; rejected consumption leaves `(used, carry)` byte-identical.
3. Boundary exploration: request exactly equal to available (admit); request one over (reject, unchanged); idle carry at cap (excess lost).
4. External assumptions: none beyond Verus machine integers; no time/clock/network.

**Duplicate rejected:** `quota` (fixed limit, no carry cap/overflow loss; requirements.md `r[quota.allows]` lines 49-51) and `rate_limit`/`tiered_rate_limit` (time-based refill, no carryover cap). Neither models bounded carryover with overflow loss.

---

## Overall findings

- No new primitive has been implemented or verified. All three candidates are UNVERIFIED proposals requiring fresh Verus specs, impls, and proofs.
- Each candidate's closest existing modules were read and cited with line numbers; none directly compose to establish the proposed missing contract.
- Duplicate rejections are source-backed: `retry`/`job_retry`/`fenced_attempt` for candidate 1; `eviction`/`vote_tally`/`bitfield` for candidate 2; `quota`/`rate_limit` for candidate 3.
- Confirmed absences (grep of `src`): no `bounded_retry_context`/`attempt_context`/`dedup_window`/`recent_keys`/`admission_window`/`carryover_quota` modules.
- Public primary sources: none used (no external URLs fetched); all citations are local source/doc lines.
- Consumers are labeled hypothesis; no demand is documented in this corpus for these exact primitives.

## Recommended next step

A maintainer should decide which candidate (if any) to admit, then author a bounded Verus spec + impl + proofs per the "future admission steps" above, followed by boundary/counterexample exploration. Until Verus accepts proofs, nothing is verified.
