//! Generic recursive counting and folding over sequences.
//!
//! Provides a generic `count_matching` spec and proof that the count is
//! bounded by the sequence length. This eliminates duplicate inductive
//! proofs across `collections`, `env_scrub`, `approval`, and `eviction`.

use vstd::prelude::*;

verus! {

// ============================================================
// Generic count_matching: count elements satisfying a predicate
// ============================================================

// r[depends seq-fold.count-matching]
/// Spec: number of elements in `s[from..]` satisfying predicate `p`.
pub open spec fn count_matching_from_spec(
    s: Seq<u64>, p: spec_fn(u64) -> bool, from: int,
) -> nat
    decreases s.len() - from,
{
    if from < 0 || from >= s.len() {
        0
    } else if p(s[from]) {
        1 + count_matching_from_spec(s, p, from + 1)
    } else {
        count_matching_from_spec(s, p, from + 1)
    }
}

// r[depends seq-fold.count-matching]
/// Spec: total count of elements satisfying predicate `p`.
pub open spec fn count_matching_spec(
    s: Seq<u64>, p: spec_fn(u64) -> bool,
) -> nat {
    count_matching_from_spec(s, p, 0)
}

// ============================================================
// Bounded count lemma
// ============================================================

// r[verify seq-fold.count-matching]
/// Count from any position is bounded by remaining length.
pub proof fn count_matching_from_bounded(
    s: Seq<u64>, p: spec_fn(u64) -> bool, from: int,
)
    requires 0 <= from <= s.len()
    ensures count_matching_from_spec(s, p, from) as int <= s.len() - from
    decreases s.len() - from,
{
    if from < s.len() {
        count_matching_from_bounded(s, p, from + 1);
    }
}

// r[verify seq-fold.count-matching]
/// Total count is bounded by sequence length.
pub proof fn count_matching_bounded(
    s: Seq<u64>, p: spec_fn(u64) -> bool,
)
    ensures count_matching_spec(s, p) as int <= s.len()
{
    count_matching_from_bounded(s, p, 0);
}

// r[verify seq-fold.count-matching]
/// Empty sequence has zero count.
pub proof fn count_matching_empty(p: spec_fn(u64) -> bool)
    ensures count_matching_spec(Seq::<u64>::empty(), p) == 0
{}

// ============================================================
// All-matching lemma
// ============================================================

// r[verify seq-fold.count-matching]
/// If every element satisfies `p`, count equals length.
pub proof fn count_matching_all(
    s: Seq<u64>, p: spec_fn(u64) -> bool,
)
    requires forall|i: int| 0 <= i < s.len() ==> p(s[i])
    ensures count_matching_spec(s, p) == s.len()
{
    count_matching_all_from(s, p, 0);
}

/// Helper: if all elements from `from` onward satisfy `p`, count = remaining.
proof fn count_matching_all_from(
    s: Seq<u64>, p: spec_fn(u64) -> bool, from: int,
)
    requires
        0 <= from <= s.len(),
        forall|i: int| from <= i < s.len() ==> p(s[i]),
    ensures count_matching_from_spec(s, p, from) as int == s.len() - from
    decreases s.len() - from,
{
    // Repair only this body. Prove the unchanged postcondition.
}

// ============================================================
// None-matching lemma
// ============================================================

// r[verify seq-fold.count-matching]
/// If no element satisfies `p`, count is zero.
pub proof fn count_matching_none(
    s: Seq<u64>, p: spec_fn(u64) -> bool,
)
    requires forall|i: int| 0 <= i < s.len() ==> !p(s[i])
    ensures count_matching_spec(s, p) == 0
{
    count_matching_none_from(s, p, 0);
}

/// Helper: no matching elements from `from` onward.
proof fn count_matching_none_from(
    s: Seq<u64>, p: spec_fn(u64) -> bool, from: int,
)
    requires
        0 <= from <= s.len(),
        forall|i: int| from <= i < s.len() ==> !p(s[i]),
    ensures count_matching_from_spec(s, p, from) == 0
    decreases s.len() - from,
{
    if from < s.len() {
        count_matching_none_from(s, p, from + 1);
    }
}

} // verus!

#[cfg(test)]
mod tests {
    // Pure ghost module — tested indirectly through modules that use it.
}
