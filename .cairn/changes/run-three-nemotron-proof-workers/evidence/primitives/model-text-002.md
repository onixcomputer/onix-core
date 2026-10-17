I'll begin the discovery work. Let me start with context.json as required.





Now let me read module-scope.md and check proof-gap-sites.tsv.




Let me search the module index and scope docs for candidate concepts.




Let me inspect the closest existing retry/admission/replay modules to find gaps.





Let me inspect job_retry and fenced_attempt internals to understand current attempt/retry contracts.




Let me survey the module index for all module names to find gaps, and check for any "context"/"guided"/"dedup"/"session" concepts.




Let me inspect circuit_breaker, lease, and quota to understand existing coverage and identify distinct gaps.





Let me confirm gaps by searching for window/dedup/admission/overflow concepts across the index and source.




Let me confirm rate_limit is time-based (not carryover) and check for any carryover/dedup-window module.




I have enough source-backed evidence. All three candidates are absent as modules (confirmed: no `bounded_retry_context`/`attempt_context`/`dedup_window`/`recent_keys`/`carryover` modules; `rate_limit` is time-based refill; `retry`/`job_retry` are stateless; `quota` has no carryover; `eviction` is cache-line eviction). Now I'll write the report.



The report has been written to `findings.md`. Here is a summary of the discovery.

## Summary

**No primitive was implemented or verified.** All three candidates are UNVERIFIED proposals requiring fresh Verus specs/impls/proofs. This was a read-only discovery; only `findings.md` was created.

**Ranked shortlist (concrete, bounded, not renamings or sufficient compositions):**

1. **Bounded guided retry with attempt-context overflow** — carries a fixed-capacity attempt record sequence (`MAX_ATTEMPT_CTX = 8`), decides retry guided by context, and on context overflow rejects with the context unchanged. Closest existing: `src/retry.rs:24-34` (`should_retry`, stateless), `src/job_retry.rs:20-70` (scalar retryable/attempts/cooldown), `src/fenced_attempt/model.rs:4-5` (`MAX_EVENTS`, phase linkage — not retry guidance). None model a bounded carried context with an overflow-reject-unchanged contract.

2. **Bounded idempotency/dedup admission window with overflow** — bounded FIFO key window (`MAX_DEDUP_KEYS = 64`): admit new, reject duplicate unchanged, on overflow evict oldest (or reject-new). Closest existing: `src/eviction.rs` (count-based cache eviction only, requirements.md `r[eviction.should-evict]` lines 1098-1100), `src/vote_tally.rs` (unbounded idempotence), `src/bitfield.rs` (fixed-width). No `dedup_window` module exists.

3. **Bounded carryover quota with overflow loss** — quota with a carry cap where unused capacity carries forward up to the cap and excess is lost; rejection leaves `(used, carry)` unchanged. Closest existing: `src/quota.rs:21-64` (fixed limit consume/release roundtrip, no carry), `src/rate_limit.rs:22-31` (time-based refill). No `carryover_quota` module exists.

**Duplicate rejections (source-backed):** `retry`/`job_retry`/`fenced_attempt` for #1; `eviction` for #2; `quota`/`rate_limit` for #3.

**Confirmed absences (grep of `src`):** no `bounded_retry_context`/`attempt_context`/`dedup_window`/`recent_keys`/`admission_window`/`carryover_quota` modules. Consumers are labeled hypothesis (no documented demand). All citations are local source/doc lines; no external public sources used.

Full report: `/home/brittonr/git/OnixResearch/trellis/target/nemotron-workers-20261017T162448Z/primitives/work/findings.md`.
