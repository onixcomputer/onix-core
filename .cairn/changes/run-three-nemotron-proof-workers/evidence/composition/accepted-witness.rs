//! Verified composition witness: causal_order + vector_clock.
//!
//! Proves a connected theorem over the same clocks/transition:
//! if a message is causally ready for delivery at `local` from `sender`,
//! then the local clock happens-before the clock obtained by merging the
//! message into `local` (componentwise max).  Readiness alone does NOT
//! imply `local` happens-before the raw message clock, because nonsender
//! local entries may already be ahead of the message; only the merge makes
//! the strict advance at `sender` visible while every component stays >=
//! local.  This composes `causal_order::is_causally_ready_spec` with
//! `vector_clock::merge_spec` and `vector_clock::happens_before_spec`.

use vstd::prelude::*;

use crate::causal_order::is_causally_ready_spec;
use crate::vector_clock::{happens_before_spec, merge_spec};
use crate::ordering::max_spec;

verus! {

// ---------------------------------------------------------------------------
// Connected theorem: causal readiness => local happens-before the merged clock
// ---------------------------------------------------------------------------

/// If `msg_clock` is causally ready for `local_clock` at `sender`, then the
/// merged clock `merge(local_clock, msg_clock)` strictly advances `local_clock`,
/// i.e. `local_clock` happens-before the merged clock.
///
/// Precondition (bridge obligation): `is_causally_ready_spec(msg_clock,
/// local_clock, sender)` holds, i.e.
///   - msg_clock.len() == local_clock.len()
///   - 0 <= sender < len
///   - msg_clock[sender] == local_clock[sender] + 1
///   - for all j != sender: msg_clock[j] <= local_clock[j]
///
/// Conclusion: `happens_before_spec(local_clock, merge_spec(local_clock,
/// msg_clock))`, i.e. every component of the merge dominates local and the
/// sender component is strict.
pub proof fn ready_merge_advances(
    msg_clock: Seq<u64>,
    local_clock: Seq<u64>,
    sender: int,
)
    requires
        is_causally_ready_spec(msg_clock, local_clock, sender),
    ensures
        happens_before_spec(local_clock, merge_spec(local_clock, msg_clock))
{
    // 1. Readiness gives the sender is exactly one ahead of local.
    assert(msg_clock[sender as int] as int == local_clock[sender as int] as int + 1) by {
        // is_causally_ready_spec unfolds to this conjunct.
    }

    // 2. Readiness rules out u64 overflow at the sender: msg_clock[sender] is a
    //    u64, so local_clock[sender] + 1 <= u64::MAX, hence local[sender] < MAX.
    assert(local_clock[sender as int] < u64::MAX) by {
        // msg_clock[sender] as int <= u64::MAX as int and equals local[sender]+1.
    }

    // 3. Merge is componentwise max, so every component of the merge dominates
    //    the local clock: forall i, local[i] <= max(local[i], msg[i]).
    assert(forall|i: int| 0 <= i < local_clock.len() ==>
        local_clock[i] <= merge_spec(local_clock, msg_clock)[i]) by {
        assert(forall|x: u64, y: u64| max_spec(x, y) >= x);
        // merge_spec(a,b)[i] = max_spec(a[i], b[i]) >= a[i].
    }

    // 4. At the sender, merged[sender] = max(local[sender], msg[sender]) =
    //    msg[sender] = local[sender] + 1 > local[sender].
    assert(merge_spec(local_clock, msg_clock)[sender as int] ==
        local_clock[sender as int] + 1) by {
        // max_spec picks the larger; msg[sender] = local[sender]+1 > local[sender].
    }

    // 5. Hence exists an index (the sender) where local < merged.
    assert(local_clock[sender as int] < merge_spec(local_clock, msg_clock)[sender as int]) by {
        // combine 3 (componentwise >=) with 4 (equality = local+1) and the
        // fact that local[sender] < u64::MAX so local[sender]+1 > local[sender].
    }

    // 6. forall i local[i] <= merged[i] AND exists i local[i] < merged[i]
    //    is exactly happens_before_spec(local, merged).
    //    (The two asserts above supply the two conjuncts.)
}

// ---------------------------------------------------------------------------
// Unconditional concrete witness: a nontrivial, non-identical instance
// ---------------------------------------------------------------------------

/// Builds a concrete 3-process instance where readiness holds and calls the
/// theorem, demonstrating a genuine advance (not identical clocks):
///   local = [2, 3, 1], sender = 1, msg = [2, 4, 1].
/// Readiness: msg[1] = 4 = local[1] + 1; msg[0] = 2 <= local[0]; msg[2] = 1 <= local[2].
/// Merged   = [2, 4, 1]; local happens-before merged (strict at index 1).
pub proof fn ready_merge_advances_concrete()
    ensures
        happens_before_spec(
            seq![2u64, 3u64, 1u64],
            merge_spec(seq![2u64, 3u64, 1u64], seq![2u64, 4u64, 1u64]),
        )
{
    // Establish the bridge precondition for the concrete instance.
    assert(is_causally_ready_spec(seq![2u64, 4u64, 1u64], seq![2u64, 3u64, 1u64], 1)) by {
        // msg[1] = 4 = local[1] + 1; msg[0]=2<=2; msg[2]=1<=1; lengths equal; sender in range.
    }

    // Apply the connected theorem to the concrete (non-identical) clocks.
    ready_merge_advances(seq![2u64, 4u64, 1u64], seq![2u64, 3u64, 1u64], 1);
}

} // verus!
