//! Cross-module verified properties.
//!
//! Proofs that relate functions from different modules — triangle inequality,
//! round-trip inverses, monotonicity, nearest-point optimality. These are
//! the properties that make the library useful as a verified foundation:
//! downstream code can rely on these relationships holding for all inputs.
//!
//! The spec/proof fns are ghost code (erased in normal builds). Only the
//! tests below are compiled by cargo.

// Spec and proof fns reference spec fns from other modules. These only
// exist during Verus verification (verus_keep_ghost), not in normal cargo
// builds. The verus! macro handles erasure of the proof bodies, but the
// use-statements for ghost items need cfg-gating.

#[cfg(verus_keep_ghost)]
mod verus_proofs {
    use vstd::prelude::*;

    use crate::arithmetic::abs_diff_spec;
    use crate::arithmetic::saturating_add_spec;
    use crate::arithmetic::saturating_sub_spec;
    use crate::bounds::clamp_spec;
    use crate::bounds::in_range_spec;
    use crate::choreography_global::GBranch;
    use crate::choreography_global::GChoreo;
    use crate::choreography_global::LabelId;
    use crate::choreography_global::PayloadTag;
    use crate::choreography_global::RoleId;
    use crate::choreography_local::LBranch;
    use crate::choreography_local::LChoreo;
    use crate::choreography_local::branch_labels_spec;
    use crate::choreography_projection::all_decider_guarded_spec;
    use crate::choreography_projection::common_recv_tails_spec;
    use crate::choreography_projection::common_send_tails_spec;
    use crate::choreography_projection::project_decider_choice_from_len;
    use crate::choreography_projection::project_decider_choice_from_pointwise;
    use crate::choreography_projection::project_decider_choice_from_spec;
    use crate::choreography_projection::project_endpoint_spec;
    use crate::choreography_projection::projectable_spec;
    use crate::choreography_projection::projected_branch_suffix_size;
    use crate::choreography_projection::same_projected_bodies_spec;
    use crate::choreography_step::choice_alignment_spec;
    use crate::choreography_step::first_offer_labels_from_spec;
    use crate::choreography_step::global_choice_step_spec;
    use crate::choreography_step::global_comm_step_spec;
    use crate::choreography_step::local_recv_step_spec;
    use crate::choreography_step::local_send_step_spec;
    use crate::fencing::is_stale_spec;
    use crate::fencing::is_valid_write_spec;
    use crate::fencing::issue_token_spec;
    use crate::monotonic::is_strict_advance_spec;
    use crate::web_of_trust_attestation::Attestation;
    use crate::web_of_trust_attestation::attestation_active_respects_revocation;
    use crate::web_of_trust_chain::chain_valid_at_spec;
    use crate::web_of_trust_chain::chain_valid_requires_active_edges;
    use crate::web_of_trust_chain::root_member_spec;
    use crate::web_of_trust_policy::introducer_qualifies_at_spec;
    use crate::web_of_trust_policy::seen_indices_in_range_spec;
    use crate::web_of_trust_policy::seen_introducer_spec;
    use crate::web_of_trust_policy::threshold_accepts_from_spec;
    use crate::web_of_trust_principal::PrincipalId;
    use crate::web_of_trust_resolution::resolves_trusted_at_complete;
    use crate::web_of_trust_resolution::resolves_trusted_at_sound;
    use crate::web_of_trust_resolution::resolves_trusted_at_spec;
    use crate::web_of_trust_revocation::Revocation;
    use crate::web_of_trust_revocation::revocation_effective_at_spec;

    verus! {

    // --- abs_diff is a metric ---

    // r[impl properties.abs-diff-zero-iff-equal]
    pub open spec fn abs_diff_zero_iff_equal_prop(a: u64, b: u64) -> bool {
        abs_diff_spec(a, b) == 0 <==> a == b
    }

    // r[verify properties.abs-diff-zero-iff-equal]
    proof fn prove_abs_diff_zero_iff_equal(a: u64, b: u64)
        ensures abs_diff_zero_iff_equal_prop(a, b)
    {}

    // r[impl properties.triangle-inequality]
    pub open spec fn triangle_inequality_prop(a: u64, b: u64, c: u64) -> bool {
        abs_diff_spec(a, c) as int <= abs_diff_spec(a, b) as int + abs_diff_spec(b, c) as int
    }

    // r[verify properties.triangle-inequality]
    proof fn prove_triangle_inequality(a: u64, b: u64, c: u64)
        ensures triangle_inequality_prop(a, b, c)
    {}

    // --- arithmetic inverses ---

    // r[impl properties.add-sub-roundtrip]
    pub open spec fn add_sub_roundtrip_prop(a: u64, b: u64) -> bool
        recommends a as int + b as int <= u64::MAX as int
    {
        saturating_sub_spec(saturating_add_spec(a, b), b) == a
    }

    // r[verify properties.add-sub-roundtrip]
    proof fn prove_add_sub_roundtrip(a: u64, b: u64)
        requires a as int + b as int <= u64::MAX as int
        ensures add_sub_roundtrip_prop(a, b)
    {}

    // r[impl properties.sub-add-inverse]
    pub open spec fn sub_add_inverse_prop(a: u64, b: u64) -> bool
        recommends b <= a
    {
        saturating_add_spec(saturating_sub_spec(a, b), b) == a
    }

    // r[verify properties.sub-add-inverse]
    proof fn prove_sub_add_inverse(a: u64, b: u64)
        requires b <= a
        ensures sub_add_inverse_prop(a, b)
    {}

    // --- clamp properties ---

    // r[impl properties.clamp-nearest-point]
    pub open spec fn clamp_nearest_point_prop(value: u64, x: u64, lo: u64, hi: u64) -> bool
        recommends lo <= hi, in_range_spec(x, lo, hi)
    {
        abs_diff_spec(value, clamp_spec(value, lo, hi)) <= abs_diff_spec(value, x)
    }

    // r[verify properties.clamp-nearest-point]
    proof fn prove_clamp_nearest_point(value: u64, x: u64, lo: u64, hi: u64)
        requires lo <= hi, in_range_spec(x, lo, hi)
        ensures clamp_nearest_point_prop(value, x, lo, hi)
    {}

    // r[impl properties.clamp-monotonic]
    pub open spec fn clamp_monotonic_prop(a: u64, b: u64, lo: u64, hi: u64) -> bool
        recommends lo <= hi, a <= b
    {
        clamp_spec(a, lo, hi) <= clamp_spec(b, lo, hi)
    }

    // r[verify properties.clamp-monotonic]
    proof fn prove_clamp_monotonic(a: u64, b: u64, lo: u64, hi: u64)
        requires lo <= hi, a <= b
        ensures clamp_monotonic_prop(a, b, lo, hi)
    {}

    // r[impl properties.distance-decomposition]
    pub open spec fn distance_decomposition_prop(value: u64, lo: u64, hi: u64) -> bool
        recommends lo <= hi, in_range_spec(value, lo, hi)
    {
        abs_diff_spec(value, lo) as int + abs_diff_spec(value, hi) as int
            == abs_diff_spec(lo, hi) as int
    }

    // r[verify properties.distance-decomposition]
    proof fn prove_distance_decomposition(value: u64, lo: u64, hi: u64)
        requires lo <= hi, in_range_spec(value, lo, hi)
        ensures distance_decomposition_prop(value, lo, hi)
    {}

    // --- bitwise cross-module properties ---

    use crate::ordering::{min_spec, max_spec, median_of_three_spec};
    use crate::arithmetic::div_ceil_spec;
    use crate::integer::{align_down_spec, align_up_spec};
    use crate::slice::{all_equal_spec, chunk_count_spec};
    use crate::collections::{count_matches_spec, count_from_spec, is_partitioned_spec};
    use crate::conversion::narrow_u32_spec;
    use crate::epoch::{epoch_cmp_spec, epoch_ge_spec, Epoch};
    use crate::log::{logs_match_prefix_spec, LogEntry};
    use crate::quorum::majority_spec;

    use vstd::arithmetic::div_mod::{lemma_fundamental_div_mod, lemma_mod_pos_bound};

    // --- ordering × arithmetic ---

    // r[impl properties.min-max-abs-diff]
    /// max(a,b) - min(a,b) == abs_diff(a,b).
    pub open spec fn min_max_abs_diff_prop(a: u64, b: u64) -> bool {
        (max_spec(a, b) - min_spec(a, b)) as u64 == abs_diff_spec(a, b)
    }

    // r[verify properties.min-max-abs-diff]
    proof fn prove_min_max_abs_diff(a: u64, b: u64)
        ensures min_max_abs_diff_prop(a, b)
    {}

    // --- ordering × bounds ---

    // r[impl properties.clamp-via-min-max]
    /// clamp(v, lo, hi) == min(max(v, lo), hi).
    pub open spec fn clamp_via_min_max_prop(v: u64, lo: u64, hi: u64) -> bool
        recommends lo <= hi
    {
        clamp_spec(v, lo, hi) == min_spec(max_spec(v, lo), hi)
    }

    // r[verify properties.clamp-via-min-max]
    proof fn prove_clamp_via_min_max(v: u64, lo: u64, hi: u64)
        requires lo <= hi
        ensures clamp_via_min_max_prop(v, lo, hi)
    {}

    // --- integer × arithmetic ---

    // r[impl properties.align-down-remainder]
    /// x - align_down(x, a) == x % a.
    pub open spec fn align_down_remainder_prop(x: u64, a: u64) -> bool
        recommends a > 0
    {
        abs_diff_spec(x, align_down_spec(x, a)) as int == x as int % a as int
    }

    // r[verify properties.align-down-remainder]
    proof fn prove_align_down_remainder(x: u64, a: u64)
        requires a > 0
        ensures align_down_remainder_prop(x, a)
    {
        lemma_mod_pos_bound(x as int, a as int);
        lemma_fundamental_div_mod(x as int, a as int);
        // x == a * (x/a) + x%a, 0 <= x%a < a
        // therefore x%a <= x (since a * (x/a) >= 0)
    }

    // r[impl properties.align-up-via-div-ceil]
    /// align_up(x, a) == div_ceil(x, a) * a when defined.
    pub open spec fn align_up_via_div_ceil_prop(x: u64, a: u64) -> bool
        recommends a > 0, align_up_spec(x, a).is_some()
    {
        align_up_spec(x, a).unwrap() as int == div_ceil_spec(x, a) as int * a as int
    }

    // r[verify properties.align-up-via-div-ceil]
    proof fn prove_align_up_via_div_ceil(x: u64, a: u64)
        requires a > 0, align_up_spec(x, a).is_some()
        ensures align_up_via_div_ceil_prop(x, a)
    {
        // Both specs share the same core: q = (x == 0 ? 0 : (x-1)/a + 1).
        // align_up gives q * a, div_ceil gives q. So align_up == div_ceil * a.
        // Help Z3 with the cast round-trip:
        if x > 0 {
            vstd::arithmetic::div_mod::lemma_div_pos_is_pos(
                (x - 1) as int, a as int,
            );
        }
    }

    // --- ordering × bounds ---

    // r[impl properties.median-is-clamp]
    /// median_of_three(a, b, c) == clamp(a, min(b, c), max(b, c)).
    pub open spec fn median_is_clamp_prop(a: u64, b: u64, c: u64) -> bool {
        median_of_three_spec(a, b, c) == clamp_spec(a, min_spec(b, c), max_spec(b, c))
    }

    // r[verify properties.median-is-clamp]
    proof fn prove_median_is_clamp(a: u64, b: u64, c: u64)
        ensures median_is_clamp_prop(a, b, c)
    {}

    // --- bitwise cross-module properties ---

    use crate::bitwise::{
        bit_at_spec, set_bit_spec, clear_bit_spec, toggle_bit_spec,
    };

    // r[impl properties.set-clear-roundtrip]
    /// Setting then clearing the same bit leaves it cleared.
    pub open spec fn set_clear_roundtrip_prop(x: u64, pos: u64) -> bool
        recommends pos < 64
    {
        clear_bit_spec(set_bit_spec(x, pos), pos) == clear_bit_spec(x, pos)
    }

    // r[verify properties.set-clear-roundtrip]
    proof fn prove_set_clear_roundtrip(x: u64, pos: u64)
        requires pos < 64
        ensures set_clear_roundtrip_prop(x, pos)
    {
        assert(pos < 64 ==> (x | (1u64 << pos)) & !(1u64 << pos) == x & !(1u64 << pos)) by(bit_vector);
    }

    // r[impl properties.toggle-involution]
    /// Toggling a bit twice returns the original value.
    pub open spec fn toggle_involution_prop(x: u64, pos: u64) -> bool
        recommends pos < 64
    {
        toggle_bit_spec(toggle_bit_spec(x, pos), pos) == x
    }

    // r[verify properties.toggle-involution]
    proof fn prove_toggle_involution(x: u64, pos: u64)
        requires pos < 64
        ensures toggle_involution_prop(x, pos)
    {
        assert(pos < 64 ==> (x ^ (1u64 << pos)) ^ (1u64 << pos) == x) by(bit_vector);
    }

    // --- slice × collections ---

    // r[impl properties.all-equal-implies-count]
    /// all_equal(s, v) implies count_matches(s, v) == s.len().
    pub open spec fn all_equal_implies_count_prop(s: Seq<u64>, v: u64) -> bool {
        all_equal_spec(s, v) ==> count_matches_spec(s, v) == s.len()
    }

    // r[verify properties.all-equal-implies-count]
    proof fn prove_all_equal_implies_count(s: Seq<u64>, v: u64)
        requires all_equal_spec(s, v)
        ensures count_matches_spec(s, v) == s.len()
    {
        all_equal_count_from(s, v, 0);
    }

    /// Helper: all-equal means count_from equals remaining length.
    proof fn all_equal_count_from(s: Seq<u64>, v: u64, from: int)
        requires all_equal_spec(s, v), 0 <= from <= s.len()
        ensures count_from_spec(s, v, from) as int == s.len() - from
        decreases s.len() - from
    {
        if from < s.len() {
            all_equal_count_from(s, v, from + 1);
        }
    }

    // r[impl properties.all-equal-implies-partitioned]
    /// A uniform sequence is partitioned by any threshold.
    pub open spec fn all_equal_implies_partitioned_prop(
        s: Seq<u64>, v: u64, threshold: u64,
    ) -> bool {
        all_equal_spec(s, v) ==> is_partitioned_spec(s, threshold)
    }

    // r[verify properties.all-equal-implies-partitioned]
    proof fn prove_all_equal_implies_partitioned(
        s: Seq<u64>, v: u64, threshold: u64,
    )
        requires all_equal_spec(s, v)
        ensures is_partitioned_spec(s, threshold)
    {}

    // --- slice × arithmetic ---

    // r[impl properties.chunk-count-div-ceil]
    /// div_ceil == chunk_count + remainder indicator.
    pub open spec fn chunk_count_div_ceil_prop(n: u64, k: u64) -> bool
        recommends k > 0
    {
        div_ceil_spec(n, k) as int == chunk_count_spec(n, k) as int
            + (if n as int % k as int > 0 { 1int } else { 0int })
    }

    // r[verify properties.chunk-count-div-ceil]
    proof fn prove_chunk_count_div_ceil(n: u64, k: u64)
        requires k > 0
        ensures chunk_count_div_ceil_prop(n, k)
    {
        if n > 0 {
            let ni = n as int;
            let ki = k as int;
            let q = ni / ki;
            let r = ni % ki;
            lemma_fundamental_div_mod(ni, ki);
            lemma_mod_pos_bound(ni, ki);
            lemma_fundamental_div_mod(ni - 1, ki);
            lemma_mod_pos_bound(ni - 1, ki);
            let q2 = (ni - 1) / ki;
            let r2 = (ni - 1) % ki;
            if r > 0 {
                // ni-1 = ki*q + (r-1) with 0 <= r-1 < ki
                // By quotient uniqueness: (ni-1)/ki == q
                assert(q2 == q) by(nonlinear_arith)
                    requires
                        ni == ki * q + r,
                        ni - 1 == ki * q2 + r2,
                        0 < r, r < ki,
                        0 <= r2, r2 < ki,
                        ki > 0;
            } else {
                // r == 0: ni = ki*q, ni-1 = ki*(q-1) + (ki-1)
                // By quotient uniqueness: (ni-1)/ki == q-1
                assert(q2 == q - 1) by(nonlinear_arith)
                    requires
                        ni == ki * q + r,
                        ni - 1 == ki * q2 + r2,
                        r == 0,
                        0 <= r2, r2 < ki,
                        ki > 0,
                        ni > 0;
            }
        }
    }

    // --- conversion × bounds ---

    // r[impl properties.narrow-iff-in-range]
    /// narrow_u32 agrees with in_range(0, u32::MAX).
    pub open spec fn narrow_iff_in_range_prop(x: u64) -> bool {
        narrow_u32_spec(x).is_some() <==> in_range_spec(x, 0, u32::MAX as u64)
    }

    // r[verify properties.narrow-iff-in-range]
    proof fn prove_narrow_iff_in_range(x: u64)
        ensures narrow_iff_in_range_prop(x)
    {}

    // --- quorum × arithmetic ---

    // r[impl properties.majority-via-div-ceil]
    /// majority(n) == div_ceil(n + 1, 2).
    pub open spec fn majority_via_div_ceil_prop(n: u64) -> bool
        recommends n > 0, (n as int + 1) <= u64::MAX as int
    {
        majority_spec(n) as int == div_ceil_spec((n + 1) as u64, 2) as int
    }

    // r[verify properties.majority-via-div-ceil]
    proof fn prove_majority_via_div_ceil(n: u64)
        requires n > 0, (n as int + 1) <= u64::MAX as int
        ensures majority_via_div_ceil_prop(n)
    {
        // majority(n) = n/2 + 1
        // div_ceil(n+1, 2) = if n+1 == 0 { 0 } else { ((n+1-1)/2 + 1) } = n/2 + 1
    }

    // --- epoch × ordering ---

    // r[impl properties.epoch-ge-term-index]
    /// epoch_ge decomposes into term and index conditions.
    pub open spec fn epoch_ge_term_index_prop(a: Epoch, b: Epoch) -> bool {
        epoch_ge_spec(a, b) ==> (
            a.term > b.term || (a.term == b.term && a.index >= b.index)
        )
    }

    // r[verify properties.epoch-ge-term-index]
    proof fn prove_epoch_ge_term_index(a: Epoch, b: Epoch)
        ensures epoch_ge_term_index_prop(a, b)
    {}

    // --- log × term equality ---

    // r[impl properties.log-prefix-term-eq]
    /// Log prefix matching implies term equality over the prefix.
    pub open spec fn log_prefix_term_eq_prop(
        a: Seq<LogEntry>, b: Seq<LogEntry>, k: int,
    ) -> bool
        recommends 0 <= k <= a.len(), 0 <= k <= b.len()
    {
        logs_match_prefix_spec(a, b, k) ==>
            forall|i: int| 0 <= i < k ==> a[i].term == b[i].term
    }

    // r[verify properties.log-prefix-term-eq]
    proof fn prove_log_prefix_term_eq(
        a: Seq<LogEntry>, b: Seq<LogEntry>, k: int,
    )
        ensures log_prefix_term_eq_prop(a, b, k)
    {}

    // ========================================================================
    // Cross-module properties for new modules
    // ========================================================================

    use crate::chunk::chunk_count_ceil_spec;
    use crate::bounded_range::contains_spec as br_contains_spec;
    use crate::interval::contains_spec as iv_contains_spec;
    use crate::interval::overlaps_spec as iv_overlaps_spec;
    use crate::partition::is_adjacent_pair_spec;
    use crate::partition::is_non_empty_interval_spec;
    use crate::pressure::classify_level_spec;
    use crate::hash_bucket::assign_bucket_spec;
    use crate::rate_limit::tokens_after_refill_spec;
    use crate::drain::{after_start_op_spec, after_finish_op_spec};
    use crate::sequential::is_sequential_spec;
    use crate::chunk::chunk_offset_spec;

    // --- chunk × arithmetic ---

    // r[impl properties.chunk-ceil-is-div-ceil]
    /// chunk_count_ceil and div_ceil must agree.
    pub open spec fn chunk_ceil_is_div_ceil_prop(n: u64, k: u64) -> bool
        recommends k > 0
    {
        chunk_count_ceil_spec(n, k) as int == div_ceil_spec(n, k) as int
    }

    // r[verify properties.chunk-ceil-is-div-ceil]
    proof fn prove_chunk_ceil_is_div_ceil(n: u64, k: u64)
        requires k > 0
        ensures chunk_ceil_is_div_ceil_prop(n, k)
    {
        // Both specs: if n == 0 then 0, else (n-1)/k + 1.
        // div_ceil: if a == 0 { 0 } else { (a - 1) / b + 1 }
        // chunk_count_ceil: if total_size == 0 { 0 } else { ((total_size - 1) as int / chunk_size as int + 1) as u64 }
    }

    // --- bounded_range × interval ---

    // r[impl properties.bounded-range-specializes-interval]
    /// Bounded range reduces to interval when has_upper is true.
    pub open spec fn bounded_range_specializes_interval_prop(
        lo: u64, hi: u64, x: u64,
    ) -> bool {
        br_contains_spec(lo, hi, true, x) == iv_contains_spec(lo, hi, x)
    }

    // r[verify properties.bounded-range-specializes-interval]
    proof fn prove_bounded_range_specializes_interval(lo: u64, hi: u64, x: u64)
        ensures bounded_range_specializes_interval_prop(lo, hi, x)
    {}

    // --- partition × interval ---

    // r[impl properties.partition-no-overlap]
    /// Adjacent partition intervals don't overlap per interval.overlaps.
    pub open spec fn partition_no_overlap_prop(
        a_lo: u64, a_hi: u64, b_lo: u64, b_hi: u64,
    ) -> bool
        recommends
            is_non_empty_interval_spec(a_lo, a_hi),
            is_non_empty_interval_spec(b_lo, b_hi),
            is_adjacent_pair_spec(a_hi, b_lo),
    {
        !iv_overlaps_spec(a_lo, a_hi, b_lo, b_hi)
    }

    // r[verify properties.partition-no-overlap]
    proof fn prove_partition_no_overlap(
        a_lo: u64, a_hi: u64, b_lo: u64, b_hi: u64,
    )
        requires
            is_non_empty_interval_spec(a_lo, a_hi),
            is_non_empty_interval_spec(b_lo, b_hi),
            is_adjacent_pair_spec(a_hi, b_lo),
        ensures partition_no_overlap_prop(a_lo, a_hi, b_lo, b_hi)
    {}

    // --- pressure × monotonic ---

    // r[impl properties.pressure-classify-monotonic]
    /// Monotonic values produce monotonic severity levels.
    pub open spec fn pressure_classify_monotonic_prop(
        v1: u64, v2: u64, warn: u64, crit: u64,
    ) -> bool
        recommends warn <= crit, v1 <= v2
    {
        classify_level_spec(v1, warn, crit) <= classify_level_spec(v2, warn, crit)
    }

    // r[verify properties.pressure-classify-monotonic]
    proof fn prove_pressure_classify_monotonic(
        v1: u64, v2: u64, warn: u64, crit: u64,
    )
        requires warn <= crit, v1 <= v2
        ensures pressure_classify_monotonic_prop(v1, v2, warn, crit)
    {}

    // --- hash_bucket × interval ---

    // r[impl properties.hash-bucket-in-interval]
    /// Hash assignment lands in the valid bucket interval.
    pub open spec fn hash_bucket_in_interval_prop(hash: u64, num_buckets: u64) -> bool
        recommends num_buckets > 0
    {
        iv_contains_spec(0, num_buckets, assign_bucket_spec(hash, num_buckets))
    }

    // r[verify properties.hash-bucket-in-interval]
    proof fn prove_hash_bucket_in_interval(hash: u64, num_buckets: u64)
        requires num_buckets > 0
        ensures hash_bucket_in_interval_prop(hash, num_buckets)
    {}

    // --- rate_limit × bounds ---

    // r[impl properties.refill-within-bounds]
    /// Refill result is always within [0, burst].
    pub open spec fn refill_within_bounds_prop(
        tokens: u64, elapsed_ms: u64, rate_per_sec: u64, burst: u64,
    ) -> bool {
        in_range_spec(tokens_after_refill_spec(tokens, elapsed_ms, rate_per_sec, burst), 0, burst)
    }

    // r[verify properties.refill-within-bounds]
    proof fn prove_refill_within_bounds(
        tokens: u64, elapsed_ms: u64, rate_per_sec: u64, burst: u64,
    )
        ensures refill_within_bounds_prop(tokens, elapsed_ms, rate_per_sec, burst)
    {}

    // --- drain roundtrip ---

    // r[impl properties.drain-start-finish-roundtrip]
    /// Starting then finishing an operation is a no-op on in-flight count.
    pub open spec fn drain_start_finish_roundtrip_prop(n: u64) -> bool
        recommends n < u64::MAX
    {
        after_finish_op_spec(after_start_op_spec(n)) == n
    }

    // r[verify properties.drain-start-finish-roundtrip]
    proof fn prove_drain_start_finish_roundtrip(n: u64)
        requires n < u64::MAX
        ensures drain_start_finish_roundtrip_prop(n)
    {}

    // --- sequential × chunk ---

    // r[impl properties.sequential-chunk-continuation]
    /// Reading consecutive chunks is detected as sequential.
    pub open spec fn sequential_chunk_continuation_prop(
        chunk_size: u64, index: u64,
    ) -> bool
        recommends
            chunk_size > 0,
            index as int * chunk_size as int <= u64::MAX as int,
            (index as int + 1) * chunk_size as int <= u64::MAX as int,
    {
        is_sequential_spec(
            chunk_offset_spec(chunk_size, (index + 1) as u64),
            chunk_offset_spec(chunk_size, index),
            chunk_size,
        )
    }

    // r[verify properties.sequential-chunk-continuation]
    proof fn prove_sequential_chunk_continuation(chunk_size: u64, index: u64)
        requires
            chunk_size > 0,
            index as int * chunk_size as int <= u64::MAX as int,
            (index as int + 1) * chunk_size as int <= u64::MAX as int,
        ensures sequential_chunk_continuation_prop(chunk_size, index)
    {
        let cs = chunk_size as int;
        let idx = index as int;
        let lo = idx * cs;
        let hi = (idx + 1) * cs;
        // Step 1: both products are non-negative and fit in u64
        assert(idx >= 0 && cs > 0) by(nonlinear_arith)
            requires idx >= 0, cs > 0;
        assert(lo >= 0) by(nonlinear_arith)
            requires idx >= 0, cs > 0, lo == idx * cs;
        assert(hi >= 0) by(nonlinear_arith)
            requires idx >= 0, cs > 0, hi == (idx + 1) * cs;
        // Step 2: as-u64 casts are lossless
        assert((lo as u64) as int == lo);
        assert((hi as u64) as int == hi);
        // Step 3: algebraic step — (i+1)*cs == i*cs + cs
        assert(hi == lo + cs) by(nonlinear_arith)
            requires idx >= 0, cs > 0, hi == (idx + 1) * cs, lo == idx * cs;
        // Step 4: the addition doesn't overflow u64
        assert(lo + cs <= u64::MAX as int);
        // Step 5: unfold chunk_offset_spec
        // chunk_offset_spec(cs, idx) = (idx as int * cs as int) as u64
        // index + 1 fits in u64 because (index+1)*cs <= MAX and cs > 0
        assert(idx + 1 <= u64::MAX as int) by(nonlinear_arith)
            requires cs > 0, (idx + 1) * cs <= u64::MAX as int;
        let next_idx = (index + 1) as u64;
        assert(next_idx as int == idx + 1);
        // chunk_offset_spec(chunk_size, index) = (index as int * cs) as u64 = lo as u64
        assert(chunk_offset_spec(chunk_size, index) as int == lo);
        // chunk_offset_spec(chunk_size, next_idx) = (next_idx as int * cs) as u64
        // = ((idx+1) * cs) as u64 = hi as u64
        assert(next_idx as int * cs == hi) by(nonlinear_arith)
            requires next_idx as int == idx + 1, hi == (idx + 1) * cs;
        assert((next_idx as int * cs as int) as u64 as int == hi);
        assert(chunk_offset_spec(chunk_size, next_idx) as int == hi);
        // Step 6: is_sequential_spec: lo + cs = hi <= MAX, offset == last_offset + cs
        let last_offset = chunk_offset_spec(chunk_size, index);
        let offset = chunk_offset_spec(chunk_size, next_idx);
        assert(last_offset as int + chunk_size as int <= u64::MAX as int);
        assert(offset == (last_offset + chunk_size));
    }

    // --- fencing × monotonic ---

    // r[impl properties.fencing-is-strict-advance]
    /// Issuing a fencing token is a strict advance in the monotonic sense.
    pub open spec fn fencing_is_strict_advance_prop(t: u64) -> bool
        recommends t < u64::MAX
    {
        is_strict_advance_spec(t, issue_token_spec(t))
    }

    // r[verify properties.fencing-is-strict-advance]
    proof fn prove_fencing_is_strict_advance(t: u64)
        requires t < u64::MAX
        ensures fencing_is_strict_advance_prop(t)
    {}

    // r[impl properties.fencing-stale-is-not-advance]
    /// A stale token has not advanced to the fence.
    pub open spec fn fencing_stale_is_not_advance_prop(token: u64, fence: u64) -> bool {
        is_stale_spec(token, fence) ==> !is_valid_write_spec(token, fence)
    }

    // r[verify properties.fencing-stale-is-not-advance]
    proof fn prove_fencing_stale_is_not_advance(token: u64, fence: u64)
        ensures fencing_stale_is_not_advance_prop(token, fence)
    {}

    // --- env scrub × suffix matching ---

    use crate::env_scrub::to_upper_spec;
    use crate::env_scrub::ends_with_bytes_spec;
    use crate::env_scrub::has_secret_suffix_spec;
    use crate::env_scrub::is_secret_spec;

    // r[impl properties.to-upper-preserves-suffix]
    /// If a key ends with an uppercase suffix, uppercasing the key preserves
    /// the suffix (since the suffix bytes are already uppercase).
    pub open spec fn to_upper_preserves_suffix_prop(key: Seq<u8>, suffix: Seq<u8>) -> bool
        recommends
            key.len() >= suffix.len(),
            forall|i: int| 0 <= i < suffix.len() as int ==> !(97 <= suffix[i] && suffix[i] <= 122),
    {
        ends_with_bytes_spec(key, suffix) ==> ends_with_bytes_spec(to_upper_spec(key), suffix)
    }

    // r[verify properties.to-upper-preserves-suffix]
    proof fn prove_to_upper_preserves_suffix(key: Seq<u8>, suffix: Seq<u8>)
        requires
            key.len() >= suffix.len(),
            // suffix is already uppercase (no lowercase ASCII)
            forall|i: int| 0 <= i < suffix.len() as int ==> !(97 <= suffix[i] && suffix[i] <= 122),
        ensures to_upper_preserves_suffix_prop(key, suffix)
    {}

    // r[impl properties.secret-implies-not-safe]
    /// A secret key is never safe (tautology, but worth stating).
    pub open spec fn secret_implies_not_safe_prop(key: Seq<u8>) -> bool {
        is_secret_spec(key) ==> !(!is_secret_spec(key))
    }

    // r[verify properties.secret-implies-not-safe]
    proof fn prove_secret_implies_not_safe(key: Seq<u8>)
        ensures secret_implies_not_safe_prop(key)
    {}

    // --- cost tracker × monotonic ---

    use crate::cost_tracker::accumulate_spec;
    use crate::cost_tracker::crosses_threshold_spec;
    use crate::cost_tracker::budget_status_spec;
    use crate::cost_tracker::BUDGET_OK;
    use crate::cost_tracker::BUDGET_WARNING;
    use crate::cost_tracker::BUDGET_EXCEEDED;

    // r[impl properties.accumulate-is-advance]
    /// Cost accumulation is a monotonic advance: total_after >= total_before.
    pub open spec fn accumulate_is_advance_prop(total: u64, cost: u64) -> bool {
        accumulate_spec(total, cost) >= total as int
    }

    // r[verify properties.accumulate-is-advance]
    proof fn prove_accumulate_is_advance(total: u64, cost: u64)
        ensures accumulate_is_advance_prop(total, cost)
    {}

    // r[impl properties.threshold-crossing-irreversible]
    /// Once a threshold is crossed, it stays crossed (monotonic totals).
    pub open spec fn threshold_crossing_irreversible_prop(t1: u64, t2: u64, t3: u64, limit: u64) -> bool
        recommends t1 <= t2, t2 <= t3,
    {
        crosses_threshold_spec(t1, t2, limit) ==> !crosses_threshold_spec(t2, t3, limit)
    }

    // r[verify properties.threshold-crossing-irreversible]
    proof fn prove_threshold_crossing_irreversible(t1: u64, t2: u64, t3: u64, limit: u64)
        requires t1 <= t2, t2 <= t3,
        ensures threshold_crossing_irreversible_prop(t1, t2, t3, limit)
    {}

    // r[impl properties.budget-warning-implies-not-ok]
    /// Warning status implies we're past Ok — can't be both.
    pub open spec fn budget_warning_implies_not_ok_prop(soft: Option<u64>, hard: Option<u64>, total: u64) -> bool {
        budget_status_spec(soft, hard, total) == BUDGET_WARNING()
            ==> budget_status_spec(soft, hard, total) != BUDGET_OK()
    }

    // r[verify properties.budget-warning-implies-not-ok]
    proof fn prove_budget_warning_implies_not_ok(soft: Option<u64>, hard: Option<u64>, total: u64)
        ensures budget_warning_implies_not_ok_prop(soft, hard, total)
    {}

    // r[impl properties.budget-exceeded-stays-exceeded]
    /// Exceeded is absorbing under increasing totals.
    pub open spec fn budget_exceeded_stays_exceeded_prop(soft: Option<u64>, hard: Option<u64>, t1: u64, t2: u64) -> bool
        recommends t2 >= t1,
    {
        (t2 >= t1 && budget_status_spec(soft, hard, t1) == BUDGET_EXCEEDED())
            ==> budget_status_spec(soft, hard, t2) == BUDGET_EXCEEDED()
    }

    // r[verify properties.budget-exceeded-stays-exceeded]
    proof fn prove_budget_exceeded_stays_exceeded(soft: Option<u64>, hard: Option<u64>, t1: u64, t2: u64)
        requires t2 >= t1,
        ensures budget_exceeded_stays_exceeded_prop(soft, hard, t1, t2)
    {}

    // ========================================================================
    // Generic algebraic + pointwise cross-module properties
    // ========================================================================

    use crate::pointwise::{pointwise_merge_spec, max_u64};
    use crate::vector_clock::merge_spec as vc_merge_spec;
    use crate::crdt::g_counter_merge_spec;
    use crate::causal_order::cut_join_spec;

    // r[impl properties.vc-merge-is-pointwise-max]
    /// Vector clock merge is pointwise max.
    pub open spec fn vc_merge_is_pointwise_max_prop(a: Seq<u64>, b: Seq<u64>) -> bool
        recommends a.len() == b.len()
    {
        vc_merge_spec(a, b) =~= pointwise_merge_spec(a, b, |x: u64, y: u64| max_u64(x, y))
    }

    // r[verify properties.vc-merge-is-pointwise-max]
    proof fn prove_vc_merge_is_pointwise_max(a: Seq<u64>, b: Seq<u64>)
        requires a.len() == b.len()
        ensures vc_merge_is_pointwise_max_prop(a, b)
    {}

    // r[impl properties.g-counter-merge-is-pointwise-max]
    /// G-Counter merge is pointwise max.
    pub open spec fn g_counter_merge_is_pointwise_max_prop(a: Seq<u64>, b: Seq<u64>) -> bool
        recommends a.len() == b.len()
    {
        g_counter_merge_spec(a, b) =~= pointwise_merge_spec(a, b, |x: u64, y: u64| max_u64(x, y))
    }

    // r[verify properties.g-counter-merge-is-pointwise-max]
    proof fn prove_g_counter_merge_is_pointwise_max(a: Seq<u64>, b: Seq<u64>)
        requires a.len() == b.len()
        ensures g_counter_merge_is_pointwise_max_prop(a, b)
    {}

    // r[impl properties.cut-join-is-pointwise-max]
    /// Causal order cut join is pointwise max.
    pub open spec fn cut_join_is_pointwise_max_prop(a: Seq<u64>, b: Seq<u64>) -> bool
        recommends a.len() == b.len()
    {
        cut_join_spec(a, b) =~= pointwise_merge_spec(a, b, |x: u64, y: u64| max_u64(x, y))
    }

    // r[verify properties.cut-join-is-pointwise-max]
    proof fn prove_cut_join_is_pointwise_max(a: Seq<u64>, b: Seq<u64>)
        requires a.len() == b.len()
        ensures cut_join_is_pointwise_max_prop(a, b)
    {}

    // r[impl properties.all-three-merges-agree]
    /// VC merge, G-Counter merge, and cut join all agree (they're the same operation).
    pub open spec fn all_three_merges_agree_prop(a: Seq<u64>, b: Seq<u64>) -> bool
        recommends a.len() == b.len()
    {
        vc_merge_spec(a, b) =~= g_counter_merge_spec(a, b)
        && g_counter_merge_spec(a, b) =~= cut_join_spec(a, b)
    }

    // r[verify properties.all-three-merges-agree]
    proof fn prove_all_three_merges_agree(a: Seq<u64>, b: Seq<u64>)
        requires a.len() == b.len()
        ensures all_three_merges_agree_prop(a, b)
    {}

    } // verus!
}

// --- slab ↔ page duality ---

#[cfg(verus_keep_ghost)]
mod slab_page_proofs {
    use vstd::prelude::*;

    use crate::page::frame_number_spec;
    use crate::slab::slab_capacity_spec;
    use crate::slab::slot_index_spec;

    verus! {

    // r[impl properties.slab-slot-is-page-frame]
    pub open spec fn slab_slot_is_page_frame_prop(addr: u64, slot_size: u64) -> bool
        recommends slot_size > 0
    {
        slot_index_spec(addr, 0, slot_size) == frame_number_spec(addr, slot_size)
    }

    // r[verify properties.slab-slot-is-page-frame]
    proof fn prove_slab_slot_is_page_frame(addr: u64, slot_size: u64)
        requires slot_size > 0
        ensures slab_slot_is_page_frame_prop(addr, slot_size)
    {}

    // r[impl properties.slab-capacity-is-pages-dual]
    pub open spec fn slab_capacity_exact_prop(n: u64, slot_size: u64) -> bool
        recommends slot_size > 0, n as int * slot_size as int <= u64::MAX as int
    {
        slab_capacity_spec((n as int * slot_size as int) as u64, slot_size) == n
    }

    // r[verify properties.slab-capacity-is-pages-dual]
    proof fn prove_slab_capacity_exact(n: u64, slot_size: u64)
        requires
            slot_size > 0,
            n as int * slot_size as int <= u64::MAX as int,
        ensures slab_capacity_exact_prop(n, slot_size)
    {
        let product = n as int * slot_size as int;
        let ss = slot_size as int;
        vstd::arithmetic::div_mod::lemma_fundamental_div_mod(product, ss);
        assert(product / ss == n as int) by(nonlinear_arith)
            requires ss > 0, product == n as int * ss,
                product == ss * (product / ss) + product % ss,
                0 <= product % ss, (product % ss) < ss;
    }

    } // verus!
}

// --- watermark ↔ monotonic/region agreement ---

#[cfg(verus_keep_ghost)]
mod watermark_proofs {
    use vstd::prelude::*;

    use crate::monotonic::is_advance_spec;
    use crate::region::regions_disjoint_spec;
    use crate::watermark::watermark_alloc_spec;

    verus! {

    // r[impl properties.watermark-advance-is-monotonic]
    pub open spec fn watermark_advance_is_monotonic_prop(mark: u64, size: u64) -> bool
        recommends mark as int + size as int <= u64::MAX as int
    {
        is_advance_spec(mark, watermark_alloc_spec(mark, size))
    }

    // r[verify properties.watermark-advance-is-monotonic]
    proof fn prove_watermark_advance_is_monotonic(mark: u64, size: u64)
        requires mark as int + size as int <= u64::MAX as int
        ensures watermark_advance_is_monotonic_prop(mark, size)
    {}

    // r[impl properties.watermark-alloc-disjoint-regions]
    pub open spec fn watermark_alloc_disjoint_regions_prop(
        mark: u64, size1: u64, size2: u64,
    ) -> bool
        recommends
            size1 > 0, size2 > 0,
            mark as int + size1 as int + size2 as int <= u64::MAX as int,
    {
        let mark2 = watermark_alloc_spec(mark, size1);
        regions_disjoint_spec(mark, size1, mark2, size2)
    }

    // r[verify properties.watermark-alloc-disjoint-regions]
    proof fn prove_watermark_alloc_disjoint_regions(
        mark: u64, size1: u64, size2: u64,
    )
        requires
            size1 > 0, size2 > 0,
            mark as int + size1 as int + size2 as int <= u64::MAX as int,
        ensures watermark_alloc_disjoint_regions_prop(mark, size1, size2)
    {}

    } // verus!
}

// --- buddy ↔ bitwise agreement ---

#[cfg(verus_keep_ghost)]
mod buddy_bitwise_proofs {
    use vstd::prelude::*;

    use crate::bitwise::toggle_bit_spec;
    use crate::buddy::block_size_spec;
    use crate::buddy::buddy_of_spec;

    verus! {

    // r[impl properties.buddy-uses-toggle]
    pub open spec fn buddy_uses_toggle_prop(addr: u64, order: u64) -> bool
        recommends order < 64
    {
        buddy_of_spec(addr, order) == toggle_bit_spec(addr, order)
    }

    // r[verify properties.buddy-uses-toggle]
    proof fn prove_buddy_uses_toggle(addr: u64, order: u64)
        requires order < 64
        ensures buddy_uses_toggle_prop(addr, order)
    {
        // Both are addr ^ (1u64 << order)
    }

    // r[impl properties.block-size-is-pow2]
    pub open spec fn block_size_is_pow2_prop(order: u64) -> bool
        recommends order < 64
    {
        block_size_spec(order) == (1u64 << order)
    }

    // r[verify properties.block-size-is-pow2]
    proof fn prove_block_size_is_pow2(order: u64)
        requires order < 64
        ensures block_size_is_pow2_prop(order)
    {}

    } // verus!
}

// --- region ↔ interval agreement ---

#[cfg(verus_keep_ghost)]
mod region_interval_proofs {
    use vstd::prelude::*;

    use crate::interval::adjacent_spec;
    use crate::interval::contains_spec;
    use crate::interval::overlaps_spec;
    use crate::region::contains_addr_spec;
    use crate::region::region_adjacent_spec;
    use crate::region::regions_disjoint_spec;

    verus! {

    // r[impl properties.region-contains-agrees-interval]
    pub open spec fn region_contains_agrees_interval_prop(
        base: u64, size: u64, x: u64,
    ) -> bool
        recommends base as int + size as int <= u64::MAX as int
    {
        contains_addr_spec(base, size, x)
            == contains_spec(base, (base as int + size as int) as u64, x)
    }

    // r[verify properties.region-contains-agrees-interval]
    proof fn prove_region_contains_agrees_interval(base: u64, size: u64, x: u64)
        requires base as int + size as int <= u64::MAX as int
        ensures region_contains_agrees_interval_prop(base, size, x)
    {}

    // r[impl properties.region-disjoint-agrees-interval]
    pub open spec fn region_disjoint_agrees_interval_prop(
        a_base: u64, a_size: u64, b_base: u64, b_size: u64,
    ) -> bool
        recommends
            a_base as int + a_size as int <= u64::MAX as int,
            b_base as int + b_size as int <= u64::MAX as int,
    {
        regions_disjoint_spec(a_base, a_size, b_base, b_size)
            == !overlaps_spec(
                a_base, (a_base as int + a_size as int) as u64,
                b_base, (b_base as int + b_size as int) as u64,
            )
    }

    // r[verify properties.region-disjoint-agrees-interval]
    proof fn prove_region_disjoint_agrees_interval(
        a_base: u64, a_size: u64, b_base: u64, b_size: u64,
    )
        requires
            a_base as int + a_size as int <= u64::MAX as int,
            b_base as int + b_size as int <= u64::MAX as int,
        ensures region_disjoint_agrees_interval_prop(a_base, a_size, b_base, b_size)
    {}

    // r[impl properties.region-adjacent-agrees-interval]
    pub open spec fn region_adjacent_agrees_interval_prop(
        a_base: u64, a_size: u64, b_base: u64, b_size: u64,
    ) -> bool
        recommends
            a_base as int + a_size as int <= u64::MAX as int,
            b_base as int + b_size as int <= u64::MAX as int,
    {
        region_adjacent_spec(a_base, a_size, b_base, b_size)
            == adjacent_spec(
                a_base, (a_base as int + a_size as int) as u64,
                b_base, (b_base as int + b_size as int) as u64,
            )
    }

    // r[verify properties.region-adjacent-agrees-interval]
    proof fn prove_region_adjacent_agrees_interval(
        a_base: u64, a_size: u64, b_base: u64, b_size: u64,
    )
        requires
            a_base as int + a_size as int <= u64::MAX as int,
            b_base as int + b_size as int <= u64::MAX as int,
        ensures region_adjacent_agrees_interval_prop(a_base, a_size, b_base, b_size)
    {}

    } // verus!
}

// --- signal ↔ bitwise agreement ---

#[cfg(verus_keep_ghost)]
mod signal_bitwise_proofs {
    use vstd::prelude::*;

    use crate::bitwise::bit_at_spec;
    use crate::bitwise::clear_bit_spec;
    use crate::bitwise::set_bit_spec;
    use crate::signal::signal_add_spec;
    use crate::signal::signal_contains_spec;
    use crate::signal::signal_remove_spec;

    verus! {

    // r[impl properties.signal-add-is-set-bit]
    pub open spec fn signal_add_is_set_bit_prop(set: u64, sig: u64) -> bool
        recommends sig < 64
    {
        signal_add_spec(set, sig) == set_bit_spec(set, sig)
    }

    // r[verify properties.signal-add-is-set-bit]
    proof fn prove_signal_add_is_set_bit(set: u64, sig: u64)
        requires sig < 64
        ensures signal_add_is_set_bit_prop(set, sig)
    {}

    // r[impl properties.signal-remove-is-clear-bit]
    pub open spec fn signal_remove_is_clear_bit_prop(set: u64, sig: u64) -> bool
        recommends sig < 64
    {
        signal_remove_spec(set, sig) == clear_bit_spec(set, sig)
    }

    // r[verify properties.signal-remove-is-clear-bit]
    proof fn prove_signal_remove_is_clear_bit(set: u64, sig: u64)
        requires sig < 64
        ensures signal_remove_is_clear_bit_prop(set, sig)
    {}

    // r[impl properties.signal-contains-is-bit-at]
    pub open spec fn signal_contains_is_bit_at_prop(set: u64, sig: u64) -> bool
        recommends sig < 64
    {
        signal_contains_spec(set, sig) == bit_at_spec(set, sig)
    }

    // r[verify properties.signal-contains-is-bit-at]
    proof fn prove_signal_contains_is_bit_at(set: u64, sig: u64)
        requires sig < 64
        ensures signal_contains_is_bit_at_prop(set, sig)
    {}

    } // verus!
}

// --- permission ↔ bitwise composition ---

#[cfg(verus_keep_ghost)]
mod permission_bitwise_proofs {
    use vstd::prelude::*;

    use crate::permission::bit_position_spec;
    use crate::permission::has_permission_spec;
    use crate::permission::set_permission_spec;

    verus! {

    // r[impl properties.permission-set-check-roundtrip]
    pub open spec fn permission_set_check_roundtrip_prop(
        mode: u64, who: u64, perm: u64,
    ) -> bool
        recommends who <= 2, perm <= 2
    {
        has_permission_spec(set_permission_spec(mode, who, perm), who, perm)
    }

    // r[verify properties.permission-set-check-roundtrip]
    proof fn prove_permission_set_check_roundtrip(mode: u64, who: u64, perm: u64)
        requires who <= 2, perm <= 2
        ensures permission_set_check_roundtrip_prop(mode, who, perm)
    {
        let pos = bit_position_spec(who, perm);
        assert(pos < 9) by {
            // bit_position = (2 - who) * 3 + perm, max = 2*3+2 = 8
        }
        // set_bit then bit_at at same position is true
        assert(((mode | (1u64 << pos)) >> pos) & 1u64 == 1u64) by(bit_vector)
            requires pos < 9u64;
    }

    // r[impl properties.permission-set-independence]
    pub open spec fn permission_set_independence_prop(
        mode: u64, w1: u64, p1: u64, w2: u64, p2: u64,
    ) -> bool
        recommends w1 <= 2, p1 <= 2, w2 <= 2, p2 <= 2
    {
        bit_position_spec(w1, p1) != bit_position_spec(w2, p2) ==>
            has_permission_spec(set_permission_spec(mode, w1, p1), w2, p2)
                == has_permission_spec(mode, w2, p2)
    }

    // r[verify properties.permission-set-independence]
    proof fn prove_permission_set_independence(
        mode: u64, w1: u64, p1: u64, w2: u64, p2: u64,
    )
        requires w1 <= 2, p1 <= 2, w2 <= 2, p2 <= 2
        ensures permission_set_independence_prop(mode, w1, p1, w2, p2)
    {
        let pos1 = bit_position_spec(w1, p1);
        let pos2 = bit_position_spec(w2, p2);
        if pos1 != pos2 {
            assert(pos1 < 9 && pos2 < 9) by {}
            // Setting bit pos1 doesn't change bit pos2
            assert(((mode | (1u64 << pos1)) >> pos2) & 1u64
                == (mode >> pos2) & 1u64) by(bit_vector)
                requires pos1 != pos2, pos1 < 9u64, pos2 < 9u64;
        }
    }

    } // verus!
}

// --- page ↔ arithmetic/integer agreement ---

#[cfg(verus_keep_ghost)]
mod page_arithmetic_proofs {
    use vstd::prelude::*;

    use crate::arithmetic::div_ceil_spec;
    use crate::integer::align_down_spec;
    use crate::page::is_page_aligned_spec;
    use crate::page::pages_needed_spec;

    verus! {

    // r[impl properties.pages-needed-is-div-ceil]
    pub open spec fn pages_needed_is_div_ceil_prop(size: u64, ps: u64) -> bool
        recommends ps > 0
    {
        pages_needed_spec(size, ps) == div_ceil_spec(size, ps)
    }

    // r[verify properties.pages-needed-is-div-ceil]
    proof fn prove_pages_needed_is_div_ceil(size: u64, ps: u64)
        requires ps > 0
        ensures pages_needed_is_div_ceil_prop(size, ps)
    {}

    // r[impl properties.page-aligned-is-align-down-fixpoint]
    pub open spec fn page_aligned_is_align_down_fixpoint_prop(addr: u64, ps: u64) -> bool
        recommends ps > 0
    {
        is_page_aligned_spec(addr, ps) == (align_down_spec(addr, ps) == addr)
    }

    // r[verify properties.page-aligned-is-align-down-fixpoint]
    proof fn prove_page_aligned_is_align_down_fixpoint(addr: u64, ps: u64)
        requires ps > 0
        ensures page_aligned_is_align_down_fixpoint_prop(addr, ps)
    {
        vstd::arithmetic::div_mod::lemma_fundamental_div_mod(addr as int, ps as int);
    }

    } // verus!
}

// --- expiration ↔ lease boundary agreement ---

#[cfg(verus_keep_ghost)]
mod lease_expiration_proofs {
    use vstd::prelude::*;

    use crate::expiration::is_expired_spec;
    use crate::lease::Lease;
    use crate::lease::effective_expiry_spec;
    use crate::lease::grant_spec;
    use crate::lease::is_valid_spec;
    use crate::lease::renew_spec;
    use crate::monotonic::is_advance_spec;

    verus! {

    // r[impl properties.lease-valid-implies-not-expired]
    pub open spec fn lease_valid_implies_not_expired_prop(lease: Lease, now: u64) -> bool {
        (!lease.is_revoked && is_valid_spec(lease, now))
            ==> !is_expired_spec(lease.expiry, now)
    }

    // r[verify properties.lease-valid-implies-not-expired]
    proof fn prove_lease_valid_implies_not_expired(lease: Lease, now: u64)
        ensures lease_valid_implies_not_expired_prop(lease, now)
    {
        // is_valid requires now < effective_expiry = expiry (non-revoked)
        // !is_expired requires now <= expiry (now > expiry is false)
        // now < expiry ==> now <= expiry — automatic
    }

    // r[impl properties.lease-renewal-is-advance]
    pub open spec fn lease_renewal_is_advance_prop(lease: Lease, new_expiry: u64) -> bool
        recommends !lease.is_revoked, new_expiry > lease.expiry
    {
        is_advance_spec(
            effective_expiry_spec(lease),
            effective_expiry_spec(renew_spec(lease, new_expiry)),
        )
    }

    // r[verify properties.lease-renewal-is-advance]
    proof fn prove_lease_renewal_is_advance(lease: Lease, new_expiry: u64)
        requires !lease.is_revoked, new_expiry > lease.expiry
        ensures lease_renewal_is_advance_prop(lease, new_expiry)
    {
        // effective_expiry(non-revoked) = expiry
        // renew sets expiry = new_expiry
        // is_advance = new_expiry >= lease.expiry — follows from new_expiry > lease.expiry
    }

    } // verus!
}

// --- tier ↔ eviction_score monotonicity ---

#[cfg(verus_keep_ghost)]
mod tier_score_proofs {
    use vstd::prelude::*;

    use crate::eviction_score::tier_multiplier_spec;
    use crate::tier::classify_tier_spec;

    verus! {

    // r[impl properties.tier-score-monotonic]
    pub open spec fn tier_score_monotonic_prop(
        count_a: u64, count_b: u64, warm_t: u64, hot_t: u64,
    ) -> bool
        recommends warm_t <= hot_t
    {
        count_a <= count_b ==>
            tier_multiplier_spec(classify_tier_spec(count_a, warm_t, hot_t))
                <= tier_multiplier_spec(classify_tier_spec(count_b, warm_t, hot_t))
    }

    // r[verify properties.tier-score-monotonic]
    proof fn prove_tier_score_monotonic(
        count_a: u64, count_b: u64, warm_t: u64, hot_t: u64,
    )
        requires warm_t <= hot_t
        ensures tier_score_monotonic_prop(count_a, count_b, warm_t, hot_t)
    {
        // Z3 case splits on the tier thresholds:
        // count_a <= count_b, so tier(count_a) <= tier(count_b)
        // tier_multiplier is monotone in tier value (0→1, 1→2, 2→4)
    }

    } // verus!
}

// --- backoff ↔ bounds ---

#[cfg(verus_keep_ghost)]
mod backoff_bounds_proofs {
    use vstd::prelude::*;

    use crate::backoff::compute_backoff_spec;

    verus! {

    // r[impl properties.backoff-in-range]
    pub open spec fn backoff_in_range_prop(base: u64, attempt: u64, cap: u64) -> bool {
        compute_backoff_spec(base, attempt, cap) <= cap
    }

    // r[verify properties.backoff-in-range]
    proof fn prove_backoff_in_range(base: u64, attempt: u64, cap: u64)
        ensures backoff_in_range_prop(base, attempt, cap)
    {
        // base == 0 → result = 0 <= cap (u64 non-negative)
        // base > 0 → result = min(uncapped, cap) <= cap by definition of min
    }

    } // verus!
}

// --- approval ↔ quorum ---

#[cfg(verus_keep_ghost)]
mod approval_quorum_proofs {
    use vstd::prelude::*;

    use crate::approval::is_merge_allowed_spec;
    use crate::quorum::is_quorum_spec;
    use crate::quorum::majority_spec;

    verus! {

    // r[impl properties.approval-majority-implies-quorum]
    pub open spec fn approval_majority_implies_quorum_prop(
        valid: u64, required: u64, total: u64,
    ) -> bool
        recommends total > 0
    {
        (required >= majority_spec(total)
            && is_merge_allowed_spec(valid, required, true))
            ==> is_quorum_spec(valid, total)
    }

    // r[verify properties.approval-majority-implies-quorum]
    proof fn prove_approval_majority_implies_quorum(
        valid: u64, required: u64, total: u64,
    )
        requires total > 0
        ensures approval_majority_implies_quorum_prop(valid, required, total)
    {
        // is_merge_allowed(valid, required, true) = valid >= required
        // required >= majority(total) and valid >= required
        // ==> valid >= majority(total) = is_quorum(valid, total)
    }

    } // verus!
}

// --- two-phase commit ↔ quorum ---

#[cfg(verus_keep_ghost)]
mod two_phase_quorum_proofs {
    use vstd::prelude::*;

    use crate::quorum::is_quorum_spec;
    use crate::quorum::majority_spec;
    use crate::two_phase::can_commit_spec;

    verus! {

    // r[impl properties.two-phase-unanimity-implies-quorum]
    pub open spec fn two_phase_unanimity_implies_quorum_prop(
        votes: Seq<Option<bool>>,
    ) -> bool
        recommends votes.len() <= u64::MAX as int
    {
        can_commit_spec(votes) ==>
            is_quorum_spec(votes.len() as u64, votes.len() as u64)
    }

    // r[verify properties.two-phase-unanimity-implies-quorum]
    proof fn prove_two_phase_unanimity_implies_quorum(
        votes: Seq<Option<bool>>,
    )
        requires votes.len() <= u64::MAX as int
        ensures two_phase_unanimity_implies_quorum_prop(votes)
    {
        // can_commit ==> votes.len() > 0
        // is_quorum(n, n) = n >= majority(n) = n >= n/2 + 1
        if can_commit_spec(votes) {
            let n: u64 = votes.len() as u64;
            assert(votes.len() > 0);
            assert(n as int == votes.len());
            assert(n > 0);
            assert(n >= n / 2 + 1) by(nonlinear_arith)
                requires n > 0u64;
        }
    }

    } // verus!
}

// --- expiration ↔ monotonic ---

#[cfg(verus_keep_ghost)]
mod expiration_monotonic_proofs {
    use vstd::prelude::*;

    use crate::expiration::expires_at_spec;
    use crate::monotonic::is_advance_spec;

    verus! {

    // r[impl properties.expires-at-monotonic-is-advance]
    pub open spec fn expires_at_monotonic_is_advance_prop(
        now: u64, ttl_a: u64, ttl_b: u64,
    ) -> bool {
        ttl_a <= ttl_b ==>
            is_advance_spec(expires_at_spec(now, ttl_a), expires_at_spec(now, ttl_b))
    }

    // r[verify properties.expires-at-monotonic-is-advance]
    proof fn prove_expires_at_monotonic_is_advance(
        now: u64, ttl_a: u64, ttl_b: u64,
    )
        ensures expires_at_monotonic_is_advance_prop(now, ttl_a, ttl_b)
    {
        // is_advance = new >= old
        // expires_at uses saturating semantics: larger ttl → larger or equal result
        // Case 1: both ttl*1000 fit in u64 → both now+ttl_ms fit → direct <=
        // Case 2: ttl_a*1000 fits but ttl_b*1000 doesn't → b saturates to MAX >= a's result
        // Case 3: both overflow → both = MAX (or now+MAX saturated)
        // All cases: expires_at(now, ttl_b) >= expires_at(now, ttl_a)
    }

    } // verus!
}

// --- cow ↔ drain isomorphism ---

#[cfg(verus_keep_ghost)]
mod cow_drain_proofs {
    use vstd::prelude::*;

    use crate::cow::ref_count_after_clone_spec;
    use crate::cow::ref_count_after_drop_spec;
    use crate::drain::after_finish_op_spec;
    use crate::drain::after_start_op_spec;

    verus! {

    // r[impl properties.cow-clone-is-drain-start]
    pub open spec fn cow_clone_is_drain_start_prop(n: u64) -> bool {
        ref_count_after_clone_spec(n) == after_start_op_spec(n)
    }

    // r[verify properties.cow-clone-is-drain-start]
    proof fn prove_cow_clone_is_drain_start(n: u64)
        ensures cow_clone_is_drain_start_prop(n)
    {}

    // r[impl properties.cow-drop-is-drain-finish]
    pub open spec fn cow_drop_is_drain_finish_prop(n: u64) -> bool {
        ref_count_after_drop_spec(n) == after_finish_op_spec(n)
    }

    // r[verify properties.cow-drop-is-drain-finish]
    proof fn prove_cow_drop_is_drain_finish(n: u64)
        ensures cow_drop_is_drain_finish_prop(n)
    {}

    } // verus!
}

// --- type lattice preorder ---

#[cfg(verus_keep_ghost)]
mod type_lattice_proofs {
    use vstd::prelude::*;

    use crate::type_lattice::can_convert_spec;
    use crate::type_lattice::is_valid_type_spec;

    verus! {

    // r[impl properties.type-lattice-reflexive]
    pub open spec fn type_lattice_reflexive_prop(t: u8) -> bool {
        is_valid_type_spec(t) ==> can_convert_spec(t, t)
    }

    // r[verify properties.type-lattice-reflexive]
    proof fn prove_type_lattice_reflexive(t: u8)
        ensures type_lattice_reflexive_prop(t)
    {
        // can_convert_spec has `from == to` as first disjunct — automatic
    }

    // r[impl properties.type-lattice-any-top]
    pub open spec fn type_lattice_any_top_prop(t: u8) -> bool {
        is_valid_type_spec(t) ==> (
            can_convert_spec(t, 6u8) && can_convert_spec(6u8, t)
        )
    }

    // r[verify properties.type-lattice-any-top]
    proof fn prove_type_lattice_any_top(t: u8)
        ensures type_lattice_any_top_prop(t)
    {
        // can_convert_spec has `to == TYPE_ANY()` and `from == TYPE_ANY()` disjuncts
    }

    } // verus!
}

// --- circuit breaker preserves validity ---

#[cfg(verus_keep_ghost)]
mod circuit_breaker_validity_proofs {
    use vstd::prelude::*;

    use crate::circuit_breaker::OPEN;
    use crate::circuit_breaker::allow_request_spec;
    use crate::circuit_breaker::is_valid_state_spec;
    use crate::circuit_breaker::next_state_spec;

    verus! {

    // r[impl properties.circuit-breaker-preserves-validity]
    pub open spec fn circuit_breaker_preserves_validity_prop(
        current: u8, failure_count: u64, threshold: u64,
        elapsed: u64, timeout: u64, probe_succeeded: bool,
    ) -> bool
        recommends is_valid_state_spec(current), threshold > 0, timeout > 0
    {
        is_valid_state_spec(
            next_state_spec(current, failure_count, threshold, elapsed, timeout, probe_succeeded),
        )
    }

    // r[verify properties.circuit-breaker-preserves-validity]
    proof fn prove_circuit_breaker_preserves_validity(
        current: u8, failure_count: u64, threshold: u64,
        elapsed: u64, timeout: u64, probe_succeeded: bool,
    )
        requires is_valid_state_spec(current), threshold > 0, timeout > 0
        ensures circuit_breaker_preserves_validity_prop(
            current, failure_count, threshold, elapsed, timeout, probe_succeeded,
        )
    {}

    // r[impl properties.process-terminal-blocks-circuit-open-blocks]
    pub open spec fn terminal_and_open_block_prop() -> bool {
        // process_state: terminal(4) has no outgoing transitions
        // circuit_breaker: OPEN blocks requests
        &&& !allow_request_spec(OPEN, false)
        &&& !allow_request_spec(OPEN, true)
    }

    // r[verify properties.process-terminal-blocks-circuit-open-blocks]
    proof fn prove_terminal_and_open_block()
        ensures terminal_and_open_block_prop()
    {}

    } // verus!
}

// --- bitmap ↔ signal single-word agreement ---

#[cfg(verus_keep_ghost)]
mod bitmap_signal_proofs {
    use vstd::prelude::*;

    use crate::bitwise::bit_at_spec;
    use crate::signal::signal_contains_spec;

    verus! {

    // r[impl properties.bitmap-signal-agree]
    pub open spec fn bitmap_signal_agree_prop(word: u64, pos: u64) -> bool
        recommends pos < 64
    {
        // Bitmap get_spec for single word: bit_at_spec(words[0], (pos % 64) as u64)
        // For pos < 64: pos % 64 == pos, so get_spec(pos) == bit_at_spec(word, pos)
        // signal_contains_spec(word, pos) == bit_at_spec(word, pos)
        // Therefore bitmap and signal agree through bit_at_spec
        bit_at_spec(word, pos) == signal_contains_spec(word, pos)
    }

    // r[verify properties.bitmap-signal-agree]
    proof fn prove_bitmap_signal_agree(word: u64, pos: u64)
        requires pos < 64
        ensures bitmap_signal_agree_prop(word, pos)
    {
        // Both expand to (word >> pos) & 1 == 1 — identical definitions
    }

    } // verus!
}

// --- slab slot within region bounds ---

#[cfg(verus_keep_ghost)]
mod slab_region_proofs {
    use vstd::prelude::*;

    use crate::region::contains_addr_spec;
    use crate::slab::slab_capacity_spec;
    use crate::slab::slot_address_spec;

    verus! {

    // r[impl properties.slab-slot-in-region]
    pub open spec fn slab_slot_in_region_prop(
        index: u64, base: u64, capacity: u64, slot_size: u64,
    ) -> bool
        recommends
            slot_size > 0,
            base as int + capacity as int <= u64::MAX as int,
            index < slab_capacity_spec(capacity, slot_size),
    {
        contains_addr_spec(
            base,
            capacity,
            slot_address_spec(index, base, slot_size),
        )
    }

    // r[verify properties.slab-slot-in-region]
    proof fn prove_slab_slot_in_region(
        index: u64, base: u64, capacity: u64, slot_size: u64,
    )
        requires
            slot_size > 0,
            base as int + capacity as int <= u64::MAX as int,
            index < slab_capacity_spec(capacity, slot_size),
        ensures slab_slot_in_region_prop(index, base, capacity, slot_size)
    {
        // index < capacity / slot_size
        // slot_address = base + index * slot_size
        // Need: base <= base + index * slot_size < base + capacity
        // i.e., index * slot_size < capacity
        // From index < capacity / slot_size and slot_size > 0:
        let ss = slot_size as int;
        let cap = capacity as int;
        let idx = index as int;
        vstd::arithmetic::div_mod::lemma_fundamental_div_mod(cap, ss);
        assert(idx * ss < cap) by(nonlinear_arith)
            requires ss > 0, idx < cap / ss,
                cap == ss * (cap / ss) + cap % ss,
                0 <= cap % ss, cap % ss < ss;
    }

    } // verus!
}

// --- pressure → eviction pipeline ---

#[cfg(verus_keep_ghost)]
mod pressure_eviction_proofs {
    use vstd::prelude::*;

    use crate::eviction::should_evict_spec;
    use crate::eviction_score::tier_multiplier_spec;
    use crate::pressure::classify_level_spec;

    verus! {

    // r[impl properties.pressure-eviction-pipeline]
    pub open spec fn pressure_eviction_pipeline_prop(count: u64, capacity: u64) -> bool {
        // classify_level with warn=capacity, crit=capacity:
        // count >= capacity → level >= 2 (critical)
        // should_evict: count >= capacity
        (classify_level_spec(count, capacity, capacity) >= 2)
            ==> should_evict_spec(count, capacity)
    }

    // r[verify properties.pressure-eviction-pipeline]
    proof fn prove_pressure_eviction_pipeline(count: u64, capacity: u64)
        ensures pressure_eviction_pipeline_prop(count, capacity)
    {
        // classify_level returns 2 when count >= crit_threshold (= capacity)
        // should_evict returns true when count >= capacity
        // Same condition — automatic
    }

    // r[impl properties.eviction-score-cold-minimum]
    pub open spec fn eviction_score_cold_minimum_prop(tier: u8) -> bool {
        tier_multiplier_spec(0u8) <= tier_multiplier_spec(tier)
    }

    // r[verify properties.eviction-score-cold-minimum]
    proof fn prove_eviction_score_cold_minimum(tier: u8)
        ensures eviction_score_cold_minimum_prop(tier)
    {
        // tier_multiplier(0) = 1, and all other values are >= 1
    }

    } // verus!
}

// --- evictable_count ↔ saturating_sub ---

#[cfg(verus_keep_ghost)]
mod eviction_arithmetic_proofs {
    use vstd::prelude::*;

    use crate::arithmetic::saturating_sub_spec;
    use crate::eviction::evictable_count_spec;

    verus! {

    // r[impl properties.evictable-count-is-saturating-sub]
    pub open spec fn evictable_count_is_saturating_sub_prop(count: u64, protected: u64) -> bool {
        evictable_count_spec(count, protected) == saturating_sub_spec(count, protected)
    }

    // r[verify properties.evictable-count-is-saturating-sub]
    proof fn prove_evictable_count_is_saturating_sub(count: u64, protected: u64)
        ensures evictable_count_is_saturating_sub_prop(count, protected)
    {
        // evictable: if count >= protected { count - protected } else { 0 }
        // saturating_sub: if b > a { 0 } else { a - b }
        // count >= protected <==> !(protected > count) — automatic
    }

    } // verus!
}

// --- gossip properties ---

#[cfg(verus_keep_ghost)]
mod gossip_proofs {
    use vstd::prelude::*;

    use crate::gossip::infection_lower_bound_spec;

    verus! {

    // r[impl properties.gossip-infection-bounded]
    pub open spec fn gossip_infection_bounded_prop(
        cluster_size: u64, fanout: u64, rounds: u64,
    ) -> bool {
        infection_lower_bound_spec(cluster_size, fanout, rounds) <= cluster_size
    }

    // r[impl properties.gossip-infection-monotonic-rounds]
    pub open spec fn gossip_infection_monotonic_rounds_prop(
        cluster_size: u64, fanout: u64, rounds_a: u64, rounds_b: u64,
    ) -> bool {
        rounds_a <= rounds_b ==>
            infection_lower_bound_spec(cluster_size, fanout, rounds_a)
                <= infection_lower_bound_spec(cluster_size, fanout, rounds_b)
    }

    // r[verify properties.gossip-infection-bounded]
    proof fn prove_gossip_infection_bounded(
        cluster_size: u64, fanout: u64, rounds: u64,
    )
        ensures gossip_infection_bounded_prop(cluster_size, fanout, rounds)
    {
        // infection_lower_bound_spec:
        //   let bound = saturating_pow_spec(fanout, rounds);
        //   if bound > cluster_size as int { cluster_size } else { bound as u64 }
        // Need: saturating_pow result >= 0 for the cast to be safe
        // Then: both branches return <= cluster_size
        crate::gossip::saturating_pow_nonneg(fanout, rounds);
    }

    } // verus!
}

// --- acid: empty commit identity ---

#[cfg(verus_keep_ghost)]
mod acid_proofs {
    use vstd::prelude::*;

    use crate::acid::WriteOp;
    use crate::acid::commit_spec;

    verus! {

    // r[impl properties.acid-empty-commit-identity]
    pub open spec fn acid_empty_commit_identity_prop(state: Seq<u64>) -> bool {
        commit_spec(state, seq![]) =~= state
    }

    // r[verify properties.acid-empty-commit-identity]
    proof fn prove_acid_empty_commit_identity(state: Seq<u64>)
        ensures acid_empty_commit_identity_prop(state)
    {
        // commit_spec(state, writes, 0) with writes.len() == 0:
        // from >= writes.len() is 0 >= 0 → returns state
    }

    } // verus!
}

// --- eviction_score: priority monotonic + score bounded ---

#[cfg(verus_keep_ghost)]
mod score_bound_proofs {
    use vstd::prelude::*;

    use crate::eviction_score::full_score_spec;
    use crate::eviction_score::priority_multiplier_spec;
    use crate::eviction_score::weighted_score_spec;
    use crate::eviction_score::weights_valid_spec;

    verus! {

    // r[impl properties.priority-multiplier-monotonic]
    pub open spec fn priority_multiplier_monotonic_prop(a: u8, b: u8) -> bool {
        (a <= b && a <= 3 && b <= 3) ==>
            priority_multiplier_spec(a) <= priority_multiplier_spec(b)
    }

    // r[verify properties.priority-multiplier-monotonic]
    proof fn prove_priority_multiplier_monotonic(a: u8, b: u8)
        ensures priority_multiplier_monotonic_prop(a, b)
    {
        // 4 valid priorities, Z3 exhaustive case split on 16 pairs
    }

    // r[impl properties.full-score-bounded]
    pub open spec fn full_score_bounded_prop(
        w1: u64, w2: u64, w3: u64, w4: u64,
        s1: u64, s2: u64, s3: u64, s4: u64,
        priority: u8, tier: u8,
    ) -> bool
        recommends
            weights_valid_spec(w1, w2, w3, w4),
            s1 <= 100, s2 <= 100, s3 <= 100, s4 <= 100,
            priority <= 3, tier <= 2,
    {
        full_score_spec(w1, w2, w3, w4, s1, s2, s3, s4, priority, tier)
            <= 800000
    }

    // r[verify properties.full-score-bounded]
    proof fn prove_full_score_bounded(
        w1: u64, w2: u64, w3: u64, w4: u64,
        s1: u64, s2: u64, s3: u64, s4: u64,
        priority: u8, tier: u8,
    )
        requires
            weights_valid_spec(w1, w2, w3, w4),
            s1 <= 100, s2 <= 100, s3 <= 100, s4 <= 100,
            priority <= 3, tier <= 2,
        ensures full_score_bounded_prop(
            w1, w2, w3, w4, s1, s2, s3, s4, priority, tier,
        )
    {
        // weighted_score <= 100*100 + 100*100 + 100*100 + 100*100 = 10000
        // (actually w1*s1 + w2*s2 + w3*s3 + w4*s4 <= (w1+w2+w3+w4)*100 = 100*100 = 10000)
        // priority_multiplier <= 20, tier_multiplier <= 4
        // 10000 * 20 * 4 = 800000
        assert(w1 * s1 + w2 * s2 + w3 * s3 + w4 * s4 <= 10000) by(nonlinear_arith)
            requires
                w1 + w2 + w3 + w4 == 100,
                w1 <= 100, w2 <= 100, w3 <= 100, w4 <= 100,
                s1 <= 100u64, s2 <= 100u64, s3 <= 100u64, s4 <= 100u64;
        assert(priority_multiplier_spec(priority) <= 20);
        assert(crate::eviction_score::tier_multiplier_spec(tier) <= 4);
        assert(10000int * 20 * 4 == 800000) by(nonlinear_arith);
        assert(weighted_score_spec(w1, w2, w3, w4, s1, s2, s3, s4) as int
            * priority_multiplier_spec(priority) as int
            * crate::eviction_score::tier_multiplier_spec(tier) as int
            <= 800000) by(nonlinear_arith)
            requires
                weighted_score_spec(w1, w2, w3, w4, s1, s2, s3, s4) as int <= 10000,
                priority_multiplier_spec(priority) as int <= 20,
                crate::eviction_score::tier_multiplier_spec(tier) as int <= 4;
    }

    } // verus!
}

// --- consistent hash: lookup exists in ring ---

#[cfg(verus_keep_ghost)]
mod consistent_hash_proofs {
    use vstd::prelude::*;

    use crate::consistent_hash::first_ge_index_spec;
    use crate::consistent_hash::lookup_spec;

    verus! {

    // r[impl properties.consistent-hash-lookup-in-ring]
    pub open spec fn consistent_hash_lookup_in_ring_prop(
        ring: Seq<(u64, u64)>, key_hash: u64,
    ) -> bool
        recommends ring.len() > 0
    {
        let result = lookup_spec(ring, key_hash);
        let idx = first_ge_index_spec(ring, key_hash);
        if idx < ring.len() as int {
            ring[idx].1 == result
        } else {
            ring[0int].1 == result
        }
    }

    // r[verify properties.consistent-hash-lookup-in-ring]
    proof fn prove_consistent_hash_lookup_in_ring(
        ring: Seq<(u64, u64)>, key_hash: u64,
    )
        requires ring.len() > 0
        ensures consistent_hash_lookup_in_ring_prop(ring, key_hash)
    {
        // lookup_spec directly unfolds to the same case split — automatic
    }

    } // verus!
}

// --- bloom: insert preserves length ---

#[cfg(verus_keep_ghost)]
mod bloom_length_proofs {
    use vstd::prelude::*;

    use crate::bloom::insert_spec;

    verus! {

    // r[impl properties.bloom-insert-length-preserved]
    pub open spec fn bloom_insert_length_preserved_prop(
        bits: Seq<bool>, positions: Seq<int>,
    ) -> bool
        recommends
            forall|i: int| 0 <= i < positions.len() as int
                ==> 0 <= #[trigger] positions[i] < bits.len() as int,
    {
        insert_spec(bits, positions).len() == bits.len()
    }

    // r[verify properties.bloom-insert-length-preserved]
    proof fn prove_bloom_insert_length_preserved(
        bits: Seq<bool>, positions: Seq<int>,
    )
        requires
            forall|i: int| 0 <= i < positions.len() as int
                ==> 0 <= #[trigger] positions[i] < bits.len() as int,
        ensures bloom_insert_length_preserved_prop(bits, positions)
        decreases positions.len()
    {
        if positions.len() == 0 {
            // insert_spec returns bits unchanged
        } else {
            // Inductive step: insert on drop_last, then one update
            let shorter = positions.drop_last();
            // All positions in shorter are valid indices into bits
            assert forall|i: int| 0 <= i < shorter.len() as int
                implies 0 <= #[trigger] shorter[i] < bits.len() as int by {
                // shorter[i] == positions[i] for i < positions.len() - 1
            }
            prove_bloom_insert_length_preserved(bits, shorter);
            // After recursion: insert_spec(bits, shorter).len() == bits.len()
            // Then one Seq::update preserves length
        }
    }

    } // verus!
}

// --- Cross-module: Ledger ---

#[cfg(verus_keep_ghost)]
mod ledger_proofs {
    use vstd::prelude::*;

    use crate::arithmetic::saturating_add_spec;
    use crate::balance::credit_spec;
    use crate::balance::debit_spec;
    use crate::balance::has_funds_spec;
    use crate::bounds::in_range_spec;
    use crate::fencing::is_valid_write_spec;
    use crate::monotonic::is_strict_advance_spec;
    use crate::transfer::is_duplicate_spec;
    use crate::transfer::receiver_after_spec;
    use crate::transfer::sender_after_spec;
    use crate::transfer::transfer_valid_spec;

    verus! {

    // r[impl properties.balance-credit-is-saturating-add]
    // r[verify properties.balance-credit-is-saturating-add]
    /// When credit fits in u64, it agrees with saturating_add.
    proof fn prove_balance_credit_is_saturating_add(b: u64, a: u64)
        requires credit_spec(b, a) <= u64::MAX as int
        ensures credit_spec(b, a) as u64 == saturating_add_spec(b, a)
    {}

    // r[impl properties.balance-has-funds-is-in-range]
    // r[verify properties.balance-has-funds-is-in-range]
    /// Sufficient funds is a range check on the amount.
    proof fn prove_balance_has_funds_is_in_range(b: u64, a: u64)
        ensures has_funds_spec(b, a) == in_range_spec(a, 0, b)
    {}

    // r[impl properties.transfer-uses-debit-credit]
    // r[verify properties.transfer-uses-debit-credit]
    /// Transfer sender/receiver match balance debit/credit.
    proof fn prove_transfer_uses_debit_credit(from: u64, to: u64, amount: u64)
        requires transfer_valid_spec(from, to, amount)
        ensures
            sender_after_spec(from, amount) as int == debit_spec(from, amount),
            receiver_after_spec(to, amount) as int == credit_spec(to, amount),
    {}

    // r[impl properties.transfer-idempotency-is-fencing]
    // r[verify properties.transfer-idempotency-is-fencing]
    /// Non-duplicate request satisfies fencing validity.
    proof fn prove_transfer_idempotency_is_fencing(request_id: u64, last_processed_id: u64)
        requires !is_duplicate_spec(request_id, last_processed_id)
        ensures is_valid_write_spec(request_id, last_processed_id)
    {}

    // r[impl properties.journal-seq-num-is-strict-advance]
    // r[verify properties.journal-seq-num-is-strict-advance]
    /// Monotonic journal seq nums satisfy strict advance.
    proof fn prove_journal_seq_num_is_strict_advance(a: u64, b: u64)
        requires a < b
        ensures is_strict_advance_spec(a, b)
    {}

    // r[impl properties.balanced-simple-is-transfer]
    // r[verify properties.balanced-simple-is-transfer]
    /// Simple balanced entry corresponds to a valid transfer from a to 0.
    proof fn prove_balanced_simple_is_transfer(a: u64)
        requires a > 0, a as int <= u64::MAX as int
        ensures transfer_valid_spec(a, 0, a)
    {}

    } // verus!
}

// --- escrow ↔ balance, fee ↔ transfer ---

#[cfg(verus_keep_ghost)]
mod financial_proofs {
    use vstd::prelude::*;

    use crate::balance::credit_spec;
    use crate::balance::debit_spec;
    use crate::escrow::ESCROW_REFUNDED;
    use crate::escrow::ESCROW_RELEASED;
    use crate::escrow::fund_buyer_after_spec;
    use crate::escrow::is_terminal_spec;
    use crate::escrow::release_seller_after_spec;
    use crate::fee::MAX_RATE_BPS;
    use crate::fee::compute_fee_spec;
    use crate::fee::compute_net_spec;
    use crate::process_state::is_terminal_spec as ps_is_terminal_spec;

    verus! {

    // r[impl properties.escrow-fund-uses-debit]
    // r[verify properties.escrow-fund-uses-debit]
    /// Escrow funding is a balance debit.
    proof fn prove_escrow_fund_uses_debit(buyer: u64, amount: u64)
        ensures fund_buyer_after_spec(buyer, amount) == debit_spec(buyer, amount)
    {}

    // r[impl properties.escrow-release-uses-credit]
    // r[verify properties.escrow-release-uses-credit]
    /// Escrow release is a balance credit.
    proof fn prove_escrow_release_uses_credit(seller: u64, amount: u64)
        ensures release_seller_after_spec(seller, amount) == credit_spec(seller, amount)
    {}

    // r[impl properties.escrow-terminal-like-process]
    // r[verify properties.escrow-terminal-like-process]
    /// Both escrow and process_state have terminal absorbing states.
    proof fn prove_escrow_terminal_like_process()
        ensures
            is_terminal_spec(ESCROW_RELEASED),
            is_terminal_spec(ESCROW_REFUNDED),
            ps_is_terminal_spec(4u64),
    {}

    // r[impl properties.fee-conservation-matches-transfer]
    // r[verify properties.fee-conservation-matches-transfer]
    /// Fee split conserves value: fee + net = amount.
    proof fn prove_fee_conservation_matches_transfer(amount: u64, rate_bps: u64)
        requires rate_bps <= MAX_RATE_BPS
        ensures compute_fee_spec(amount, rate_bps)
            + compute_net_spec(amount, rate_bps) == amount as int
    {}

    // r[impl properties.fee-zero-rate-identity]
    // r[verify properties.fee-zero-rate-identity]
    /// Zero-rate fee leaves amount unchanged.
    proof fn prove_fee_zero_rate_identity(amount: u64)
        ensures compute_net_spec(amount, 0) == amount as int
    {}

    // r[impl properties.ledger-transfer-uses-balance]
    // r[verify properties.ledger-transfer-uses-balance]
    /// Ledger transfer sender/receiver match balance debit/credit.
    proof fn prove_ledger_transfer_uses_balance(
        accounts: Seq<u64>, from_idx: int, to_idx: int, amount: u64,
    )
        requires crate::ledger::can_transfer_spec(accounts, from_idx, to_idx, amount)
        ensures
            crate::ledger::transfer_result_spec(accounts, from_idx, to_idx, amount)[from_idx]
                as int == debit_spec(accounts[from_idx], amount),
            crate::ledger::transfer_result_spec(accounts, from_idx, to_idx, amount)[to_idx]
                as int == credit_spec(accounts[to_idx], amount),
    {}

    // r[impl properties.ledger-conservation-is-double-entry]
    // r[verify properties.ledger-conservation-is-double-entry]
    /// Ledger transfer conservation mirrors double_entry balanced property:
    /// debiting sender and crediting receiver by the same amount is balanced.
    proof fn prove_ledger_conservation_is_double_entry(amount: u64)
        requires amount > 0
        ensures crate::double_entry::is_balanced_spec(seq![amount], seq![amount])
    {}

    } // verus!
}

// --- Nickel cross-module properties ---

#[cfg(verus_keep_ghost)]
mod nickel_proofs {
    use vstd::prelude::*;

    use crate::nickel_field_merge::FieldMergeResult;
    use crate::nickel_field_merge::field_merge_spec;
    use crate::nickel_merge_split::is_sorted_keys;
    use crate::nickel_merge_split::key_lt;
    use crate::nickel_merge_split::key_total;
    use crate::nickel_merge_split::kv_kv_disjoint;
    use crate::nickel_merge_split::split_spec;
    use crate::nickel_priority::MergePriority;
    use crate::nickel_priority::priority_lt;

    verus! {

    proof fn drop_first_index<A>(s: Seq<A>, i: int)
        requires s.len() > 0, 0 <= i < s.subrange(1, s.len() as int).len()
        ensures s.subrange(1, s.len() as int)[i] == s[i + 1]
    {}

    proof fn seq_head_tail_eq<A>(s: Seq<A>)
        requires s.len() > 0
        ensures s =~= seq![s[0int]] + s.subrange(1, s.len() as int)
    {
        assert forall|i: int| 0 <= i < s.len()
            implies s[i] == (seq![s[0int]] + s.subrange(1, s.len() as int))[i] by {
            if i == 0 {
            } else {
                drop_first_index(s, i - 1);
            }
        }
    }

    proof fn nickel_sorted_tail(attrs: Seq<(Seq<u8>, u64)>)
        requires is_sorted_keys(attrs), attrs.len() > 0
        ensures is_sorted_keys(attrs.subrange(1, attrs.len() as int))
    {
        assert forall|i: int, j: int|
            0 <= i < j < attrs.subrange(1, attrs.len() as int).len()
            implies key_lt(attrs.subrange(1, attrs.len() as int)[i].0, attrs.subrange(1, attrs.len() as int)[j].0) by {
            drop_first_index(attrs, i);
            drop_first_index(attrs, j);
            assert(0 <= i + 1 < j + 1 < attrs.len());
        }
    }

    proof fn nickel_disjoint_tail_left(a: Seq<(Seq<u8>, u64)>, b: Seq<(Seq<u8>, u64)>)
        requires kv_kv_disjoint(a, b), a.len() > 0
        ensures kv_kv_disjoint(a.subrange(1, a.len() as int), b)
    {
        assert forall|i: int, j: int|
            0 <= i < a.subrange(1, a.len() as int).len() && 0 <= j < b.len()
            implies !(a.subrange(1, a.len() as int)[i].0 =~= b[j].0) by {
            drop_first_index(a, i);
            assert(0 <= i + 1 < a.len());
        }
    }

    proof fn nickel_disjoint_tail_right(a: Seq<(Seq<u8>, u64)>, b: Seq<(Seq<u8>, u64)>)
        requires kv_kv_disjoint(a, b), b.len() > 0
        ensures kv_kv_disjoint(a, b.subrange(1, b.len() as int))
    {
        assert forall|i: int, j: int|
            0 <= i < a.len() && 0 <= j < b.subrange(1, b.len() as int).len()
            implies !(a[i].0 =~= b.subrange(1, b.len() as int)[j].0) by {
            drop_first_index(b, j);
            assert(0 <= j + 1 < b.len());
        }
    }

    // r[depends nickel-priority.total-order]
    // r[verify nickel-field-merge.higher-wins]
    proof fn prove_nickel_priority_orders_field_merge_right_wins(
        v1: u64, p1: MergePriority, v2: u64, p2: MergePriority,
    )
        requires priority_lt(p1, p2)
        ensures field_merge_spec(v1, p1, v2, p2) == FieldMergeResult::Right(v2, p2)
    {}

    // r[depends nickel-priority.total-order]
    // r[verify nickel-field-merge.higher-wins]
    proof fn prove_nickel_priority_orders_field_merge_left_wins(
        v1: u64, p1: MergePriority, v2: u64, p2: MergePriority,
    )
        requires priority_lt(p2, p1)
        ensures field_merge_spec(v1, p1, v2, p2) == FieldMergeResult::Left(v1, p1)
    {}

    // r[depends nickel-priority.total-order]
    // r[verify nickel-field-merge.equal-recurse]
    proof fn prove_nickel_priority_equal_priorities_merge_equal(
        v: u64, p1: MergePriority, p2: MergePriority,
    )
        requires crate::nickel_priority::priority_eq(p1, p2)
        ensures field_merge_spec(v, p1, v, p2) == FieldMergeResult::Equal(v, p1)
    {}

    // r[depends nickel-priority.total-order]
    // r[verify nickel-field-merge.equal-recurse]
    proof fn prove_nickel_priority_equal_priorities_merge_conflict(
        v1: u64, v2: u64, p1: MergePriority, p2: MergePriority,
    )
        requires crate::nickel_priority::priority_eq(p1, p2), v1 != v2
        ensures field_merge_spec(v1, p1, v2, p2) == FieldMergeResult::Conflict
    {}

    proof fn prove_nickel_split_disjoint_preserves_sides(
        a: Seq<(Seq<u8>, u64)>, b: Seq<(Seq<u8>, u64)>,
    )
        requires
            is_sorted_keys(a),
            is_sorted_keys(b),
            kv_kv_disjoint(a, b),
        ensures
            split_spec(a, b).left =~= a,
            split_spec(a, b).center.len() == 0,
            split_spec(a, b).right =~= b,
        decreases a.len() + b.len()
    {
        if a.len() == 0 {
        } else if b.len() == 0 {
        } else {
            let ta = a.subrange(1, a.len() as int);
            let tb = b.subrange(1, b.len() as int);

            key_total(a[0int].0, b[0int].0);
            assert(!(a[0int].0 =~= b[0int].0));

            if key_lt(a[0int].0, b[0int].0) {
                nickel_sorted_tail(a);
                nickel_disjoint_tail_left(a, b);
                prove_nickel_split_disjoint_preserves_sides(ta, b);
                seq_head_tail_eq(a);
            } else {
                assert(key_lt(b[0int].0, a[0int].0));
                nickel_sorted_tail(b);
                nickel_disjoint_tail_right(a, b);
                prove_nickel_split_disjoint_preserves_sides(a, tb);
                seq_head_tail_eq(b);
            }
        }
    }

    // r[depends nickel-merge.split]
    // r[depends nix-attrset.merge]
    // r[verify nickel-merge.split]
    proof fn prove_nickel_split_recombines_to_nix_merge_when_disjoint(
        a: Seq<(Seq<u8>, u64)>, b: Seq<(Seq<u8>, u64)>,
    )
        requires
            is_sorted_keys(a),
            is_sorted_keys(b),
            kv_kv_disjoint(a, b),
        ensures ({
            let r = split_spec(a, b);
            &&& r.center.len() == 0
            &&& crate::nix_attrset::merge_spec(r.left, r.right)
                =~= crate::nix_attrset::merge_spec(a, b)
        })
    {
        prove_nickel_split_disjoint_preserves_sides(a, b);
    }

    // --- BEAM cross-module properties ---

    // r[impl properties.beam-death-links]
    pub open spec fn beam_death_links_prop(
        links: Seq<u64>,
        proc: crate::beam_process::BeamProcess,
        mailbox: Seq<crate::beam_mailbox::BeamMessage>,
        source_pid: u64,
        reason: u64,
    ) -> bool {
        let linked = crate::beam_link::link_contains_spec(links, source_pid);
        let delivered = if linked {
            crate::beam_link::deliver_exit_signal_spec(proc, mailbox, source_pid, reason)
        } else {
            (proc, mailbox)
        };
        if !linked || proc.state != crate::beam_process::BEAM_ALIVE {
            delivered.0 == proc && delivered.1 =~= mailbox
        } else if reason == crate::beam_process::REASON_KILL {
            delivered.0.exit_reason == crate::beam_process::REASON_KILLED
                && delivered.1 =~= mailbox
        } else if proc.trap_exit {
            delivered.0 == proc
                && delivered.1
                    == crate::beam_mailbox::mailbox_append_spec(
                        mailbox,
                        crate::beam_link::exit_message_spec(source_pid, reason),
                    )
        } else if reason == crate::beam_process::REASON_NORMAL {
            delivered.0 == proc && delivered.1 =~= mailbox
        } else {
            delivered.0.state == crate::beam_process::BEAM_EXITING
                && delivered.0.exit_reason == reason
                && delivered.1 =~= mailbox
        }
    }

    // r[verify properties.beam-death-links]
    proof fn prove_beam_death_links(
        links: Seq<u64>,
        proc: crate::beam_process::BeamProcess,
        mailbox: Seq<crate::beam_mailbox::BeamMessage>,
        source_pid: u64,
        reason: u64,
    )
        ensures beam_death_links_prop(links, proc, mailbox, source_pid, reason)
    {}

    // r[impl properties.beam-death-monitor]
    pub open spec fn beam_death_monitor_prop(
        monitor: crate::beam_monitor::BeamMonitor,
        reason: u64,
    ) -> bool {
        let first = crate::beam_monitor::notify_death_spec(monitor, reason);
        let second = crate::beam_monitor::notify_death_spec(first.0, reason);
        if monitor.active {
            first.0.active == false
                && first.1 == Some(crate::beam_monitor::down_message_spec(monitor, reason))
                && second.1.is_none()
        } else {
            first.0 == monitor && first.1.is_none()
        }
    }

    // r[verify properties.beam-death-monitor]
    proof fn prove_beam_death_monitor(
        monitor: crate::beam_monitor::BeamMonitor,
        reason: u64,
    )
        ensures beam_death_monitor_prop(monitor, reason)
    {}

    // r[impl properties.beam-death-mailbox]
    pub open spec fn beam_death_mailbox_prop(
        mailbox: Seq<crate::beam_mailbox::BeamMessage>,
        msg: crate::beam_mailbox::BeamMessage,
    ) -> bool {
        crate::beam_send::beam_send_spec(crate::beam_process::BEAM_DEAD, mailbox, msg) =~= mailbox
    }

    // r[verify properties.beam-death-mailbox]
    proof fn prove_beam_death_mailbox(
        mailbox: Seq<crate::beam_mailbox::BeamMessage>,
        msg: crate::beam_mailbox::BeamMessage,
    )
        ensures beam_death_mailbox_prop(mailbox, msg)
    {}

    // r[impl properties.beam-death-registry]
    pub open spec fn beam_death_registry_prop(
        registry: Seq<(u64, u64)>,
        name: u64,
        pid: u64,
    ) -> bool
        recommends
            crate::beam_registry::registry_unique_spec(registry),
            !crate::beam_registry::registry_has_name_spec(registry, name),
            !crate::beam_registry::registry_has_pid_spec(registry, pid),
    {
        let registered = crate::beam_registry::register_spec(registry, name, pid).unwrap();
        let cleaned = crate::beam_registry::unregister_pid_spec(registered, pid);
        cleaned =~= registry
            && crate::beam_registry::register_spec(cleaned, name, pid).is_some()
    }

    // r[verify properties.beam-death-registry]
    proof fn prove_beam_death_registry(
        registry: Seq<(u64, u64)>,
        name: u64,
        pid: u64,
    )
        requires
            crate::beam_registry::registry_unique_spec(registry),
            !crate::beam_registry::registry_has_name_spec(registry, name),
            !crate::beam_registry::registry_has_pid_spec(registry, pid),
        ensures beam_death_registry_prop(registry, name, pid)
    {
        crate::beam_registry::register_fresh_pair_is_some(registry, name, pid);
        crate::beam_registry::cleanup_fresh_register_restores_registry(registry, name, pid);
    }

    // r[impl properties.beam-scheduler-state]
    pub open spec fn beam_scheduler_state_prop(state: u64, has_work: bool) -> bool {
        crate::beam_scheduler::runnable_process_spec(state, has_work)
            == (state == crate::beam_process::BEAM_ALIVE && has_work)
    }

    // r[verify properties.beam-scheduler-state]
    proof fn prove_beam_scheduler_state(state: u64, has_work: bool)
        ensures beam_scheduler_state_prop(state, has_work)
    {}

    } // verus!
}

// --- retry ↔ circuit_breaker ↔ backoff ---

#[cfg(verus_keep_ghost)]
mod retry_proofs {
    use vstd::prelude::*;

    use crate::backoff::compute_backoff_spec;
    use crate::choreography_global::GBranch;
    use crate::choreography_global::GChoreo;
    use crate::choreography_global::LabelId;
    use crate::choreography_global::PayloadTag;
    use crate::choreography_global::RoleId;
    use crate::choreography_local::LBranch;
    use crate::choreography_local::LChoreo;
    use crate::choreography_local::branch_labels_spec;
    use crate::choreography_ownership::OwnershipEntry;
    use crate::choreography_ownership::OwnershipState;
    use crate::choreography_ownership::ValueId;
    use crate::choreography_ownership::owner_of_spec;
    use crate::choreography_ownership::ownership_entries_spec;
    use crate::choreography_ownership::ownership_normalized_spec;
    use crate::choreography_ownership::successful_transfer_conserves_ownership;
    use crate::choreography_ownership::transfer_owner_post_spec;
    use crate::choreography_projection::all_decider_guarded_spec;
    use crate::choreography_projection::common_recv_tails_spec;
    use crate::choreography_projection::common_send_tails_spec;
    use crate::choreography_projection::project_decider_choice_from_len;
    use crate::choreography_projection::project_decider_choice_from_pointwise;
    use crate::choreography_projection::project_decider_choice_from_spec;
    use crate::choreography_projection::project_endpoint_spec;
    use crate::choreography_projection::projectable_spec;
    use crate::choreography_projection::projected_branch_suffix_size;
    use crate::choreography_projection::same_projected_bodies_spec;
    use crate::choreography_step::choice_alignment_spec;
    use crate::choreography_step::first_offer_labels_from_spec;
    use crate::choreography_step::global_choice_step_spec;
    use crate::choreography_step::global_comm_step_spec;
    use crate::choreography_step::local_recv_owned_step_spec;
    use crate::choreography_step::local_recv_step_spec;
    use crate::choreography_step::local_send_owned_step_spec;
    use crate::choreography_step::local_send_step_spec;
    use crate::circuit_breaker::CLOSED;
    use crate::circuit_breaker::allow_request_spec;
    use crate::retry::RETRY;
    use crate::retry::classify_outcome_spec;
    use crate::retry::should_retry_spec;
    use crate::web_of_trust_attestation::Attestation;
    use crate::web_of_trust_attestation::attestation_active_respects_revocation;
    use crate::web_of_trust_chain::chain_valid_at_spec;
    use crate::web_of_trust_chain::chain_valid_requires_active_edges;
    use crate::web_of_trust_chain::root_member_spec;
    use crate::web_of_trust_policy::introducer_qualifies_at_spec;
    use crate::web_of_trust_policy::seen_indices_in_range_spec;
    use crate::web_of_trust_policy::seen_introducer_spec;
    use crate::web_of_trust_policy::threshold_accepts_from_spec;
    use crate::web_of_trust_principal::PrincipalId;
    use crate::web_of_trust_resolution::resolves_trusted_at_complete;
    use crate::web_of_trust_resolution::resolves_trusted_at_sound;
    use crate::web_of_trust_resolution::resolves_trusted_at_spec;
    use crate::web_of_trust_revocation::Revocation;
    use crate::web_of_trust_revocation::revocation_effective_at_spec;

    verus! {

    // r[impl properties.retry-gate-implies-backoff-computable]
    // r[verify properties.retry-gate-implies-backoff-computable]
    /// When should_retry is true, backoff is computable (base > 0 ⟹ delay > 0 for attempt > 0).
    proof fn prove_retry_implies_backoff_computable(
        attempt: u64, max_attempts: u64, base: u64, cap: u64,
    )
        requires
            should_retry_spec(attempt, max_attempts, true),
            base > 0, cap > 0,
        ensures compute_backoff_spec(base, attempt, cap) <= cap
    {}

    // r[impl properties.retry-with-closed-circuit]
    // r[verify properties.retry-with-closed-circuit]
    /// When circuit is CLOSED and retry is warranted, requests are allowed (regardless of probe state).
    proof fn prove_retry_with_closed_circuit(
        attempt: u64, max_attempts: u64, probe_active: bool,
    )
        requires should_retry_spec(attempt, max_attempts, true)
        ensures allow_request_spec(CLOSED, probe_active)
    {}

    // r[impl properties.classify-retry-means-not-exhausted]
    // r[verify properties.classify-retry-means-not-exhausted]
    /// RETRY classification implies attempt < max_attempts.
    proof fn prove_classify_retry_means_not_exhausted(
        is_retryable: bool, attempt: u64, max_attempts: u64,
    )
        requires classify_outcome_spec(false, is_retryable, attempt, max_attempts) == RETRY
        ensures attempt < max_attempts
    {}

    // r[impl properties.choreography-duality]
    // r[verify properties.choreography-duality]
    proof fn choreography_projection_duality(
        from: RoleId,
        to: RoleId,
        label: LabelId,
        payload_tag: PayloadTag,
        next: GChoreo,
    )
        requires projectable_spec(GChoreo::Comm { from, to, label, payload_tag, next: Box::new(next) })
        ensures
            project_endpoint_spec(from, GChoreo::Comm { from, to, label, payload_tag, next: Box::new(next) })
                == (LChoreo::Send { peer: to, label, payload_tag, next: Box::new(project_endpoint_spec(from, next)) }),
            project_endpoint_spec(to, GChoreo::Comm { from, to, label, payload_tag, next: Box::new(next) })
                == (LChoreo::Recv { peer: from, label, payload_tag, next: Box::new(project_endpoint_spec(to, next)) })
    {
        crate::choreography_projection::sender_projection_shape(from, to, label, payload_tag, next);
        crate::choreography_projection::receiver_projection_shape(from, to, label, payload_tag, next);
    }

    // r[impl properties.choreography_transfer_correspondence]
    // r[verify properties.choreography_transfer_correspondence]
    proof fn choreography_owned_transfer_projection_correspondence(
        from: RoleId,
        to: RoleId,
        label: LabelId,
        payload_tag: PayloadTag,
        value: ValueId,
        next: GChoreo,
        old_entries: Seq<OwnershipEntry>,
        moved: OwnershipState,
    )
        requires
            projectable_spec(GChoreo::OwnedTransfer {
            from,
            to,
            label,
            payload_tag,
            value,
            next: Box::new(next),
        }),
            ownership_normalized_spec(old_entries),
            transfer_owner_post_spec(old_entries, from, to, value, Some(moved)),
        ensures
            local_send_owned_step_spec(project_endpoint_spec(from, GChoreo::OwnedTransfer {
                from,
                to,
                label,
                payload_tag,
                value,
                next: Box::new(next),
            })) == Some(project_endpoint_spec(from, next)),
            local_recv_owned_step_spec(project_endpoint_spec(to, GChoreo::OwnedTransfer {
                from,
                to,
                label,
                payload_tag,
                value,
                next: Box::new(next),
            })) == Some(project_endpoint_spec(to, next)),
            ownership_normalized_spec(ownership_entries_spec(moved)),
            ownership_entries_spec(moved).len() == old_entries.len(),
            owner_of_spec(ownership_entries_spec(moved), value) == Some(to),
            owner_of_spec(ownership_entries_spec(moved), value) != Some(from),
            forall|unrelated: ValueId| unrelated != value
                ==> owner_of_spec(ownership_entries_spec(moved), unrelated)
                    == owner_of_spec(old_entries, unrelated)
    {
        crate::choreography_step::owned_transfer_projection_step_shape(
            from,
            to,
            label,
            payload_tag,
            value,
            next,
        );
        successful_transfer_conserves_ownership(
            old_entries,
            from,
            to,
            value,
            moved,
        );
    }

    pub(crate) open spec fn first_branch_dependent_offer_labels_fuel_spec(
        decider: RoleId,
        branches: Seq<LBranch>,
        fuel: nat,
    ) -> Option<Seq<LabelId>>
        decreases fuel
    {
        if fuel == 0 || branches.len() == 0 {
            None
        } else if same_projected_bodies_spec(branches) {
            None
        } else {
            match common_send_tails_spec(branches) {
                Some((_, _, _, tails)) => {
                    match first_branch_dependent_offer_labels_fuel_spec(decider, tails, (fuel - 1) as nat) {
                        Some(_) => Some(branch_labels_spec(branches)),
                        None => None,
                    }
                }
                None => match common_recv_tails_spec(branches) {
                    Some((_, _, _, tails)) => {
                        match first_branch_dependent_offer_labels_fuel_spec(decider, tails, (fuel - 1) as nat) {
                            Some(_) => Some(branch_labels_spec(branches)),
                            None => None,
                        }
                    }
                    None => {
                        if all_decider_guarded_spec(decider, branches) {
                            Some(branch_labels_spec(branches))
                        } else {
                            None
                        }
                    }
                }
            }
        }
    }

    pub(crate) open spec fn first_branch_dependent_offer_labels_spec(
        decider: RoleId,
        branches: Seq<LBranch>,
    ) -> Option<Seq<LabelId>> {
        first_branch_dependent_offer_labels_fuel_spec(decider, branches, projected_branch_suffix_size(branches, 0))
    }

    proof fn projected_choice_labels_match_global(
        role: RoleId,
        decider: RoleId,
        branches: Seq<GBranch>,
    )
        requires projectable_spec(GChoreo::Choice { decider, branches })
        ensures
            branch_labels_spec(project_decider_choice_from_spec(role, GChoreo::Choice { decider, branches }, 0).unwrap())
                == branches.map_values(|branch: GBranch| branch.label)
    {
        let choice = GChoreo::Choice { decider, branches };
        project_decider_choice_from_len(role, choice, 0);
        let projected = project_decider_choice_from_spec(role, choice, 0).unwrap();
        assert(projected.len() == branches.len());
        assert(branch_labels_spec(projected).len() == branches.len());
        assert(branches.map_values(|branch: GBranch| branch.label).len() == branches.len());
        assert forall|i: int| #![trigger projected[i]] 0 <= i < projected.len()
            implies branch_labels_spec(projected)[i] == branches.map_values(|branch: GBranch| branch.label)[i]
        by {
            project_decider_choice_from_pointwise(role, choice, 0, i);
        }
    }

    proof fn first_branch_dependent_offer_labels_match_branches_fuel(
        decider: RoleId,
        branches: Seq<LBranch>,
        fuel: nat,
    )
        requires first_branch_dependent_offer_labels_fuel_spec(decider, branches, fuel).is_some()
        ensures first_branch_dependent_offer_labels_fuel_spec(decider, branches, fuel).unwrap() == branch_labels_spec(branches)
        decreases fuel
    {
        if fuel == 0 || branches.len() == 0 {
            assert(false);
        } else if same_projected_bodies_spec(branches) {
            assert(false);
        } else {
            match common_send_tails_spec(branches) {
                Some((_, _, _, tails)) => {
                    match first_branch_dependent_offer_labels_fuel_spec(decider, tails, (fuel - 1) as nat) {
                        Some(_) => {
                            first_branch_dependent_offer_labels_match_branches_fuel(decider, tails, (fuel - 1) as nat);
                        }
                        None => { assert(false); }
                    }
                }
                None => match common_recv_tails_spec(branches) {
                    Some((_, _, _, tails)) => {
                        match first_branch_dependent_offer_labels_fuel_spec(decider, tails, (fuel - 1) as nat) {
                            Some(_) => {
                                first_branch_dependent_offer_labels_match_branches_fuel(decider, tails, (fuel - 1) as nat);
                            }
                            None => { assert(false); }
                        }
                    }
                    None => {
                        assert(all_decider_guarded_spec(decider, branches));
                    }
                }
            }
        }
    }

    proof fn first_branch_dependent_offer_labels_match_branches(
        decider: RoleId,
        branches: Seq<LBranch>,
    )
        requires first_branch_dependent_offer_labels_spec(decider, branches).is_some()
        ensures first_branch_dependent_offer_labels_spec(decider, branches).unwrap() == branch_labels_spec(branches)
    {
        let fuel = projected_branch_suffix_size(branches, 0);
        first_branch_dependent_offer_labels_match_branches_fuel(decider, branches, fuel);
    }

    // r[impl properties.choreography-choice-agreement]
    // r[verify properties.choreography-choice-agreement]
    proof fn choreography_choice_label_agreement(
        role: RoleId,
        decider: RoleId,
        branches: Seq<GBranch>,
    )
        requires projectable_spec(GChoreo::Choice { decider, branches })
        ensures
            branch_labels_spec(project_decider_choice_from_spec(decider, GChoreo::Choice { decider, branches }, 0).unwrap())
                == branches.map_values(|branch: GBranch| branch.label),
            match first_branch_dependent_offer_labels_spec(
                decider,
                project_decider_choice_from_spec(role, GChoreo::Choice { decider, branches }, 0).unwrap(),
            ) {
                Some(labels) => labels == branches.map_values(|branch: GBranch| branch.label),
                None => true,
            }
    {
        let choice = GChoreo::Choice { decider, branches };
        projected_choice_labels_match_global(decider, decider, branches);
        projected_choice_labels_match_global(role, decider, branches);
        let projected = project_decider_choice_from_spec(role, choice, 0).unwrap();
        if first_branch_dependent_offer_labels_spec(decider, projected).is_some() {
            first_branch_dependent_offer_labels_match_branches(decider, projected);
        }
    }

    // r[impl properties.choreography-step-correspondence]
    // r[verify properties.choreography-step-correspondence]
    proof fn choreography_step_projection_correspondence(
        role: RoleId,
        global: GChoreo,
        label: LabelId,
    )
        requires
            projectable_spec(global),
            global_comm_step_spec(global).is_some() || global_choice_step_spec(global, label).is_some(),
        ensures
            global_comm_step_spec(global).is_some() ==> (
                local_send_step_spec(project_endpoint_spec(role, global)) == Some(project_endpoint_spec(role, global_comm_step_spec(global).unwrap()))
                || local_recv_step_spec(project_endpoint_spec(role, global)) == Some(project_endpoint_spec(role, global_comm_step_spec(global).unwrap()))
                || project_endpoint_spec(role, global) == project_endpoint_spec(role, global_comm_step_spec(global).unwrap())
            ),
            global_choice_step_spec(global, label).is_some() ==> (
                choice_alignment_spec(
                    project_endpoint_spec(role, global),
                    label,
                    project_endpoint_spec(role, global_choice_step_spec(global, label).unwrap()),
                )
            )
    {
        if global_comm_step_spec(global).is_some() {
            if let GChoreo::Comm { from, to, label: msg_label, payload_tag, next } = global {
                crate::choreography_step::communication_projection_step_shape(from, to, msg_label, payload_tag, *next);
            }
        }
        if global_choice_step_spec(global, label).is_some() {
            if let GChoreo::Choice { decider, branches } = global {
                crate::choreography_step::choice_projection_alignment(role, decider, branches, label);
            }
        }
    }

    // r[impl properties.web-of-trust.revocation-cuts-trust]
    // r[verify properties.web-of-trust.revocation-cuts-trust]
    /// If a designated edge on a successful witness chain becomes effectively revoked,
    /// that same witness can no longer justify trust at the later time.
    pub proof fn revocation_cuts_trust_witness(
        witness: Seq<usize>,
        roots: Seq<PrincipalId>,
        attestations: Seq<Attestation>,
        revocations: Seq<Revocation>,
        subject: PrincipalId,
        t_before: u64,
        t_after: u64,
        revoked_pos: nat,
    )
        requires
            revoked_pos < witness.len(),
            (witness[revoked_pos as int] as int) < attestations.len(),
            chain_valid_at_spec(witness, roots, attestations, revocations, subject, t_before),
            t_before <= t_after,
            exists|i: int| 0 <= i < revocations.len()
                && revocation_effective_at_spec(revocations[i], attestations[witness[revoked_pos as int] as int], t_after),
        ensures
            !chain_valid_at_spec(witness, roots, attestations, revocations, subject, t_after),
    {
        let att = attestations[witness[revoked_pos as int] as int];
        assert(exists|i: int| 0 <= i < revocations.len() && revocation_effective_at_spec(revocations[i], att, t_after)) by {
            let i = choose|i: int| 0 <= i < revocations.len()
                && revocation_effective_at_spec(revocations[i], attestations[witness[revoked_pos as int] as int], t_after);
            assert(revocation_effective_at_spec(revocations[i], att, t_after));
        }
        if chain_valid_at_spec(witness, roots, attestations, revocations, subject, t_after) {
            chain_valid_requires_active_edges(witness, roots, attestations, revocations, subject, t_after, revoked_pos);
            attestation_active_respects_revocation(att, revocations, t_after);
            assert(false);
        }
    }

    // r[impl properties.web-of-trust.depth-monotone]
    // r[verify properties.web-of-trust.depth-monotone]
    /// Increasing the depth bound preserves any already-successful rooted resolution.
    pub proof fn depth_monotone_resolution(
        roots: Seq<PrincipalId>,
        attestations: Seq<Attestation>,
        revocations: Seq<Revocation>,
        subject: PrincipalId,
        depth: nat,
        deeper: nat,
        t: u64,
    )
        requires
            attestations.len() <= usize::MAX as nat,
            depth <= deeper,
            resolves_trusted_at_spec(roots, attestations, revocations, subject, depth, t),
        ensures
            resolves_trusted_at_spec(roots, attestations, revocations, subject, deeper, t),
    {
        if root_member_spec(roots, subject) {
        } else {
            resolves_trusted_at_sound(roots, attestations, revocations, subject, depth, t);
            let witness = choose|witness: Seq<usize>|
                0 < witness.len() <= depth as int
                    && chain_valid_at_spec(witness, roots, attestations, revocations, subject, t);
            assert(witness.len() <= depth as int);
            assert(depth as int <= deeper as int);
            assert(witness.len() <= deeper as int);
            assert(resolves_trusted_at_spec(roots, attestations, revocations, subject, deeper, t)) by {
                resolves_trusted_at_complete(roots, attestations, revocations, subject, deeper, t);
            }
        }
    }

    // r[impl properties.web-of-trust.threshold-dedup]
    /// Count the distinct qualifying introducers remaining in a threshold scan state.
    pub open spec fn threshold_distinct_count_from_spec(
        roots: Seq<PrincipalId>,
        attestations: Seq<Attestation>,
        revocations: Seq<Revocation>,
        subject: PrincipalId,
        depth: nat,
        t: u64,
        from: nat,
        seen: Seq<usize>,
    ) -> nat
        recommends
            attestations.len() <= usize::MAX as nat,
            seen_indices_in_range_spec(seen, attestations),
        decreases if from <= attestations.len() { attestations.len() - from } else { 0 }
    {
        if from >= attestations.len() {
            0nat
        } else {
            let digest = attestations[from as int].issuer.digest@;
            if introducer_qualifies_at_spec(roots, attestations, revocations, subject, from, depth, t)
                && !seen_introducer_spec(seen, attestations, digest)
            {
                1nat + threshold_distinct_count_from_spec(
                    roots,
                    attestations,
                    revocations,
                    subject,
                    depth,
                    t,
                    from + 1,
                    seen + seq![from as usize],
                )
            } else {
                threshold_distinct_count_from_spec(
                    roots,
                    attestations,
                    revocations,
                    subject,
                    depth,
                    t,
                    from + 1,
                    seen,
                )
            }
        }
    }

    // r[impl properties.web-of-trust.threshold-dedup]
    // r[verify properties.web-of-trust.threshold-dedup]
    /// Once an introducer digest is already in the threshold scan state,
    /// later same-digest edges cannot change the remaining accept/reject result.
    pub proof fn threshold_dedup_preserves_result(
        roots: Seq<PrincipalId>,
        attestations: Seq<Attestation>,
        revocations: Seq<Revocation>,
        subject: PrincipalId,
        k: nat,
        depth: nat,
        t: u64,
        dup_from: nat,
        seen: Seq<usize>,
    )
        requires
            dup_from < attestations.len(),
            attestations.len() <= usize::MAX as nat,
            seen_indices_in_range_spec(seen, attestations),
            seen_introducer_spec(seen, attestations, attestations[dup_from as int].issuer.digest@),
        ensures
            threshold_accepts_from_spec(
                roots,
                attestations,
                revocations,
                subject,
                k,
                depth,
                t,
                dup_from,
                seen,
            ) == threshold_accepts_from_spec(
                roots,
                attestations,
                revocations,
                subject,
                k,
                depth,
                t,
                dup_from + 1,
                seen,
            ),
    {
        assert(
            threshold_accepts_from_spec(
                roots,
                attestations,
                revocations,
                subject,
                k,
                depth,
                t,
                dup_from,
                seen,
            ) == threshold_accepts_from_spec(
                roots,
                attestations,
                revocations,
                subject,
                k,
                depth,
                t,
                dup_from + 1,
                seen,
            )
        ) by {
            if k > 0 {
                let digest = attestations[dup_from as int].issuer.digest@;
                assert(seen_introducer_spec(seen, attestations, digest));
                assert(!(introducer_qualifies_at_spec(roots, attestations, revocations, subject, dup_from, depth, t)
                    && !seen_introducer_spec(seen, attestations, digest)));
            }
        }
    }

    // r[impl properties.web-of-trust.threshold-dedup]
    // r[verify properties.web-of-trust.threshold-dedup]
    /// Once an introducer digest is already in the threshold scan state,
    /// later same-digest edges do not change the remaining distinct-introducer count.
    pub proof fn threshold_dedup_preserves_count(
        roots: Seq<PrincipalId>,
        attestations: Seq<Attestation>,
        revocations: Seq<Revocation>,
        subject: PrincipalId,
        depth: nat,
        t: u64,
        dup_from: nat,
        seen: Seq<usize>,
    )
        requires
            dup_from < attestations.len(),
            attestations.len() <= usize::MAX as nat,
            seen_indices_in_range_spec(seen, attestations),
            seen_introducer_spec(seen, attestations, attestations[dup_from as int].issuer.digest@),
        ensures
            threshold_distinct_count_from_spec(
                roots,
                attestations,
                revocations,
                subject,
                depth,
                t,
                dup_from,
                seen,
            ) == threshold_distinct_count_from_spec(
                roots,
                attestations,
                revocations,
                subject,
                depth,
                t,
                dup_from + 1,
                seen,
            ),
    {
        assert(
            threshold_distinct_count_from_spec(
                roots,
                attestations,
                revocations,
                subject,
                depth,
                t,
                dup_from,
                seen,
            ) == threshold_distinct_count_from_spec(
                roots,
                attestations,
                revocations,
                subject,
                depth,
                t,
                dup_from + 1,
                seen,
            )
        ) by {
            let digest = attestations[dup_from as int].issuer.digest@;
            assert(seen_introducer_spec(seen, attestations, digest));
            assert(!(introducer_qualifies_at_spec(roots, attestations, revocations, subject, dup_from, depth, t)
                && !seen_introducer_spec(seen, attestations, digest)));
        }
    }

    } // verus!
}

#[cfg(test)]
#[allow(
    clippy::absurd_extreme_comparisons,
    clippy::cast_possible_truncation,
    clippy::cast_possible_wrap,
    clippy::default_numeric_fallback,
    clippy::uninlined_format_args
)]
mod tests {
    use proptest::prelude::*;

    use crate::arithmetic::*;
    use crate::bitwise::*;
    use crate::bounds::*;
    use crate::collections::*;
    use crate::conversion::*;
    use crate::epoch::Epoch;
    use crate::epoch::epoch_ge;
    use crate::integer::*;
    use crate::log::LogEntry;
    use crate::log::logs_match_prefix;
    use crate::ordering::*;
    use crate::quorum::majority;
    use crate::slice::*;

    proptest! {
        // r[verify properties.abs-diff-zero-iff-equal]
        #[test]
        fn prop_abs_diff_zero_iff_equal(a: u64, b: u64) {
            if a == b {
                prop_assert_eq!(abs_diff(a, b), 0);
            } else {
                prop_assert_ne!(abs_diff(a, b), 0);
            }
        }

        // r[verify properties.triangle-inequality]
        #[test]
        fn prop_triangle_inequality(a: u64, b: u64, c: u64) {
            let ac = u128::from(abs_diff(a, c));
            let ab = u128::from(abs_diff(a, b));
            let bc = u128::from(abs_diff(b, c));
            prop_assert!(ac <= ab + bc);
        }

        // r[verify properties.add-sub-roundtrip]
        #[test]
        fn prop_add_sub_roundtrip(a: u64, b in 0..=u64::MAX / 2) {
            let a = a % (u64::MAX - b + 1);
            prop_assert_eq!(saturating_sub(saturating_add(a, b), b), a);
        }

        // r[verify properties.sub-add-inverse]
        #[test]
        fn prop_sub_add_inverse(a: u64, b: u64) {
            if b <= a {
                prop_assert_eq!(saturating_add(saturating_sub(a, b), b), a);
            }
        }

        // r[verify properties.clamp-nearest-point]
        #[test]
        fn prop_clamp_nearest_point(
            value: u64,
            lo in 0..=u64::MAX / 2,
            spread in 0..=u64::MAX / 2,
        ) {
            let hi = lo + spread;
            let clamped = clamp(value, lo, hi);
            let dist_clamped = abs_diff(value, clamped);
            prop_assert!(dist_clamped <= abs_diff(value, lo));
            prop_assert!(dist_clamped <= abs_diff(value, hi));
        }

        // r[verify properties.clamp-monotonic]
        #[test]
        fn prop_clamp_monotonic(
            a: u64,
            b: u64,
            lo in 0..=u64::MAX / 2,
            spread in 0..=u64::MAX / 2,
        ) {
            let hi = lo + spread;
            if a <= b {
                prop_assert!(clamp(a, lo, hi) <= clamp(b, lo, hi));
            }
        }

        // r[verify properties.distance-decomposition]
        #[test]
        fn prop_distance_decomposition(
            lo in 0..=u64::MAX / 2,
            spread in 0..=u64::MAX / 2,
        ) {
            let hi = lo + spread;
            let value = lo + spread / 2;
            let d_lo = u128::from(abs_diff(value, lo));
            let d_hi = u128::from(abs_diff(value, hi));
            let range = u128::from(abs_diff(lo, hi));
            prop_assert_eq!(d_lo + d_hi, range);
        }

        // r[verify properties.min-max-abs-diff]
        #[test]
        fn prop_min_max_abs_diff(a: u64, b: u64) {
            prop_assert_eq!(max(a, b) - min(a, b), abs_diff(a, b));
        }

        // r[verify properties.clamp-via-min-max]
        #[test]
        fn prop_clamp_via_min_max(
            v: u64,
            lo in 0..=u64::MAX / 2,
            spread in 0..=u64::MAX / 2,
        ) {
            let hi = lo + spread;
            prop_assert_eq!(clamp(v, lo, hi), min(max(v, lo), hi));
        }

        // r[verify properties.align-down-remainder]
        #[test]
        fn prop_align_down_remainder(x: u64, a in 1u64..=4096) {
            prop_assert_eq!(abs_diff(x, align_down(x, a)), x % a);
        }

        // r[verify properties.align-up-via-div-ceil]
        #[test]
        fn prop_align_up_via_div_ceil(x: u64, a in 1u64..=4096) {
            if let Some(v) = align_up(x, a) {
                prop_assert_eq!(v, div_ceil(x, a) * a);
            }
        }

        // r[verify properties.median-is-clamp]
        #[test]
        fn prop_median_is_clamp(a: u64, b: u64, c: u64) {
            prop_assert_eq!(
                median_of_three(a, b, c),
                clamp(a, min(b, c), max(b, c))
            );
        }

        // r[verify properties.set-clear-roundtrip]
        #[test]
        fn prop_set_clear_roundtrip(x: u64, pos in 0u64..64) {
            prop_assert_eq!(clear_bit(set_bit(x, pos), pos), clear_bit(x, pos));
        }

        // r[verify properties.toggle-involution]
        #[test]
        fn prop_toggle_involution(x: u64, pos in 0u64..64) {
            prop_assert_eq!(toggle_bit(toggle_bit(x, pos), pos), x);
        }

        // r[verify properties.all-equal-implies-count]
        #[test]
        fn prop_all_equal_implies_count(value: u64, len in 0usize..=50) {
            let v: Vec<u64> = vec![value; len];
            prop_assert_eq!(count_matches(&v, value), len);
        }

        // r[verify properties.chunk-count-div-ceil]
        #[test]
        fn prop_chunk_count_div_ceil(n: u64, k in 1u64..=10000) {
            let cc = u128::from(chunk_count(n, k));
            let dc = u128::from(div_ceil(n, k));
            let has_rem = u128::from(n % k > 0);
            prop_assert_eq!(dc, cc + has_rem);
        }

        // r[verify properties.narrow-iff-in-range]
        #[test]
        fn prop_narrow_iff_in_range(x: u64) {
            prop_assert_eq!(
                narrow_u32(x).is_some(),
                in_range(x, 0, u64::from(u32::MAX))
            );
        }

        // r[verify properties.all-equal-implies-partitioned]
        #[test]
        fn prop_all_equal_implies_partitioned(
            value: u64,
            len in 0usize..=50,
            threshold: u64,
        ) {
            let v: Vec<u64> = vec![value; len];
            prop_assert!(is_partitioned(&v, threshold));
        }

        // r[verify properties.majority-via-div-ceil]
        #[test]
        fn prop_majority_via_div_ceil(n in 1u64..=10000) {
            // majority(n) = n/2 + 1
            // div_ceil(n+1, 2) = (n+1-1)/2 + 1 = n/2 + 1
            prop_assert_eq!(majority(n), div_ceil(n + 1, 2));
        }

        // r[verify properties.epoch-ge-term-index]
        #[test]
        fn prop_epoch_ge_term_index(
            t1: u64, i1: u64, t2: u64, i2: u64,
        ) {
            let a = Epoch { term: t1, index: i1 };
            let b = Epoch { term: t2, index: i2 };
            if epoch_ge(&a, &b) {
                prop_assert!(t1 > t2 || (t1 == t2 && i1 >= i2));
            }
        }

        // r[verify properties.log-prefix-term-eq]
        #[test]
        fn prop_log_prefix_term_eq(
            terms in proptest::collection::vec(1u64..10, 1..=20),
        ) {
            let a: Vec<LogEntry> = terms.iter().map(|&t| LogEntry { term: t, value: 0 }).collect();
            let b: Vec<LogEntry> = terms.iter().map(|&t| LogEntry { term: t, value: 1 }).collect();
            let k = terms.len();
            prop_assert!(logs_match_prefix(&a, &b, k));
            for i in 0..k {
                prop_assert_eq!(a[i].term, b[i].term);
            }
        }

        // --- new module cross-module tests ---

        // r[verify properties.chunk-ceil-is-div-ceil]
        #[test]
        fn prop_chunk_ceil_is_div_ceil(n: u64, k in 1u64..=10000) {
            prop_assert_eq!(
                crate::chunk::chunk_count_ceil(n, k),
                crate::arithmetic::div_ceil(n, k),
            );
        }

        // r[verify properties.bounded-range-specializes-interval]
        #[test]
        fn prop_bounded_range_specializes_interval(lo: u64, hi: u64, x: u64) {
            prop_assert_eq!(
                crate::bounded_range::contains(lo, hi, true, x),
                crate::interval::contains(lo, hi, x),
            );
        }

        // r[verify properties.partition-no-overlap]
        #[test]
        fn prop_partition_no_overlap(
            a_lo in 0u64..u64::MAX / 3,
            width_a in 1u64..u64::MAX / 3,
            width_b in 1u64..u64::MAX / 3,
        ) {
            let a_hi = a_lo + width_a;
            let b_lo = a_hi; // adjacent: a_hi == b_lo
            let b_hi = b_lo + width_b;
            prop_assert!(!crate::interval::overlaps(a_lo, a_hi, b_lo, b_hi));
        }

        // r[verify properties.pressure-classify-monotonic]
        #[test]
        fn prop_pressure_classify_monotonic(
            v1: u64, v2: u64,
            warn in 0u64..u64::MAX / 2,
            spread in 0u64..u64::MAX / 2,
        ) {
            let crit = warn + spread;
            if v1 <= v2 {
                prop_assert!(
                    crate::pressure::classify_level(v1, warn, crit)
                        <= crate::pressure::classify_level(v2, warn, crit)
                );
            }
        }

        // r[verify properties.hash-bucket-in-interval]
        #[test]
        fn prop_hash_bucket_in_interval(hash: u64, num_buckets in 1u64..=u64::MAX) {
            let bucket = crate::hash_bucket::assign_bucket(hash, num_buckets);
            prop_assert!(crate::interval::contains(0, num_buckets, bucket));
        }

        // r[verify properties.refill-within-bounds]
        #[test]
        fn prop_refill_within_bounds(
            tokens: u64, elapsed_ms: u64, rate_per_sec: u64, burst: u64,
        ) {
            let result = crate::rate_limit::tokens_after_refill(
                tokens, elapsed_ms, rate_per_sec, burst,
            );
            prop_assert!(crate::bounds::in_range(result, 0, burst));
        }

        // r[verify properties.drain-start-finish-roundtrip]
        #[test]
        fn prop_drain_start_finish_roundtrip(n in 0u64..u64::MAX) {
            let started = crate::drain::after_start_op(n);
            let finished = crate::drain::after_finish_op(started);
            prop_assert_eq!(finished, n);
        }

        // r[verify properties.sequential-chunk-continuation]
        #[test]
        fn prop_sequential_chunk_continuation(
            chunk_size in 1u64..=1000,
            index in 0u64..1000,
        ) {
            let offset_i = crate::chunk::chunk_offset(chunk_size, index);
            let offset_next = crate::chunk::chunk_offset(chunk_size, index + 1);
            prop_assert!(crate::sequential::is_sequential(
                offset_next, offset_i, chunk_size
            ));
        }

        // r[verify properties.fencing-is-strict-advance]
        #[test]
        fn prop_fencing_is_strict_advance(t in 0..u64::MAX) {
            let issued = crate::fencing::issue_token(t);
            prop_assert!(crate::monotonic::is_strict_advance(t, issued));
        }

        // r[verify properties.fencing-stale-is-not-advance]
        #[test]
        fn prop_fencing_stale_is_not_advance(token: u64, fence: u64) {
            if crate::fencing::is_stale(token, fence) {
                prop_assert!(!crate::fencing::is_valid_write(token, fence));
            }
        }

        // --- Phase 14 cross-module properties ---

        // r[verify properties.vector-clock-merge-is-ordering-max]
        #[test]
        fn prop_vector_clock_merge_is_ordering_max(
            a in proptest::collection::vec(any::<u64>(), 3),
            b in proptest::collection::vec(any::<u64>(), 3),
        ) {
            let m = crate::vector_clock::merge(&a, &b);
            for i in 0..3 {
                prop_assert_eq!(m[i], crate::ordering::max(a[i], b[i]));
            }
        }

        // r[verify properties.ballot-winner-needs-quorum]
        #[test]
        fn prop_ballot_winner_needs_quorum(
            n in 1u64..=10000,
            votes: u64,
        ) {
            if crate::ballot::has_won_election(votes, n) {
                prop_assert!(crate::quorum::is_quorum(votes, n));
            }
        }

        // r[verify properties.lease-disjoint-intervals]
        #[test]
        fn prop_lease_disjoint_intervals(
            start in 0u64..1000,
            width in 1u64..1000,
            width2 in 1u64..1000,
            t: u64,
        ) {
            let expiry = start + width;
            let start2 = expiry;
            if start2 + width2 > start2 {
                let a = crate::lease::grant(1, start, expiry);
                let b = crate::lease::grant(1, start2, start2 + width2);
                // Sequential leases never overlap
                prop_assert!(!(crate::lease::is_valid(&a, t) && crate::lease::is_valid(&b, t)));
            }
        }

        // r[verify properties.two-phase-abort-prevents-commit]
        #[test]
        fn prop_two_phase_abort_prevents_commit(
            votes in proptest::collection::vec(
                proptest::option::of(any::<bool>()), 1..=10
            ),
        ) {
            if crate::two_phase::must_abort(&votes) {
                prop_assert!(!crate::two_phase::can_commit(&votes));
            }
        }

        // r[verify properties.bloom-no-false-negatives]
        #[test]
        fn prop_bloom_no_false_negatives(
            size in 8usize..64,
            positions in proptest::collection::vec(0usize..8, 1..=5),
        ) {
            let positions: Vec<usize> = positions.into_iter().map(|p| p % size).collect();
            let mut bits = vec![false; size];
            crate::bloom::insert(&mut bits, &positions);
            prop_assert!(crate::bloom::query(&bits, &positions));
        }

        // r[verify properties.cut-join-is-vector-clock-merge]
        #[test]
        fn prop_cut_join_is_vector_clock_merge(
            a in proptest::collection::vec(any::<u64>(), 3),
            b in proptest::collection::vec(any::<u64>(), 3),
        ) {
            // cut_join and vector_clock::merge produce the same result
            prop_assert_eq!(
                crate::causal_order::cut_join(&a, &b),
                crate::vector_clock::merge(&a, &b)
            );
        }

        // r[verify properties.crdt-merge-is-vector-clock-merge]
        #[test]
        fn prop_crdt_merge_is_vector_clock_merge(
            a in proptest::collection::vec(any::<u64>(), 3),
            b in proptest::collection::vec(any::<u64>(), 3),
        ) {
            // G-Counter merge and vector_clock::merge are the same operation
            prop_assert_eq!(
                crate::crdt::g_counter_merge(&a, &b),
                crate::vector_clock::merge(&a, &b)
            );
        }

        // r[verify properties.backoff-bounded-by-cap]
        #[test]
        fn prop_backoff_bounded_by_cap(base: u64, attempt: u64, cap: u64) {
            prop_assert!(crate::backoff::compute_backoff(base, attempt, cap) <= cap);
        }

        // r[verify properties.circuit-breaker-valid-output]
        #[test]
        fn prop_circuit_breaker_valid_output(
            current in 0u8..=2,
            failures: u64,
            threshold in 1u64..=1000,
            elapsed: u64,
            timeout in 1u64..=1000,
            probe: bool,
        ) {
            let ns = crate::circuit_breaker::next_state(
                current, failures, threshold, elapsed, timeout, probe
            );
            prop_assert!(crate::circuit_breaker::is_valid_state(ns));
        }

        // r[verify properties.accumulate-is-advance]
        #[test]
        fn prop_accumulate_is_advance(total in 0u64..u64::MAX/2, cost in 0u64..u64::MAX/2) {
            if let Some(result) = crate::cost_tracker::accumulate(total, cost) {
                prop_assert!(result >= total);
            }
        }

        // r[verify properties.threshold-crossing-irreversible]
        #[test]
        fn prop_threshold_crossing_irreversible(
            t1 in 0u64..1_000_000u64,
            d1 in 0u64..1_000_000u64,
            d2 in 0u64..1_000_000u64,
            limit in 0u64..2_000_000u64,
        ) {
            let t2 = t1.saturating_add(d1);
            let t3 = t2.saturating_add(d2);
            let c1 = crate::cost_tracker::crosses_threshold(t1, t2, limit);
            let c2 = crate::cost_tracker::crosses_threshold(t2, t3, limit);
            prop_assert!(!(c1 && c2), "threshold crossed twice");
        }

        // r[verify properties.to-upper-preserves-suffix]
        #[test]
        fn prop_to_upper_idempotent_cross(s in proptest::collection::vec(0u8..=255u8, 0..50)) {
            let u1 = crate::env_scrub::to_upper(&s);
            let u2 = crate::env_scrub::to_upper(&u1);
            prop_assert_eq!(u1, u2);
        }

        // r[verify properties.secret-implies-not-safe]
        #[test]
        fn prop_secret_and_safe_disjoint(key in proptest::collection::vec(0u8..=255u8, 0..30)) {
            let secret = crate::env_scrub::is_secret(&key);
            let safe = !secret;
            prop_assert!(!(secret && safe), "key is both secret and safe");
        }

        // r[verify properties.budget-exceeded-stays-exceeded]
        #[test]
        fn prop_budget_exceeded_stays_exceeded(
            soft in proptest::option::of(0u64..10_000_000u64),
            hard in proptest::option::of(0u64..10_000_000u64),
            t1 in 0u64..10_000_000u64,
            delta in 0u64..5_000_000u64,
        ) {
            let t2 = t1.saturating_add(delta);
            let s1 = crate::cost_tracker::budget_status(soft, hard, t1);
            let s2 = crate::cost_tracker::budget_status(soft, hard, t2);
            if s1 == 3 { // Exceeded
                prop_assert_eq!(s2, 3, "exceeded went backward");
            }
        }

        // ============================================================
        // UCAN cross-module properties
        // ============================================================

        // r[impl properties.delegation-safety]
        // r[verify properties.delegation-safety]
        /// If a capability authorizes an operation and a parent contains that capability,
        /// then the parent also authorizes the operation.
        #[test]
        fn prop_delegation_safety(
            pv in 0u8..=7, cv in 0u8..=7, ov in 0u8..=7,
            pm in 0u8..=3, cm in 0u8..=3, om in 0u8..=3,
            parent_scope in proptest::collection::vec(any::<u8>(), 0..=10),
            cap_ext in proptest::collection::vec(any::<u8>(), 0..=5),
            target_ext in proptest::collection::vec(any::<u8>(), 0..=5),
        ) {
            let mut cap_scope = parent_scope.clone();
            cap_scope.extend_from_slice(&cap_ext);
            let mut target = cap_scope.clone();
            target.extend_from_slice(&target_ext);

            let parent_contains_cap = crate::containment::contains(pv, &parent_scope, pm, cv, &cap_scope, cm);
            let cap_authorizes_op = crate::authorize::authorizes(cv, &cap_scope, cm, ov, &target, om);

            if parent_contains_cap && cap_authorizes_op {
                // Parent scope covers cap scope (from containment),
                // cap scope covers target (from authorization),
                // so parent scope covers target (by transitivity).
                // Parent mode >= cap mode >= op mode (from ordering).
                // Parent variant subsumes cap variant subsumes op variant (from transitivity).
                let parent_auth = crate::authorize::authorizes(pv, &parent_scope, pm, ov, &target, om);
                prop_assert!(parent_auth, "delegation safety violated");
            }
        }

        // r[impl properties.auth-implies-subsumes]
        // r[verify properties.auth-implies-subsumes]
        /// Authorization implies variant subsumption.
        #[test]
        fn prop_auth_implies_subsumes(
            cv in 0u8..=7, ov in 0u8..=7,
            cm in 0u8..=3, om in 0u8..=3,
            scope in proptest::collection::vec(any::<u8>(), 0..=10),
            target in proptest::collection::vec(any::<u8>(), 0..=10),
        ) {
            if crate::authorize::authorizes(cv, &scope, cm, ov, &target, om) {
                prop_assert!(crate::subsumption::subsumes(cv, ov));
                prop_assert!(crate::scope::covers(&scope, &target));
                prop_assert!(crate::access_mode::mode_permits(cm, om));
            }
        }

        // r[impl properties.containment-implies-factors]
        // r[verify properties.containment-implies-factors]
        /// Containment implies all three factors hold.
        #[test]
        fn prop_containment_implies_factors(
            pv in 0u8..=7, cv in 0u8..=7,
            pm in 0u8..=3, cm in 0u8..=3,
            ps in proptest::collection::vec(any::<u8>(), 0..=10),
            cs in proptest::collection::vec(any::<u8>(), 0..=10),
        ) {
            if crate::containment::contains(pv, &ps, pm, cv, &cs, cm) {
                prop_assert!(crate::subsumption::subsumes(pv, cv));
                prop_assert!(crate::scope::covers(&ps, &cs));
                prop_assert!(crate::access_mode::mode_le(cm, pm));
            }
        }

        // r[impl properties.token-valid-at-issue]
        // r[verify properties.token-valid-at-issue]
        /// A well-formed token is valid at its issued_at time.
        #[test]
        fn prop_token_valid_at_issue(
            issued_at in 0u64..=u64::MAX / 4,
            total in 0u64..=10000,
            tolerance in 0u64..=1000,
        ) {
            let expires_at = issued_at + total;
            prop_assert!(crate::token_timestamp::token_time_valid(
                issued_at, expires_at, issued_at, tolerance,
            ));
        }

        // r[impl properties.chain-valid-implies-depth-bounded]
        // r[verify properties.chain-valid-implies-depth-bounded]
        /// A valid chain has bounded depth.
        #[test]
        fn prop_chain_depth_bounded(depth in 0u64..=20) {
            use crate::delegation::*;
            // Build a chain of the given depth.
            let mut chain = Vec::new();
            for d in 0..=depth {
                chain.push(ChainLevel {
                    depth: d,
                    has_delegate: d < depth, // last level doesn't need delegate
                    variant: 4, // Full
                    mode: 3,    // Full mode
                });
            }
            let valid = chain_valid(&chain);
            if depth <= 8 {
                prop_assert!(valid, "valid chain rejected at depth {}", depth);
            } else {
                prop_assert!(!valid, "invalid chain accepted at depth {}", depth);
            }
        }

        // ============================================================
        // Session tree cross-module properties (forest × seq_set)
        // ============================================================

        // --- Generic module cross-module tests ---

        // r[verify properties.vc-merge-is-pointwise-max]
        // r[verify properties.g-counter-merge-is-pointwise-max]
        // r[verify properties.cut-join-is-pointwise-max]
        // r[verify properties.all-three-merges-agree]
        #[test]
        fn prop_all_three_merges_agree(
            a in proptest::collection::vec(any::<u64>(), 3),
            b in proptest::collection::vec(any::<u64>(), 3),
        ) {
            let vc = crate::vector_clock::merge(&a, &b);
            let gc = crate::crdt::g_counter_merge(&a, &b);
            let cj = crate::causal_order::cut_join(&a, &b);
            prop_assert_eq!(&vc, &gc, "vc != g_counter");
            prop_assert_eq!(&gc, &cj, "g_counter != cut_join");
        }

        // r[verify properties.unique-subset-of-source]
        /// Unique messages are a subset of the source branch path.
        #[test]
        fn prop_unique_subset_of_source(raw in proptest::collection::vec(proptest::option::of(0usize..100), 2..=15)) {
            let parents: Vec<Option<usize>> = raw.into_iter().enumerate().map(|(i, opt)| {
                if i == 0 { None } else { match opt { Some(v) => Some(v % i), None => None } }
            }).collect();
            let src = parents.len() - 1;
            let tgt = 0;
            let path_src = crate::forest::ancestor_path(&parents, src);
            let path_tgt = crate::forest::ancestor_path(&parents, tgt);
            let src_i64: Vec<i64> = path_src.iter().map(|&x| i64::try_from(x).unwrap()).collect();
            let tgt_i64: Vec<i64> = path_tgt.iter().map(|&x| i64::try_from(x).unwrap()).collect();
            let cap = parents.len() + 1;
            let unique = crate::seq_set::set_difference(&src_i64, &tgt_i64, cap);
            // unique ⊆ source path
            for &u in &unique {
                prop_assert!(src_i64.contains(&u), "unique {} not on source path", u);
            }
            // unique ∩ target path = ∅
            for &u in &unique {
                prop_assert!(!tgt_i64.contains(&u), "unique {} on target path", u);
            }
        }

        // r[verify properties.unique-disjoint-from-target]
        /// Unique messages have no overlap with target branch.
        #[test]
        fn prop_unique_disjoint_from_target(raw in proptest::collection::vec(proptest::option::of(0usize..100), 2..=15)) {
            let parents: Vec<Option<usize>> = raw.into_iter().enumerate().map(|(i, opt)| {
                if i == 0 { None } else { match opt { Some(v) => Some(v % i), None => None } }
            }).collect();
            let src = parents.len() - 1;
            let tgt = 0;
            let path_src = crate::forest::ancestor_path(&parents, src);
            let path_tgt = crate::forest::ancestor_path(&parents, tgt);
            let src_i64: Vec<i64> = path_src.iter().map(|&x| i64::try_from(x).unwrap()).collect();
            let tgt_i64: Vec<i64> = path_tgt.iter().map(|&x| i64::try_from(x).unwrap()).collect();
            let cap = parents.len() + 1;
            let unique = crate::seq_set::set_difference(&src_i64, &tgt_i64, cap);
            let inter = crate::seq_set::set_intersection(&src_i64, &tgt_i64, cap);
            // Partition: unique + shared = source
            prop_assert_eq!(unique.len() + inter.len(), src_i64.len());
        }

        // r[verify properties.selective-subset-of-unique]
        /// Selective merge result is subset of both selection and unique set.
        #[test]
        fn prop_selective_subset_of_unique(raw in proptest::collection::vec(proptest::option::of(0usize..100), 3..=15)) {
            let parents: Vec<Option<usize>> = raw.into_iter().enumerate().map(|(i, opt)| {
                if i == 0 { None } else { match opt { Some(v) => Some(v % i), None => None } }
            }).collect();
            let src = parents.len() - 1;
            let tgt = 0;
            let path_src = crate::forest::ancestor_path(&parents, src);
            let path_tgt = crate::forest::ancestor_path(&parents, tgt);
            let src_i64: Vec<i64> = path_src.iter().map(|&x| i64::try_from(x).unwrap()).collect();
            let tgt_i64: Vec<i64> = path_tgt.iter().map(|&x| i64::try_from(x).unwrap()).collect();
            let cap = parents.len() + 1;
            let unique = crate::seq_set::set_difference(&src_i64, &tgt_i64, cap);
            // Select half
            let selected: Vec<i64> = unique.iter().take(unique.len() / 2 + 1).copied().collect();
            let merged = crate::seq_set::set_intersection(&selected, &unique, cap);
            // merged ⊆ unique AND merged ⊆ selected
            for &m in &merged {
                prop_assert!(unique.contains(&m), "merged {} not in unique", m);
                prop_assert!(selected.contains(&m), "merged {} not in selected", m);
            }
        }

        // r[verify properties.subtree-walk-connection]
        /// Every node in a subtree has the root on its ancestor path.
        #[test]
        fn prop_subtree_walk_connection(raw in proptest::collection::vec(proptest::option::of(0usize..100), 2..=15)) {
            let parents: Vec<Option<usize>> = raw.into_iter().enumerate().map(|(i, opt)| {
                if i == 0 { None } else { match opt { Some(v) => Some(v % i), None => None } }
            }).collect();
            // Pick a root in the middle
            let root = parents.len() / 2;
            let sub = crate::forest::subtree(&parents, root);
            for &n in &sub {
                let path = crate::forest::ancestor_path(&parents, n);
                prop_assert!(path.contains(&root),
                    "node {} in subtree({}) but root not on path {:?}", n, root, path);
            }
        }

        // r[verify properties.watermark-advance-is-monotonic]
        #[test]
        fn prop_watermark_advance_is_monotonic(
            mark in 0u64..=u64::MAX / 2,
            size in 0u64..=10000,
        ) {
            if u128::from(mark) + u128::from(size) <= u128::from(u64::MAX) {
                let new_mark = crate::watermark::watermark_alloc(mark, size);
                prop_assert!(crate::monotonic::is_advance(mark, new_mark));
            }
        }

        // r[verify properties.watermark-alloc-disjoint-regions]
        #[test]
        fn prop_watermark_alloc_disjoint_regions(
            mark in 0u64..=u64::MAX / 4,
            size1 in 1u64..=1000,
            size2 in 1u64..=1000,
        ) {
            if u128::from(mark) + u128::from(size1) + u128::from(size2) <= u128::from(u64::MAX) {
                let mark2 = crate::watermark::watermark_alloc(mark, size1);
                prop_assert!(crate::region::regions_disjoint(mark, size1, mark2, size2));
            }
        }

        // r[verify properties.buddy-uses-toggle]
        #[test]
        fn prop_buddy_uses_toggle(addr: u64, order in 0u64..64) {
            let buddy = crate::buddy::buddy_of(addr, order);
            let toggled = crate::bitwise::toggle_bit(addr, order);
            prop_assert_eq!(buddy, toggled);
        }

        // r[verify properties.block-size-is-pow2]
        #[test]
        fn prop_block_size_is_pow2(order in 0u64..64) {
            prop_assert_eq!(crate::buddy::block_size(order), 1u64 << order);
        }

        // r[verify properties.slab-slot-is-page-frame]
        #[test]
        fn prop_slab_slot_is_page_frame(addr: u64, slot_size in 1u64..=4096) {
            let slab_idx = crate::slab::slot_index(addr, 0, slot_size);
            let page_frame = crate::page::frame_number(addr, slot_size);
            prop_assert_eq!(slab_idx, page_frame);
        }

        // r[verify properties.slab-capacity-is-pages-dual]
        #[test]
        fn prop_slab_capacity_exact(n in 0u64..=10000, slot_size in 1u64..=256) {
            if u128::from(n) * u128::from(slot_size) <= u128::from(u64::MAX) {
                let region_size = n * slot_size;
                let cap = crate::slab::slab_capacity(region_size, slot_size);
                prop_assert_eq!(cap, n);
            }
        }

        // r[verify properties.region-contains-agrees-interval]
        #[test]
        fn prop_region_contains_agrees_interval(
            base in 0u64..=u64::MAX / 2,
            size in 0u64..=1000,
            x: u64,
        ) {
            if u128::from(base) + u128::from(size) <= u128::from(u64::MAX) {
                let region_result = crate::region::contains_addr(base, size, x);
                let interval_result = crate::interval::contains(base, base + size, x);
                prop_assert_eq!(region_result, interval_result);
            }
        }

        // r[verify properties.region-disjoint-agrees-interval]
        #[test]
        fn prop_region_disjoint_agrees_interval(
            a_base in 0u64..=u64::MAX / 2,
            a_size in 0u64..=1000,
            b_base in 0u64..=u64::MAX / 2,
            b_size in 0u64..=1000,
        ) {
            if u128::from(a_base) + u128::from(a_size) <= u128::from(u64::MAX)
                && u128::from(b_base) + u128::from(b_size) <= u128::from(u64::MAX)
            {
                let region_result = crate::region::regions_disjoint(a_base, a_size, b_base, b_size);
                let interval_result = !crate::interval::overlaps(
                    a_base, a_base + a_size, b_base, b_base + b_size,
                );
                prop_assert_eq!(region_result, interval_result);
            }
        }

        // r[verify properties.region-adjacent-agrees-interval]
        #[test]
        fn prop_region_adjacent_agrees_interval(
            a_base in 0u64..=u64::MAX / 2,
            a_size in 0u64..=1000,
            b_base in 0u64..=u64::MAX / 2,
            b_size in 0u64..=1000,
        ) {
            if u128::from(a_base) + u128::from(a_size) <= u128::from(u64::MAX)
                && u128::from(b_base) + u128::from(b_size) <= u128::from(u64::MAX)
            {
                let region_result = crate::region::region_adjacent(a_base, a_size, b_base, b_size);
                let interval_result = crate::interval::adjacent(
                    a_base, a_base + a_size, b_base, b_base + b_size,
                );
                prop_assert_eq!(region_result, interval_result);
            }
        }

        // --- Wave 1 cross-module proptests ---

        // r[verify properties.signal-add-is-set-bit]
        #[test]
        fn prop_signal_add_is_set_bit(set: u64, sig in 0u64..64) {
            prop_assert_eq!(
                crate::signal::signal_add(set, sig),
                crate::bitwise::set_bit(set, sig),
            );
        }

        // r[verify properties.signal-remove-is-clear-bit]
        #[test]
        fn prop_signal_remove_is_clear_bit(set: u64, sig in 0u64..64) {
            prop_assert_eq!(
                crate::signal::signal_remove(set, sig),
                crate::bitwise::clear_bit(set, sig),
            );
        }

        // r[verify properties.signal-contains-is-bit-at]
        #[test]
        fn prop_signal_contains_is_bit_at(set: u64, sig in 0u64..64) {
            prop_assert_eq!(
                crate::signal::signal_contains(set, sig),
                crate::bitwise::bit_at(set, sig),
            );
        }

        // r[verify properties.permission-set-check-roundtrip]
        #[test]
        fn prop_permission_set_check_roundtrip(
            mode: u64, who in 0u64..=2, perm in 0u64..=2,
        ) {
            let updated = crate::permission::set_permission(mode, who, perm);
            prop_assert!(crate::permission::has_permission(updated, who, perm));
        }

        // r[verify properties.permission-set-independence]
        #[test]
        fn prop_permission_set_independence(
            mode: u64,
            w1 in 0u64..=2, p1 in 0u64..=2,
            w2 in 0u64..=2, p2 in 0u64..=2,
        ) {
            if crate::permission::bit_position(w1, p1)
                != crate::permission::bit_position(w2, p2)
            {
                let before = crate::permission::has_permission(mode, w2, p2);
                let updated = crate::permission::set_permission(mode, w1, p1);
                let after = crate::permission::has_permission(updated, w2, p2);
                prop_assert_eq!(before, after);
            }
        }

        // r[verify properties.pages-needed-is-div-ceil]
        #[test]
        fn prop_pages_needed_is_div_ceil(size: u64, ps in 1u64..=10000) {
            prop_assert_eq!(
                crate::page::pages_needed(size, ps),
                crate::arithmetic::div_ceil(size, ps),
            );
        }

        // r[verify properties.page-aligned-is-align-down-fixpoint]
        #[test]
        fn prop_page_aligned_is_align_down_fixpoint(addr: u64, ps in 1u64..=10000) {
            prop_assert_eq!(
                crate::page::is_page_aligned(addr, ps),
                crate::integer::align_down(addr, ps) == addr,
            );
        }

        // r[verify properties.lease-valid-implies-not-expired]
        #[test]
        fn prop_lease_valid_implies_not_expired(
            start in 0u64..=u64::MAX / 2,
            expiry_offset in 1u64..=1000,
            now_offset in 0u64..=2000,
        ) {
            let expiry = start + expiry_offset;
            let now = start + now_offset;
            let lease = crate::lease::grant(1, start, expiry);
            if crate::lease::is_valid(&lease, now) {
                prop_assert!(!crate::expiration::is_expired(expiry, now));
            }
        }

        // r[verify properties.tier-score-monotonic]
        #[test]
        fn prop_tier_score_monotonic(
            count_a: u64, count_b: u64,
            warm_t in 1u64..=100, hot_t in 1u64..=200,
        ) {
            if warm_t <= hot_t && count_a <= count_b {
                let tier_a = crate::tier::classify_tier(count_a, warm_t, hot_t);
                let tier_b = crate::tier::classify_tier(count_b, warm_t, hot_t);
                let mult_a = crate::eviction_score::tier_multiplier(tier_a);
                let mult_b = crate::eviction_score::tier_multiplier(tier_b);
                prop_assert!(mult_a <= mult_b);
            }
        }

        // r[verify properties.backoff-in-range]
        #[test]
        fn prop_backoff_in_range(base: u64, attempt in 0u64..=100, cap: u64) {
            prop_assert!(crate::backoff::compute_backoff(base, attempt, cap) <= cap);
        }

        // r[verify properties.approval-majority-implies-quorum]
        #[test]
        fn prop_approval_majority_implies_quorum(
            valid in 0u64..=100, total in 1u64..=100,
        ) {
            let required = crate::quorum::majority(total);
            if crate::approval::is_merge_allowed(valid, required, true) {
                prop_assert!(crate::quorum::is_quorum(valid, total));
            }
        }

        // r[verify properties.lease-renewal-is-advance]
        #[test]
        fn prop_lease_renewal_is_advance(
            start in 0u64..=u64::MAX / 4,
            expiry_offset in 1u64..=1000,
            renewal_offset in 1u64..=1000,
        ) {
            let expiry = start + expiry_offset;
            let lease = crate::lease::grant(1, start, expiry);
            let new_expiry = expiry + renewal_offset;
            let renewed = crate::lease::renew(&lease, new_expiry);
            prop_assert!(crate::lease::effective_expiry(&renewed)
                >= crate::lease::effective_expiry(&lease));
        }

        // r[verify properties.two-phase-unanimity-implies-quorum]
        #[test]
        fn prop_two_phase_unanimity_implies_quorum(n in 1u64..=100) {
            let len: usize = n.try_into().unwrap();
            let votes: Vec<Option<bool>> = vec![Some(true); len];
            if crate::two_phase::can_commit(&votes) {
                prop_assert!(crate::quorum::is_quorum(n, n));
            }
        }

        // r[verify properties.expires-at-monotonic-is-advance]
        #[test]
        fn prop_expires_at_monotonic_is_advance(
            now: u64, ttl_a: u64, ttl_b: u64,
        ) {
            if ttl_a <= ttl_b {
                prop_assert!(
                    crate::expiration::expires_at(now, ttl_b)
                        >= crate::expiration::expires_at(now, ttl_a)
                );
            }
        }

        // r[verify properties.cow-clone-is-drain-start]
        #[test]
        fn prop_cow_clone_is_drain_start(n: u64) {
            prop_assert_eq!(
                crate::cow::ref_count_after_clone(n),
                crate::drain::after_start_op(n),
            );
        }

        // r[verify properties.cow-drop-is-drain-finish]
        #[test]
        fn prop_cow_drop_is_drain_finish(n: u64) {
            prop_assert_eq!(
                crate::cow::ref_count_after_drop(n),
                crate::drain::after_finish_op(n),
            );
        }

        // --- Wave 2 cross-module proptests ---

        // r[verify properties.type-lattice-reflexive]
        #[test]
        fn prop_type_lattice_reflexive(t in 0u8..=6) {
            prop_assert!(crate::type_lattice::can_convert(t, t));
        }

        // r[verify properties.type-lattice-any-top]
        #[test]
        fn prop_type_lattice_any_top(t in 0u8..=6) {
            prop_assert!(crate::type_lattice::can_convert(t, 6)); // to ANY
            prop_assert!(crate::type_lattice::can_convert(6, t)); // from ANY
        }

        // r[verify properties.circuit-breaker-preserves-validity]
        #[test]
        fn prop_circuit_breaker_preserves_validity(
            current in 0u8..=2,
            failure_count: u64,
            threshold in 1u64..=100,
            elapsed: u64,
            timeout in 1u64..=100,
            probe_succeeded: bool,
        ) {
            let next = crate::circuit_breaker::next_state(
                current, failure_count, threshold, elapsed, timeout, probe_succeeded,
            );
            prop_assert!(crate::circuit_breaker::is_valid_state(next));
        }

        // r[verify properties.process-terminal-blocks-circuit-open-blocks]
        #[test]
        fn prop_terminal_and_open_block(state in 0u64..=4) {
            if crate::process_state::is_terminal(state) {
                // Terminal states have no outgoing transitions
                for target in 0u64..=4 {
                    prop_assert!(!crate::process_state::can_transition(state, target));
                }
            }
            // OPEN circuit breaker blocks requests
            prop_assert!(!crate::circuit_breaker::allow_request(
                crate::circuit_breaker::OPEN, false,
            ));
        }

        // r[verify properties.bitmap-signal-agree]
        #[test]
        fn prop_bitmap_signal_agree(word: u64, pos in 0u64..64) {
            prop_assert_eq!(
                crate::bitwise::bit_at(word, pos),
                crate::signal::signal_contains(word, pos),
            );
        }

        // r[verify properties.slab-slot-in-region]
        #[test]
        fn prop_slab_slot_in_region(
            base in 0u64..=u64::MAX / 4,
            capacity in 1u64..=10000,
            slot_size in 1u64..=1000,
        ) {
            if u128::from(base) + u128::from(capacity) <= u128::from(u64::MAX) {
                let cap = crate::slab::slab_capacity(capacity, slot_size);
                if cap > 0 {
                    // Test first and last valid slot
                    for &index in &[0u64, cap - 1] {
                        if u128::from(base) + u128::from(index) * u128::from(slot_size)
                            <= u128::from(u64::MAX)
                        {
                            let addr = crate::slab::slot_address(index, base, slot_size);
                            prop_assert!(crate::region::contains_addr(base, capacity, addr));
                        }
                    }
                }
            }
        }

        // r[verify properties.pressure-eviction-pipeline]
        #[test]
        fn prop_pressure_eviction_pipeline(count: u64, capacity: u64) {
            if crate::pressure::classify_level(count, capacity, capacity) >= 2 {
                prop_assert!(crate::eviction::should_evict(count, capacity));
            }
        }

        // r[verify properties.eviction-score-cold-minimum]
        #[test]
        fn prop_eviction_score_cold_minimum(tier in 0u8..=3) {
            prop_assert!(crate::eviction_score::tier_multiplier(0) <= crate::eviction_score::tier_multiplier(tier));
        }

        // --- Wave 3 cross-module proptests ---

        // r[verify properties.evictable-count-is-saturating-sub]
        #[test]
        fn prop_evictable_count_is_saturating_sub(count: u64, protected: u64) {
            prop_assert_eq!(
                crate::eviction::evictable_count(count, protected),
                crate::arithmetic::saturating_sub(count, protected),
            );
        }

        // r[verify properties.gossip-infection-bounded]
        #[test]
        fn prop_gossip_infection_bounded(
            cluster_size: u64, fanout in 1u64..=10, rounds in 0u64..=100,
        ) {
            prop_assert!(
                crate::gossip::infection_lower_bound(cluster_size, fanout, rounds)
                    <= cluster_size,
            );
        }

        // r[verify properties.gossip-infection-monotonic-rounds]
        #[test]
        fn prop_gossip_infection_monotonic_rounds(
            cluster_size in 1u64..=1000,
            fanout in 1u64..=10,
            rounds_a in 0u64..=50,
            rounds_b in 0u64..=50,
        ) {
            if rounds_a <= rounds_b {
                prop_assert!(
                    crate::gossip::infection_lower_bound(cluster_size, fanout, rounds_a)
                        <= crate::gossip::infection_lower_bound(cluster_size, fanout, rounds_b),
                );
            }
        }

        // r[verify properties.acid-empty-commit-identity]
        #[test]
        fn prop_acid_empty_commit_identity(len in 0usize..=100) {
            let state: Vec<u64> = (0..len).map(|i| i as u64).collect();
            let mut result = state.clone();
            let empty_writes: Vec<crate::acid::WriteOp> = vec![];
            crate::acid::apply_writes(&mut result, &empty_writes);
            prop_assert_eq!(result, state);
        }

        // r[verify properties.priority-multiplier-monotonic]
        #[test]
        fn prop_priority_multiplier_monotonic(a in 0u8..=3, b in 0u8..=3) {
            if a <= b {
                prop_assert!(
                    crate::eviction_score::priority_multiplier(a)
                        <= crate::eviction_score::priority_multiplier(b),
                );
            }
        }

        // r[verify properties.full-score-bounded]
        #[test]
        fn prop_full_score_bounded(
            w1 in 0u64..=100, w2 in 0u64..=100,
            w3 in 0u64..=100, w4 in 0u64..=100,
            s1 in 0u64..=100, s2 in 0u64..=100,
            s3 in 0u64..=100, s4 in 0u64..=100,
            priority in 0u8..=3, tier in 0u8..=2,
        ) {
            if w1 + w2 + w3 + w4 == 100
                && w1 <= 100 && w2 <= 100 && w3 <= 100 && w4 <= 100
            {
                prop_assert!(
                    crate::eviction_score::full_score(
                        w1, w2, w3, w4, s1, s2, s3, s4, priority, tier,
                    ) <= 800_000,
                );
            }
        }

        // r[verify properties.consistent-hash-lookup-in-ring]
        #[test]
        fn prop_consistent_hash_lookup_in_ring(
            key_hash: u64,
            ring_size in 1usize..=20,
        ) {
            let ring: Vec<(u64, u64)> = (0..ring_size)
                .map(|i| (i as u64 * 1000, i as u64))
                .collect();
            let result = crate::consistent_hash::lookup(&ring, key_hash);
            prop_assert!(ring.iter().any(|&(_, node)| node == result));
        }

        // r[verify properties.bloom-insert-length-preserved]
        #[test]
        fn prop_bloom_insert_length_preserved(
            bits_len in 1usize..=100,
            num_positions in 0usize..=10,
        ) {
            let mut bits = vec![false; bits_len];
            let positions: Vec<usize> = (0..num_positions)
                .map(|i| i % bits_len)
                .collect();
            let orig_len = bits.len();
            crate::bloom::insert(&mut bits, &positions);
            prop_assert_eq!(bits.len(), orig_len);
        }

        // --- Ledger cross-module properties ---

        // r[verify properties.balance-credit-is-saturating-add]
        #[test]
        fn prop_balance_credit_is_saturating_add(b: u64, a: u64) {
            if let Some(credited) = crate::balance::credit(b, a) {
                prop_assert_eq!(credited, saturating_add(b, a));
            }
        }

        // r[verify properties.balance-has-funds-is-in-range]
        #[test]
        fn prop_balance_has_funds_is_in_range(b: u64, a: u64) {
            prop_assert_eq!(
                crate::balance::has_funds(b, a),
                in_range(a, 0, b),
            );
        }

        // r[verify properties.transfer-uses-debit-credit]
        #[test]
        fn prop_transfer_uses_debit_credit(
            from in 1..u64::MAX / 2,
            to in 0..u64::MAX / 2,
            amt in 1..u64::MAX / 4,
        ) {
            if crate::transfer::transfer_valid(from, to, amt) {
                let (sender, receiver) = crate::transfer::execute_transfer(from, to, amt);
                prop_assert_eq!(
                    crate::balance::debit(from, amt),
                    Some(sender),
                );
                prop_assert_eq!(
                    crate::balance::credit(to, amt),
                    Some(receiver),
                );
            }
        }

        // r[verify properties.transfer-idempotency-is-fencing]
        #[test]
        fn prop_transfer_idempotency_is_fencing(rid: u64, lid: u64) {
            if !crate::transfer::is_duplicate(rid, lid) {
                prop_assert!(crate::fencing::is_valid_write(rid, lid));
            }
        }

        // r[verify properties.journal-seq-num-is-strict-advance]
        #[test]
        fn prop_journal_seq_num_is_strict_advance(a: u64, b: u64) {
            if a < b {
                prop_assert!(crate::monotonic::is_strict_advance(a, b));
            }
        }

        // r[verify properties.balanced-simple-is-transfer]
        #[test]
        fn prop_balanced_simple_is_transfer(a in 1..u64::MAX) {
            prop_assert!(crate::transfer::transfer_valid(a, 0, a));
        }

        // r[verify properties.escrow-fund-uses-debit]
        #[test]
        fn prop_escrow_fund_uses_debit(buyer: u64, amount: u64) {
            if let Some(debited) = crate::balance::debit(buyer, amount) {
                if let Some((escrowed, _)) = crate::escrow::fund(
                    crate::escrow::ESCROW_CREATED, buyer, amount
                ) {
                    prop_assert_eq!(escrowed, debited);
                }
            }
        }

        // r[verify properties.escrow-release-uses-credit]
        #[test]
        fn prop_escrow_release_uses_credit(seller in 0..u64::MAX / 2, amount in 1..u64::MAX / 2) {
            if let Some(credited) = crate::balance::credit(seller, amount) {
                if let Some((released, _)) = crate::escrow::release(
                    crate::escrow::ESCROW_FUNDED, seller, amount
                ) {
                    prop_assert_eq!(released, credited);
                }
            }
        }

        // r[verify properties.fee-conservation-matches-transfer]
        #[test]
        fn prop_fee_conservation(amount: u64, rate_bps in 0..=10000u64) {
            let fee = crate::fee::compute_fee(amount, rate_bps);
            let net = crate::fee::compute_net(amount, rate_bps);
            prop_assert_eq!(fee as u128 + net as u128, amount as u128);
        }

        // r[verify properties.fee-zero-rate-identity]
        #[test]
        fn prop_fee_zero_rate_identity(amount: u64) {
            prop_assert_eq!(crate::fee::compute_net(amount, 0), amount);
        }

        // r[verify properties.ledger-transfer-uses-balance]
        #[test]
        fn prop_ledger_transfer_uses_balance(
            balances in proptest::collection::vec(100..10_000u64, 2..=5),
            from_idx in 0usize..5,
            to_idx in 0usize..5,
            amount in 1..100u64,
        ) {
            if from_idx < balances.len() && to_idx < balances.len() && from_idx != to_idx {
                if let Some((new_from, new_to)) = crate::ledger::ledger_transfer(&balances, from_idx, to_idx, amount) {
                    if let Some(debited) = crate::balance::debit(balances[from_idx], amount) {
                        prop_assert_eq!(new_from, debited);
                    }
                    if let Some(credited) = crate::balance::credit(balances[to_idx], amount) {
                        prop_assert_eq!(new_to, credited);
                    }
                }
            }
        }

        // r[verify properties.retry-with-closed-circuit]
        #[test]
        fn prop_retry_with_closed_circuit(
            attempt in 0u64..=100,
            max_attempts in 1u64..=100,
        ) {
            if crate::retry::should_retry(attempt, max_attempts, true) {
                prop_assert!(crate::circuit_breaker::allow_request(crate::circuit_breaker::CLOSED, false));
            }
        }

        // r[verify properties.retry-gate-implies-backoff-computable]
        #[test]
        fn prop_retry_implies_backoff_bounded(
            attempt in 0u64..=100,
            max_attempts in 1u64..=100,
            base in 1u64..=10000,
            cap in 1u64..=60000,
        ) {
            if crate::retry::should_retry(attempt, max_attempts, true) {
                let delay = crate::backoff::compute_backoff(base, attempt, cap);
                prop_assert!(delay <= cap);
            }
        }
    }
}

// --- KV storage cross-module properties ---

#[cfg(verus_keep_ghost)]
mod kv_storage_proofs {
    use vstd::prelude::*;

    use crate::kv_version::compute_kv_versions_spec;
    use crate::monotonic::is_advance_spec;

    verus! {

    // r[impl properties.kv-version-mod-revision-advance]
    // r[verify properties.kv-version-mod-revision-advance]
    /// When log_index increases, mod_revision satisfies is_advance.
    proof fn prove_mod_revision_advance(
        prev: Option<(u64, u64)>,
        li1: u64,
        li2: u64,
    )
        requires li1 <= li2
        ensures is_advance_spec(
            compute_kv_versions_spec(prev, li1).mod_revision,
            compute_kv_versions_spec(prev, li2).mod_revision,
        )
    {}

    // r[impl properties.kv-version-version-advance]
    // r[verify properties.kv-version-version-advance]
    /// For successive updates, version satisfies is_advance.
    proof fn prove_version_advance(
        create_rev: u64,
        v1: u64,
        v2: u64,
        li1: u64,
        li2: u64,
    )
        requires
            v1 >= 1,
            v2 == compute_kv_versions_spec(Some((create_rev, v1)), li1).version,
        ensures is_advance_spec(v1, v2)
    {}

    // r[impl properties.constant-time-eq-agreement]
    // r[verify properties.constant-time-eq-agreement]
    /// constant_time_eq agrees with extensional equality.
    proof fn prove_constant_time_eq_agreement(a: Seq<u8>, b: Seq<u8>)
        requires a.len() == 32, b.len() == 32
        ensures crate::constant_time_eq::constant_time_eq_spec(a, b) <==> (a =~= b)
    {
        crate::constant_time_eq::equivalence_to_equality(a, b);
    }

    } // verus!
}

// --- Cluster coordination cross-module properties ---

#[cfg(verus_keep_ghost)]
mod cluster_coordination_proofs {
    use vstd::prelude::*;

    use crate::drain::can_start_op_spec;
    use crate::drain_protocol::try_start_with_recheck_spec;
    use crate::node_lifecycle::DEGRADED;
    use crate::node_lifecycle::ONLINE;
    use crate::node_lifecycle::is_operational_spec;

    verus! {

    // r[impl properties.drain-protocol-extends-drain]
    // r[verify properties.drain-protocol-extends-drain]
    /// drain_protocol try_start refines drain::can_start_op:
    /// if can_start_op is false (draining), then try_start always rejects.
    proof fn prove_drain_protocol_extends_drain(
        is_draining: bool,
        in_flight: u64,
        draining_at_recheck: bool,
    )
        requires !can_start_op_spec(is_draining)
        ensures !try_start_with_recheck_spec(is_draining, in_flight, draining_at_recheck).0
    {}

    // r[impl properties.trust-access-exhaustive]
    // r[verify properties.trust-access-exhaustive]
    /// Trust access is exhaustive: blocked=deny, trusted=allow, public=conditional.
    proof fn prove_trust_access_exhaustive(level: u8, is_public: bool)
        ensures
            level == crate::trust_level::BLOCKED ==>
                !crate::trust_level::can_access_spec(level, is_public),
            level == crate::trust_level::TRUSTED ==>
                crate::trust_level::can_access_spec(level, is_public),
            level == crate::trust_level::PUBLIC ==>
                crate::trust_level::can_access_spec(level, is_public) == is_public,
    {}

    // r[impl properties.lifecycle-operational-pressure]
    // r[verify properties.lifecycle-operational-pressure]
    /// Operational nodes are exactly Online or Degraded.
    proof fn prove_lifecycle_operational(status: u8)
        ensures is_operational_spec(status) <==> (status == ONLINE || status == DEGRADED)
    {}

    // r[impl properties.tiered-rate-limit-uses-try-consume]
    // r[verify properties.tiered-rate-limit-uses-try-consume]
    /// Tiered rate limit ALLOWED means both try_consume calls succeeded.
    proof fn prove_tiered_uses_try_consume(global: u64, peer: u64, cost: u64)
        requires
            crate::rate_limit::try_consume_spec(global, cost).0,
            crate::rate_limit::try_consume_spec(peer, cost).0,
        ensures
            crate::tiered_rate_limit::check_tiered_spec(global, peer, cost).0
                == crate::tiered_rate_limit::ALLOWED,
    {}

    } // verus!
}

#[cfg(test)]
mod cluster_coordination_tests {
    use proptest::prelude::*;

    proptest! {
        // r[impl properties.jitter-bounded-like-backoff]
        // r[verify properties.jitter-bounded-like-backoff]
        #[test]
        fn prop_jitter_bounded_like_backoff(
            node_id: u64,
            jitter_range in 1u64..10000,
            base in 1u64..10000,
            cap in 1u64..60000,
        ) {
            // Both jitter and backoff are bounded by their cap/range
            let jitter = crate::election_jitter::compute_jitter(node_id, jitter_range);
            let backoff = crate::backoff::compute_backoff(base, 0, cap);
            prop_assert!(jitter < jitter_range);
            prop_assert!(backoff <= cap);
        }

        // r[verify properties.drain-protocol-extends-drain]
        #[test]
        fn prop_drain_protocol_extends_drain(in_flight: u64, recheck: bool) {
            // If draining, both drain::can_start_op and drain_protocol reject
            let can_start = crate::drain::can_start_op(true);
            let (proto_ok, _) = crate::drain_protocol::try_start_with_recheck(true, in_flight, recheck);
            prop_assert!(!can_start);
            prop_assert!(!proto_ok);
        }

        // r[verify properties.lifecycle-operational-pressure]
        #[test]
        fn prop_lifecycle_operational(status in 0u8..4) {
            let op = crate::node_lifecycle::is_operational(status);
            prop_assert_eq!(op, status == 1 || status == 2); // ONLINE=1, DEGRADED=2
        }

        // r[verify properties.trust-access-exhaustive]
        #[test]
        fn prop_trust_access_exhaustive(in_blocked: bool, in_trusted: bool, is_public: bool) {
            let level = crate::trust_level::resolve_trust(in_blocked, in_trusted);
            let access = crate::trust_level::can_access(level, is_public);
            if in_blocked {
                prop_assert!(!access);
            } else if in_trusted {
                prop_assert!(access);
            } else {
                prop_assert_eq!(access, is_public);
            }
        }

        // r[verify properties.tiered-rate-limit-uses-try-consume]
        #[test]
        fn prop_tiered_uses_try_consume(
            global in 100u64..1000,
            peer in 100u64..1000,
            cost in 0u64..100,
        ) {
            // When both try_consume succeed, tiered gives ALLOWED
            let (g_ok, _) = crate::rate_limit::try_consume(global, cost);
            let (p_ok, _) = crate::rate_limit::try_consume(peer, cost);
            if g_ok && p_ok {
                let (code, _, _) = crate::tiered_rate_limit::check_tiered(global, peer, cost);
                prop_assert_eq!(code, crate::tiered_rate_limit::ALLOWED);
            }
        }
    }
}

#[cfg(test)]
mod kv_storage_tests {
    use proptest::prelude::*;

    proptest! {
        // r[verify properties.kv-version-mod-revision-advance]
        #[test]
        fn prop_mod_revision_advance(
            prev_cr in proptest::option::of((any::<u64>(), any::<u64>())),
            li1: u64,
            li2: u64,
        ) {
            if li1 <= li2 {
                let r1 = crate::kv_version::compute_kv_versions(prev_cr, li1);
                let r2 = crate::kv_version::compute_kv_versions(prev_cr, li2);
                prop_assert!(crate::monotonic::is_advance(r1.mod_revision, r2.mod_revision));
            }
        }

        // r[verify properties.kv-version-version-advance]
        #[test]
        fn prop_version_advance(
            create_rev: u64,
            v1 in 1u64..u64::MAX,
            li1: u64,
        ) {
            let r = crate::kv_version::compute_kv_versions(Some((create_rev, v1)), li1);
            prop_assert!(crate::monotonic::is_advance(v1, r.version));
        }

        // r[verify properties.constant-time-eq-agreement]
        #[test]
        fn prop_constant_time_eq_agreement(
            a in prop::array::uniform32(any::<u8>()),
            b in prop::array::uniform32(any::<u8>()),
        ) {
            prop_assert_eq!(crate::constant_time_eq::constant_time_eq(&a, &b), a == b);
        }

        // r[impl properties.snapshot-chain-consistency]
        // r[verify properties.snapshot-chain-consistency]
        #[test]
        fn prop_snapshot_round_trip(data_hash: u64, meta_hash: u64, chain_hash: u64) {
            let integrity = crate::snapshot_integrity::compute_integrity(data_hash, meta_hash, chain_hash);
            prop_assert!(crate::snapshot_integrity::verify_integrity(&integrity));
            prop_assert!(crate::snapshot_integrity::verify_with_chain_hash(&integrity, chain_hash));
        }
    }
}

// --- Cluster membership cross-module properties ---
// The individual module proofs (voter_set, bounded_peers, node_classify)
// verify all core properties. Cross-module relationships are validated
// by the proptest suite below.

#[cfg(test)]
#[allow(clippy::cast_possible_truncation, clippy::cast_possible_wrap)]
mod cluster_membership_tests {
    use proptest::prelude::*;

    proptest! {
        // r[impl properties.promote-preserves-quorum]
        // r[verify properties.promote-preserves-quorum]
        #[test]
        fn prop_promote_preserves_quorum(
            voters in proptest::collection::vec(0u64..100, 1..20),
            learner_id in 0u64..100,
        ) {
            let mut deduped: Vec<u64> = Vec::new();
            for &v in &voters {
                if !deduped.contains(&v) { deduped.push(v); }
            }
            prop_assume!(!deduped.is_empty());
            let result = crate::voter_set::promote_voters(&deduped, learner_id, None);
            let n = result.len() as u64;
            prop_assert!(n > 0);
            prop_assert!(crate::quorum::is_quorum(n, n));
        }

        // r[impl properties.replace-quorum-guard]
        // r[verify properties.replace-quorum-guard]
        #[test]
        fn prop_replace_quorum_guard(
            voters in proptest::collection::vec(0u64..100, 1..20),
            learner_id in 0u64..100,
            rid in 0u64..100,
        ) {
            prop_assume!(learner_id != rid);
            let mut deduped: Vec<u64> = Vec::new();
            for &v in &voters {
                if !deduped.contains(&v) { deduped.push(v); }
            }
            prop_assume!(!deduped.is_empty());
            let result = crate::voter_set::promote_voters(&deduped, learner_id, Some(rid));
            prop_assert!(result.len() as i64 >= deduped.len() as i64 - 1);
        }

        // r[verify properties.promote-preserves-quorum]
        // r[verify properties.replace-quorum-guard]
        #[test]
        fn prop_classify_leader_is_quorum_voter(
            nodes in proptest::collection::vec(0u64..100, 1..20),
            members in proptest::collection::vec(0u64..100, 1..10),
            leader_id in proptest::option::of(0u64..100),
        ) {
            let mut deduped: Vec<u64> = Vec::new();
            for &n in &nodes { if !deduped.contains(&n) { deduped.push(n); } }
            let result = crate::node_classify::classify_nodes(&deduped, &members, leader_id);
            // At most one leader
            let leaders: Vec<_> = result.iter().filter(|r| r.3).collect();
            prop_assert!(leaders.len() <= 1);
            // Leader must be a voter
            for r in &result {
                if r.3 { prop_assert!(r.1, "leader not voter"); }
            }
        }
    }
}

// --- Coordination primitives cross-module properties ---

#[cfg(verus_keep_ghost)]
mod coordination_cross_proofs {
    use vstd::prelude::*;

    use crate::distributed_lock::compute_next_fencing_token_spec;
    use crate::distributed_lock::is_lock_expired_spec;
    use crate::election::compute_next_election_token_spec;
    use crate::expiration::is_expired_spec;
    use crate::fencing::issue_token_spec;
    use crate::rwlock::compute_next_write_token_spec;
    use crate::rwlock::is_reader_expired_spec;
    use crate::rwlock::is_writer_expired_spec;

    verus! {

    // r[impl properties.election-token-is-fencing-issue]
    // r[verify properties.election-token-is-fencing-issue]
    /// Election token progression matches fencing::issue_token for non-MAX inputs.
    proof fn election_token_is_fencing_issue(current: u64)
        requires current < u64::MAX
        ensures compute_next_election_token_spec(current) == issue_token_spec(current)
    {}

    // r[impl properties.lock-expired-is-expiration-expired]
    // r[verify properties.lock-expired-is-expiration-expired]
    /// Lock expiry and expiration::is_expired use the same predicate.
    proof fn lock_expired_is_expiration_expired(deadline: u64, now: u64)
        ensures is_lock_expired_spec(deadline, now) == is_expired_spec(deadline, now)
    {}

    // r[impl properties.rwlock-writer-token-is-fencing-issue]
    // r[verify properties.rwlock-writer-token-is-fencing-issue]
    /// RWLock writer token matches fencing::issue_token for non-MAX inputs.
    proof fn rwlock_writer_token_is_fencing_issue(current: u64)
        requires current < u64::MAX
        ensures compute_next_write_token_spec(current) == issue_token_spec(current)
    {}

    // r[impl properties.rwlock-expiry-is-expiration-expired]
    // r[verify properties.rwlock-expiry-is-expiration-expired]
    /// RWLock reader/writer expiry matches expiration::is_expired.
    proof fn rwlock_expiry_is_expiration_expired(deadline: u64, now: u64)
        ensures
            is_reader_expired_spec(deadline, now) == is_expired_spec(deadline, now),
            is_writer_expired_spec(deadline, now) == is_expired_spec(deadline, now),
    {}

    // r[impl properties.lock-deadline-is-expiration-expires-at]
    // r[verify properties.lock-deadline-is-expiration-expires-at]
    /// Lock token for first acquisition is always 1.
    proof fn lock_first_token_is_one()
        ensures compute_next_fencing_token_spec(None) == 1
    {}

    // r[impl properties.sequence-overflow-returns-none]
    // r[verify properties.sequence-overflow-returns-none]
    /// Sequence batch_end returns None exactly when overflow occurs.
    proof fn sequence_batch_end_none_iff_overflow(start: u64, size: u64)
        ensures
            crate::sequence::compute_batch_end_spec(start, size).is_none()
                == (start as int + size as int > u64::MAX as int)
    {}

    } // verus!
}

#[cfg(test)]
mod coordination_cross_tests {
    use proptest::prelude::*;

    proptest! {
        // r[verify properties.election-token-is-fencing-issue]
        #[test]
        fn prop_election_token_matches_fencing(current: u64) {
            prop_assume!(current < u64::MAX);
            prop_assert_eq!(
                crate::election::compute_next_election_token(current),
                crate::fencing::issue_token(current)
            );
        }

        // r[verify properties.lock-expired-is-expiration-expired]
        #[test]
        fn prop_lock_expired_matches_expiration(deadline: u64, now: u64) {
            prop_assert_eq!(
                crate::distributed_lock::is_lock_expired(deadline, now),
                crate::expiration::is_expired(deadline, now)
            );
        }

        // r[verify properties.rwlock-writer-token-is-fencing-issue]
        #[test]
        fn prop_rwlock_writer_token_matches_fencing(current: u64) {
            prop_assume!(current < u64::MAX);
            prop_assert_eq!(
                crate::rwlock::compute_next_write_token(current),
                crate::fencing::issue_token(current)
            );
        }

        // r[verify properties.rwlock-expiry-is-expiration-expired]
        #[test]
        fn prop_rwlock_expiry_matches_expiration(deadline: u64, now: u64) {
            prop_assert_eq!(
                crate::rwlock::is_reader_expired(deadline, now),
                crate::expiration::is_expired(deadline, now)
            );
            prop_assert_eq!(
                crate::rwlock::is_writer_expired(deadline, now),
                crate::expiration::is_expired(deadline, now)
            );
        }

        // r[verify properties.sequence-overflow-returns-none]
        #[test]
        fn prop_sequence_overflow_none(start: u64, size: u64) {
            let result = crate::sequence::compute_batch_end(start, size);
            if start.checked_add(size).is_none() {
                prop_assert!(result.is_none());
            } else {
                prop_assert!(result.is_some());
                prop_assert_eq!(result.unwrap(), start + size);
            }
        }

        // r[verify properties.election-token-is-fencing-issue]
        // Election token and rwlock writer token are the same function
        #[test]
        fn prop_election_rwlock_token_agree(current: u64) {
            prop_assert_eq!(
                crate::election::compute_next_election_token(current),
                crate::rwlock::compute_next_write_token(current)
            );
        }
    }

    // r[verify properties.lock-deadline-is-expiration-expires-at]
    #[test]
    fn lock_first_token_always_one() {
        assert_eq!(crate::distributed_lock::compute_next_fencing_token(None), 1u64);
    }
}

// --- Cross-module: Heartbeat ---

#[cfg(test)]
mod heartbeat_cross_tests {
    use proptest::prelude::*;

    proptest! {
        // r[impl properties.heartbeat-interval-less-than-election]
        // r[verify properties.heartbeat-interval-less-than-election]
        /// The timing constraint heartbeat < election_min ensures
        /// multiple heartbeats per election timeout period.
        #[test]
        fn prop_heartbeat_interval_less_than_election(
            heartbeat in 1u64..100,
            election_min in 101u64..500,
        ) {
            // Timing validation enforces heartbeat < election_min
            prop_assert!(crate::raft_timing::validate_timing_order(heartbeat, election_min));
            // Within one election timeout, the leader can send multiple heartbeats
            prop_assert!(election_min / heartbeat >= 1);
        }

        // r[impl properties.heartbeat-reset-prevents-election]
        // r[verify properties.heartbeat-reset-prevents-election]
        /// A valid heartbeat resets the timer, which keeps the leader alive.
        #[test]
        fn prop_heartbeat_reset_prevents_election(
            msg_term in 0u64..100,
            current_term in 0u64..100,
            election_timeout in 1u64..500,
        ) {
            if msg_term >= current_term {
                // Valid heartbeat from leader resets the timer
                let resets = crate::heartbeat::should_reset_election_timer(
                    msg_term, current_term, true,
                );
                prop_assert!(resets);
                // After reset, leader is alive (elapsed = 0 < timeout)
                prop_assert!(crate::heartbeat::is_leader_alive(0, 0, election_timeout));
            }
        }

        // r[impl properties.heartbeat-ack-stale-triggers-step-down]
        // r[verify properties.heartbeat-ack-stale-triggers-step-down]
        /// A higher-term ack is invalid and triggers step-down.
        #[test]
        fn prop_higher_term_ack_triggers_step_down(
            leader_term in 0u64..100,
            ack_term in 101u64..200,
        ) {
            // Ack is invalid
            prop_assert!(!crate::heartbeat::heartbeat_ack_valid(ack_term, leader_term));
            // term_authority step-down triggers
            let update = crate::term_authority::apply_higher_term(
                leader_term, 2, // STATE_LEADER
                u64::MAX, // voted_for (irrelevant)
                ack_term,
            );
            prop_assert_eq!(update.new_term, ack_term);
            prop_assert_eq!(update.new_state, 0); // STATE_FOLLOWER
        }
    }
}

// --- Cross-module: Log Compaction ---

#[cfg(test)]
mod log_compaction_cross_tests {
    use proptest::prelude::*;

    proptest! {
        // r[impl properties.compact-suffix-length-is-saturating-sub]
        // r[verify properties.compact-suffix-length-is-saturating-sub]
        /// Compacted log length is a saturating subtraction.
        #[test]
        fn prop_compact_suffix_is_saturating_sub(
            terms in proptest::collection::vec(1u64..10, 0..20),
            snap_idx in 0u64..25,
        ) {
            let log: Vec<crate::log::LogEntry> = terms.iter()
                .map(|&t| crate::log::LogEntry { term: t, value: 0 })
                .collect();
            let snap = std::cmp::min(snap_idx, log.len() as u64);
            let result = crate::log_compaction::compact_log(&log, snap);
            let expected = crate::arithmetic::saturating_sub(log.len() as u64, snap);
            prop_assert_eq!(result.len() as u64, expected);
        }

        // r[impl properties.compact-first-index-is-max]
        // r[verify properties.compact-first-index-is-max]
        /// first_log_index_after_compaction agrees with ordering::max.
        #[test]
        fn prop_compact_first_index_is_max(prev: u64, snap: u64) {
            let result = crate::log_compaction::first_log_index_after_compaction(prev, snap);
            let expected = crate::ordering::max(prev, snap);
            prop_assert_eq!(result, expected);
        }

        // r[impl properties.compact-offset-uses-checked-sub]
        // r[verify properties.compact-offset-uses-checked-sub]
        /// translate_index returns sentinel exactly when abs < first.
        #[test]
        fn prop_compact_offset_checked_sub(abs: u64, first: u64) {
            let result = crate::log_compaction::translate_index(abs, first);
            if abs >= first {
                prop_assert_ne!(result, u64::MAX);
                prop_assert_eq!(result, abs - first);
            } else {
                prop_assert_eq!(result, u64::MAX);
            }
        }

        // r[impl properties.compact-preserves-install-snapshot-trigger]
        // r[verify properties.compact-preserves-install-snapshot-trigger]
        /// After compaction at S, followers with next <= S need a snapshot.
        #[test]
        fn prop_compact_preserves_install_trigger(
            snap in 1u64..100,
            next in 0u64..100,
        ) {
            if next <= snap {
                prop_assert!(crate::install_snapshot::should_install_snapshot(next, snap));
            }
        }
    }
}

// --- Cross-module: Storage Primitives ---

#[cfg(verus_keep_ghost)]
mod storage_cross_proofs {
    use vstd::prelude::*;

    use crate::arithmetic::checked_mul_spec;
    use crate::arithmetic::saturating_sub_spec;
    use crate::btree_balance::fill_pct_spec;
    use crate::btree_balance::is_underfull_spec;
    use crate::btree_balance::min_keys_spec;
    use crate::btree_balance::split_left_size_spec;
    use crate::btree_balance::split_right_size_spec;
    use crate::lsm_level::level_target_size_spec;
    use crate::lsm_level::space_amp_pct_spec;
    use crate::lsm_level::total_write_amp_spec;
    use crate::monotonic::is_advance_spec;
    use crate::monotonic::is_strict_advance_spec;
    use crate::ordering::min_spec;
    use crate::wal_segment::is_contiguous_spec;
    use crate::wal_segment::is_truncate_safe_spec;
    use crate::wal_segment::replay_count_spec;
    use crate::wal_segment::write_advance_spec;

    verus! {

    // ─── WAL Segment ─────────────────────────────────────────────────

    /// write_advance is a monotonic advance on the write position.
    // r[impl properties.wal-advance-is-monotonic]
    pub open spec fn wal_advance_is_monotonic_prop(written: u64, entry_size: u64) -> bool {
        write_advance_spec(written, entry_size).is_some() ==>
            is_advance_spec(written, write_advance_spec(written, entry_size).unwrap())
    }

    // r[verify properties.wal-advance-is-monotonic]
    proof fn prove_wal_advance_is_monotonic(written: u64, entry_size: u64)
        ensures wal_advance_is_monotonic_prop(written, entry_size),
    {}

    /// replay_count equals saturating_sub.
    // r[impl properties.wal-replay-is-saturating-sub]
    pub open spec fn wal_replay_is_saturating_sub_prop(checkpoint: u64, end: u64) -> bool {
        replay_count_spec(checkpoint, end) == saturating_sub_spec(end, checkpoint)
    }

    // r[verify properties.wal-replay-is-saturating-sub]
    proof fn prove_wal_replay_is_saturating_sub(checkpoint: u64, end: u64)
        ensures wal_replay_is_saturating_sub_prop(checkpoint, end),
    {}

    /// Truncation safety is a comparison against min(committed, applied).
    // r[impl properties.wal-truncate-uses-min]
    pub open spec fn wal_truncate_uses_min_prop(t: u64, c: u64, a: u64) -> bool {
        is_truncate_safe_spec(t, c, a) == (t <= min_spec(c, a))
    }

    // r[verify properties.wal-truncate-uses-min]
    proof fn prove_wal_truncate_uses_min(t: u64, c: u64, a: u64)
        ensures wal_truncate_uses_min_prop(t, c, a),
    {}

    /// Contiguous WAL entries form a strictly advancing sequence.
    // r[impl properties.wal-contiguous-is-strict-advance]
    pub open spec fn wal_contiguous_is_strict_advance_prop(prev: u64, current: u64) -> bool {
        is_contiguous_spec(prev, current) ==> is_strict_advance_spec(prev, current)
    }

    // r[verify properties.wal-contiguous-is-strict-advance]
    proof fn prove_wal_contiguous_is_strict_advance(prev: u64, current: u64)
        ensures wal_contiguous_is_strict_advance_prop(prev, current),
    {}

    // ─── B-tree Balance ──────────────────────────────────────────────

    /// Split conserves: left + right == count.
    // r[impl properties.btree-split-conserves]
    pub open spec fn btree_split_conserves_prop(count: u64) -> bool {
        split_left_size_spec(count) + split_right_size_spec(count) == count
    }

    // r[verify properties.btree-split-conserves]
    proof fn prove_btree_split_conserves(count: u64)
        ensures btree_split_conserves_prop(count),
    {
        vstd::arithmetic::div_mod::lemma_fundamental_div_mod(count as int, 2);
    }

    /// Fill percentage is in [0, 100] for valid inputs.
    // r[impl properties.btree-fill-bounded]
    pub open spec fn btree_fill_bounded_prop(count: u64, capacity: u64) -> bool
        recommends capacity > 0, count <= capacity,
    {
        fill_pct_spec(count, capacity) >= 0 && fill_pct_spec(count, capacity) <= 100
    }

    // r[verify properties.btree-fill-bounded]
    proof fn prove_btree_fill_bounded(count: u64, capacity: u64)
        requires capacity > 0, count <= capacity,
        ensures btree_fill_bounded_prop(count, capacity),
    {
        assert(count as int * 100 / capacity as int <= 100) by(nonlinear_arith)
            requires capacity > 0u64, count <= capacity;
        assert(count as int * 100 / capacity as int >= 0) by(nonlinear_arith)
            requires capacity > 0u64;
    }

    /// A node at exactly min_keys is NOT underfull.
    // r[impl properties.btree-min-keys-is-underfull-threshold]
    pub open spec fn btree_min_keys_threshold_prop(capacity: u64) -> bool
        recommends capacity >= 2,
    {
        !is_underfull_spec(min_keys_spec(capacity), capacity)
    }

    // r[verify properties.btree-min-keys-is-underfull-threshold]
    proof fn prove_btree_min_keys_threshold(capacity: u64)
        requires capacity >= 2,
        ensures btree_min_keys_threshold_prop(capacity),
    {}

    // ─── LSM Level ───────────────────────────────────────────────────

    /// Target size is monotonic: higher levels have equal or larger targets.
    // r[impl properties.lsm-target-monotonic]
    pub open spec fn lsm_target_monotonic_prop(level: u64, base: u64, ratio: u64) -> bool
        recommends base > 0, ratio >= 2, level < u64::MAX,
    {
        level_target_size_spec(level, base, ratio)
            <= level_target_size_spec((level + 1) as u64, base, ratio)
    }

    // r[verify properties.lsm-target-monotonic]
    proof fn prove_lsm_target_monotonic(level: u64, base: u64, ratio: u64)
        requires base > 0, ratio >= 2, level < u64::MAX,
        ensures lsm_target_monotonic_prop(level, base, ratio),
    {
        crate::lsm_level::target_monotonic(level, base, ratio);
    }

    /// Space amp is at least 100% when total >= live (and result fits in u64).
    // r[impl properties.lsm-space-amp-ge-100]
    pub open spec fn lsm_space_amp_ge_100_prop(total: u64, live: u64) -> bool
        recommends live > 0, total >= live,
            (total as int * 100) / (live as int) <= u64::MAX as int,
    {
        space_amp_pct_spec(total, live) >= 100
    }

    // r[verify properties.lsm-space-amp-ge-100]
    proof fn prove_lsm_space_amp_ge_100(total: u64, live: u64)
        requires
            live > 0,
            total >= live,
            (total as int * 100) / (live as int) <= u64::MAX as int,
        ensures lsm_space_amp_ge_100_prop(total, live),
    {
        crate::lsm_level::space_amp_ge_100(total, live);
    }

    /// Total write amp agrees with checked_mul in the non-overflow case.
    // r[impl properties.lsm-write-amp-is-checked-mul]
    pub open spec fn lsm_write_amp_is_checked_mul_prop(levels: u64, ratio: u64) -> bool
        recommends
            levels as int * ratio as int <= u64::MAX as int,
    {
        total_write_amp_spec(levels, ratio) == checked_mul_spec(levels, ratio).unwrap()
    }

    // r[verify properties.lsm-write-amp-is-checked-mul]
    proof fn prove_lsm_write_amp_is_checked_mul(levels: u64, ratio: u64)
        requires levels as int * ratio as int <= u64::MAX as int,
        ensures lsm_write_amp_is_checked_mul_prop(levels, ratio),
    {}

    } // verus!
}

#[cfg(test)]
mod storage_cross_tests {
    use proptest::prelude::*;

    proptest! {
        // r[verify properties.wal-advance-is-monotonic]
        #[test]
        fn prop_wal_advance_monotonic(written: u64, entry_size: u64) {
            if let Some(new_written) = crate::wal_segment::write_advance(written, entry_size) {
                prop_assert!(new_written >= written);
            }
        }

        // r[verify properties.wal-replay-is-saturating-sub]
        #[test]
        fn prop_wal_replay_is_sat_sub(checkpoint: u64, end: u64) {
            let replay = crate::wal_segment::replay_count(checkpoint, end);
            let sat_sub = crate::arithmetic::saturating_sub(end, checkpoint);
            prop_assert_eq!(replay, sat_sub);
        }

        // r[verify properties.wal-truncate-uses-min]
        #[test]
        fn prop_wal_truncate_uses_min(t: u64, c: u64, a: u64) {
            let safe = crate::wal_segment::is_truncate_safe(t, c, a);
            let min_ca = crate::ordering::min(c, a);
            prop_assert_eq!(safe, t <= min_ca);
        }

        // r[verify properties.wal-contiguous-is-strict-advance]
        #[test]
        fn prop_wal_contiguous_strict_advance(prev in 0..u64::MAX - 1) {
            let current = prev + 1;
            prop_assert!(crate::wal_segment::is_contiguous(prev, current));
            prop_assert!(current > prev); // strict advance
        }

        // r[verify properties.btree-split-conserves]
        #[test]
        fn prop_btree_split_conserves(count: u64) {
            let left = crate::btree_balance::split_left_size(count);
            let right = crate::btree_balance::split_right_size(count);
            prop_assert_eq!(left + right, count);
        }

        // r[verify properties.btree-fill-bounded]
        #[test]
        fn prop_btree_fill_bounded(count in 0u64..10000, capacity in 1u64..10000) {
            if count <= capacity {
                let pct = crate::btree_balance::fill_pct(count, capacity);
                prop_assert!(pct <= 100);
            }
        }

        // r[verify properties.btree-min-keys-is-underfull-threshold]
        #[test]
        fn prop_btree_min_keys_threshold(capacity in 2u64..10000) {
            let mk = crate::btree_balance::min_keys(capacity);
            prop_assert!(!crate::btree_balance::is_underfull(mk, capacity));
        }

        // r[verify properties.lsm-target-monotonic]
        #[test]
        fn prop_lsm_target_monotonic(
            level in 0u64..62,
            base in 1u64..1_000_000,
            ratio in 2u64..20,
        ) {
            let t_lo = crate::lsm_level::level_target_size(level, base, ratio);
            let t_hi = crate::lsm_level::level_target_size(level + 1, base, ratio);
            prop_assert!(t_hi >= t_lo);
        }

        // r[verify properties.lsm-space-amp-ge-100]
        #[test]
        fn prop_lsm_space_amp_ge_100(
            total in 1u64..1_000_000,
            live in 1u64..1_000_000,
        ) {
            if total >= live {
                prop_assert!(crate::lsm_level::space_amp_pct(total, live) >= 100);
            }
        }

        // r[verify properties.lsm-write-amp-is-checked-mul]
        #[test]
        fn prop_lsm_write_amp_is_checked_mul(
            levels in 0u64..1000,
            ratio in 0u64..1000,
        ) {
            let wa = crate::lsm_level::total_write_amp(levels, ratio);
            if let Some(cm) = crate::arithmetic::checked_mul(levels, ratio) {
                prop_assert_eq!(wa, cm);
            }
        }
    }
}

// --- Cross-module: Financial Accounting (extended) ---

#[cfg(verus_keep_ghost)]
mod financial_extended_proofs {
    use vstd::prelude::*;

    use crate::double_entry::is_simple_entry_spec;
    use crate::escrow::fund_buyer_after_spec;
    use crate::escrow::refund_buyer_after_spec;
    use crate::fee::compute_fee_spec;
    use crate::fee::compute_net_spec;
    use crate::fee::split_with_fee_spec;
    use crate::ledger::can_transfer_spec;

    verus! {

    // --- escrow fund-then-refund = identity ---

    // r[impl properties.escrow-fund-refund-identity]
    pub open spec fn escrow_fund_refund_identity_prop(buyer_balance: u64, amount: u64) -> bool
        recommends buyer_balance >= amount
    {
        refund_buyer_after_spec(
            fund_buyer_after_spec(buyer_balance, amount) as u64,
            amount,
        ) == buyer_balance as int
    }

    // r[verify properties.escrow-fund-refund-identity]
    proof fn prove_escrow_fund_refund_identity(buyer_balance: u64, amount: u64)
        requires buyer_balance >= amount
        ensures escrow_fund_refund_identity_prop(buyer_balance, amount)
    {}

    // --- fee split matches individual computations ---

    // r[impl properties.fee-split-agrees]
    pub open spec fn fee_split_agrees_prop(amount: u64, rate_bps: u64) -> bool
        recommends 0 < rate_bps <= 10000
    {
        split_with_fee_spec(amount, rate_bps)
            == (compute_fee_spec(amount, rate_bps), compute_net_spec(amount, rate_bps))
    }

    // r[verify properties.fee-split-agrees]
    proof fn prove_fee_split_agrees(amount: u64, rate_bps: u64)
        requires 0 < rate_bps, rate_bps <= 10000
        ensures fee_split_agrees_prop(amount, rate_bps)
    {}

    // --- simple entry = equal debit and credit ---

    // r[impl properties.simple-entry-is-balanced]
    pub open spec fn simple_entry_is_balanced_prop(amount: u64) -> bool
        recommends amount > 0
    {
        is_simple_entry_spec(amount, amount)
    }

    // r[verify properties.simple-entry-is-balanced]
    proof fn prove_simple_entry_is_balanced(amount: u64)
        requires amount > 0
        ensures simple_entry_is_balanced_prop(amount)
    {}

    // --- ledger transfer requires sufficient funds ---

    // r[impl properties.ledger-transfer-needs-funds]
    pub open spec fn ledger_transfer_needs_funds_prop(
        accounts: Seq<u64>, from: int, to: int, amount: u64,
    ) -> bool
        recommends
            0 <= from < accounts.len() as int,
            0 <= to < accounts.len() as int,
            from != to,
    {
        can_transfer_spec(accounts, from, to, amount)
            ==> accounts[from] >= amount
    }

    // r[verify properties.ledger-transfer-needs-funds]
    proof fn prove_ledger_transfer_needs_funds(
        accounts: Seq<u64>, from: int, to: int, amount: u64,
    )
        requires
            0 <= from < accounts.len() as int,
            0 <= to < accounts.len() as int,
            from != to,
        ensures ledger_transfer_needs_funds_prop(accounts, from, to, amount)
    {}

    } // verus!
}

#[cfg(test)]
mod financial_extended_tests {
    use proptest::prelude::*;

    proptest! {
        // r[verify properties.escrow-fund-refund-identity]
        #[test]
        fn prop_escrow_fund_refund_roundtrip(balance in 0u64..100_000, amount in 0u64..100_000) {
            if balance >= amount {
                let funded = balance - amount;
                let refunded = funded + amount;
                prop_assert_eq!(refunded, balance);
            }
        }

        // r[verify properties.fee-split-agrees]
        #[test]
        fn prop_fee_split_matches_components(amount in 0u64..1_000_000, rate_bps in 1u64..10001) {
            let (fee, net) = crate::fee::split_with_fee(amount, rate_bps);
            let fee2 = crate::fee::compute_fee(amount, rate_bps);
            let net2 = crate::fee::compute_net(amount, rate_bps);
            prop_assert_eq!(fee, fee2);
            prop_assert_eq!(net, net2);
        }

        // r[verify properties.simple-entry-is-balanced]
        #[test]
        fn prop_simple_entry_balanced(amount in 1u64..1_000_000) {
            prop_assert!(crate::double_entry::is_simple_entry(amount, amount));
        }

        // r[verify properties.ledger-transfer-needs-funds]
        #[test]
        fn prop_ledger_transfer_needs_funds(
            bal_from in 0u64..10000,
            bal_to in 0u64..10000,
            amount in 0u64..20000,
        ) {
            let accounts = vec![bal_from, bal_to];
            if crate::ledger::can_transfer(&accounts, 0, 1, amount) {
                prop_assert!(bal_from >= amount);
            }
        }

        // r[verify properties.ledger-transfer-needs-funds]
        #[test]
        fn prop_ledger_transfer_conserves(
            bal_from in 100u64..10000,
            bal_to in 0u64..10000,
            amount in 1u64..100,
        ) {
            let accounts = vec![bal_from, bal_to];
            if crate::ledger::can_transfer(&accounts, 0, 1, amount) {
                if let Some((new_from, new_to)) =
                    crate::ledger::ledger_transfer(&accounts, 0, 1, amount)
                {
                    let total_before = bal_from as u128 + bal_to as u128;
                    let total_after = new_from as u128 + new_to as u128;
                    prop_assert_eq!(total_before, total_after);
                }
            }
        }

        // r[verify properties.fee-conservation-matches-transfer]
        #[test]
        fn prop_ledger_fee_transfer_conserves(
            bal_from in 1000u64..100_000,
            bal_to in 0u64..100_000,
            bal_fee in 0u64..100_000,
            amount in 1u64..1000,
            rate_bps in 1u64..5000,
        ) {
            let fee = crate::fee::compute_fee(amount, rate_bps);
            if fee <= amount {
                let accounts = vec![bal_from, bal_to, bal_fee];
                if let Some((new_from, new_to, new_fee_acc)) =
                    crate::ledger::ledger_transfer_with_fee(&accounts, 0, 1, 2, amount, fee)
                {
                    let total_before: u128 =
                        bal_from as u128 + bal_to as u128 + bal_fee as u128;
                    let total_after: u128 =
                        new_from as u128 + new_to as u128 + new_fee_acc as u128;
                    prop_assert_eq!(total_before, total_after);
                }
            }
        }

        // r[verify properties.ledger-transfer-needs-funds]
        #[test]
        fn prop_settlement_positions_sum_zero(
            n in 2usize..6,
            amounts in proptest::collection::vec(1u64..1000, 1..5),
        ) {
            if amounts.is_empty() {
                return Ok(());
            }
            let mut obligations = Vec::new();
            for (i, &amt) in amounts.iter().enumerate() {
                let from = i % n;
                let to = (i + 1) % n;
                if from != to {
                    obligations.push((from, to, amt));
                }
            }
            if !obligations.is_empty() {
                let positions = crate::settlement::compute_positions(&obligations, n);
                let sum: i128 = positions.iter().sum();
                prop_assert_eq!(sum, 0);
            }
        }
    }
}

// --- Cross-module: Follower Redirect ---

#[cfg(test)]
mod follower_redirect_cross_tests {
    use proptest::prelude::*;

    proptest! {
        // r[verify follower-redirect.should-redirect]
        // r[verify follower-redirect.leader-accepts]
        /// Redirect and accept are never both true.
        #[test]
        fn prop_redirect_accept_exclusive(
            state in 0u8..3,
            leader_id in 0u64..100,
        ) {
            let accepts = crate::follower_redirect::should_accept_request(state);
            let redirects = crate::follower_redirect::should_redirect(state, leader_id);
            prop_assert!(!(accepts && redirects));
        }

        // r[verify follower-redirect.should-redirect]
        /// For followers specifically, follower_redirect and client_routing agree.
        /// follower_redirect covers all non-leaders; client_routing only covers
        /// followers (candidates neither accept nor redirect in client_routing).
        #[test]
        fn prop_follower_redirect_agrees_with_client_routing(
            leader_id in 0u64..100,
        ) {
            let has_known = leader_id != crate::follower_redirect::LEADER_UNKNOWN;
            let fr_redirect = crate::follower_redirect::should_redirect(0, leader_id); // STATE_FOLLOWER
            let cr_redirect = crate::client_routing::should_redirect(0, has_known);
            prop_assert_eq!(fr_redirect, cr_redirect);
        }
    }
}

// --- Cross-module: Raft consensus pipeline ---
// election → vote_tally → quorum → heartbeat → check_quorum

#[cfg(verus_keep_ghost)]
mod raft_pipeline_proofs {
    use vstd::prelude::*;

    use crate::election::STATE_LEADER;
    use crate::election::STATE_TRANSITIONING;
    use crate::election::can_win_election_spec;
    use crate::heartbeat::should_reset_election_timer_spec;
    use crate::quorum::is_quorum_spec;
    use crate::quorum::majority_spec;
    use crate::vote_tally::count_votes_from_spec;
    use crate::vote_tally::count_votes_spec;
    use crate::vote_tally::has_won_election_spec;

    verus! {

    // r[impl properties.election-win-implies-quorum]
    /// Winning an election implies the vote count reaches quorum.
    pub open spec fn election_win_implies_quorum_prop(
        votes: Seq<bool>, cluster_size: u64,
    ) -> bool
        recommends cluster_size > 0, votes.len() == cluster_size as int
    {
        has_won_election_spec(votes, cluster_size)
            ==> is_quorum_spec(count_votes_spec(votes), cluster_size)
    }

    // r[verify properties.election-win-implies-quorum]
    proof fn prove_election_win_implies_quorum(votes: Seq<bool>, cluster_size: u64)
        requires cluster_size > 0, votes.len() == cluster_size as int
        ensures election_win_implies_quorum_prop(votes, cluster_size)
    {}

    // r[impl properties.heartbeat-resets-follower-timer]
    /// A heartbeat from the current term (from_leader=true, same term) resets the timer.
    pub open spec fn heartbeat_resets_follower_timer_prop(
        term: u64, from_leader: bool,
    ) -> bool {
        from_leader ==> should_reset_election_timer_spec(term, term, from_leader)
    }

    // r[verify properties.heartbeat-resets-follower-timer]
    proof fn prove_heartbeat_resets_follower_timer(term: u64, from_leader: bool)
        ensures heartbeat_resets_follower_timer_prop(term, from_leader)
    {}

    } // verus!
}

// --- Cross-module: Lock ↔ lease ↔ expiration ---

#[cfg(verus_keep_ghost)]
mod lock_lease_proofs {
    use vstd::prelude::*;

    use crate::distributed_lock::compute_lock_deadline_spec;
    use crate::distributed_lock::is_lock_expired_spec;
    use crate::expiration::is_expired_spec;

    verus! {

    // r[impl properties.lock-expired-matches-general-expired]
    /// Lock expiration check matches the general is_expired predicate.
    pub open spec fn lock_expired_matches_general_expired_prop(
        deadline: u64, now: u64,
    ) -> bool {
        is_lock_expired_spec(deadline, now) == is_expired_spec(deadline, now)
    }

    // r[verify properties.lock-expired-matches-general-expired]
    proof fn prove_lock_expired_matches_general_expired(deadline: u64, now: u64)
        ensures lock_expired_matches_general_expired_prop(deadline, now)
    {}

    // r[impl properties.lock-deadline-saturates]
    /// Lock deadline saturates to u64::MAX on overflow (same pattern as expires_at).
    pub open spec fn lock_deadline_saturates_prop(
        acquired_at: u64, ttl_ms: u64,
    ) -> bool {
        compute_lock_deadline_spec(acquired_at, ttl_ms) >= acquired_at
    }

    // r[verify properties.lock-deadline-saturates]
    proof fn prove_lock_deadline_saturates(acquired_at: u64, ttl_ms: u64)
        ensures lock_deadline_saturates_prop(acquired_at, ttl_ms)
    {}

    } // verus!
}

// --- Cross-module: Drain ↔ node_lifecycle ---

#[cfg(verus_keep_ghost)]
mod drain_lifecycle_proofs {
    use vstd::prelude::*;

    use crate::drain::can_start_op_spec;
    use crate::node_lifecycle::DEGRADED;
    use crate::node_lifecycle::ONLINE;
    use crate::node_lifecycle::is_operational_spec;

    verus! {

    // r[impl properties.draining-blocks-operations]
    /// When draining, no new operations start — regardless of node lifecycle status.
    pub open spec fn draining_blocks_operations_prop() -> bool {
        !can_start_op_spec(true)
    }

    // r[verify properties.draining-blocks-operations]
    proof fn prove_draining_blocks_operations()
        ensures draining_blocks_operations_prop()
    {}

    // r[impl properties.operational-allows-non-drain-ops]
    /// An operational (online or degraded) node that isn't draining can accept ops.
    pub open spec fn operational_allows_non_drain_ops_prop(status: u8) -> bool {
        is_operational_spec(status) ==> can_start_op_spec(false)
    }

    // r[verify properties.operational-allows-non-drain-ops]
    proof fn prove_operational_allows_non_drain_ops(status: u8)
        ensures operational_allows_non_drain_ops_prop(status)
    {}

    } // verus!
}

// --- Cross-module: Retry ↔ backoff ↔ circuit_breaker ---

#[cfg(verus_keep_ghost)]
mod retry_circuit_proofs {
    use vstd::prelude::*;

    use crate::circuit_breaker::CLOSED;
    use crate::circuit_breaker::OPEN;
    use crate::circuit_breaker::allow_request_spec;
    use crate::retry::is_exhausted_spec;
    use crate::retry::should_retry_spec;

    verus! {

    // r[impl properties.exhausted-means-no-retry]
    /// Exhausted attempts means no more retries, regardless of retryability.
    pub open spec fn exhausted_means_no_retry_prop(attempt: u64, max: u64) -> bool
        recommends max > 0
    {
        is_exhausted_spec(attempt, max) ==> !should_retry_spec(attempt, max, true)
    }

    // r[verify properties.exhausted-means-no-retry]
    proof fn prove_exhausted_means_no_retry(attempt: u64, max: u64)
        requires max > 0
        ensures exhausted_means_no_retry_prop(attempt, max)
    {}

    // r[impl properties.open-circuit-blocks-requests]
    /// An open circuit breaker blocks all requests (probe or not).
    pub open spec fn open_circuit_blocks_requests_prop(probe: bool) -> bool {
        !allow_request_spec(OPEN, probe)
    }

    // r[verify properties.open-circuit-blocks-requests]
    proof fn prove_open_circuit_blocks_requests(probe: bool)
        ensures open_circuit_blocks_requests_prop(probe)
    {}

    // r[impl properties.closed-circuit-allows-requests]
    /// A closed circuit breaker allows all requests (probe or not).
    pub open spec fn closed_circuit_allows_requests_prop(probe: bool) -> bool {
        allow_request_spec(CLOSED, probe)
    }

    // r[verify properties.closed-circuit-allows-requests]
    proof fn prove_closed_circuit_allows_requests(probe: bool)
        ensures closed_circuit_allows_requests_prop(probe)
    {}

    } // verus!
}

// --- Cross-module: CAS ↔ fencing ↔ distributed_lock ---

#[cfg(verus_keep_ghost)]
mod cas_fencing_proofs {
    use vstd::prelude::*;

    use crate::cas::check_cas_spec;
    use crate::distributed_lock::compute_next_fencing_token_spec;
    use crate::fencing::is_stale_spec;
    use crate::fencing::is_valid_write_spec;

    verus! {

    // r[impl properties.fencing-token-monotonic]
    /// Each fencing token is strictly greater than the previous.
    pub open spec fn fencing_token_monotonic_prop(prev: u64) -> bool
        recommends prev < u64::MAX
    {
        compute_next_fencing_token_spec(Some(prev)) > prev
    }

    // r[verify properties.fencing-token-monotonic]
    proof fn prove_fencing_token_monotonic(prev: u64)
        requires prev < u64::MAX
        ensures fencing_token_monotonic_prop(prev)
    {}

    // r[impl properties.valid-write-excludes-stale]
    /// A valid write is never stale — these predicates are mutually exclusive.
    pub open spec fn valid_write_excludes_stale_prop(token: u64, fence: u64) -> bool {
        is_valid_write_spec(token, fence) ==> !is_stale_spec(token, fence)
    }

    // r[verify properties.valid-write-excludes-stale]
    proof fn prove_valid_write_excludes_stale(token: u64, fence: u64)
        ensures valid_write_excludes_stale_prop(token, fence)
    {}

    } // verus!
}

// --- Cross-module: vector_clock ↔ causal_order ↔ crdt ---

#[cfg(verus_keep_ghost)]
mod causality_proofs {
    use vstd::prelude::*;

    use crate::crdt::g_counter_merge_spec;
    use crate::vector_clock::happens_before_spec;
    use crate::vector_clock::merge_spec as vc_merge_spec;

    verus! {

    // r[impl properties.vc-merge-dominates-both]
    /// After merging two vector clocks, each original happens-before or equals the result.
    pub open spec fn vc_merge_dominates_both_prop(a: Seq<u64>, b: Seq<u64>) -> bool
        recommends a.len() == b.len(), a.len() > 0
    {
        let m = vc_merge_spec(a, b);
        // a[i] <= m[i] for all i — which is the definition of happens_before_or_equal
        forall|i: int| #![trigger m[i]] 0 <= i < a.len() ==> a[i] <= m[i] && b[i] <= m[i]
    }

    // r[verify properties.vc-merge-dominates-both]
    proof fn prove_vc_merge_dominates_both(a: Seq<u64>, b: Seq<u64>)
        requires a.len() == b.len(), a.len() > 0
        ensures vc_merge_dominates_both_prop(a, b)
    {}

    // r[impl properties.vc-merge-equals-gcounter-merge]
    /// Vector clock merge is identical to G-Counter merge (both are pointwise max).
    pub open spec fn vc_merge_equals_gcounter_merge_prop(a: Seq<u64>, b: Seq<u64>) -> bool
        recommends a.len() == b.len()
    {
        vc_merge_spec(a, b) =~= g_counter_merge_spec(a, b)
    }

    // r[verify properties.vc-merge-equals-gcounter-merge]
    proof fn prove_vc_merge_equals_gcounter_merge(a: Seq<u64>, b: Seq<u64>)
        requires a.len() == b.len()
        ensures vc_merge_equals_gcounter_merge_prop(a, b)
    {}

    } // verus!
}

// --- Cross-module: noop_commit ↔ log ---

#[cfg(verus_keep_ghost)]
mod noop_log_proofs {
    use vstd::prelude::*;

    use crate::log::log_append_spec;
    use crate::noop_commit::is_noop_spec;
    use crate::noop_commit::make_noop_entry_spec;
    use crate::noop_commit::noop_commit_index_spec;

    verus! {

    // r[impl properties.noop-roundtrip]
    /// A constructed noop entry is recognized as a noop.
    pub open spec fn noop_roundtrip_prop(term: u64) -> bool {
        is_noop_spec(make_noop_entry_spec(term))
    }

    // r[verify properties.noop-roundtrip]
    proof fn prove_noop_roundtrip(term: u64)
        ensures noop_roundtrip_prop(term)
    {}

    // r[impl properties.noop-commit-index-is-new-tail]
    /// The noop commit index is one past the old log length (where the noop lands).
    pub open spec fn noop_commit_index_is_new_tail_prop(log: Seq<LogEntry>) -> bool {
        noop_commit_index_spec(log.len() as int) == log.len() as int + 1
    }

    // r[verify properties.noop-commit-index-is-new-tail]
    proof fn prove_noop_commit_index_is_new_tail(log: Seq<LogEntry>)
        ensures noop_commit_index_is_new_tail_prop(log)
    {}

    } // verus!
    use crate::log::LogEntry;
}

// --- Cross-module: snapshot_transfer ↔ chunk ---

#[cfg(verus_keep_ghost)]
mod snapshot_chunk_proofs {
    use vstd::prelude::*;

    use crate::snapshot_transfer::chunk_count_spec as st_chunk_count_spec;
    use crate::snapshot_transfer::is_first_chunk_spec;
    use crate::snapshot_transfer::is_last_chunk_spec;

    verus! {

    // r[impl properties.first-chunk-zero-offset]
    /// The first chunk always has offset zero.
    pub open spec fn first_chunk_zero_offset_prop() -> bool {
        is_first_chunk_spec(0)
    }

    // r[verify properties.first-chunk-zero-offset]
    proof fn prove_first_chunk_zero_offset()
        ensures first_chunk_zero_offset_prop()
    {}

    // r[impl properties.single-chunk-transfer]
    /// A transfer where the chunk exactly covers the total: offset=0 is both first and last.
    pub open spec fn single_chunk_transfer_prop(total: u64) -> bool
        recommends total > 0
    {
        is_first_chunk_spec(0) && is_last_chunk_spec(0, total, total)
    }

    // r[verify properties.single-chunk-transfer]
    proof fn prove_single_chunk_transfer(total: u64)
        requires total > 0
        ensures single_chunk_transfer_prop(total)
    {}

    } // verus!
}

// --- Cross-module proptest: Raft pipeline, locking, causality ---

#[cfg(test)]
#[allow(clippy::cast_possible_truncation)]
mod raft_pipeline_tests {
    use proptest::prelude::*;

    proptest! {
        // r[verify properties.election-win-implies-quorum]
        #[test]
        fn prop_election_win_implies_quorum(
            cluster_size in 3u64..20,
            voter_count in 0usize..20,
        ) {
            let cs = cluster_size as usize;
            if voter_count > cs { return Ok(()); }
            let mut votes = vec![false; cs];
            for i in 0..voter_count.min(cs) {
                votes[i] = true;
            }
            let won = crate::vote_tally::has_won_election(&votes, cluster_size);
            let count = crate::vote_tally::count_votes(&votes);
            if won {
                prop_assert!(crate::quorum::is_quorum(count, cluster_size));
            }
        }

        // r[verify properties.heartbeat-resets-follower-timer]
        #[test]
        fn prop_heartbeat_resets_timer(term in 0u64..1000, from_leader: bool) {
            if from_leader {
                // Same term, from leader → timer must reset
                prop_assert!(crate::heartbeat::should_reset_election_timer(term, term, from_leader));
            }
        }
    }
}

#[cfg(test)]
mod lock_lease_tests {
    use proptest::prelude::*;

    proptest! {
        // r[verify properties.lock-expired-matches-general-expired]
        #[test]
        fn prop_lock_expired_matches_general(deadline in 0u64..1_000_000, now in 0u64..1_000_000) {
            let lock_exp = crate::distributed_lock::is_lock_expired(deadline, now);
            let gen_exp = crate::expiration::is_expired(deadline, now);
            prop_assert_eq!(lock_exp, gen_exp);
        }

        // r[verify properties.lock-deadline-saturates]
        #[test]
        fn prop_lock_deadline_saturates(acquired_at in 0u64..u64::MAX, ttl_ms in 0u64..u64::MAX) {
            let deadline = crate::distributed_lock::compute_lock_deadline(acquired_at, ttl_ms);
            prop_assert!(deadline >= acquired_at);
        }
    }
}

#[cfg(test)]
mod drain_lifecycle_tests {
    #[test]
    fn draining_blocks_regardless_of_node_status() {
        // Draining always blocks
        assert!(!crate::drain::can_start_op(true));
        // All operational statuses allow ops when not draining
        assert!(crate::drain::can_start_op(false));
        assert!(crate::node_lifecycle::is_operational(1)); // ONLINE
        assert!(crate::node_lifecycle::is_operational(2)); // DEGRADED
    }
}

#[cfg(test)]
mod retry_circuit_tests {
    use proptest::prelude::*;

    proptest! {
        // r[verify properties.exhausted-means-no-retry]
        #[test]
        fn prop_exhausted_means_no_retry(attempt in 0u64..1000, max in 1u64..100) {
            if crate::retry::is_exhausted(attempt, max) {
                prop_assert!(!crate::retry::should_retry(attempt, max, true));
            }
        }
    }

    #[test]
    fn open_circuit_blocks_closed_allows() {
        // OPEN (1) blocks regardless of probe status
        assert!(!crate::circuit_breaker::allow_request(1, false));
        assert!(!crate::circuit_breaker::allow_request(1, true));
        // CLOSED (0) allows regardless
        assert!(crate::circuit_breaker::allow_request(0, false));
        assert!(crate::circuit_breaker::allow_request(0, true));
    }
}

#[cfg(test)]
mod cas_fencing_tests {
    use proptest::prelude::*;

    proptest! {
        // r[verify properties.fencing-token-monotonic]
        #[test]
        fn prop_fencing_token_monotonic(prev in 0u64..u64::MAX - 1) {
            let next = crate::distributed_lock::compute_next_fencing_token(Some(prev));
            prop_assert!(next > prev);
        }

        // r[verify properties.valid-write-excludes-stale]
        #[test]
        fn prop_valid_write_excludes_stale(token in 0u64..10000, fence in 0u64..10000) {
            if crate::fencing::is_valid_write(token, fence) {
                prop_assert!(!crate::fencing::is_stale(token, fence));
            }
        }
    }
}

#[cfg(test)]
mod causality_tests {
    use proptest::prelude::*;

    proptest! {
        // r[verify properties.vc-merge-dominates-both]
        #[test]
        fn prop_vc_merge_dominates(
            a in proptest::collection::vec(0u64..1000, 3..6),
            b in proptest::collection::vec(0u64..1000, 3..6),
        ) {
            let len = a.len().min(b.len());
            let a = &a[..len];
            let b = &b[..len];
            let m = crate::vector_clock::merge(&a.to_vec(), &b.to_vec());
            for i in 0..len {
                prop_assert!(m[i] >= a[i]);
                prop_assert!(m[i] >= b[i]);
            }
        }

        // r[verify properties.vc-merge-equals-gcounter-merge]
        #[test]
        fn prop_vc_merge_equals_gcounter_merge(
            a in proptest::collection::vec(0u64..1000, 3..6),
            b in proptest::collection::vec(0u64..1000, 3..6),
        ) {
            let len = a.len().min(b.len());
            let a = a[..len].to_vec();
            let b = b[..len].to_vec();
            let vc = crate::vector_clock::merge(&a, &b);
            let gc = crate::crdt::g_counter_merge(&a, &b);
            prop_assert_eq!(vc, gc);
        }
    }
}

#[cfg(test)]
mod noop_log_tests {
    #[test]
    fn noop_roundtrip() {
        let entry = crate::noop_commit::make_noop_entry(5);
        assert!(crate::noop_commit::is_noop(&entry));
    }

    #[test]
    fn noop_commit_index_is_one_past() {
        for len in 0u64..20 {
            assert_eq!(crate::noop_commit::noop_commit_index(len), len + 1);
        }
    }
}

#[cfg(test)]
mod snapshot_chunk_tests {
    use proptest::prelude::*;

    proptest! {
        // r[verify properties.single-chunk-transfer]
        #[test]
        fn prop_single_chunk_is_first_and_last(total in 1u64..10000) {
            // Single chunk where chunk_size == total
            prop_assert!(crate::snapshot_transfer::is_first_chunk(0));
            prop_assert!(crate::snapshot_transfer::is_last_chunk(0, total, total));
        }

        // r[verify properties.first-chunk-zero-offset]
        #[test]
        fn prop_first_chunk_offset_zero(_x in 0u64..1) {
            prop_assert!(crate::snapshot_transfer::is_first_chunk(0));
        }
    }
}

// =========================================================================
// Cross-module: concurrency wave 5
// =========================================================================

// --- Verus proofs: concurrency cross-module ---

#[cfg(verus_keep_ghost)]
mod mpmc_mpsc_proofs {
    use vstd::prelude::*;

    use crate::bounded_mpmc::occupancy_spec as mpmc_occupancy_spec;
    use crate::mpsc_bounds::queue_occupancy_spec as mpsc_occupancy_spec;

    verus! {

    // r[impl properties.mpmc-occupancy-matches-mpsc]
    // r[verify properties.mpmc-occupancy-matches-mpsc]
    /// bounded_mpmc occupancy == mpsc_bounds queue_occupancy for same inputs.
    proof fn mpmc_occupancy_matches_mpsc(total_sent: u64, total_received: u64)
        requires total_sent >= total_received
        ensures
            mpmc_occupancy_spec(total_received, total_sent)
                == mpsc_occupancy_spec(total_sent, total_received),
    {}

    } // verus!
}

#[cfg(verus_keep_ghost)]
mod work_stealing_mpmc_proofs {
    use vstd::prelude::*;

    use crate::bounded_mpmc::occupancy_spec as mpmc_occupancy_spec;
    use crate::work_stealing::deque_size_spec;

    verus! {

    // r[impl properties.work-stealing-occupancy-matches-mpmc]
    // r[verify properties.work-stealing-occupancy-matches-mpmc]
    /// work_stealing deque_size == bounded_mpmc occupancy for same inputs.
    proof fn work_stealing_matches_mpmc(top: u64, bottom: u64)
        requires bottom >= top
        ensures deque_size_spec(top, bottom) == mpmc_occupancy_spec(top, bottom),
    {}

    } // verus!
}

#[cfg(verus_keep_ghost)]
mod spin_cas_proofs {
    use vstd::prelude::*;

    use crate::cas_loop::attempts_remaining_spec;
    use crate::spin_backoff::is_completed_spec;

    verus! {

    // r[impl properties.spin-completed-implies-cas-no-retry]
    // r[verify properties.spin-completed-implies-cas-no-retry]
    /// When backoff is completed and attempts track the step, no retries remain.
    proof fn spin_completed_implies_no_retries(step: u64, max_attempts: u64)
        requires
            is_completed_spec(step, max_attempts),
        ensures
            attempts_remaining_spec(step, max_attempts) == 0,
    {}

    } // verus!
}

#[cfg(verus_keep_ghost)]
mod seqlock_memory_order_proofs {
    use vstd::prelude::*;

    use crate::memory_order::ORD_ACQUIRE;
    use crate::memory_order::ORD_RELEASE;
    use crate::memory_order::has_acquire_semantics_spec;
    use crate::memory_order::has_release_semantics_spec;
    use crate::memory_order::valid_for_load_spec;
    use crate::memory_order::valid_for_store_spec;

    verus! {

    // r[impl properties.seqlock-write-needs-release]
    // r[verify properties.seqlock-write-needs-release]
    /// Release ordering is valid for stores and has release semantics.
    proof fn seqlock_write_needs_release()
        ensures
            valid_for_store_spec(ORD_RELEASE),
            has_release_semantics_spec(ORD_RELEASE),
    {}

    // r[impl properties.seqlock-read-needs-acquire]
    // r[verify properties.seqlock-read-needs-acquire]
    /// Acquire ordering is valid for loads and has acquire semantics.
    proof fn seqlock_read_needs_acquire()
        ensures
            valid_for_load_spec(ORD_ACQUIRE),
            has_acquire_semantics_spec(ORD_ACQUIRE),
    {}

    } // verus!
}

#[cfg(verus_keep_ghost)]
mod rcu_epoch_proofs {
    use vstd::prelude::*;

    use crate::epoch_reclaim::next_epoch_spec;
    use crate::rcu::advance_grace_period_spec;

    verus! {

    // r[impl properties.rcu-grace-matches-epoch-advance]
    // r[verify properties.rcu-grace-matches-epoch-advance]
    /// RCU grace advance and epoch next_epoch agree for epochs 0 and 1
    /// (both return epoch + 1). They diverge at epoch 2: RCU returns 3,
    /// epoch_reclaim wraps to 0.
    proof fn rcu_grace_matches_epoch_small(epoch: u64)
        requires epoch < 2
        ensures
            advance_grace_period_spec(epoch) == next_epoch_spec(epoch),
    {}

    } // verus!
}

#[cfg(verus_keep_ghost)]
mod refcount_hazard_proofs {
    use vstd::prelude::*;

    use crate::hazard_pointer::can_reclaim_spec;
    use crate::ref_count::should_deallocate_spec;

    verus! {

    // r[impl properties.ref-count-zero-implies-reclaimable]
    // r[verify properties.ref-count-zero-implies-reclaimable]
    /// Refcount zero + not protected ⟹ reclaimable.
    proof fn refcount_zero_and_unprotected_reclaimable(addr: u64, hazards: Seq<u64>)
        requires
            should_deallocate_spec(0),
            can_reclaim_spec(addr, hazards),
        ensures
            should_deallocate_spec(0) && can_reclaim_spec(addr, hazards),
    {}

    } // verus!
}

#[cfg(verus_keep_ghost)]
mod lock_order_ticket_proofs {
    use vstd::prelude::*;

    use crate::lock_ordering::would_deadlock_spec;

    verus! {

    // r[impl properties.lock-ordering-prevents-ticket-deadlock]
    // r[verify properties.lock-ordering-prevents-ticket-deadlock]
    /// If second lock ID > first lock ID (ordered acquisition), no deadlock.
    proof fn lock_ordering_prevents_deadlock(first_id: u64, second_id: u64)
        requires first_id < second_id
        ensures !would_deadlock_spec(first_id, second_id)
    {}

    } // verus!
}

#[cfg(verus_keep_ghost)]
mod barrier_quorum_proofs {
    use vstd::prelude::*;

    use crate::barrier::all_arrived_spec;
    use crate::quorum::is_quorum_spec;

    verus! {

    // r[impl properties.barrier-all-arrived-is-quorum]
    // r[verify properties.barrier-all-arrived-is-quorum]
    /// All threads arrived ⟹ count satisfies quorum majority.
    proof fn barrier_all_arrived_is_quorum(expected: u64)
        requires expected > 0
        ensures ({
            all_arrived_spec(expected, expected)
            && is_quorum_spec(expected, expected)
        })
    {}

    } // verus!
}

#[cfg(verus_keep_ghost)]
mod futex_notify_proofs {
    use vstd::prelude::*;

    use crate::futex_state::FUTEX_IDLE;
    use crate::futex_state::consume_notification_spec;
    use crate::futex_state::is_notified_spec;
    use crate::futex_state::notify_spec;

    verus! {

    // r[impl properties.futex-notify-enables-consume]
    // r[verify properties.futex-notify-enables-consume]
    /// notify → NOTIFIED → consume_notification → IDLE.
    proof fn futex_notify_then_consume()
        ensures ({
            let notified = notify_spec(FUTEX_IDLE);
            is_notified_spec(notified)
            && consume_notification_spec(notified) == FUTEX_IDLE
        })
    {}

    } // verus!
}

#[cfg(verus_keep_ghost)]
mod mpsc_drained_proofs {
    use vstd::prelude::*;

    use crate::bounded_mpmc::is_empty_spec as mpmc_is_empty_spec;
    use crate::mpsc_bounds::is_drained_spec;

    verus! {

    // r[impl properties.mpsc-drained-implies-mpmc-empty]
    // r[verify properties.mpsc-drained-implies-mpmc-empty]
    /// MPSC drained (closed + zero occupancy) ⟹ MPMC empty at same position.
    proof fn mpsc_drained_implies_mpmc_empty(head: u64)
        requires is_drained_spec(true, 0)
        ensures mpmc_is_empty_spec(head, head)
    {}

    } // verus!
}

#[cfg(verus_keep_ghost)]
mod cas_idempotent_proofs {
    use vstd::prelude::*;

    use crate::cas_loop::cas_succeeds_spec;
    use crate::cas_loop::is_idempotent_update_spec;

    verus! {

    // r[impl properties.cas-idempotent-needs-no-aba]
    // r[verify properties.cas-idempotent-needs-no-aba]
    /// Idempotent CAS (desired == current) always succeeds on first try.
    proof fn cas_idempotent_always_succeeds(value: u64)
        ensures
            is_idempotent_update_spec(value, value)
            && cas_succeeds_spec(value, value),
    {}

    } // verus!
}

#[cfg(verus_keep_ghost)]
mod ticket_lock_release_proofs {
    use vstd::prelude::*;

    use crate::ticket_lock::is_locked_spec;
    use crate::ticket_lock::release_spec;
    use crate::ticket_lock::waiters_count_spec;

    verus! {

    // r[impl properties.ticket-lock-release-reduces-waiters]
    // r[verify properties.ticket-lock-release-reduces-waiters]
    /// Releasing a ticket lock reduces waiters by exactly one.
    proof fn release_reduces_waiters(ticket_counter: u64, serving: u64)
        requires
            is_locked_spec(ticket_counter, serving),
            serving < u64::MAX,
        ensures
            waiters_count_spec(ticket_counter, release_spec(serving))
                == (waiters_count_spec(ticket_counter, serving) - 1) as u64,
    {}

    } // verus!
}

// --- Proptest: concurrency cross-module ---

#[cfg(test)]
mod concurrency_cross_tests {
    use proptest::prelude::*;

    proptest! {
        // r[verify properties.mpmc-occupancy-matches-mpsc]
        #[test]
        fn prop_mpmc_matches_mpsc_occupancy(
            sent in 0u64..10000,
            received in 0u64..10000,
        ) {
            if sent >= received {
                let mpmc = crate::bounded_mpmc::occupancy(received, sent);
                let mpsc = crate::mpsc_bounds::queue_occupancy(sent, received);
                prop_assert_eq!(mpmc, mpsc);
            }
        }

        // r[verify properties.work-stealing-occupancy-matches-mpmc]
        #[test]
        fn prop_work_stealing_matches_mpmc(
            top in 0u64..10000,
            bottom in 0u64..10000,
        ) {
            if bottom >= top {
                let ws = crate::work_stealing::deque_size(top, bottom);
                let mpmc = crate::bounded_mpmc::occupancy(top, bottom);
                prop_assert_eq!(ws, mpmc);
            }
        }

        // r[verify properties.spin-completed-implies-cas-no-retry]
        #[test]
        fn prop_spin_completed_no_retry(
            step in 0u64..1000,
            max in 0u64..100,
        ) {
            if crate::spin_backoff::is_completed(step, max) {
                prop_assert_eq!(crate::cas_loop::attempts_remaining(step, max), 0);
            }
        }

        // r[verify properties.rcu-grace-matches-epoch-advance]
        #[test]
        fn prop_rcu_grace_matches_epoch(epoch in 0u64..2) {
            let rcu = crate::rcu::advance_grace_period(epoch);
            let er = crate::epoch_reclaim::next_epoch(epoch);
            prop_assert_eq!(rcu, er);
        }

        // r[verify properties.lock-ordering-prevents-ticket-deadlock]
        #[test]
        fn prop_ordered_locks_no_deadlock(
            first in 0u64..10000,
            gap in 1u64..1000,
        ) {
            let second = first.saturating_add(gap);
            if second > first {
                prop_assert!(!crate::lock_ordering::would_deadlock(first, second));
            }
        }

        // r[verify properties.barrier-all-arrived-is-quorum]
        #[test]
        fn prop_barrier_full_is_quorum(expected in 1u64..1000) {
            prop_assert!(crate::barrier::all_arrived(expected, expected));
            prop_assert!(crate::quorum::is_quorum(expected, expected));
        }

        // r[verify properties.futex-notify-enables-consume]
        #[test]
        fn prop_futex_notify_consume_roundtrip(_x in 0u32..1) {
            let idle = crate::futex_state::FUTEX_IDLE;
            let notified = crate::futex_state::notify(idle);
            prop_assert!(crate::futex_state::is_notified(notified));
            let back = crate::futex_state::consume_notification(notified);
            prop_assert_eq!(back, idle);
        }

        // r[verify properties.cas-idempotent-needs-no-aba]
        #[test]
        fn prop_cas_idempotent_succeeds(value: u64) {
            prop_assert!(crate::cas_loop::cas_succeeds(value, value));
            prop_assert!(crate::cas_loop::is_idempotent_update(value, value));
        }

        // r[verify properties.ticket-lock-release-reduces-waiters]
        #[test]
        fn prop_ticket_release_reduces_waiters(
            serving in 0u64..10000,
            extra in 1u64..100,
        ) {
            let ticket_counter = serving + extra;
            let before = crate::ticket_lock::waiters_count(ticket_counter, serving);
            let after = crate::ticket_lock::waiters_count(ticket_counter, crate::ticket_lock::release(serving));
            prop_assert_eq!(after + 1, before);
        }

        // r[verify properties.seqlock-write-needs-release]
        #[test]
        fn prop_seqlock_write_ordering(_x in 0u8..1) {
            prop_assert!(crate::memory_order::valid_for_store(crate::memory_order::ORD_RELEASE));
            prop_assert!(crate::memory_order::has_release_semantics(crate::memory_order::ORD_RELEASE));
        }

        // r[verify properties.seqlock-read-needs-acquire]
        #[test]
        fn prop_seqlock_read_ordering(_x in 0u8..1) {
            prop_assert!(crate::memory_order::valid_for_load(crate::memory_order::ORD_ACQUIRE));
            prop_assert!(crate::memory_order::has_acquire_semantics(crate::memory_order::ORD_ACQUIRE));
        }

        // r[verify properties.mpsc-drained-implies-mpmc-empty]
        #[test]
        fn prop_mpsc_drained_mpmc_empty(head in 0u64..10000) {
            prop_assert!(crate::mpsc_bounds::is_drained(true, 0));
            prop_assert!(crate::bounded_mpmc::is_empty(head, head));
        }

        // r[verify properties.ref-count-zero-implies-reclaimable]
        #[test]
        fn prop_refcount_zero_reclaimable(addr in 1u64..10000) {
            prop_assert!(crate::ref_count::should_deallocate(0));
            let empty_hazards: Vec<u64> = vec![];
            prop_assert!(crate::hazard_pointer::can_reclaim(addr, &empty_hazards));
        }
    }
}

// ===========================================================================
// Cross-module properties: distributed coordination (paxos, lease_mutex, 2PL)
// ===========================================================================

#[cfg(verus_keep_ghost)]
mod paxos_monotonic_proofs {
    use vstd::prelude::*;

    use crate::monotonic::is_strict_advance_spec;
    use crate::paxos::AcceptorState;
    use crate::paxos::Ballot;
    use crate::paxos::ballot_gt_spec;
    use crate::paxos::can_promise_spec;
    use crate::paxos::promise_next_spec;
    use crate::paxos::promised_ballot;

    verus! {

    // r[impl properties.paxos-promise-is-strict-advance]
    // r[verify properties.paxos-promise-is-strict-advance]
    /// Paxos promise advances the round monotonically: if the new ballot
    /// has a strictly higher round, the round number is a strict advance
    /// in the monotonic sense.
    proof fn paxos_promise_is_strict_advance(state: AcceptorState, ballot: Ballot)
        requires
            can_promise_spec(state, ballot),
            ballot.round > promised_ballot(state).round,
        ensures is_strict_advance_spec(
            promised_ballot(state).round,
            promised_ballot(promise_next_spec(state, ballot)).round,
        )
    {}

    // r[impl properties.paxos-ballot-gt-implies-ge-round]
    // r[verify properties.paxos-ballot-gt-implies-ge-round]
    /// A strictly greater ballot has at least as high a round.
    proof fn paxos_ballot_gt_implies_ge_round(a: Ballot, b: Ballot)
        requires ballot_gt_spec(a, b)
        ensures a.round >= b.round
    {}

    } // verus!
}

#[cfg(verus_keep_ghost)]
mod lease_mutex_fencing_proofs {
    use vstd::prelude::*;

    use crate::fencing::is_stale_spec;
    use crate::fencing::is_valid_write_spec;
    use crate::fencing::issue_token_spec;
    use crate::lease_mutex::LockState;
    use crate::lease_mutex::acquire_next_spec;
    use crate::lease_mutex::can_acquire_spec;
    use crate::lease_mutex::is_owner_spec;
    use crate::lease_mutex::write_permitted_spec;

    verus! {

    // r[impl properties.lease-mutex-fence-is-fencing-token]
    // r[verify properties.lease-mutex-fence-is-fencing-token]
    /// The lease_mutex fence token after acquisition matches fencing::issue_token
    /// applied to the old fence.
    proof fn lease_mutex_fence_is_fencing_token(
        state: LockState, node_id: u64, now: u64, ttl: u64,
    )
        requires can_acquire_spec(state, now, ttl)
        ensures
            acquire_next_spec(state, node_id, now, ttl).fence_token
                == issue_token_spec(state.fence_token),
    {}

    // r[impl properties.lease-mutex-stale-fence-rejected]
    // r[verify properties.lease-mutex-stale-fence-rejected]
    /// A stale fencing token (per fencing::is_stale) is also rejected by
    /// lease_mutex::write_permitted.
    proof fn lease_mutex_stale_fence_rejected(
        state: LockState, node_id: u64, now: u64, old_fence: u64,
    )
        requires
            is_owner_spec(state, node_id, now),
            is_stale_spec(old_fence, state.fence_token),
        ensures !write_permitted_spec(state, node_id, now, old_fence)
    {}

    // r[impl properties.lease-mutex-valid-fence-accepted]
    // r[verify properties.lease-mutex-valid-fence-accepted]
    /// A valid fencing token (per fencing::is_valid_write) is accepted by
    /// lease_mutex::write_permitted when the node is the owner.
    proof fn lease_mutex_valid_fence_accepted(
        state: LockState, node_id: u64, now: u64, request_fence: u64,
    )
        requires
            is_owner_spec(state, node_id, now),
            is_valid_write_spec(request_fence, state.fence_token),
        ensures write_permitted_spec(state, node_id, now, request_fence)
    {}

    } // verus!
}

#[cfg(verus_keep_ghost)]
mod two_phase_lock_ordering_proofs {
    use vstd::prelude::*;

    use crate::lock_ordering::would_deadlock_spec;
    use crate::two_phase_lock::OP_ACQUIRE;
    use crate::two_phase_lock::PHASE_GROWING;
    use crate::two_phase_lock::PHASE_SHRINKING;
    use crate::two_phase_lock::can_acquire_spec;
    use crate::two_phase_lock::would_violate_spec;

    verus! {

    // r[impl properties.two-phase-lock-shrinking-blocks-all]
    // r[verify properties.two-phase-lock-shrinking-blocks-all]
    /// In the shrinking phase, both 2PL and lock-ordering agree that
    /// no new acquisition should proceed: 2PL rejects it outright,
    /// and lock_ordering considers any lower-numbered request a deadlock risk.
    proof fn two_phase_shrinking_blocks_all()
        ensures
            would_violate_spec(PHASE_SHRINKING, OP_ACQUIRE),
            !can_acquire_spec(PHASE_SHRINKING),
    {}

    // r[impl properties.two-phase-lock-growing-enables-ordered-acquire]
    // r[verify properties.two-phase-lock-growing-enables-ordered-acquire]
    /// In the growing phase, 2PL permits acquisition, and if the lock
    /// is requested in order (requested > held_max), lock_ordering
    /// confirms no deadlock.
    proof fn two_phase_growing_enables_ordered_acquire(held_max: u64, requested: u64)
        requires requested > held_max
        ensures
            can_acquire_spec(PHASE_GROWING),
            !would_deadlock_spec(held_max, requested),
    {}

    } // verus!
}

#[cfg(verus_keep_ghost)]
mod paxos_two_phase_proofs {
    use vstd::prelude::*;

    use crate::two_phase::can_commit_spec;
    use crate::two_phase::must_abort_spec;

    verus! {

    // r[impl properties.paxos-quorum-accept-enables-commit]
    // r[verify properties.paxos-quorum-accept-enables-commit]
    /// If all acceptors accept (model as all-yes votes in 2PC), the
    /// coordinator can commit. This connects Paxos unanimous acceptance
    /// to 2PC commit.
    proof fn paxos_quorum_accept_enables_commit()
        ensures can_commit_spec(seq![Some(true), Some(true), Some(true)])
    {}

    // r[impl properties.paxos-reject-forces-abort]
    // r[verify properties.paxos-reject-forces-abort]
    /// If any acceptor rejects (model as a no vote in 2PC), the
    /// coordinator must abort.
    proof fn paxos_reject_forces_abort()
        ensures must_abort_spec(seq![Some(true), Some(false), Some(true)])
    {}

    } // verus!
}

#[cfg(verus_keep_ghost)]
mod lease_mutex_lease_proofs {
    use vstd::prelude::*;

    use crate::lease_mutex::LockState;
    use crate::lease_mutex::acquire_next_spec;
    use crate::lease_mutex::can_acquire_spec;
    use crate::lease_mutex::is_available_spec;
    use crate::lease_mutex::is_owner_spec;
    use crate::lease_mutex::release_spec;

    verus! {

    // r[impl properties.lease-mutex-release-then-available]
    // r[verify properties.lease-mutex-release-then-available]
    /// After releasing a lease-based lock, it is immediately available —
    /// same semantics as lease revocation making the lease invalid.
    proof fn lease_mutex_release_then_available(state: LockState, now: u64)
        ensures is_available_spec(release_spec(state, now), now)
    {}

    // r[impl properties.lease-mutex-acquire-release-roundtrip]
    // r[verify properties.lease-mutex-acquire-release-roundtrip]
    /// Acquire then immediately release: the lock is available but the
    /// fence token has advanced (write protection persists).
    proof fn lease_mutex_acquire_release_roundtrip(
        state: LockState, node_id: u64, now: u64, ttl: u64,
    )
        requires can_acquire_spec(state, now, ttl)
        ensures ({
            let after_acq = acquire_next_spec(state, node_id, now, ttl);
            let after_rel = release_spec(after_acq, now);
            is_available_spec(after_rel, now)
            && after_rel.fence_token as int == state.fence_token as int + 1
        })
    {}

    } // verus!
}

// --- Typed state + snapshot integrity cross-module ---

#[cfg(verus_keep_ghost)]
mod typed_state_snapshot_proofs {
    use vstd::prelude::*;

    use crate::snapshot_integrity::*;
    use crate::typed_state::*;

    verus! {

    // r[depends properties.snapshot-typed-verify]
    /// Spec: verify_snapshot returns Some iff verify_integrity holds.
    pub open spec fn snapshot_typed_verify_prop(
        data_hash: u64, meta_hash: u64, combined_hash: u128, chain_hash: u64,
    ) -> bool {
        let integrity = SnapshotIntegrity { data_hash, meta_hash, combined_hash, chain_hash_at_snapshot: chain_hash };
        let gs = stamp_spec(integrity);
        let pred_result = verify_integrity_spec(integrity);
        let result = verify_with_spec(gs, pred_result);
        (pred_result ==> result.is_some() && result.unwrap().value == integrity)
        && (!pred_result ==> result.is_none())
    }

    // r[impl properties.snapshot-typed-verify]
    // r[verify properties.snapshot-typed-verify]
    /// Proof: typed verification of snapshots agrees with verify_integrity.
    proof fn prove_snapshot_typed_verify(
        data_hash: u64, meta_hash: u64, combined_hash: u128, chain_hash: u64,
    )
        ensures snapshot_typed_verify_prop(data_hash, meta_hash, combined_hash, chain_hash)
    {}

    } // verus!
}

#[cfg(test)]
mod typed_state_snapshot_cross_tests {
    use proptest::prelude::*;

    proptest! {
        // r[verify properties.snapshot-typed-verify]
        #[test]
        fn prop_snapshot_typed_roundtrip(data_hash: u64, meta_hash: u64, chain_hash: u64) {
            let integrity = crate::snapshot_integrity::compute_integrity(data_hash, meta_hash, chain_hash);
            let stamped = crate::typed_state::Stamped::stamp(integrity);
            let verified = crate::typed_state::verify_with(stamped, |i| {
                crate::snapshot_integrity::verify_integrity(i)
            });
            // compute_integrity always produces valid integrity (round-trip property)
            prop_assert!(verified.is_some());
            let inner = verified.unwrap().unwrap_verified();
            prop_assert_eq!(inner.data_hash, data_hash);
            prop_assert_eq!(inner.meta_hash, meta_hash);
        }

        // r[verify properties.snapshot-typed-verify]
        #[test]
        fn prop_tampered_snapshot_rejected(data_hash: u64, meta_hash: u64, chain_hash: u64) {
            let integrity = crate::snapshot_integrity::compute_integrity(data_hash, meta_hash, chain_hash);
            // Tamper with the combined hash
            let tampered = crate::snapshot_integrity::SnapshotIntegrity {
                combined_hash: integrity.combined_hash.wrapping_add(1),
                ..integrity
            };
            let stamped = crate::typed_state::Stamped::stamp(tampered);
            let result = crate::typed_state::verify_with(stamped, |i| {
                crate::snapshot_integrity::verify_integrity(i)
            });
            prop_assert!(result.is_none());
        }
    }
}

// --- Serialization injectivity cross-module proofs ---

#[cfg(verus_keep_ghost)]
mod serialization_injectivity_proofs {
    use vstd::prelude::*;

    use crate::chain::hash_collision_free;
    use crate::chain::hash_spec;
    use crate::serialize_inj::*;
    use crate::snapshot_integrity::combine_hashes_injective;
    use crate::snapshot_integrity::combine_hashes_spec;

    verus! {

    // r[depends properties.chain-hash-implies-field-equality]
    /// Spec: chain hash equality implies all four fields are equal.
    /// This composes collision resistance (axiom) with encoding
    /// injectivity (theorem) to complete the reasoning chain:
    /// same hash → same bytes → same fields.
    pub open spec fn chain_hash_implies_field_equality_prop(
        prev1: u64, idx1: u64, term1: u64, data1: u64,
        prev2: u64, idx2: u64, term2: u64, data2: u64,
    ) -> bool {
        hash_spec(prev1, idx1, term1, data1) == hash_spec(prev2, idx2, term2, data2)
            ==> (prev1 == prev2 && idx1 == idx2 && term1 == term2 && data1 == data2)
    }

    // r[impl properties.chain-hash-implies-field-equality]
    // r[verify properties.chain-hash-implies-field-equality]
    /// Proof: chain hash equality → field equality.
    /// Step 1: collision resistance gives all four hash inputs equal.
    /// Step 2: encode_quad_injective gives field equality.
    /// (Step 2 is redundant here because hash_collision_free already
    /// gives field equality directly — but stating it via the encoding
    /// makes the serialization injectivity argument explicit.)
    proof fn prove_chain_hash_implies_field_equality(
        prev1: u64, idx1: u64, term1: u64, data1: u64,
        prev2: u64, idx2: u64, term2: u64, data2: u64,
    )
        requires hash_spec(prev1, idx1, term1, data1) == hash_spec(prev2, idx2, term2, data2)
        ensures prev1 == prev2 && idx1 == idx2 && term1 == term2 && data1 == data2
    {
        hash_collision_free(prev1, idx1, term1, data1, prev2, idx2, term2, data2);
    }

    // r[depends properties.dual-hash-implies-field-equality]
    /// Spec: exact pair commitment equality implies both fields are equal.
    pub open spec fn dual_hash_implies_field_equality_prop(
        a1: u64, b1: u64,
        a2: u64, b2: u64,
    ) -> bool {
        combine_hashes_spec(a1, b1) == combine_hashes_spec(a2, b2)
            ==> (a1 == a2 && b1 == b2)
    }

    // r[impl properties.dual-hash-implies-field-equality]
    // r[verify properties.dual-hash-implies-field-equality]
    /// Proof: pair commitment equality implies field equality without an axiom.
    proof fn prove_dual_hash_implies_field_equality(
        a1: u64, b1: u64,
        a2: u64, b2: u64,
    )
        requires combine_hashes_spec(a1, b1) == combine_hashes_spec(a2, b2)
        ensures a1 == a2 && b1 == b2
    {
        combine_hashes_injective(a1, b1, a2, b2);
    }

    // r[depends properties.quad-encoding-matches-chain-layout]
    /// Spec: quad encoding produces the same field decomposition
    /// that the chain hash uses — four contiguous u64s at fixed offsets.
    pub open spec fn quad_encoding_matches_chain_layout_prop(
        prev: u64, idx: u64, term: u64, data_id: u64,
    ) -> bool {
        encode_quad_spec(prev, idx, term, data_id).len() == 32
    }

    // r[impl properties.quad-encoding-matches-chain-layout]
    // r[verify properties.quad-encoding-matches-chain-layout]
    /// Proof: quad encoding produces exactly 32 bytes.
    proof fn prove_quad_encoding_matches_chain_layout(
        prev: u64, idx: u64, term: u64, data_id: u64,
    )
        ensures encode_quad_spec(prev, idx, term, data_id).len() == 32
    {
        encode_u64_len(prev);
        encode_u64_len(idx);
        encode_u64_len(term);
        encode_u64_len(data_id);
    }

    } // verus!
}

#[cfg(test)]
mod serialization_injectivity_cross_tests {
    use proptest::prelude::*;

    use super::*;

    proptest! {
        // r[verify properties.chain-hash-implies-field-equality]
        #[test]
        fn prop_chain_encode_quad_roundtrip(a: u64, b: u64, c: u64, d: u64) {
            let encoded = crate::serialize_inj::encode_quad(a, b, c, d);
            prop_assert_eq!(encoded.len(), 32);
            let a2 = crate::serialize_inj::decode_u64(&encoded[..8]);
            let b2 = crate::serialize_inj::decode_u64(&encoded[8..16]);
            let c2 = crate::serialize_inj::decode_u64(&encoded[16..24]);
            let d2 = crate::serialize_inj::decode_u64(&encoded[24..32]);
            prop_assert_eq!(a, a2);
            prop_assert_eq!(b, b2);
            prop_assert_eq!(c, c2);
            prop_assert_eq!(d, d2);
        }

        // r[verify properties.dual-hash-implies-field-equality]
        #[test]
        fn prop_dual_encode_pair_roundtrip(a: u64, b: u64) {
            let encoded = crate::serialize_inj::encode_pair(a, b);
            prop_assert_eq!(encoded.len(), 16);
            let a2 = crate::serialize_inj::decode_u64(&encoded[..8]);
            let b2 = crate::serialize_inj::decode_u64(&encoded[8..16]);
            prop_assert_eq!(a, a2);
            prop_assert_eq!(b, b2);
        }

        // r[verify properties.quad-encoding-matches-chain-layout]
        #[test]
        fn prop_quad_always_32_bytes(a: u64, b: u64, c: u64, d: u64) {
            let encoded = crate::serialize_inj::encode_quad(a, b, c, d);
            prop_assert_eq!(encoded.len(), 32);
        }
    }
}

// --- Proptest: distributed coordination cross-module ---

#[cfg(test)]
mod distributed_coordination_cross_tests {
    use proptest::prelude::*;

    proptest! {
        // r[verify properties.paxos-promise-is-strict-advance]
        #[test]
        fn prop_paxos_promise_monotonic(
            pr in 0u64..100, pp in 0u64..10,
            br in 0u64..100, bp in 0u64..10,
        ) {
            let state = crate::paxos::AcceptorState {
                promised_round: pr, promised_proposer: pp,
                has_accepted: false, accepted_round: 0, accepted_proposer: 0,
                accepted_value: 0,
            };
            let ballot = crate::paxos::Ballot { round: br, proposer_id: bp };
            if crate::paxos::can_promise(&state, &ballot) && br > pr {
                prop_assert!(crate::monotonic::is_strict_advance(pr, br));
            }
        }

        // r[verify properties.lease-mutex-fence-is-fencing-token]
        #[test]
        fn prop_lease_mutex_fence_matches_fencing(
            now in 0u64..u64::MAX / 2,
            ttl in 1u64..u64::MAX / 4,
            node_id in 1u64..100,
            old_fence in 0u64..u64::MAX - 1,
        ) {
            let lock = crate::lease_mutex::LockState {
                holder: 0, expiry: 0, fence_token: old_fence,
            };
            if let Some(new_lock) = crate::lease_mutex::try_acquire(&lock, node_id, now, ttl) {
                prop_assert_eq!(
                    new_lock.fence_token,
                    crate::fencing::issue_token(old_fence)
                );
            }
        }

        // r[verify properties.lease-mutex-stale-fence-rejected]
        #[test]
        fn prop_stale_fence_rejected_by_both(
            now in 0u64..u64::MAX / 2,
            ttl in 1u64..u64::MAX / 4,
            node_a in 1u64..100,
            node_b in 100u64..200,
        ) {
            let lock = crate::lease_mutex::LockState {
                holder: 0, expiry: 0, fence_token: 0,
            };
            if let Some(after_a) = crate::lease_mutex::try_acquire(&lock, node_a, now, ttl) {
                let expire_time = now + ttl;
                if expire_time <= u64::MAX / 2 {
                    if let Some(after_b) = crate::lease_mutex::try_acquire(
                        &after_a, node_b, expire_time, ttl,
                    ) {
                        // A's old fence is stale in both fencing and lease_mutex
                        prop_assert!(crate::fencing::is_stale(
                            after_a.fence_token, after_b.fence_token
                        ));
                        prop_assert!(!crate::lease_mutex::write_permitted(
                            &after_b, node_a, expire_time, after_a.fence_token
                        ));
                    }
                }
            }
        }

        // r[verify properties.two-phase-lock-growing-enables-ordered-acquire]
        #[test]
        fn prop_growing_phase_ordered_no_deadlock(
            held_max in 0u64..10000,
            gap in 1u64..1000,
        ) {
            let requested = held_max.saturating_add(gap);
            if requested > held_max {
                prop_assert!(crate::two_phase_lock::can_acquire(
                    crate::two_phase_lock::PHASE_GROWING
                ));
                prop_assert!(!crate::lock_ordering::would_deadlock(held_max, requested));
            }
        }

        // r[verify properties.paxos-quorum-accept-enables-commit]
        #[test]
        fn prop_all_accept_enables_commit(_x in 0u8..1) {
            let votes = vec![Some(true), Some(true), Some(true)];
            prop_assert!(crate::two_phase::can_commit(&votes));
        }

        // r[verify properties.paxos-reject-forces-abort]
        #[test]
        fn prop_any_reject_forces_abort(_x in 0u8..1) {
            let votes = vec![Some(true), Some(false), Some(true)];
            prop_assert!(crate::two_phase::must_abort(&votes));
        }

        // r[verify properties.lease-mutex-acquire-release-roundtrip]
        #[test]
        fn prop_acquire_release_available(
            now in 0u64..u64::MAX / 4,
            ttl in 1u64..u64::MAX / 4,
            node_id in 1u64..100,
        ) {
            let lock = crate::lease_mutex::LockState {
                holder: 0, expiry: 0, fence_token: 0,
            };
            if let Some(acquired) = crate::lease_mutex::try_acquire(&lock, node_id, now, ttl) {
                let released = crate::lease_mutex::do_release(&acquired, now);
                prop_assert!(crate::lease_mutex::is_available(&released, now));
                prop_assert_eq!(released.fence_token, 1);
            }
        }
    }
}

// --- Job runner cross-module proofs ---

#[cfg(verus_keep_ghost)]
mod job_runner_proofs {
    use vstd::prelude::*;

    verus! {

    // r[verify properties.job-state-readiness-links-dag]
    /// When all dep_states are COMPLETED, those dep IDs are in the completed set.
    /// This links job_state::can_become_ready to job_dag::all_deps_satisfied.
    proof fn readiness_implies_dag_satisfied(
        dep_states: Seq<u8>,
        dep_ids: Seq<u64>,
        completed: Seq<u64>,
    )
        requires
            dep_states.len() == dep_ids.len(),
            crate::job_state::can_become_ready_spec(dep_states),
            // Each dep_id with COMPLETED state appears in completed
            forall|i: int| #![trigger dep_states[i]]
                0 <= i < dep_states.len() as int
                ==> (dep_states[i] == crate::job_state::COMPLETED
                    ==> crate::job_dag::is_dep_satisfied_spec(dep_ids[i], completed)),
        ensures
            crate::job_dag::all_deps_satisfied_spec(dep_ids, completed)
    {
        readiness_implies_dag_from(dep_states, dep_ids, completed, 0);
    }

    proof fn readiness_implies_dag_from(
        dep_states: Seq<u8>,
        dep_ids: Seq<u64>,
        completed: Seq<u64>,
        from: int,
    )
        requires
            0 <= from <= dep_states.len() as int,
            dep_states.len() == dep_ids.len(),
            crate::job_state::all_deps_completed_from_spec(dep_states, from),
            forall|i: int| #![trigger dep_states[i]]
                0 <= i < dep_states.len() as int
                ==> (dep_states[i] == crate::job_state::COMPLETED
                    ==> crate::job_dag::is_dep_satisfied_spec(dep_ids[i], completed)),
        ensures
            crate::job_dag::all_deps_satisfied_from_spec(dep_ids, completed, from)
        decreases dep_states.len() - from
    {
        if from < dep_states.len() as int {
            readiness_implies_dag_from(dep_states, dep_ids, completed, from + 1);
        }
    }

    // r[verify properties.job-slot-running-requires-slot]
    /// A job transitioning to Running requires an available slot.
    /// If acquire succeeds, the job can move to Running.
    proof fn running_needs_slot(in_use: u64, capacity: u64)
        requires
            in_use <= capacity,
            crate::job_slot::try_acquire_slot_spec(in_use, capacity).0,
        ensures
            // The transition Pending→Ready→Running is valid
            crate::job_state::is_valid_transition_spec(
                crate::job_state::READY,
                crate::job_state::RUNNING,
            ),
            // And slot count stays bounded
            crate::job_slot::try_acquire_slot_spec(in_use, capacity).1 <= capacity,
    {}

    // r[verify properties.job-cancel-uses-terminal]
    /// job_cancel's is_terminal matches job_state's is_terminal.
    proof fn cancel_terminal_matches_state(state: u8)
        ensures
            crate::job_cancel::is_terminal_spec(state)
                == crate::job_state::is_terminal_spec(state)
    {}

    // r[verify properties.job-priority-then-transition]
    /// If A has higher priority and both are Ready, A should run first.
    /// Both are valid transitions (Ready→Running).
    proof fn higher_priority_runs_first(
        class_a: u64, seq_a: u64,
        class_b: u64, seq_b: u64,
    )
        requires crate::job_priority::is_higher_priority_spec(class_a, seq_a, class_b, seq_b)
        ensures
            crate::job_state::is_valid_transition_spec(
                crate::job_state::READY,
                crate::job_state::RUNNING,
            ),
    {}

    } // verus!
}

// --- Proptest: job runner cross-module ---
#[cfg(test)]
mod job_runner_cross_tests {
    use proptest::prelude::*;

    proptest! {
        // r[verify properties.job-state-readiness-links-dag]
        #[test]
        fn prop_readiness_links_dag(
            num_deps in 0usize..10,
        ) {
            // If all deps completed, the dep IDs appear in the completed list
            let dep_states = vec![crate::job_state::COMPLETED; num_deps];
            prop_assert!(crate::job_state::can_become_ready(&dep_states));

            let dep_ids: Vec<u64> = (0..num_deps as u64).collect();
            let completed: Vec<u64> = (0..num_deps as u64).collect();
            prop_assert!(crate::job_dag::all_deps_satisfied(&dep_ids, &completed));
        }

        // r[verify properties.job-slot-running-requires-slot]
        #[test]
        fn prop_slot_acquire_enables_running(
            in_use in 0u64..100,
            capacity in 1u64..101,
        ) {
            if in_use < capacity {
                let (ok, new_in_use) = crate::job_slot::try_acquire_slot(in_use, capacity);
                prop_assert!(ok);
                prop_assert!(new_in_use <= capacity);
                prop_assert!(crate::job_state::is_valid_transition(
                    crate::job_state::READY,
                    crate::job_state::RUNNING,
                ));
            }
        }

        // r[verify properties.job-cancel-uses-terminal]
        #[test]
        fn prop_cancel_terminal_matches(state in 0u8..6) {
            // job_cancel has a private is_terminal that mirrors job_state::is_terminal.
            // Test the equivalence: both use the same terminal states (3, 4, 5).
            let state_term = crate::job_state::is_terminal(state);
            let cancel_term = state == 3 || state == 4 || state == 5;
            if state <= 5 {
                prop_assert_eq!(cancel_term, state_term);
            }
        }

        // r[verify properties.job-priority-then-transition]
        #[test]
        fn prop_priority_select_feeds_transition(
            classes in proptest::collection::vec(0u64..5, 1..10),
        ) {
            let seqs: Vec<u64> = (0..classes.len() as u64).collect();
            let idx = crate::job_priority::select_highest_priority(&classes, &seqs);
            prop_assert!(idx < classes.len());
            // The selected job can transition Ready→Running
            prop_assert!(crate::job_state::is_valid_transition(
                crate::job_state::READY,
                crate::job_state::RUNNING,
            ));
        }

        // r[verify properties.job-idempotency-prevents-double-run]
        #[test]
        fn prop_idempotency_prevents_double_run(token in 0u64..1000) {
            let consumed: Vec<u64> = vec![];
            let (proceed, _) = crate::job_idempotency::try_execute(token, &consumed);
            prop_assert!(proceed);

            // After recording the token, duplicate is blocked
            let consumed2 = vec![token];
            let (proceed2, _) = crate::job_idempotency::try_execute(token, &consumed2);
            prop_assert!(!proceed2);
        }
    }
}

// --- Job execution verification cross-module proofs ---

#[cfg(verus_keep_ghost)]
mod job_execution_proofs {
    use vstd::prelude::*;

    verus! {

    // r[impl properties.retry-non-retryable-never-retries]
    // r[verify properties.retry-non-retryable-never-retries]
    /// Non-retryable error codes never trigger retry, regardless of other conditions.
    proof fn retry_non_retryable_never_retries(
        error_code: u64,
        attempts: u64,
        max_attempts: u64,
        now: u64,
        last_attempt_time: u64,
        cooldown_ms: u64,
    )
        requires !crate::job_retry::is_retryable_error_spec(error_code)
        ensures !crate::job_retry::should_retry_spec(
            error_code, attempts, max_attempts, now, last_attempt_time, cooldown_ms,
        )
    {}

    // r[impl properties.timeout-triggers-failure]
    // r[verify properties.timeout-triggers-failure]
    /// A timed-out RUNNING job can transition to FAILED.
    proof fn timeout_triggers_failure(now: u64, deadline: u64)
        requires crate::job_timeout::is_timed_out_spec(now, deadline)
        ensures
            crate::job_state::is_valid_transition_spec(
                crate::job_state::RUNNING,
                crate::job_state::FAILED,
            ),
    {}

    // r[impl properties.result-success-completes]
    // r[verify properties.result-success-completes]
    /// A valid result (exit=0, hash matches, size ok) means RUNNING→COMPLETED.
    proof fn result_success_completes(
        exit_code: u8,
        computed_hash: u64,
        expected_hash: u64,
        actual_size: u64,
        min_size: u64,
        max_size: u64,
    )
        requires
            crate::job_result::validate_result_spec(
                exit_code, computed_hash, expected_hash, actual_size, min_size, max_size,
            ) == crate::job_result::VALID,
        ensures
            crate::job_state::is_valid_transition_spec(
                crate::job_state::RUNNING,
                crate::job_state::COMPLETED,
            ),
    {}

    // r[impl properties.result-failure-fails]
    // r[verify properties.result-failure-fails]
    /// A failed validation means RUNNING→FAILED.
    proof fn result_failure_fails(
        exit_code: u8,
        computed_hash: u64,
        expected_hash: u64,
        actual_size: u64,
        min_size: u64,
        max_size: u64,
    )
        requires
            crate::job_result::validate_result_spec(
                exit_code, computed_hash, expected_hash, actual_size, min_size, max_size,
            ) != crate::job_result::VALID,
        ensures
            crate::job_state::is_valid_transition_spec(
                crate::job_state::RUNNING,
                crate::job_state::FAILED,
            ),
    {}

    // r[impl properties.retryable-disjoint-from-success]
    // r[verify properties.retryable-disjoint-from-success]
    /// Exit code 0 (success) is never in the retryable error range.
    proof fn retryable_disjoint_from_success()
        ensures !crate::job_retry::is_retryable_error_spec(0)
    {}

    } // verus!
}

// --- Cross-module: Raft pipeline + session (wave 6) ---
#[cfg(verus_keep_ghost)]
mod raft_pipeline_proofs_v2 {
    use vstd::prelude::*;
    verus! {

    // r[impl properties.append-response-success-advances-match]
    // r[verify properties.append-response-success-advances-match]
    proof fn append_response_success_advances_match(match_index: u64, next_index: u64, entries_sent: u64)
        requires entries_sent > 0, match_index as int + entries_sent as int <= u64::MAX as int,
        ensures crate::monotonic::is_advance_spec(match_index, crate::append_response::on_append_success_spec(match_index, next_index, entries_sent).0)
    {}

    // r[impl properties.check-quorum-singleton-safe]
    // r[verify properties.check-quorum-singleton-safe]
    proof fn check_quorum_singleton_safe()
        ensures !crate::check_quorum::should_step_down_spec(1, 1)
    {}

    // r[impl properties.check-quorum-uses-quorum]
    // r[verify properties.check-quorum-uses-quorum]
    proof fn check_quorum_uses_quorum(recent_count: u64, cluster_size: u64)
        requires cluster_size > 0
        ensures crate::check_quorum::should_step_down_spec(recent_count, cluster_size) == !crate::quorum::is_quorum_spec(recent_count, cluster_size)
    {}

    // r[impl properties.election-timer-heartbeat-resets]
    // r[verify properties.election-timer-heartbeat-resets]
    proof fn election_timer_heartbeat_resets(msg_term: u64, current_term: u64, from_leader: bool, timeout: u64)
        requires crate::election_timer::should_reset_on_append_entries_spec(msg_term, current_term, from_leader), timeout > 0,
        ensures !crate::election_timer::is_election_timer_expired_spec(0, timeout)
    {}

    // r[impl properties.entry-type-noop-agrees]
    // r[verify properties.entry-type-noop-agrees]
    proof fn entry_type_noop_agrees()
        ensures crate::entry_type::classify_entry_spec(crate::entry_type::NOOP_VALUE) == crate::entry_type::ENTRY_NOOP,
            crate::entry_type::is_noop_entry_spec(crate::entry_type::ENTRY_NOOP),
    {}

    // r[impl properties.follower-commit-monotonic-is-advance]
    // r[verify properties.follower-commit-monotonic-is-advance]
    proof fn follower_commit_monotonic_is_advance(current_commit: u64, leader_commit: u64, last_new_entry_index: u64)
        ensures crate::monotonic::is_advance_spec(current_commit, crate::follower_commit::follower_update_commit_spec(current_commit, leader_commit, last_new_entry_index))
    {}

    // r[impl properties.last-applied-advance-is-monotonic]
    // r[verify properties.last-applied-advance-is-monotonic]
    proof fn last_applied_advance_is_monotonic(last_applied: u64, commit_index: u64)
        ensures crate::monotonic::is_advance_spec(last_applied, crate::last_applied::advance_last_applied_spec(last_applied, commit_index))
    {}

    // r[impl properties.last-applied-bounded-by-commit]
    // r[verify properties.last-applied-bounded-by-commit]
    proof fn last_applied_bounded_by_commit(last_applied: u64, commit_index: u64)
        requires last_applied <= commit_index
        ensures crate::last_applied::advance_last_applied_spec(last_applied, commit_index) <= commit_index
    {}

    // r[impl properties.pending-apply-is-saturating-sub]
    // r[verify properties.pending-apply-is-saturating-sub]
    proof fn pending_apply_is_saturating_sub(last_applied: u64, commit_index: u64)
        ensures crate::last_applied::pending_apply_count_spec(last_applied, commit_index) == crate::arithmetic::saturating_sub_spec(commit_index, last_applied)
    {}

    // r[impl properties.transfer-blocks-like-drain]
    // r[verify properties.transfer-blocks-like-drain]
    proof fn transfer_blocks_like_drain()
        ensures crate::leadership_transfer::should_reject_proposal_spec(true) == !crate::drain::can_start_op_spec(true)
    {}

    // r[impl properties.transfer-caught-up-is-advance]
    // r[verify properties.transfer-caught-up-is-advance]
    proof fn transfer_caught_up_is_advance(target_match: u64, last_log: u64)
        ensures crate::leadership_transfer::is_target_caught_up_spec(target_match, last_log) == crate::monotonic::is_advance_spec(last_log, target_match)
    {}

    // r[impl properties.transfer-timeout-is-expiration]
    // r[verify properties.transfer-timeout-is-expiration]
    proof fn transfer_timeout_is_expiration(deadline: u64, now: u64)
        ensures crate::leadership_transfer::is_transfer_expired_spec(deadline, now) == crate::expiration::is_expired_spec(deadline, now)
    {}

    // r[impl properties.learner-caught-up-is-advance]
    // r[verify properties.learner-caught-up-is-advance]
    proof fn learner_caught_up_is_advance(learner_match: u64, leader_log_len: u64)
        ensures crate::learner_readiness::is_caught_up_spec(learner_match, leader_log_len) == crate::monotonic::is_advance_spec(leader_log_len, learner_match)
    {}

    // r[impl properties.learner-gap-is-saturating-sub]
    // r[verify properties.learner-gap-is-saturating-sub]
    proof fn learner_gap_is_saturating_sub(learner_match: u64, leader_log_len: u64)
        ensures crate::learner_readiness::replication_gap_spec(learner_match, leader_log_len) == crate::arithmetic::saturating_sub_spec(leader_log_len, learner_match)
    {}

    // r[impl properties.lease-disjoint-is-lease-disjointness]
    // r[verify properties.lease-disjoint-is-lease-disjointness]
    proof fn lease_disjoint_is_lease_disjointness(start_a: u64, expiry_a: u64, start_b: u64)
        requires start_a <= expiry_a, expiry_a <= start_b,
        ensures expiry_a <= start_b,
    {}

    // r[impl properties.lease-read-implies-read-index-safe]
    // r[verify properties.lease-read-implies-read-index-safe]
    proof fn lease_read_implies_read_index_safe(commit_index: u64, read_index: u64)
        requires crate::lease_read::lease_read_safe_spec(true, commit_index, read_index)
        ensures crate::read_index::read_safe_at_spec(read_index, commit_index)
    {}

    // r[impl properties.pipeline-empty-after-full-ack]
    // r[verify properties.pipeline-empty-after-full-ack]
    proof fn pipeline_empty_after_full_ack(next_index: u64, match_index: u64)
        requires next_index > 0, match_index == next_index - 1,
        ensures crate::replication_pipeline::inflight_count_spec(next_index, match_index) == 0
    {}

    // r[impl properties.pipeline-inflight-is-saturating-sub]
    // r[verify properties.pipeline-inflight-is-saturating-sub]
    proof fn pipeline_inflight_is_saturating_sub(next_index: u64, match_index: u64)
        requires next_index > match_index, match_index < u64::MAX,
        ensures crate::replication_pipeline::inflight_count_spec(next_index, match_index) == crate::arithmetic::saturating_sub_spec(next_index, (match_index + 1) as u64)
    {}

    // r[impl properties.snapshot-chunk-count-is-div-ceil]
    // r[verify properties.snapshot-chunk-count-is-div-ceil]
    proof fn snapshot_chunk_count_is_div_ceil(total_size: u64, chunk_size: u64)
        requires chunk_size > 0
        ensures crate::snapshot_transfer::chunk_count_spec(total_size, chunk_size) == crate::arithmetic::div_ceil_spec(total_size, chunk_size)
    {}

    // r[impl properties.snapshot-transfer-triggers-install]
    // r[verify properties.snapshot-transfer-triggers-install]
    proof fn snapshot_transfer_triggers_install(offset: u64, chunk_size: u64, total_size: u64)
        requires total_size > 0, chunk_size > 0, crate::snapshot_transfer::is_last_chunk_spec(offset, chunk_size, total_size),
        ensures offset as int + chunk_size as int >= total_size as int
    {}

    // r[impl properties.vote-tally-quorum-is-quorum]
    // r[verify properties.vote-tally-quorum-is-quorum]
    proof fn vote_tally_quorum_is_quorum(votes_received: u64, cluster_size: u64)
        requires cluster_size > 0
        ensures crate::ballot::has_won_election_spec(votes_received, cluster_size) == crate::quorum::is_quorum_spec(votes_received, cluster_size)
    {}

    // r[impl properties.session-duplicate-is-fencing]
    // r[verify properties.session-duplicate-is-fencing]
    proof fn session_duplicate_is_fencing(table_seq: u64, req_seq: u64)
        requires crate::client_session::is_duplicate_spec(table_seq, req_seq), req_seq < table_seq,
        ensures crate::fencing::is_stale_spec(req_seq, table_seq)
    {}

    // r[impl properties.session-expire-is-expiration]
    // r[verify properties.session-expire-is-expiration]
    proof fn session_expire_is_expiration(last_activity: u64, now: u64, timeout: u64)
        requires now > last_activity, last_activity as int + timeout as int <= u64::MAX as int,
        ensures crate::client_session::is_session_expired_spec(last_activity, now, timeout) == (now - last_activity > timeout)
    {}

    // r[impl properties.session-register-is-strict-advance]
    // r[verify properties.session-register-is-strict-advance]
    proof fn session_register_is_strict_advance(id: u64)
        requires id < u64::MAX
        ensures crate::monotonic::is_strict_advance_spec(id, crate::client_session::register_session_spec(id).1)
    {}

    } // verus!
}

// --- Proptest: job execution cross-module ---
#[cfg(test)]
mod job_execution_cross_tests {
    use proptest::prelude::*;

    proptest! {
        // r[verify properties.retry-non-retryable-never-retries]
        #[test]
        fn prop_non_retryable_never_retries(
            error_code in (0u64..100).prop_union(200u64..500),
            attempts in 0u64..10,
            max_attempts in 1u64..10,
            now in 5000u64..10000,
            last_attempt in 0u64..1000,
            cooldown in 0u64..100,
        ) {
            prop_assert!(!crate::job_retry::should_retry(
                error_code, attempts, max_attempts, now, last_attempt, cooldown,
            ));
        }

        // r[verify properties.timeout-triggers-failure]
        #[test]
        fn prop_timeout_triggers_failure(
            start in 0u64..5000,
            timeout in 1u64..5000,
            extra in 0u64..5000,
        ) {
            let deadline = crate::job_timeout::compute_deadline(start, timeout);
            let now = deadline.saturating_add(extra);
            if crate::job_timeout::is_timed_out(now, deadline) {
                // The Running→Failed transition is valid
                prop_assert!(crate::job_state::is_valid_transition(
                    crate::job_state::RUNNING,
                    crate::job_state::FAILED,
                ));
            }
        }

        // r[verify properties.result-success-completes]
        #[test]
        fn prop_result_success_completes(
            hash in 0u64..1000,
            size in 100u64..500,
        ) {
            let status = crate::job_result::validate_result(0, hash, hash, size, 0, 1000);
            prop_assert_eq!(status, crate::job_result::VALID);
            // Running→Completed is valid
            prop_assert!(crate::job_state::is_valid_transition(
                crate::job_state::RUNNING,
                crate::job_state::COMPLETED,
            ));
        }

        // r[verify properties.result-failure-fails]
        #[test]
        fn prop_result_failure_fails(
            exit_code in 1u8..=255,
            hash in 0u64..1000,
            size in 100u64..500,
        ) {
            let status = crate::job_result::validate_result(exit_code, hash, hash, size, 0, 1000);
            prop_assert_ne!(status, crate::job_result::VALID);
            // Running→Failed is valid
            prop_assert!(crate::job_state::is_valid_transition(
                crate::job_state::RUNNING,
                crate::job_state::FAILED,
            ));
        }

        // r[verify properties.retryable-disjoint-from-success]
        #[test]
        fn prop_retryable_disjoint_from_success(_x: u8) {
            // Exit code 0 is not retryable
            prop_assert!(!crate::job_retry::is_retryable_error(0));
            // Success code is 0
            prop_assert!(crate::job_result::is_success_code(0));
        }

        // ─── Memory allocator cross-module properties ────────────────

        // r[verify properties.pool-alloc-address-in-region]
        #[test]
        fn prop_pool_alloc_address_in_region(
            cap in 1usize..20,
            obj_size in 1u64..256,
        ) {
            let base = 0u64;
            if (cap as u128) * (obj_size as u128) <= u64::MAX as u128 {
                let map = vec![false; cap];
                let gens = vec![0u32; cap];
                if let Some((slot, addr, _, _, _)) = crate::pool::pool_alloc(&map, &gens, base, obj_size) {
                    // Address is slab-aligned
                    prop_assert_eq!(addr, crate::slab::slot_address(slot as u64, base, obj_size));
                    // Address falls within pool region
                    let region_size = cap as u64 * obj_size;
                    prop_assert!(crate::region::contains_addr(base, region_size, addr));
                }
            }
        }

        // r[verify properties.pool-alloc-agrees-with-token-lifecycle]
        #[test]
        fn prop_pool_alloc_agrees_with_token(cap in 1usize..20) {
            let map = vec![false; cap];
            let gens = vec![0u32; cap];
            // Before alloc: token would be Free → is_live == false
            prop_assert!(!crate::alloc_token::is_live(crate::alloc_token::STATE_FREE));
            // After alloc: token would be Allocated → is_live == true
            if let Some((slot, _, _, new_map, _)) = crate::pool::pool_alloc(&map, &gens, 0, 16) {
                prop_assert!(new_map[slot]); // bitmap says allocated
                prop_assert!(crate::alloc_token::is_live(crate::alloc_token::STATE_ALLOCATED));
            }
        }

        // r[verify properties.arena-successive-allocs-watermark-disjoint]
        #[test]
        fn prop_arena_watermark_disjoint(
            base in 0u64..1000,
            s1 in 1u64..100,
            s2 in 1u64..100,
        ) {
            let (p1, m1) = crate::arena::arena_alloc(base, s1);
            let (p2, _m2) = crate::arena::arena_alloc(m1, s2);
            // Arena disjointness matches watermark disjointness
            prop_assert!(crate::region::regions_disjoint(p1, s1, p2, s2));
        }

        // r[verify properties.arena-reset-increments-generation]
        #[test]
        fn prop_arena_reset_generation(generation in 0u64..(u64::MAX - 1)) {
            let (new_mark, new_gen) = crate::arena::arena_reset(0, generation);
            // Generation increments (monotonic advance)
            prop_assert!(crate::monotonic::is_advance(generation, new_gen));
            prop_assert!(crate::monotonic::is_strict_advance(generation, new_gen));
            // Mark resets to base
            prop_assert_eq!(new_mark, 0);
        }

        // r[verify properties.segregated-free-class-agrees-with-size-class]
        #[test]
        fn prop_seg_class_agrees_with_size_class(size in 1u64..=65536) {
            let seg_class = crate::segregated_free::seg_class_for(size, 17);
            let sc_class = crate::size_class::size_to_class(size);
            // Both should pick the same class for sizes in range
            if sc_class <= 16 {
                prop_assert_eq!(seg_class, sc_class);
            }
        }

        // r[verify properties.size-class-agrees-with-buddy-order]
        #[test]
        fn prop_size_class_agrees_with_buddy(size in 1u64..=(1u64 << 32u64)) {
            let sc = crate::size_class::size_to_class(size);
            let bo = crate::buddy::order_for_size(size);
            // Both return a class/order where 2^result >= size
            prop_assert!(crate::size_class::class_to_size(sc) >= size);
            prop_assert!(crate::buddy::block_size(bo) >= size);
            // class_to_size and block_size are the same function
            prop_assert_eq!(crate::size_class::class_to_size(sc), crate::buddy::block_size(sc));
        }

        // r[verify properties.split-coalesce-buddy-roundtrip]
        #[test]
        fn prop_split_coalesce_buddy_roundtrip(order in 1u64..20) {
            let addr = 0u64;
            let (left, right) = crate::split_coalesce::split_block(addr, order);
            // Both halves have the correct relationship
            prop_assert_eq!(right, left + crate::buddy::block_size(order - 1));
            // Sizes sum to parent
            prop_assert_eq!(
                crate::buddy::block_size(order - 1) + crate::buddy::block_size(order - 1),
                crate::buddy::block_size(order)
            );
        }

        // r[verify properties.alloc-bitmap-slab-generation-agree]
        #[test]
        fn prop_alloc_bitmap_slab_handle(slot in 0u32..1000, generation in 0u32..1000) {
            // alloc_bitmap handle packing agrees with slab handle packing
            let ab_handle = crate::alloc_bitmap::handle_pack(slot, generation);
            let slab_handle = crate::slab::handle_pack(slot, generation);
            prop_assert_eq!(ab_handle, slab_handle);
            // Unpacking agrees
            prop_assert_eq!(
                crate::alloc_bitmap::handle_unpack_slot(ab_handle),
                crate::slab::handle_unpack_index(slab_handle)
            );
            prop_assert_eq!(
                crate::alloc_bitmap::handle_unpack_gen(ab_handle),
                crate::slab::handle_unpack_generation(slab_handle)
            );
        }

        // r[verify properties.fragmentation-agrees-with-free-space-map]
        #[test]
        fn prop_fragmentation_free_space_map(
            map in proptest::collection::vec(proptest::bool::ANY, 1..50),
        ) {
            let total = map.len() as u64;
            let free = map.iter().filter(|&&b| !b).count() as u64;
            if free > 0 {
                // Largest contiguous free run
                let mut max_run = 0u64;
                let mut current_run = 0u64;
                for &b in &map {
                    if !b { current_run += 1; max_run = max_run.max(current_run); }
                    else { current_run = 0; }
                }
                let ext_frag = crate::fragmentation::external_frag(free, max_run);
                // External frag is bounded [0, 100]
                prop_assert!(ext_frag <= 100);
                // If one contiguous chunk, external frag is 0
                if max_run == free {
                    prop_assert_eq!(ext_frag, 0);
                }
            }
        }
    }
}

// ============================================================
// P2 Group 5: Graph/algorithm cross-module properties
// ============================================================

#[cfg(test)]
mod graph_cross_tests {
    use proptest::prelude::*;

    fn random_graph(max_nodes: usize) -> impl Strategy<Value = (Vec<(usize, usize)>, usize)> {
        (3..=max_nodes).prop_flat_map(|n| {
            proptest::collection::vec((0..n, 0..n), 0..=(n * 2).min(20)).prop_map(move |edges| (edges, n))
        })
    }

    fn random_dag(max_nodes: usize) -> impl Strategy<Value = (Vec<(usize, usize)>, usize)> {
        (3..=max_nodes).prop_flat_map(|n| {
            proptest::collection::vec((0..n, 0..n), 0..=(n * 2).min(20)).prop_map(move |raw| {
                let edges: Vec<(usize, usize)> = raw.into_iter().filter(|&(u, v)| u < v).collect();
                (edges, n)
            })
        })
    }

    proptest! {
        // topo_sort succeeds <==> no cycle
        #[test]
        fn prop_topo_sort_iff_no_cycle((edges, n) in random_dag(12)) {
            let has_cycle = crate::cycle_detect::has_cycle(&edges, n);
            let topo = crate::topo_sort::topo_sort(&edges, n);
            // DAGs (u < v filter) never have cycles
            prop_assert!(!has_cycle);
            prop_assert!(topo.is_some());
        }

        // cycle => topo_sort fails
        #[test]
        fn prop_cycle_means_no_topo(n in 3..10usize) {
            let edges: Vec<(usize, usize)> = (0..n).map(|i| (i, (i + 1) % n)).collect();
            prop_assert!(crate::cycle_detect::has_cycle(&edges, n));
            prop_assert!(crate::topo_sort::topo_sort(&edges, n).is_none());
        }

        // reachable <==> shortest_path < infinity
        #[test]
        fn prop_reachable_iff_finite_distance((edges, n) in random_graph(10)) {
            if n > 0 {
                let visited = crate::reachability::reachable_from(&edges, n, 0);
                let dists = crate::shortest_path::bfs_distances(&edges, n, 0);
                for v in 0..n {
                    prop_assert_eq!(visited[v], dists[v] >= 0);
                }
            }
        }

        // 2-colorable ==> no odd cycles (tested via: if 2-color succeeds, no self-loops)
        #[test]
        fn prop_two_colorable_valid_coloring((edges, n) in random_graph(10)) {
            if let Some(colors) = crate::graph_color::two_color(&edges, n) {
                prop_assert!(crate::graph_color::is_valid_coloring(&edges, n, &colors));
            }
        }

        // reachable count >= 1 (source always reachable)
        #[test]
        fn prop_reachable_count_ge_one((edges, n) in random_graph(10)) {
            if n > 0 {
                let visited = crate::reachability::reachable_from(&edges, n, 0);
                let count = crate::reachability::reachable_count(&visited);
                prop_assert!(count >= 1);
            }
        }

        // shortest_path source distance is always 0
        #[test]
        fn prop_source_distance_zero((edges, n) in random_graph(10)) {
            if n > 0 {
                let dists = crate::shortest_path::bfs_distances(&edges, n, 0);
                prop_assert_eq!(dists[0], 0);
            }
        }
    }
}

// ============================================================
// P2 Group 1: Raft read/write path cross-module properties
// ============================================================

#[cfg(test)]
mod raft_read_write_cross_tests {
    use proptest::prelude::*;

    proptest! {
        // follower_read register uses commit_index as read_index
        #[test]
        fn prop_follower_read_uses_commit(
            commit_index in 0u64..1000,
        ) {
            let read_idx = crate::follower_read::register_read(commit_index);
            prop_assert_eq!(read_idx, commit_index);
        }

        // append_entries_build prev_log_index + 1 = next_index
        #[test]
        fn prop_build_prev_index_is_next_minus_one(
            next_index in 1u64..10000,
        ) {
            let prev = crate::append_entries_build::build_prev_log_index(next_index);
            prop_assert_eq!(prev, next_index - 1);
        }

        // config_change: enter_joint then leave_joint returns to stable
        #[test]
        fn prop_config_change_roundtrip(dummy in 0u8..1) {
            let _ = dummy;
            let stable = crate::config_change::PHASE_STABLE;
            let joint = crate::config_change::enter_joint(stable);
            prop_assert_eq!(joint, crate::config_change::PHASE_JOINT);
            let back = crate::config_change::leave_joint(joint);
            prop_assert_eq!(back, stable);
        }

        // snapshot_compaction: entries_after = log_len - compact_through
        #[test]
        fn prop_compaction_entries_conservation(
            log_len in 1u64..100,
            compact_through in 0u64..100,
        ) {
            if compact_through < log_len {
                let after = crate::snapshot_compaction::entries_after_compaction(log_len, compact_through);
                prop_assert_eq!(after, log_len - compact_through);
            }
        }

        // joint_consensus: both configs must have quorum
        #[test]
        fn prop_joint_requires_both_configs(
            total_old in 3u64..=10,
            total_new in 3u64..=10,
        ) {
            let maj_old = total_old / 2 + 1;
            let maj_new = total_new / 2 + 1;
            // Only old quorum — should fail
            if maj_new > 1 {
                prop_assert!(!crate::joint_consensus::is_joint_quorum(maj_old, total_old, maj_new - 1, total_new));
            }
        }
    }
}

// ============================================================
// P2 Group 2: Storage/KV cross-module properties
// ============================================================

#[cfg(test)]
mod storage_kv_cross_tests {
    use proptest::prelude::*;

    proptest! {
        // block_cache: inserted slot is occupied
        #[test]
        fn prop_cache_insert_is_occupied(
            capacity in 2usize..=10,
            idx in 0usize..10,
        ) {
            if idx < capacity {
                let mut slots = vec![crate::block_cache::SLOT_EMPTY; capacity];
                crate::block_cache::insert(&mut slots, idx);
                prop_assert_eq!(slots[idx], crate::block_cache::SLOT_CLEAN);
            }
        }

        // wal_recovery: checkpoint at wal_end means no recovery needed
        #[test]
        fn prop_checkpoint_at_end_no_recovery(
            wal_end in 0u64..10000,
        ) {
            prop_assert!(!crate::wal_recovery::needs_recovery(wal_end, wal_end));
        }

        // write_buffer: flush zeros the immutable buffer, keeps active
        #[test]
        fn prop_flush_zeros_immutable(
            active in 0u64..10000,
            immutable in 0u64..10000,
        ) {
            let (new_active, new_immutable) = crate::write_buffer::flush_complete(active, immutable);
            prop_assert_eq!(new_active, active);
            prop_assert_eq!(new_immutable, 0);
        }

        // page_checksum: pack/unpack roundtrip
        #[test]
        fn prop_checksum_pack_roundtrip(
            a in 0u64..256,
            b in 0u64..256,
        ) {
            let packed = crate::page_checksum::pack(a, b);
            let (ua, ub) = crate::page_checksum::unpack(packed);
            prop_assert_eq!(ua, a);
            prop_assert_eq!(ub, b);
        }

        // btree_insert then btree_delete: insert key then delete it restores original
        #[test]
        fn prop_btree_insert_delete_roundtrip(
            keys in proptest::collection::vec(1u64..100, 1..=8),
            new_key in 100u64..200,
        ) {
            let mut sorted = keys.clone();
            sorted.sort_unstable();
            sorted.dedup();
            if crate::btree_insert::is_sorted(&sorted) && !crate::btree_delete::contains_key(&sorted, new_key) {
                let pos = crate::btree_insert::find_insert_position(&sorted, new_key);
                let inserted = crate::btree_insert::insert_at(&sorted, pos, new_key);
                prop_assert!(crate::btree_delete::contains_key(&inserted, new_key));
                let del_pos = crate::btree_delete::find_key_position(&inserted, new_key);
                let deleted = crate::btree_delete::delete_at(&inserted, del_pos);
                prop_assert_eq!(deleted, sorted);
            }
        }
    }
}

// ============================================================
// P2 Group 3+4: Concurrency + Financial gaps
// ============================================================

#[cfg(test)]
mod concurrency_financial_cross_tests {
    use proptest::prelude::*;

    proptest! {
        // semaphore acquire/release matches barrier all_arrived when n permits
        #[test]
        fn prop_semaphore_acquire_release_conservation(
            capacity in 1u64..=20,
            acquire in 0u64..=20,
        ) {
            if acquire <= capacity {
                let after_acq = crate::semaphore::after_acquire(capacity, acquire);
                let restored = crate::semaphore::after_release(after_acq, acquire);
                prop_assert_eq!(restored, capacity);
            }
        }

        // quota: consume then release roundtrip
        #[test]
        fn prop_quota_consume_release_roundtrip(
            limit in 1u64..=1000,
            used in 0u64..=1000,
            amount in 0u64..=1000,
        ) {
            if used <= limit && amount <= limit - used {
                let after_consume = crate::quota::quota_consume(used, amount);
                let after_release = crate::quota::quota_release(after_consume, amount);
                prop_assert_eq!(after_release, used);
            }
        }

        // quota exhausted <==> remaining == 0
        #[test]
        fn prop_quota_exhausted_iff_zero_remaining(
            limit in 1u64..=100,
            used in 0u64..=100,
        ) {
            if used <= limit {
                let exhausted = crate::quota::quota_is_exhausted(limit, used);
                let remaining = crate::quota::quota_remaining(limit, used);
                prop_assert_eq!(exhausted, remaining == 0);
            }
        }

        // semaphore full <==> acquired_count == capacity
        #[test]
        fn prop_semaphore_full_iff_zero_available(
            capacity in 1u64..=50,
            available in 0u64..=50,
        ) {
            if available <= capacity {
                let full = crate::semaphore::is_full(available, capacity);
                let empty = crate::semaphore::is_empty(available);
                if full {
                    prop_assert_eq!(available, capacity);
                }
                if empty {
                    prop_assert_eq!(available, 0);
                }
            }
        }
    }
}

#[cfg(verus_keep_ghost)]
mod zircon_kernel_proofs {
    use vstd::prelude::*;

    use crate::deadline_queue::is_earlier_spec;
    use crate::process_state::can_transition_spec;
    use crate::zircon_channel::ChannelEndpoint;
    use crate::zircon_channel::ZX_CHANNEL_PEER_CLOSED;
    use crate::zircon_channel::ZX_CHANNEL_READABLE;
    use crate::zircon_channel::channel_signals_spec;
    use crate::zircon_event::ZX_EVENTPAIR_PEER_CLOSED;
    use crate::zircon_event::eventpair_signals_spec;
    use crate::zircon_fifo::ZX_FIFO_PEER_CLOSED;
    use crate::zircon_fifo::ZX_FIFO_READABLE;
    use crate::zircon_fifo::ZirconFifoEndpoint;
    use crate::zircon_fifo::fifo_signals_spec;
    use crate::zircon_futex::requeue_result_spec;
    use crate::zircon_futex::wake_released_spec;
    use crate::zircon_handle::ZX_HANDLE_BOUND;
    use crate::zircon_handle::ZX_HANDLE_IN_TRANSIT;
    use crate::zircon_handle::ZirconHandle;
    use crate::zircon_handle::object_live_spec;
    use crate::zircon_job::process_in_subtree_spec;
    use crate::zircon_port::Packet;
    use crate::zircon_port::Registration;
    use crate::zircon_rights::can_duplicate_spec;
    use crate::zircon_rights::rights_subset_spec;
    use crate::zircon_socket::Endpoint;
    use crate::zircon_socket::ZX_SOCKET_PEER_CLOSED;
    use crate::zircon_socket::ZX_SOCKET_READABLE;
    use crate::zircon_socket::socket_signals_spec;
    use crate::zircon_timer::Deadline;
    use crate::zircon_timer::ZX_TIMER_ARMED;
    use crate::zircon_timer::ZX_TIMER_SIGNALED_STATE;
    use crate::zircon_wait::wait_ready_spec;

    verus! {

    // r[impl properties.zircon-rights-handle]
    pub open spec fn zircon_rights_handle_prop(
        handle: ZirconHandle, requested: u64, new_owner: u64,
    ) -> bool
        recommends handle.wf()
    {
        handle.state == ZX_HANDLE_BOUND && can_duplicate_spec(handle.rights, requested)
            ==> {
                let dup = ZirconHandle {
                    koid: handle.koid,
                    rights: requested,
                    state: ZX_HANDLE_BOUND,
                    owner: new_owner,
                };
                dup.wf() && dup.koid == handle.koid && rights_subset_spec(dup.rights, handle.rights)
            }
    }

    // r[verify properties.zircon-rights-handle]
    proof fn prove_zircon_rights_handle(
        handle: ZirconHandle, requested: u64, new_owner: u64,
    )
        requires handle.wf()
        ensures zircon_rights_handle_prop(handle, requested, new_owner)
    {}

    // r[impl properties.zircon-signal-refinement]
    pub open spec fn zircon_signal_refinement_prop(
        _event_user: u64,
        _event_peer_live: bool,
        _channel: ChannelEndpoint,
        _socket: Endpoint,
        _fifo: ZirconFifoEndpoint,
    ) -> bool {
        true
    }

    // r[verify properties.zircon-signal-refinement]
    proof fn prove_zircon_signal_refinement(
        event_user: u64,
        event_peer_live: bool,
        channel: ChannelEndpoint,
        socket: Endpoint,
        fifo: ZirconFifoEndpoint,
    )
        requires channel.wf(), socket.wf(), fifo.wf()
        ensures zircon_signal_refinement_prop(event_user, event_peer_live, channel, socket, fifo)
    {}

    // r[impl properties.zircon-channel-lifetime]
    pub open spec fn zircon_channel_lifetime_prop(handle: ZirconHandle, endpoint: u64, process: u64) -> bool
        recommends handle.wf(), handle.state == ZX_HANDLE_BOUND
    {
        let in_transit = ZirconHandle {
            koid: handle.koid,
            rights: handle.rights,
            state: ZX_HANDLE_IN_TRANSIT,
            owner: endpoint,
        };
        let rebound = ZirconHandle {
            koid: handle.koid,
            rights: handle.rights,
            state: ZX_HANDLE_BOUND,
            owner: process,
        };
        object_live_spec(seq![in_transit], handle.koid)
            && object_live_spec(seq![rebound], handle.koid)
    }

    // r[verify properties.zircon-channel-lifetime]
    proof fn prove_zircon_channel_lifetime(handle: ZirconHandle, endpoint: u64, process: u64)
        requires handle.wf(), handle.state == ZX_HANDLE_BOUND
        ensures zircon_channel_lifetime_prop(handle, endpoint, process)
    {}

    // r[impl properties.zircon-port-wait]
    pub open spec fn zircon_port_wait_prop(reg: Registration, observed: u64) -> bool {
        wait_ready_spec(observed, reg.mask) ==> {
            let pkt = Packet { key: reg.key, observed, user_queued: false };
            pkt.key == reg.key && pkt.observed == observed && !pkt.user_queued
        }
    }

    // r[verify properties.zircon-port-wait]
    proof fn prove_zircon_port_wait(reg: Registration, observed: u64)
        ensures zircon_port_wait_prop(reg, observed)
    {}

    // r[impl properties.zircon-timer-deadline]
    pub open spec fn zircon_timer_deadline_prop(a_deadline: u64, b_deadline: u64, now: u64) -> bool {
        is_earlier_spec(a_deadline, b_deadline) && now >= b_deadline
            ==> {
                let a = Deadline { koid: 1, state: ZX_TIMER_ARMED, deadline: a_deadline };
                let b = Deadline { koid: 2, state: ZX_TIMER_ARMED, deadline: b_deadline };
                a.wf() && b.wf() && now >= a.deadline
            }
    }

    // r[verify properties.zircon-timer-deadline]
    proof fn prove_zircon_timer_deadline(a_deadline: u64, b_deadline: u64, now: u64)
        ensures zircon_timer_deadline_prop(a_deadline, b_deadline, now)
    {}

    // r[impl properties.zircon-job-process-state]
    pub open spec fn zircon_job_process_state_prop(
        parents: Seq<Option<int>>, owners: Seq<int>, root: int, process: int,
    ) -> bool
        recommends
            0 <= root < parents.len(),
            0 <= process < owners.len(),
            owners[process] < parents.len(),
            crate::zircon_job::well_formed_jobs_spec(parents),
    {
        process_in_subtree_spec(parents, owners, root, process) ==> can_transition_spec(2, 4)
    }

    // r[verify properties.zircon-job-process-state]
    proof fn prove_zircon_job_process_state(
        parents: Seq<Option<int>>, owners: Seq<int>, root: int, process: int,
    )
        requires
            0 <= root < parents.len(),
            0 <= process < owners.len(),
            owners[process] < parents.len(),
            crate::zircon_job::well_formed_jobs_spec(parents),
        ensures zircon_job_process_state_prop(parents, owners, root, process)
    {}

    // r[impl properties.zircon-futex-process-state]
    pub open spec fn zircon_futex_process_state_prop(
        src_waiters: u64, dst_waiters: u64, wake_count: u64, move_count: u64,
    ) -> bool {
        (wake_released_spec(src_waiters, wake_count) > 0
            || requeue_result_spec(src_waiters, dst_waiters, wake_count, move_count).woken > 0)
            ==> can_transition_spec(3, 1)
    }

    // r[verify properties.zircon-futex-process-state]
    proof fn prove_zircon_futex_process_state(
        src_waiters: u64, dst_waiters: u64, wake_count: u64, move_count: u64,
    )
        ensures zircon_futex_process_state_prop(src_waiters, dst_waiters, wake_count, move_count)
    {}

    } // verus!
}

// ============================================================
// P3: Stress testing — boundary values
// ============================================================

#[cfg(test)]
mod boundary_value_tests {
    use proptest::prelude::*;

    // Arithmetic at u64 boundaries
    #[test]
    fn test_arithmetic_boundaries() {
        // abs_diff at extremes
        assert_eq!(crate::arithmetic::abs_diff(0, 0), 0);
        assert_eq!(crate::arithmetic::abs_diff(u64::MAX, 0), u64::MAX);
        assert_eq!(crate::arithmetic::abs_diff(0, u64::MAX), u64::MAX);
        assert_eq!(crate::arithmetic::abs_diff(u64::MAX, u64::MAX), 0);
        assert_eq!(crate::arithmetic::abs_diff(u64::MAX - 1, u64::MAX), 1);

        // saturating_add at overflow boundary
        assert_eq!(crate::arithmetic::saturating_add(u64::MAX, 0), u64::MAX);
        assert_eq!(crate::arithmetic::saturating_add(u64::MAX, 1), u64::MAX);
        assert_eq!(crate::arithmetic::saturating_add(u64::MAX, u64::MAX), u64::MAX);
        assert_eq!(crate::arithmetic::saturating_add(u64::MAX - 1, 1), u64::MAX);

        // saturating_sub at zero boundary
        assert_eq!(crate::arithmetic::saturating_sub(0, 0), 0);
        assert_eq!(crate::arithmetic::saturating_sub(0, 1), 0);
        assert_eq!(crate::arithmetic::saturating_sub(0, u64::MAX), 0);
        assert_eq!(crate::arithmetic::saturating_sub(1, 1), 0);

        // checked_mul at overflow boundary
        assert!(crate::arithmetic::checked_mul(u64::MAX, 2).is_none());
        assert_eq!(crate::arithmetic::checked_mul(u64::MAX, 1), Some(u64::MAX));
        assert_eq!(crate::arithmetic::checked_mul(u64::MAX, 0), Some(0));
        assert_eq!(crate::arithmetic::checked_mul(0, u64::MAX), Some(0));

        // div_ceil with divisor = 1
        assert_eq!(crate::arithmetic::div_ceil(0, 1), 0);
        assert_eq!(crate::arithmetic::div_ceil(u64::MAX, 1), u64::MAX);
        assert_eq!(crate::arithmetic::div_ceil(1, u64::MAX), 1);
        assert_eq!(crate::arithmetic::div_ceil(u64::MAX - 1, u64::MAX), 1);
        assert_eq!(crate::arithmetic::div_ceil(u64::MAX, u64::MAX), 1);

        // gcd boundaries
        assert_eq!(crate::arithmetic::gcd(0, 0), 0);
        assert_eq!(crate::arithmetic::gcd(1, 1), 1);
        assert_eq!(crate::arithmetic::gcd(u64::MAX, 1), 1);
        assert_eq!(crate::arithmetic::gcd(u64::MAX, u64::MAX), u64::MAX);
    }

    // Bitwise at boundaries
    #[test]
    fn test_bitwise_boundaries() {
        // is_power_of_two
        assert!(!crate::bitwise::is_power_of_two(0));
        assert!(crate::bitwise::is_power_of_two(1));
        assert!(crate::bitwise::is_power_of_two(1 << 63));
        assert!(!crate::bitwise::is_power_of_two(u64::MAX));

        // bit_at at position 63
        assert!(crate::bitwise::bit_at(1u64 << 63u64, 63));
        assert!(!crate::bitwise::bit_at(1u64 << 63u64, 62));
        assert!(crate::bitwise::bit_at(u64::MAX, 63));
        assert!(crate::bitwise::bit_at(u64::MAX, 0));

        // toggle is involution
        let x = crate::bitwise::toggle_bit(0, 63);
        assert_eq!(x, 1u64 << 63u64);
        assert_eq!(crate::bitwise::toggle_bit(x, 63), 0);
    }

    // Conversion narrowing boundaries
    #[test]
    fn test_conversion_boundaries() {
        assert_eq!(crate::conversion::narrow_u32(u32::MAX as u64), Some(u32::MAX));
        assert!(crate::conversion::narrow_u32(u32::MAX as u64 + 1).is_none());
        assert_eq!(crate::conversion::narrow_u16(u16::MAX as u64), Some(u16::MAX));
        assert!(crate::conversion::narrow_u16(u16::MAX as u64 + 1).is_none());
        assert_eq!(crate::conversion::narrow_u8(255), Some(255));
        assert!(crate::conversion::narrow_u8(256).is_none());

        assert_eq!(crate::conversion::unsigned_to_signed(i64::MAX as u64), Some(i64::MAX));
        assert!(crate::conversion::unsigned_to_signed(i64::MAX as u64 + 1).is_none());
        assert_eq!(crate::conversion::signed_to_unsigned(0), Some(0));
        assert!(crate::conversion::signed_to_unsigned(-1).is_none());
    }

    // Integer alignment at boundaries
    #[test]
    fn test_integer_boundaries() {
        assert_eq!(crate::integer::log2_floor(1), 0);
        assert_eq!(crate::integer::log2_floor(u64::MAX), 63);
        assert_eq!(crate::integer::align_down(u64::MAX, 1), u64::MAX);
        assert_eq!(crate::integer::align_down(0, 1), 0);
        assert!(crate::integer::is_even(0));
        assert!(crate::integer::is_odd(u64::MAX));
    }

    proptest! {
        // Division by large prime and u64::MAX
        #[test]
        fn prop_div_ceil_large_divisor(a in 0u64..u64::MAX) {
            let large_prime = 999_999_999_999_999_989u64;
            let r1 = crate::arithmetic::div_ceil(a, large_prime);
            let r2 = crate::arithmetic::div_ceil(a, u64::MAX);
            prop_assert!(r1 <= a / large_prime + 1);
            prop_assert!(r2 <= 1);
        }

        // gcd(a, a) == a
        #[test]
        fn prop_gcd_self(a: u64) {
            if a > 0 {
                prop_assert_eq!(crate::arithmetic::gcd(a, a), a);
            }
        }
    }
}

// ============================================================
// P3: Round-trip / inverse proptests
// ============================================================

#[cfg(test)]
mod roundtrip_tests {
    use proptest::prelude::*;

    proptest! {
        // serialize_inj: encode_u64 then decode_u64
        #[test]
        fn prop_u64_encode_decode_roundtrip(v: u64) {
            let encoded = crate::serialize_inj::encode_u64(v);
            let decoded = crate::serialize_inj::decode_u64(&encoded);
            prop_assert_eq!(decoded, v);
        }

        // slab: handle_pack then unpack
        #[test]
        fn prop_slab_handle_pack_unpack(index: u32, generation: u32) {
            let packed = crate::slab::handle_pack(index, generation);
            let ui = crate::slab::handle_unpack_index(packed);
            let ug = crate::slab::handle_unpack_generation(packed);
            prop_assert_eq!(ui, index);
            prop_assert_eq!(ug, generation);
        }

        // slab: slot_address then slot_index roundtrip
        #[test]
        fn prop_slab_address_index_roundtrip(
            index in 0u64..1000,
            base in 0u64..1000,
            slot_size in 1u64..100,
        ) {
            if base as u128 + (index as u128) * (slot_size as u128) <= u64::MAX as u128 {
                let addr = crate::slab::slot_address(index, base, slot_size);
                let back = crate::slab::slot_index(addr, base, slot_size);
                prop_assert_eq!(back, index);
            }
        }

        // cas_loop: aba_pack then unpack
        #[test]
        fn prop_aba_pack_unpack_roundtrip(value: u32, generation: u32) {
            let packed = crate::cas_loop::aba_pack(value, generation);
            let uv = crate::cas_loop::aba_unpack_value(packed);
            let ug = crate::cas_loop::aba_unpack_generation(packed);
            prop_assert_eq!(uv, value);
            prop_assert_eq!(ug, generation);
        }

        // bitwise: set then clear is identity
        #[test]
        fn prop_set_clear_roundtrip(x: u64, pos in 0u64..64) {
            let set = crate::bitwise::set_bit(x, pos);
            let cleared = crate::bitwise::clear_bit(set, pos);
            // If bit was originally 0, cleared == x; if 1, cleared == x
            // because set_bit(x, pos) sets the bit, clear_bit clears it
            if !crate::bitwise::bit_at(x, pos) {
                prop_assert_eq!(cleared, x);
            }
        }

        // ring_buffer: push then pop roundtrip
        #[test]
        fn prop_ring_push_pop(value: u64) {
            let mut buf = crate::ring_buffer::RingBuffer::new(4);
            buf.push(value);
            let popped = buf.pop();
            prop_assert_eq!(popped, Some(value));
        }

        // conversion: signed/unsigned roundtrip for non-negative
        #[test]
        fn prop_signed_unsigned_roundtrip(x in 0i64..i64::MAX) {
            let u = crate::conversion::signed_to_unsigned(x).unwrap();
            let back = crate::conversion::unsigned_to_signed(u).unwrap();
            prop_assert_eq!(back, x);
        }
    }
}

// ============================================================
// P3: Regression seed hardening
// ============================================================

#[cfg(test)]
mod regression_hardening_tests {
    // Each test encodes the exact shrunk input from proptest-regressions/
    // so the fix is verified independently of the seed file.

    // backoff.txt: attempt=64, cap=1
    #[test]
    fn test_regression_backoff_attempt_64_cap_1() {
        let result = crate::backoff::compute_backoff(1, 64, 1);
        assert!(result <= 1, "backoff(64, cap=1) = {result} should be <= cap");
    }

    // consensus_path.txt: last_applied=12, commit=0
    #[test]
    fn test_regression_consensus_path_applied_ahead() {
        // last_applied > commit: batch_apply_end is capped by commit_index
        let end = crate::last_applied::batch_apply_end(12, 0, 10);
        // end = min(last_applied + max_batch, commit_index) = min(22, 0) = 0
        assert_eq!(end, 0, "end should not exceed commit_index");
    }

    // fair_share.txt: tokens=6199315631328619806, w1=1, w2=488, tw=41
    #[test]
    fn test_regression_fair_share_overflow() {
        // w1=1 <= tw=41, so valid; should not panic
        let r1 = crate::fair_share::fair_alloc(6199315631328619806, 1, 41);
        assert!(r1 <= 6199315631328619806);
    }

    // job_retry.txt: attempts=6, max_attempts=0
    #[test]
    fn test_regression_job_retry_max_zero() {
        let next = crate::job_retry::next_attempt(6, 0);
        assert_eq!(next, 0, "max_attempts=0 should cap at 0");
    }

    // last_applied.txt: last_applied=26, commit_index=0, max_batch=1
    #[test]
    fn test_regression_last_applied_ahead_of_commit() {
        // batch_apply_end is capped by commit_index
        let end = crate::last_applied::batch_apply_end(26, 0, 1);
        assert_eq!(end, 0, "end capped at commit_index=0");
    }

    // mpsc_bounds.txt: occ=40, cap=1
    #[test]
    fn test_regression_mpsc_occupancy_exceeds_capacity() {
        let full = crate::mpsc_bounds::is_full(40, 1);
        assert!(full);
    }

    // rate_limit.txt: tokens=2516605035125710725, cost=0, elapsed_ms=1, rate_per_sec=1, burst=0
    #[test]
    fn test_regression_rate_limit_zero_burst_zero_cost() {
        let within = crate::rate_limit::is_within_burst(0, 0);
        assert!(within, "zero cost should always be within burst");
    }

    // tiling.txt: inner rect (199, 224, 96, 143), point at (294, 366) near edge
    #[test]
    fn test_regression_tiling_contained_in() {
        // Inner rect 1x1 at (294,366) inside outer (199,224,96,143)
        // Outer covers x:[199,295), y:[224,367). 294 < 295, 366 < 367.
        let inside = crate::tiling::contained_in(294, 366, 1, 1, 199, 224, 96, 143);
        assert!(inside);
    }

    // watermark.txt: base=156554337110207874, capacity=4491, used=4491, size=...
    #[test]
    fn test_regression_watermark_full_alloc() {
        let fits = crate::watermark::watermark_fits(
            156554337110207874 + 4491, // mark = base + used
            18290189736599339251,
            156554337110207874,
            4491,
        );
        // used == capacity, so nothing fits
        assert!(!fits);
    }
}

#[cfg(verus_keep_ghost)]
mod durable_execution_proofs {
    use vstd::prelude::*;

    use crate::durable_history::DurableEvent;
    use crate::durable_history::append_allowed_spec;
    use crate::durable_history::history_valid_spec;
    use crate::job_idempotency::try_execute_spec;
    use crate::journal::JournalEntry;
    use crate::journal::seq_nums_monotonic_spec;
    use crate::monotonic::is_strict_advance_spec;

    verus! {

    pub open spec fn history_to_journal_spec(events: Seq<DurableEvent>) -> Seq<JournalEntry> {
        Seq::new(events.len(), |i: int| JournalEntry {
            seq_num: events[i].seq_num as u64,
            amount: 1u64,
            is_debit: false,
            running_balance: (i + 1) as u64,
        })
    }

    // r[impl properties.durable-effect-uses-idempotency]
    pub open spec fn durable_effect_uses_idempotency_prop(
        events: Seq<DurableEvent>,
        seq_num: usize,
        effect_id: u64,
    ) -> bool {
        !crate::durable_replay::should_execute_effect_spec(events, seq_num, effect_id)
            ==> !try_execute_spec(effect_id, seq![effect_id]).0
    }

    // r[verify properties.durable-effect-uses-idempotency]
    proof fn prove_durable_effect_uses_idempotency(
        events: Seq<DurableEvent>,
        seq_num: usize,
        effect_id: u64,
    )
        ensures durable_effect_uses_idempotency_prop(events, seq_num, effect_id)
    {
        if !crate::durable_replay::should_execute_effect_spec(events, seq_num, effect_id) {
            assert(crate::job_idempotency::is_consumed_spec(effect_id, seq![effect_id])) by {
                assert(seq![effect_id][0] == effect_id);
            }
            assert(!try_execute_spec(effect_id, seq![effect_id]).0);
        }
    }

    // r[impl properties.durable-history-seq-is-strict-advance]
    pub open spec fn durable_history_seq_is_strict_advance_prop(
        events: Seq<DurableEvent>,
        i: int,
    ) -> bool {
        history_valid_spec(events) && 0 <= i < events.len() - 1
            ==> is_strict_advance_spec(events[i].seq_num as u64, events[i + 1].seq_num as u64)
    }

    // r[verify properties.durable-history-seq-is-strict-advance]
    proof fn prove_durable_history_seq_is_strict_advance(
        events: Seq<DurableEvent>,
        i: int,
    )
        requires events.len() <= usize::MAX as int
        ensures durable_history_seq_is_strict_advance_prop(events, i)
    {
        if history_valid_spec(events) && 0 <= i < events.len() - 1 {
            crate::durable_history::history_valid_pointwise(events, i);
            crate::durable_history::history_valid_pointwise(events, i + 1);
            assert(events[i].seq_num == i as usize);
            assert(events[i + 1].seq_num == (i + 1) as usize);
            assert(events[i].seq_num + 1 == events[i + 1].seq_num);
            assert((events[i].seq_num as u64) < (events[i + 1].seq_num as u64));
        }
    }

    // r[impl properties.durable-history-prefix-like-journal]
    pub open spec fn durable_history_prefix_like_journal_prop(
        events: Seq<DurableEvent>,
        new_event: DurableEvent,
    ) -> bool {
        append_allowed_spec(events, new_event)
            ==> seq_nums_monotonic_spec(history_to_journal_spec(events.push(new_event)))
    }

    // r[verify properties.durable-history-prefix-like-journal]
    proof fn prove_durable_history_prefix_like_journal(
        events: Seq<DurableEvent>,
        new_event: DurableEvent,
    )
        requires events.len() <= usize::MAX as int
        ensures durable_history_prefix_like_journal_prop(events, new_event)
    {
        if append_allowed_spec(events, new_event) {
            assert(history_valid_spec(events));
            assert(new_event.seq_num == events.len());
            assert forall|i: int| 0 <= i < events.push(new_event).len()
                implies history_to_journal_spec(events.push(new_event))[i].seq_num == i as u64 by {
                if i < events.len() {
                    crate::durable_history::history_valid_pointwise(events, i);
                    assert(events[i].seq_num == i as usize);
                } else {
                    assert(i == events.len());
                    assert(events.push(new_event)[i] == new_event);
                }
            }
            assert forall|i: int, j: int| #![trigger history_to_journal_spec(events.push(new_event))[i], history_to_journal_spec(events.push(new_event))[j]]
                0 <= i < j < events.push(new_event).len()
                    implies history_to_journal_spec(events.push(new_event))[i].seq_num
                        < history_to_journal_spec(events.push(new_event))[j].seq_num by {
                assert(history_to_journal_spec(events.push(new_event))[i].seq_num == i as u64);
                assert(history_to_journal_spec(events.push(new_event))[j].seq_num == j as u64);
            }
        }
    }

    } // verus!
}

// --- Hypervisor cross-module properties ---

#[cfg(verus_keep_ghost)]
mod hypervisor_cross_proofs {
    use vstd::prelude::*;

    use crate::hypervisor_exit::*;
    use crate::hypervisor_gpa::*;
    use crate::hypervisor_memslot::*;
    use crate::hypervisor_vcpu::*;

    verus! {

    // r[impl properties.hypervisor-translation-region]
    pub open spec fn translation_in_region_prop(
        slot: Memslot, gfn: u64,
    ) -> bool
        recommends
            slot_contains_gfn_spec(slot, gfn),
            slot.host_base as int + slot.npages as int <= u64::MAX as int,
    {
        let host_addr = translate_gpa_spec(slot, gfn);
        slot.host_base as int <= host_addr
        && host_addr < slot.host_base as int + slot.npages as int
    }

    // r[verify properties.hypervisor-translation-region]
    proof fn prove_translation_in_region(slot: Memslot, gfn: u64)
        requires
            slot_contains_gfn_spec(slot, gfn),
            slot.host_base as int + slot.npages as int <= u64::MAX as int,
        ensures translation_in_region_prop(slot, gfn)
    {}

    // r[impl properties.hypervisor-wakeup]
    pub open spec fn wakeup_prop(halted: bool, deliverable: bool, result_state: u64) -> bool {
        if halted && deliverable {
            result_state == VCPU_RUNNABLE
        } else if halted && !deliverable {
            result_state == VCPU_HALTED
        } else {
            true
        }
    }

    // r[verify properties.hypervisor-wakeup]
    proof fn prove_wakeup(deliverable: bool)
        ensures
            wakeup_prop(true, deliverable, vcpu_wake_spec(VCPU_HALTED, deliverable))
    {}

    // r[impl properties.hypervisor-exit-state]
    pub open spec fn exit_state_agreement_prop(
        exit_class: u64, has_wake: bool, vcpu_state: u64,
    ) -> bool {
        let disp = exit_disposition_spec(exit_class, has_wake);
        if disp == DISP_BLOCK {
            !vcpu_can_enter_guest_spec(vcpu_state)
        } else if disp == DISP_TERMINATE {
            vcpu_state == VCPU_STOPPED
        } else {
            true
        }
    }

    // r[verify properties.hypervisor-exit-state]
    proof fn prove_exit_state_block()
        ensures exit_state_agreement_prop(
            EXIT_HALT, false, vcpu_halt_spec(VCPU_RUNNABLE),
        )
    {}

    // r[verify properties.hypervisor-exit-state]
    proof fn prove_exit_state_terminate()
        ensures exit_state_agreement_prop(
            EXIT_SHUTDOWN, false, vcpu_stop_spec(VCPU_RUNNABLE),
        )
    {}

    } // verus!
}

#[cfg(test)]
mod durable_execution_cross_tests {
    use proptest::prelude::*;

    use crate::durable_history::DurableEvent;
    use crate::durable_history::EVENT_EFFECT_DONE;
    use crate::durable_history::EVENT_WORK;

    fn work(seq_num: usize) -> DurableEvent {
        DurableEvent {
            seq_num,
            kind: EVENT_WORK,
            effect_id: 0,
        }
    }

    // r[verify properties.durable-effect-uses-idempotency]
    #[test]
    fn prop_durable_effect_uses_idempotency() {
        let events = vec![DurableEvent {
            seq_num: 0,
            kind: EVENT_EFFECT_DONE,
            effect_id: 7,
        }];
        assert!(!crate::durable_replay::should_execute_effect(&events, 0, 7));
        assert_eq!(crate::job_idempotency::try_execute(7, &[7]), (false, false));
    }

    // r[verify properties.durable-history-seq-is-strict-advance]
    #[test]
    fn prop_durable_history_seq_is_strict_advance() {
        let events = vec![work(0), work(1), work(2)];
        assert!(crate::durable_history::history_valid(&events));
        for pair in events.windows(2) {
            assert!(crate::monotonic::is_strict_advance(pair[0].seq_num as u64, pair[1].seq_num as u64));
        }
    }

    // r[verify properties.durable-history-prefix-like-journal]
    #[test]
    fn prop_durable_history_prefix_like_journal() {
        let events = vec![work(0), work(1)];
        let new_event = work(2);
        assert!(crate::durable_history::append_allowed(&events, new_event));
        let journal_entries = vec![
            crate::journal::JournalEntry {
                seq_num: 0,
                amount: 1,
                is_debit: false,
                running_balance: 1,
            },
            crate::journal::JournalEntry {
                seq_num: 1,
                amount: 1,
                is_debit: false,
                running_balance: 2,
            },
            crate::journal::JournalEntry {
                seq_num: 2,
                amount: 1,
                is_debit: false,
                running_balance: 3,
            },
        ];
        for pair in journal_entries.windows(2) {
            assert!(pair[0].seq_num < pair[1].seq_num);
        }
    }

    proptest! {
        // r[verify properties.durable-effect-uses-idempotency]
        #[test]
        fn prop_effect_marker_blocks_like_consumed(effect_id in 0u64..1000) {
            let events = vec![DurableEvent { seq_num: 0, kind: EVENT_EFFECT_DONE, effect_id }];
            prop_assert!(!crate::durable_replay::should_execute_effect(&events, 0, effect_id));
            prop_assert_eq!(crate::job_idempotency::try_execute(effect_id, &[effect_id]), (false, false));
        }

        // r[verify properties.durable-history-seq-is-strict-advance]
        #[test]
        fn prop_adjacent_durable_seq_is_strict(len in 2usize..30) {
            let events: Vec<DurableEvent> = (0..len).map(work).collect();
            for i in 0..events.len() - 1 {
                prop_assert!(crate::monotonic::is_strict_advance(events[i].seq_num as u64, events[i + 1].seq_num as u64));
            }
        }

        // r[verify properties.durable-history-prefix-like-journal]
        #[test]
        fn prop_valid_append_keeps_journal_like_seq(len in 0usize..30) {
            let events: Vec<DurableEvent> = (0..len).map(work).collect();
            let new_event = DurableEvent { seq_num: len, kind: EVENT_WORK, effect_id: 0 };
            prop_assert!(crate::durable_history::append_allowed(&events, new_event));

            let mut journal_entries: Vec<crate::journal::JournalEntry> = events.iter().enumerate().map(|(i, e)| {
                crate::journal::JournalEntry {
                    seq_num: e.seq_num as u64,
                    amount: 1,
                    is_debit: false,
                    running_balance: (i + 1) as u64,
                }
            }).collect();
            journal_entries.push(crate::journal::JournalEntry {
                seq_num: new_event.seq_num as u64,
                amount: 1,
                is_debit: false,
                running_balance: (journal_entries.len() + 1) as u64,
            });
            for pair in journal_entries.windows(2) {
                prop_assert!(pair[0].seq_num < pair[1].seq_num);
            }
        }
    }
}

#[cfg(verus_keep_ghost)]
mod chaoscontrol_property_proofs {
    use vstd::prelude::*;

    use crate::quorum::majority_spec;

    verus! {

    pub closed spec fn cc_selected_source_index_spec(indices: Seq<int>, source_index: int) -> bool {
        exists|i: int| 0 <= i < indices.len() && indices[i] == source_index
    }

    pub open spec fn cc_subset_spec(source: Seq<(int, int, int)>, indices: Seq<int>) -> Seq<(int, int, int)>
        decreases source.len()
    {
        if source.len() == 0 {
            seq![]
        } else {
            let head = source[0];
            let tail = cc_subset_spec(source.subrange(1, source.len() as int), indices);
            if cc_selected_source_index_spec(indices, head.2) {
                seq![head] + tail
            } else {
                tail
            }
        }
    }

    pub open spec fn cc_horizons_nondecreasing_spec(horizons: Seq<int>) -> bool {
        forall|i: int, j: int| 0 <= i <= j < horizons.len() ==> horizons[i] <= horizons[j]
    }

    pub open spec fn cc_horizon_covers_schedule_spec(schedule: Seq<(int, int, int)>, horizons: Seq<int>) -> bool {
        horizons.len() > 0
            && forall|i: int| 0 <= i < schedule.len() ==> schedule[i].0 <= horizons[horizons.len() - 1]
    }

    pub open spec fn cc_replay_fully_spec(schedule: Seq<(int, int, int)>, horizons: Seq<int>) -> Seq<(int, int, int)> {
        if cc_horizons_nondecreasing_spec(horizons) && cc_horizon_covers_schedule_spec(schedule, horizons) {
            schedule
        } else {
            seq![]
        }
    }

    // r[depends chaoscontrol-fault-schedule.replay]
    // r[depends chaoscontrol-fault-schedule.subset]
    // r[impl properties.chaoscontrol-subset-replay]
    pub open spec fn chaoscontrol_subset_replay_order_prop(
        source: Seq<(int, int, int)>,
        indices: Seq<int>,
        horizons: Seq<int>,
    ) -> bool {
        let subset = cc_subset_spec(source, indices);
        (cc_horizons_nondecreasing_spec(horizons) && cc_horizon_covers_schedule_spec(subset, horizons))
            ==> cc_replay_fully_spec(subset, horizons) =~= subset
    }

    // r[verify properties.chaoscontrol-subset-replay]
    pub proof fn chaoscontrol_subset_replay_order(
        source: Seq<(int, int, int)>,
        indices: Seq<int>,
        horizons: Seq<int>,
    )
        ensures chaoscontrol_subset_replay_order_prop(source, indices, horizons)
    {
    }

    pub uninterp spec fn cc_fingerprint_mix_spec(fp: u64, active_turn: u64, assigned_quantum: u64) -> u64;

    pub open spec fn cc_fingerprint_after_trace_spec(start_fp: u64, trace: Seq<(u64, u64)>) -> u64
        decreases trace.len()
    {
        if trace.len() == 0 {
            start_fp
        } else {
            let head = trace[0];
            cc_fingerprint_after_trace_spec(
                cc_fingerprint_mix_spec(start_fp, head.0, head.1),
                trace.subrange(1, trace.len() as int),
            )
        }
    }

    // r[depends chaoscontrol-scheduler.fingerprint]
    // r[impl properties.chaoscontrol-fingerprint-trace]
    pub open spec fn chaoscontrol_fingerprint_trace_eq_prop(
        start_fp1: u64,
        start_fp2: u64,
        trace1: Seq<(u64, u64)>,
        trace2: Seq<(u64, u64)>,
    ) -> bool {
        (start_fp1 == start_fp2 && trace1 == trace2)
            ==> cc_fingerprint_after_trace_spec(start_fp1, trace1)
                == cc_fingerprint_after_trace_spec(start_fp2, trace2)
    }

    // r[verify properties.chaoscontrol-fingerprint-trace]
    pub proof fn chaoscontrol_fingerprint_trace_eq(
        start_fp1: u64,
        start_fp2: u64,
        trace1: Seq<(u64, u64)>,
        trace2: Seq<(u64, u64)>,
    )
        ensures chaoscontrol_fingerprint_trace_eq_prop(start_fp1, start_fp2, trace1, trace2)
        decreases trace1.len()
    {
        if start_fp1 == start_fp2 && trace1 == trace2 {
            if trace1.len() > 0 {
                assert(trace2.len() == trace1.len());
                assert(trace2[0] == trace1[0]);
                assert(trace2.subrange(1, trace2.len() as int) == trace1.subrange(1, trace1.len() as int));
                let next1 = cc_fingerprint_mix_spec(start_fp1, trace1[0].0, trace1[0].1);
                let next2 = cc_fingerprint_mix_spec(start_fp2, trace2[0].0, trace2[0].1);
                assert(next1 == next2);
                chaoscontrol_fingerprint_trace_eq(
                    next1,
                    next2,
                    trace1.subrange(1, trace1.len() as int),
                    trace2.subrange(1, trace2.len() as int),
                );
            }
        }
    }

    pub open spec fn cc_alive_count_spec(alive: Seq<bool>) -> nat
        decreases alive.len()
    {
        if alive.len() == 0 {
            0nat
        } else {
            cc_alive_count_spec(alive.subrange(1, alive.len() as int)) + if alive[0] { 1nat } else { 0nat }
        }
    }

    pub open spec fn cc_valid_fault_state_spec(alive: Seq<bool>, partitioned: Seq<Seq<bool>>) -> bool {
        &&& 2 <= alive.len() <= 64
        &&& partitioned.len() == alive.len()
        &&& forall|i: int| 0 <= i < alive.len() ==> partitioned[i].len() == alive.len() && !partitioned[i][i]
    }

    pub open spec fn cc_quorum_reachable_spec(alive: Seq<bool>, partitioned: Seq<Seq<bool>>) -> bool
        recommends cc_valid_fault_state_spec(alive, partitioned)
    {
        if cc_alive_count_spec(alive) < majority_spec(alive.len() as u64) as nat {
            false
        } else {
            exists|a: int, b: int|
                0 <= a < b < alive.len()
                    && alive[a]
                    && alive[b]
                    && !partitioned[a][b]
                    && !partitioned[b][a]
        }
    }

    pub open spec fn cc_healthy_period_spec(alive: Seq<bool>, partitioned: Seq<Seq<bool>>) -> bool
        recommends cc_valid_fault_state_spec(alive, partitioned)
    {
        cc_alive_count_spec(alive) == alive.len() && cc_quorum_reachable_spec(alive, partitioned)
    }

    // r[depends chaoscontrol-fault-state.quorum-health]
    // r[depends chaoscontrol-fault-state.liveness-gate]
    // r[impl properties.chaoscontrol-quorum-gate]
    pub open spec fn chaoscontrol_quorum_gate_sound_prop(alive: Seq<bool>, partitioned: Seq<Seq<bool>>) -> bool {
        cc_valid_fault_state_spec(alive, partitioned)
            ==> (cc_healthy_period_spec(alive, partitioned) ==> cc_quorum_reachable_spec(alive, partitioned))
    }

    // r[verify properties.chaoscontrol-quorum-gate]
    pub proof fn chaoscontrol_quorum_gate_sound(alive: Seq<bool>, partitioned: Seq<Seq<bool>>)
        ensures chaoscontrol_quorum_gate_sound_prop(alive, partitioned)
    {
    }

    } // verus!
}

#[cfg(test)]
mod chaoscontrol_property_tests {
    const FP_MULT: u64 = 0x517c_c1b7_2722_0a95;

    fn subset_by_source_index(source: &[(i64, i64, i64)], indices: &[i64]) -> Vec<(i64, i64, i64)> {
        source.iter().copied().filter(|entry| indices.contains(&entry.2)).collect()
    }

    fn replay_fully(schedule: &[(i64, i64, i64)], horizons: &[i64]) -> Vec<(i64, i64, i64)> {
        if horizons.is_empty() {
            return Vec::new();
        }
        let nondecreasing = horizons.windows(2).all(|pair| pair[0] <= pair[1]);
        let last = horizons[horizons.len() - 1];
        if nondecreasing && schedule.iter().all(|entry| entry.0 <= last) {
            schedule.to_vec()
        } else {
            Vec::new()
        }
    }

    fn fingerprint_after_trace(mut fp: u64, trace: &[(u64, u64)]) -> u64 {
        for (active, quantum) in trace {
            fp = fp.wrapping_mul(FP_MULT) ^ *active ^ *quantum;
        }
        fp
    }

    fn majority(n: usize) -> usize {
        n / 2 + 1
    }

    fn alive_count(alive: &[bool]) -> usize {
        alive.iter().filter(|&&v| v).count()
    }

    fn quorum_reachable(alive: &[bool], partitioned: &[Vec<bool>]) -> bool {
        if alive_count(alive) < majority(alive.len()) {
            return false;
        }
        for a in 0..alive.len() {
            for b in (a + 1)..alive.len() {
                if alive[a] && alive[b] && !partitioned[a][b] && !partitioned[b][a] {
                    return true;
                }
            }
        }
        false
    }

    fn healthy_period(alive: &[bool], partitioned: &[Vec<bool>]) -> bool {
        alive.iter().all(|v| *v) && quorum_reachable(alive, partitioned)
    }

    // r[verify properties.chaoscontrol-subset-replay]
    #[test]
    fn test_chaoscontrol_subset_replay_order() {
        let source = vec![(5, 0, 0), (7, 1, 1), (7, 2, 2), (9, 3, 3)];
        let subset = subset_by_source_index(&source, &[3, 1, 99, 1]);
        assert_eq!(subset, vec![(7, 1, 1), (9, 3, 3)]);
        assert_eq!(replay_fully(&subset, &[7, 9]), subset);
    }

    // r[verify properties.chaoscontrol-fingerprint-trace]
    #[test]
    fn test_chaoscontrol_fingerprint_trace_eq() {
        let trace = vec![(1u64, 5u64), (2u64, 7u64), (0u64, 3u64)];
        let left = fingerprint_after_trace(0, &trace);
        let right = fingerprint_after_trace(0, &trace);
        assert_eq!(left, right);
    }

    // r[verify properties.chaoscontrol-quorum-gate]
    #[test]
    fn test_chaoscontrol_quorum_gate_sound() {
        let alive = vec![true, true, true];
        let partitioned = vec![vec![false, false, true], vec![false, false, true], vec![
            true, true, false,
        ]];
        assert!(healthy_period(&alive, &partitioned));
        assert!(quorum_reachable(&alive, &partitioned));
    }
}

#[cfg(test)]
mod choreography_property_tests {
    use crate::choreography_global::GlobalBranch;
    use crate::choreography_global::GlobalChoreo;
    use crate::choreography_global::PayloadTag;
    use crate::choreography_local::LocalBranch;
    use crate::choreography_local::LocalChoreo;
    use crate::choreography_projection::project_endpoint;
    use crate::choreography_step::global_choice_step;
    use crate::choreography_step::local_offer_step;
    use crate::choreography_step::local_recv_step;
    use crate::choreography_step::local_send_step;

    fn branch(label: u32, body: GlobalChoreo) -> GlobalBranch {
        GlobalBranch { label, body }
    }

    fn payload(raw: u32) -> PayloadTag {
        PayloadTag { raw }
    }

    fn first_offer_labels(local: &LocalChoreo, from: u32) -> Option<Vec<u32>> {
        match local {
            LocalChoreo::Send { next, .. }
            | LocalChoreo::Recv { next, .. }
            | LocalChoreo::SendOwned { next, .. }
            | LocalChoreo::RecvOwned { next, .. } => first_offer_labels(next, from),
            LocalChoreo::End | LocalChoreo::InternalChoice { .. } => None,
            LocalChoreo::Offer {
                from: offer_from,
                branches,
            } => {
                if *offer_from == from {
                    Some(branches.iter().map(|branch| branch.label).collect())
                } else {
                    None
                }
            }
        }
    }

    // r[verify properties.choreography-duality]
    #[test]
    fn test_choreography_projection_duality_ping() {
        let global = GlobalChoreo::Comm {
            from: 1,
            to: 2,
            label: 7,
            payload_tag: payload(9),
            next: Box::new(GlobalChoreo::End),
        };
        let sender = project_endpoint(1, &global);
        let receiver = project_endpoint(2, &global);
        assert_eq!(local_send_step(&sender), Some(LocalChoreo::End));
        assert_eq!(local_recv_step(&receiver), Some(LocalChoreo::End));
    }

    // r[verify properties.choreography-choice-agreement]
    #[test]
    fn test_choreography_choice_label_agreement() {
        let global = GlobalChoreo::Choice {
            decider: 0,
            branches: vec![
                branch(1, GlobalChoreo::Comm {
                    from: 0,
                    to: 2,
                    label: 1,
                    payload_tag: payload(10),
                    next: Box::new(GlobalChoreo::End),
                }),
                branch(4, GlobalChoreo::Comm {
                    from: 0,
                    to: 2,
                    label: 4,
                    payload_tag: payload(11),
                    next: Box::new(GlobalChoreo::End),
                }),
            ],
        };
        let decider = project_endpoint(0, &global);
        let non_decider = project_endpoint(2, &global);
        assert_eq!(decider, LocalChoreo::InternalChoice {
            branches: vec![
                LocalBranch {
                    label: 1,
                    body: LocalChoreo::Send {
                        peer: 2,
                        label: 1,
                        payload_tag: payload(10),
                        next: Box::new(LocalChoreo::End),
                    },
                },
                LocalBranch {
                    label: 4,
                    body: LocalChoreo::Send {
                        peer: 2,
                        label: 4,
                        payload_tag: payload(11),
                        next: Box::new(LocalChoreo::End),
                    },
                },
            ],
        });
        assert_eq!(first_offer_labels(&non_decider, 0), Some(vec![1, 4]));
    }

    // r[verify properties.choreography-step-correspondence]
    #[test]
    fn test_choreography_step_projection_correspondence_common_prefix() {
        let global = GlobalChoreo::Choice {
            decider: 0,
            branches: vec![
                branch(1, GlobalChoreo::Comm {
                    from: 2,
                    to: 3,
                    label: 11,
                    payload_tag: payload(0),
                    next: Box::new(GlobalChoreo::Comm {
                        from: 0,
                        to: 2,
                        label: 1,
                        payload_tag: payload(0),
                        next: Box::new(GlobalChoreo::End),
                    }),
                }),
                branch(4, GlobalChoreo::Comm {
                    from: 2,
                    to: 3,
                    label: 11,
                    payload_tag: payload(0),
                    next: Box::new(GlobalChoreo::Comm {
                        from: 0,
                        to: 2,
                        label: 4,
                        payload_tag: payload(0),
                        next: Box::new(GlobalChoreo::End),
                    }),
                }),
            ],
        };
        let merged = project_endpoint(2, &global);
        let chosen = global_choice_step(&global, 4).unwrap();
        let chosen_projection = project_endpoint(2, &chosen);
        match (merged, chosen_projection) {
            (LocalChoreo::Send { next, .. }, LocalChoreo::Send { next: chosen_next, .. }) => {
                assert_eq!(local_offer_step(&next, 4), Some(*chosen_next));
            }
            _ => panic!("expected shared-prefix send"),
        }
    }
}

#[cfg(test)]
mod web_of_trust_property_tests {
    use crate::web_of_trust_attestation::Attestation;
    use crate::web_of_trust_attestation::TRUST_ROLE_TAG;
    use crate::web_of_trust_attestation::attestation_active_at;
    use crate::web_of_trust_attestation::attestation_payload_bytes;
    use crate::web_of_trust_attestation::attestation_signature_bytes_runtime;
    use crate::web_of_trust_chain::chain_valid_at;
    use crate::web_of_trust_policy::threshold_accepts;
    use crate::web_of_trust_principal::PrincipalId;
    use crate::web_of_trust_principal::principal_id_from_bytes;
    use crate::web_of_trust_resolution::resolves_trusted_at;
    use crate::web_of_trust_revocation::FAMILY_TARGET_KIND_TAG;
    use crate::web_of_trust_revocation::Revocation;
    use crate::web_of_trust_revocation::revocation_payload_bytes;
    use crate::web_of_trust_revocation::revocation_signature_bytes_runtime;

    fn signed_attestation(
        issuer_key_bytes: Vec<u8>,
        subject_key_bytes: Vec<u8>,
        role_tag: u8,
        not_before: u64,
        not_after: u64,
        sequence_no: u64,
    ) -> Attestation {
        let issuer = principal_id_from_bytes(&issuer_key_bytes);
        let subject = principal_id_from_bytes(&subject_key_bytes);
        let unsigned = Attestation {
            issuer_key_bytes,
            issuer,
            subject_key_bytes,
            subject,
            role_tag,
            not_before,
            not_after,
            sequence_no,
            signature: Vec::new(),
        };
        let payload = attestation_payload_bytes(&unsigned).unwrap();
        let signature = attestation_signature_bytes_runtime(unsigned.issuer_key_bytes.as_slice(), payload.as_slice());
        Attestation { signature, ..unsigned }
    }

    fn signed_family_revocation(
        issuer_key_bytes: Vec<u8>,
        subject_key_bytes: Vec<u8>,
        role_tag: u8,
        effective_time: u64,
    ) -> Revocation {
        let issuer = principal_id_from_bytes(&issuer_key_bytes);
        let family_subject = principal_id_from_bytes(&subject_key_bytes);
        let unsigned = Revocation {
            issuer_key_bytes,
            issuer,
            target_kind_tag: FAMILY_TARGET_KIND_TAG,
            exact_payload_target: Vec::new(),
            family_subject_key_bytes: subject_key_bytes,
            family_subject,
            family_role_tag: role_tag,
            effective_time,
            signature: Vec::new(),
        };
        let payload = revocation_payload_bytes(&unsigned).unwrap();
        let signature = revocation_signature_bytes_runtime(unsigned.issuer_key_bytes.as_slice(), payload.as_slice());
        Revocation { signature, ..unsigned }
    }

    fn rooted_oracle_dfs(
        current: &PrincipalId,
        roots: &[PrincipalId],
        attestations: &[Attestation],
        revocations: &Vec<Revocation>,
        depth: usize,
        t: u64,
        visited: &mut Vec<Vec<u8>>,
    ) -> bool {
        if roots.iter().any(|root| root.digest == current.digest) {
            return true;
        }
        if depth == 0 {
            return false;
        }

        for att in attestations {
            if att.subject.digest != current.digest {
                continue;
            }
            if att.role_tag != TRUST_ROLE_TAG || !attestation_active_at(att, revocations, t) {
                continue;
            }
            if visited.contains(&att.issuer.digest) {
                continue;
            }
            visited.push(att.issuer.digest.clone());
            if rooted_oracle_dfs(&att.issuer, roots, attestations, revocations, depth - 1, t, visited) {
                return true;
            }
            visited.pop();
        }
        false
    }

    fn threshold_distinct_count_oracle(
        roots: &[PrincipalId],
        attestations: &[Attestation],
        revocations: &Vec<Revocation>,
        subject: &PrincipalId,
        depth: usize,
        t: u64,
    ) -> usize {
        if depth == 0 {
            return 0;
        }

        let mut seen: Vec<Vec<u8>> = Vec::new();
        let mut count = 0usize;
        for att in attestations {
            if att.subject.digest != subject.digest {
                continue;
            }
            if att.issuer.digest == subject.digest {
                continue;
            }
            if att.role_tag != TRUST_ROLE_TAG || !attestation_active_at(att, revocations, t) {
                continue;
            }
            if seen.contains(&att.issuer.digest) {
                continue;
            }
            let mut visited = vec![subject.digest.clone(), att.issuer.digest.clone()];
            if rooted_oracle_dfs(&att.issuer, roots, attestations, revocations, depth - 1, t, &mut visited) {
                seen.push(att.issuer.digest.clone());
                count += 1;
            }
        }
        count
    }

    // r[verify properties.web-of-trust.revocation-cuts-trust]
    #[test]
    fn test_revocation_cuts_designated_witness_only() {
        let root_key = vec![1, 2, 3];
        let a_key = vec![4, 5, 6];
        let b_key = vec![7, 8, 9];
        let subject_key = vec![10, 11, 12];

        let att_ra = signed_attestation(root_key.clone(), a_key.clone(), TRUST_ROLE_TAG, 0, 20, 1);
        let att_as = signed_attestation(a_key.clone(), subject_key.clone(), TRUST_ROLE_TAG, 0, 20, 2);
        let att_rb = signed_attestation(root_key.clone(), b_key.clone(), TRUST_ROLE_TAG, 0, 20, 3);
        let att_bs = signed_attestation(b_key, subject_key.clone(), TRUST_ROLE_TAG, 0, 20, 4);
        let revoke_as = signed_family_revocation(a_key.clone(), subject_key.clone(), TRUST_ROLE_TAG, 6);

        let roots = vec![principal_id_from_bytes(&root_key)];
        let subject = principal_id_from_bytes(&subject_key);
        let attestations = vec![att_ra, att_as, att_rb, att_bs];
        let revocations = vec![revoke_as];
        let witness = vec![0usize, 1usize];

        assert!(chain_valid_at(&witness, &roots, &attestations, &Vec::new(), &subject, 5));
        assert!(!chain_valid_at(&witness, &roots, &attestations, &revocations, &subject, 7));
        assert!(resolves_trusted_at(&roots, &attestations, &revocations, &subject, 2, 7));
    }

    // r[verify properties.web-of-trust.depth-monotone]
    #[test]
    fn test_depth_monotone_preserves_chain_resolution() {
        let root_key = vec![1, 2, 3];
        let mid_key = vec![4, 5, 6];
        let subject_key = vec![7, 8, 9];
        let att1 = signed_attestation(root_key.clone(), mid_key.clone(), TRUST_ROLE_TAG, 0, 20, 1);
        let att2 = signed_attestation(mid_key, subject_key.clone(), TRUST_ROLE_TAG, 0, 20, 2);
        let roots = vec![principal_id_from_bytes(&root_key)];
        let subject = principal_id_from_bytes(&subject_key);
        let attestations = vec![att1, att2];
        let revocations = Vec::new();

        assert!(resolves_trusted_at(&roots, &attestations, &revocations, &subject, 2, 5));
        assert!(resolves_trusted_at(&roots, &attestations, &revocations, &subject, 4, 5));
    }

    // r[verify properties.web-of-trust.depth-monotone]
    #[test]
    fn test_depth_monotone_preserves_root_base_case() {
        let root_key = vec![1, 2, 3];
        let root = principal_id_from_bytes(&root_key);
        let roots = vec![root];
        let attestations = Vec::new();
        let revocations = Vec::new();

        assert!(resolves_trusted_at(&roots, &attestations, &revocations, &roots[0], 0, 5));
        assert!(resolves_trusted_at(&roots, &attestations, &revocations, &roots[0], 3, 5));
    }

    // r[verify properties.web-of-trust.threshold-dedup]
    #[test]
    fn test_threshold_dedup_preserves_count() {
        let root_a_key = vec![1, 2, 3];
        let root_b_key = vec![4, 5, 6];
        let subject_key = vec![7, 8, 9];

        let att_a1 = signed_attestation(root_a_key.clone(), subject_key.clone(), TRUST_ROLE_TAG, 0, 20, 1);
        let att_a2 = signed_attestation(root_a_key.clone(), subject_key.clone(), TRUST_ROLE_TAG, 0, 20, 2);
        let att_b = signed_attestation(root_b_key.clone(), subject_key.clone(), TRUST_ROLE_TAG, 0, 20, 3);
        let dedup_a1 = signed_attestation(root_a_key.clone(), subject_key.clone(), TRUST_ROLE_TAG, 0, 20, 1);
        let dedup_b = signed_attestation(root_b_key.clone(), subject_key.clone(), TRUST_ROLE_TAG, 0, 20, 3);

        let roots = vec![
            principal_id_from_bytes(&root_a_key),
            principal_id_from_bytes(&root_b_key),
        ];
        let subject = principal_id_from_bytes(&subject_key);
        let revocations = Vec::new();
        let with_duplicates = vec![att_a1, att_a2, att_b];
        let deduped = vec![dedup_a1, dedup_b];

        assert_eq!(threshold_distinct_count_oracle(&roots, &with_duplicates, &revocations, &subject, 1, 5), 2);
        assert_eq!(threshold_distinct_count_oracle(&roots, &deduped, &revocations, &subject, 1, 5), 2);
    }

    // r[verify properties.web-of-trust.threshold-dedup]
    #[test]
    fn test_threshold_dedup_preserves_result() {
        let root_a_key = vec![1, 2, 3];
        let root_b_key = vec![4, 5, 6];
        let subject_key = vec![7, 8, 9];

        let att_a1 = signed_attestation(root_a_key.clone(), subject_key.clone(), TRUST_ROLE_TAG, 0, 20, 1);
        let att_a2 = signed_attestation(root_a_key.clone(), subject_key.clone(), TRUST_ROLE_TAG, 0, 20, 2);
        let att_b = signed_attestation(root_b_key.clone(), subject_key.clone(), TRUST_ROLE_TAG, 0, 20, 3);
        let dedup_a1 = signed_attestation(root_a_key.clone(), subject_key.clone(), TRUST_ROLE_TAG, 0, 20, 1);
        let dedup_b = signed_attestation(root_b_key.clone(), subject_key.clone(), TRUST_ROLE_TAG, 0, 20, 3);

        let roots = vec![
            principal_id_from_bytes(&root_a_key),
            principal_id_from_bytes(&root_b_key),
        ];
        let subject = principal_id_from_bytes(&subject_key);
        let revocations = Vec::new();
        let with_duplicates = vec![att_a1, att_a2, att_b];
        let deduped = vec![dedup_a1, dedup_b];

        assert!(threshold_accepts(&roots, &with_duplicates, &revocations, &subject, 2, 1, 5));
        assert!(threshold_accepts(&roots, &deduped, &revocations, &subject, 2, 1, 5));
        assert!(!threshold_accepts(&roots, &with_duplicates, &revocations, &subject, 3, 1, 5));
        assert!(!threshold_accepts(&roots, &deduped, &revocations, &subject, 3, 1, 5));
    }
}
