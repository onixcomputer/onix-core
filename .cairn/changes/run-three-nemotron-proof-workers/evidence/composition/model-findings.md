# Nemotron composition findings

## Verified artifact: `src/composition.rs` (module `nemotron_composition`)

`./verify` result: **2 verified, 0 errors** (partial verification with `--verify-*`). The `nemotron_composition` module verifies cleanly; the earlier rustc E0425 errors (ten missing unqualified functions) were fixed by adding the three imports below. No solver errors remain.

### Imports added to `composition.rs`

```rust
use crate::causal_order::is_causally_ready_spec;
use crate::vector_clock::{happens_before_spec, merge_spec};
use crate::ordering::max_spec;
```

### Preserved public theorem contract (unchanged, not weakened)

```rust
pub proof fn ready_merge_advances(
    msg_clock: Seq<u64>,
    local_clock: Seq<u64>,
    sender: int,
)
    requires is_causally_ready_spec(msg_clock, local_clock, sender),
    ensures happens_before_spec(local_clock, merge_spec(local_clock, msg_clock))
```

Bridge precondition (`is_causally_ready_spec`, `causal_order.rs:31`):
- `msg_clock.len() == local_clock.len()`
- `0 <= sender < msg_clock.len()`
- `msg_clock[sender] == local_clock[sender] + 1`
- `forall j != sender: msg_clock[j] <= local_clock[j]`

Conclusion: `happens_before_spec(local_clock, merge_spec(local_clock, msg_clock))` — every component of the merge dominates `local` and the sender component is strict. `merge_spec` (`vector_clock.rs:108`) is componentwise max; `max_spec` (`ordering.rs:48`) returns the larger operand; `happens_before_spec` (`vector_clock.rs:27`) is pointwise `≤` with at least one strict `<`.

### Unconditional concrete proof (satisfiable, non-vacuous)

`ready_merge_advances_concrete()` (unconditional, no requires) establishes the bridge itself and invokes the theorem:

- `local = [2, 3, 1]`, `msg = [2, 4, 1]`, `sender = 1`
- Readiness: `msg[1] = 4 = local[1] + 1`; `msg[0] = 2 <= 2 = local[0]`; `msg[2] = 1 <= 1 = local[2]`; equal lengths (3); sender in range.
- Merged = `[2, 4, 1]`; `local` happens-before merged (strict at index 1: `3 < 4`).
- Satisfiability evidence: all counters are small u64 values (`<= 4`), so no `local[sender] + 1` overflow; `local[1] < u64::MAX` holds concretely. The instance is non-identical (`local != msg` and `local != merged`).

### Precise finite-model limits

- Domain: finite sequences of `u64` over a fixed process count `n = len`.
- Readiness requires `msg[sender] = local[sender] + 1`, so soundness implicitly assumes `local[sender] < u64::MAX` (no wraparound); the concrete instance satisfies this.
- `happens_before_spec` requires a strict index, so `n >= 1` and `sender` must be a valid index; the witness uses `n = 3`.
- Lengths of `msg_clock` and `local_clock` must be equal; the bridge precondition enforces this.
- Result is a finite-model guarantee: for this fixed 3-process instance, the strict advance is machine-checked, not asymptotic.

## Composition opportunities

### Opportunity 1 (VERIFIED): readiness => merged-clock strict advance

**Source-grounded:** composes `causal_order::is_causally_ready_spec` with `vector_clock::merge_spec` and `vector_clock::happens_before_spec` via `ordering::max_spec`. This is the actual checked witness in `composition.rs` (see above). The nonsender entries of `msg` may already exceed `local` (e.g. a nonsender local counter greater than the raw message counter), so readiness alone does not imply `local` happens-before the raw message clock; only the merge makes the sender's strict advance visible while keeping every component `>= local`. This is a genuine causal-order/vector-clock composition, not an alias facade.

### Opportunity 2 (UNVERIFIED ADVISORY): lease.rs + bounded_range.rs

**APIs cited:** `lease::effective_expiry_spec` (`lease.rs:33`, `min(expiry, revoked_at)` when revoked), `lease::is_valid_spec` (`lease.rs:57`, half-open `[start, effective_expiry)`), `lease::renew_spec`/`revoke_spec`; `bounded_range::contains_spec` (`bounded_range.rs:16`, half-open `[lower, upper)` or `[lower, ∞)`), `bounded_range::overlaps_spec` (`bounded_range.rs:94`), `bounded_range::is_empty_spec` (`bounded_range.rs:55`).

**Connecting predicate / shared state:** map a lease's validity interval `[start, effective_expiry)` onto a bounded range `[lower, upper)` with `lower = start`, `upper = effective_expiry`, `has_upper = true`. The natural consumer is a lease scheduler/admission controller distinct from the observed callers (`lease::grant`, `lease::renew`, `lease::is_valid` callers): it must decide whether a newly granted lease overlaps any existing valid lease on the same `resource_id`.

**Proposed composition theorem (advisory, not proved):** if lease B is granted with `B.start >= effective_expiry(A)` for every existing valid lease A on the same resource, then `!overlaps_spec(A.range, B.range)`, i.e. no time point satisfies both leases — the disjointness safety property hinted at in `lease.rs` module docs. This requires lifting `effective_expiry_spec` (u64) into `bounded_range` half-open bounds and relating `is_valid_spec(lease, t)` to `contains_spec(start, effective_expiry, true, t)`.

**Missing bridge obligations:** (1) `effective_expiry` may equal `start` (empty range) when revoked at/ before start — `is_empty_spec` must be handled so an empty lease does not vacuously "overlap"; (2) u64 overflow in `start`/`effective_expiry` arithmetic when constructing bounds; (3) resource-identity equality (`resource_id`) is not part of `bounded_range`, so it must be carried as an external predicate alongside the range overlap. (4) `effective_expiry_spec` uses `min_spec` from `ordering`, so the bridge must import `crate::ordering::min_spec` under `verus_keep_ghost`.

**Limitations:** advisory only — no proof body written, not verified by `./verify`. Half-open `[start, expiry)` means a lease ending exactly when another begins is disjoint, which matches the lease doc but must be explicitly assumed in the consumer.

**Bounded duplicate check (grep):** no existing module imports both `lease::*` and `bounded_range::*`; `gis_bounding_box.rs` composes `bounded_interval` (a different module) but not `bounded_range` with `lease`. Confirmed via grep for `effective_expiry`/`is_valid_spec`/`contains_spec`/`overlaps_spec` — no cross-module lease+bounded_range composition exists.

### Opportunity 3 (UNVERIFIED ADVISORY): quorum_cert.rs + quorum.rs

**APIs cited:** `quorum_cert::vote_count_spec` (`quorum_cert.rs:34`, counts `(view, seq, replica)` tuples), `quorum_cert::is_valid_qc_spec` (`quorum_cert.rs:76`, `vote_count >= threshold`), `quorum::majority_spec` (`quorum.rs:17`, `n/2 + 1`), `quorum::is_quorum_spec` (`quorum.rs:63`), `quorum::prove_quorum_intersection` (`quorum.rs:111`).

**Connecting predicate / shared state:** a QC's `vote_count` is a raw tuple count over `Seq<(u64, u64, u64)>` where the third element is a replica id, but `vote_count_spec` ignores replica identity (it counts every matching `(view, seq)` tuple regardless of `_replica`). `quorum::majority_spec`/`is_quorum_spec` count distinct members of an n-node set. The bridge must connect "threshold matching votes" to "a quorum of unique authenticated in-universe voters."

**Proposed composition theorem (advisory, not proved):** for a QC with `n` total replicas and threshold `t = majority_spec(n)`, if `is_valid_qc_spec(votes, view, seq, t)` and the matching votes have pairwise-distinct replica ids, then the set of voting replicas is a quorum (`is_quorum_spec(distinct_voter_count, n)`), and two such QCs for the same view intersect by `prove_quorum_intersection`.

**Missing bridge obligations:** (1) uniqueness of replica ids among matching votes is NOT enforced by `vote_count_spec` — tuple count is not a membership proof, so a duplicate-authenticated-voter attack inflates the count without adding distinct voters; the bridge needs an explicit distinct-replica precondition; (2) `vote_count` returns `u64` capped by `votes@.len() <= u64::MAX`, while `majority_spec` works over `u64 n` — no overflow for realistic n but the type boundary is a bridge obligation; (3) the consumer must supply an authentication predicate binding tuple replica ids to in-universe voters, which neither module provides.

**Concrete consumer distinguished from observed callers:** observed callers of `quorum_cert` are `leader_completeness.rs`, `ballot.rs`, `raft_consensus_core.rs` (they call `quorum::prove_quorum_intersection` directly on counts, not on QC vote tuples). A new consumer would be a QC-based commit rule that takes an actual `&[(u64,u64,u64)]` vote list, extracts distinct replica ids, and invokes both `is_valid_qc` and `quorum::is_quorum` — distinct from the existing count-based callers.

**Limitations:** advisory only — not verified by `./verify`. Does not address Byzantine equivocation (same replica sending two votes for the same seq), which distinct-replica preconditions alone do not rule out without a per-replica single-vote invariant.

**Bounded duplicate check (grep):** `quorum_cert.rs` does not import `crate::quorum`; grep for `vote_count_spec`/`majority_spec`/`prove_quorum_intersection` shows `quorum` is used by `leader_completeness`, `ballot`, `raft_consensus_core`, `joint_consensus`, `election_safety_proof`, but never composed with `quorum_cert::vote_count`. Confirmed no existing quorum_cert+quorum bridge.

## Summary

- `composition.rs`: verified (2 proofs, 0 errors); imports fixed; public theorem and concrete unconditional witness preserved.
- `findings.md` records the exact verify outcome, signatures, preconditions, satisfiable instance, finite-model limits, and three opportunities (1 verified, 2 advisory with source-grounded APIs, bridge obligations, consumers, limitations, and grep-based duplicate checks).