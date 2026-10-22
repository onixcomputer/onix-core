//! Verified snapshot integrity with an exact u128 pair commitment.
//!
//! Models the integrity check for Raft snapshots: data and metadata are
//! hashed independently, then combined into a single u128 commitment that
//! commits to both components exactly (data_hash in the low 64 bits,
//! meta_hash in the high 64 bits).
//!
//! The combination is a pure, allocation-free scalar u128 pairing:
//! `combine_hashes(a, b) = (a as u128) | ((b as u128) << 64)`. Because the
//! two u64 inputs occupy disjoint bit ranges, this mapping is exactly
//! injective over the full u64 x u64 domain — no collision-resistance
//! axiom, no trusted bridge, and no permanent axiom are needed.
//!
//! Verification recomputes the combined commitment and compares. An
//! optional chain hash check ties the snapshot to a position in the log's
//! hash chain.
//!
//! This is consistency binding of already supplied u64 hashes, NOT a
//! cryptographic hash/MAC/authentication of arbitrary payload bytes.
//! Changing fields AND recomputing the commitment can produce a different
//! valid record.
//!
//! Proves: compute→verify round-trip, tamper detection on data and
//! metadata independently, chain hash mismatch detection, and the
//! combined hash commits to both components.

use vstd::prelude::*;

verus! {

/// Snapshot integrity record.
pub struct SnapshotIntegrity {
    /// Hash of the snapshot data.
    pub data_hash: u64,
    /// Hash of the snapshot metadata.
    pub meta_hash: u64,
    /// Combined hash of `data_hash` and `meta_hash` (u128 pair commitment).
    pub combined_hash: u128,
    /// Chain hash at the snapshot's log position.
    pub chain_hash_at_snapshot: u64,
}

// --- Hash function (exact u128 pair commitment) ---

/// Spec: combine two u64 values into an exact u128 pair commitment.
///
/// data_hash (a) occupies the low 64 bits; meta_hash (b) occupies the
/// high 64 bits. Allocation-free and exactly injective over full u64 x
/// u64 inputs, matching independent LE64(a)||LE64(b) orientation.
pub open spec fn combine_hashes_spec(a: u64, b: u64) -> u128 {
    (a as u128) | ((b as u128) << 64)
}

/// Exec wrapper for the pair commitment (allocation-free scalar op).
pub fn combine_hashes(a: u64, b: u64) -> (result: u128)
    ensures result == combine_hashes_spec(a, b)
{
    (a as u128) | ((b as u128) << 64)
}

/// Proof: the pair commitment is exactly injective — equal commitments
/// imply equal inputs, over the full u64 x u64 domain.
pub proof fn combine_hashes_injective(
    a1: u64, b1: u64,
    a2: u64, b2: u64,
)
    requires combine_hashes_spec(a1, b1) == combine_hashes_spec(a2, b2)
    ensures a1 == a2 && b1 == b2
{
    // Contrapositive of injectivity, in the style of the u32/u64 handle
    // packing proofs: unequal inputs give unequal commitments.
    if a1 != a2 {
        // Low 64 bits carry `a`; different `a` → different low 64 bits.
        assert(
            (((a1 as u128) | ((b1 as u128) << 64u128)) & 0xFFFF_FFFF_FFFF_FFFFu128)
                != (((a2 as u128) | ((b2 as u128) << 64u128)) & 0xFFFF_FFFF_FFFF_FFFFu128)
        ) by(bit_vector);
        // But the commitments are equal, so their low 64 bits are equal,
        // which forces a1 == a2.
        assert(a1 == a2);
    } else {
        // a1 == a2. If b1 != b2, the high 64 bits differ.
        if b1 != b2 {
            assert(
                ((((a1 as u128) | ((b1 as u128) << 64u128)) >> 64u128) & 0xFFFF_FFFF_FFFF_FFFFu128)
                    != ((((a2 as u128) | ((b2 as u128) << 64u128)) >> 64u128) & 0xFFFF_FFFF_FFFF_FFFFu128)
            ) by(bit_vector);
            // Equal commitments → equal high 64 bits → b1 == b2, contradiction.
            assert(b1 == b2);
        }
    }
}

/// Proof: the pair commitment is deterministic for equal inputs.
pub proof fn combine_hashes_deterministic(
    a1: u64, b1: u64,
    a2: u64, b2: u64,
)
    requires a1 == a2, b1 == b2
    ensures combine_hashes_spec(a1, b1) == combine_hashes_spec(a2, b2)
{
}

// --- compute_integrity ---

/// Spec: compute the snapshot integrity record.
pub open spec fn compute_integrity_spec(
    data_hash: u64,
    meta_hash: u64,
    chain_hash_at_snapshot: u64,
) -> SnapshotIntegrity {
    SnapshotIntegrity {
        data_hash,
        meta_hash,
        combined_hash: combine_hashes_spec(data_hash, meta_hash),
        chain_hash_at_snapshot,
    }
}

/// Compute a snapshot integrity record.
pub fn compute_integrity(
    data_hash: u64,
    meta_hash: u64,
    chain_hash_at_snapshot: u64,
) -> (result: SnapshotIntegrity)
    ensures
        result.data_hash == compute_integrity_spec(data_hash, meta_hash, chain_hash_at_snapshot).data_hash,
        result.meta_hash == compute_integrity_spec(data_hash, meta_hash, chain_hash_at_snapshot).meta_hash,
        result.combined_hash == compute_integrity_spec(data_hash, meta_hash, chain_hash_at_snapshot).combined_hash,
        result.chain_hash_at_snapshot == compute_integrity_spec(data_hash, meta_hash, chain_hash_at_snapshot).chain_hash_at_snapshot,
{
    SnapshotIntegrity {
        data_hash,
        meta_hash,
        combined_hash: combine_hashes(data_hash, meta_hash),
        chain_hash_at_snapshot,
    }
}

// --- verify_integrity ---

/// Spec: verify snapshot integrity by recomputing the combined commitment.
pub open spec fn verify_integrity_spec(integrity: SnapshotIntegrity) -> bool {
    combine_hashes_spec(integrity.data_hash, integrity.meta_hash) == integrity.combined_hash
}

/// Verify a snapshot integrity record.
pub fn verify_integrity(integrity: &SnapshotIntegrity) -> (result: bool)
    ensures result == verify_integrity_spec(*integrity)
{
    combine_hashes(integrity.data_hash, integrity.meta_hash) == integrity.combined_hash
}

// --- verify_with_chain_hash ---

/// Spec: verify integrity AND check the chain hash matches.
pub open spec fn verify_with_chain_hash_spec(
    integrity: SnapshotIntegrity,
    expected_chain_hash: u64,
) -> bool {
    verify_integrity_spec(integrity)
        && integrity.chain_hash_at_snapshot == expected_chain_hash
}

/// Verify integrity with chain hash check.
pub fn verify_with_chain_hash(
    integrity: &SnapshotIntegrity,
    expected_chain_hash: u64,
) -> (result: bool)
    ensures result == verify_with_chain_hash_spec(*integrity, expected_chain_hash)
{
    verify_integrity(integrity) && integrity.chain_hash_at_snapshot == expected_chain_hash
}

// --- Safety proofs ---

/// Compute then verify always succeeds.
proof fn round_trip(data_hash: u64, meta_hash: u64, chain_hash: u64)
    ensures verify_integrity_spec(compute_integrity_spec(data_hash, meta_hash, chain_hash))
{
    combine_hashes_deterministic(data_hash, meta_hash, data_hash, meta_hash);
}

/// Changing data_hash breaks verification (exact pair binding).
proof fn data_tamper_detected(
    data_hash: u64,
    meta_hash: u64,
    chain_hash: u64,
    tampered_data_hash: u64,
)
    requires tampered_data_hash != data_hash
    ensures
        !verify_integrity_spec(SnapshotIntegrity {
            data_hash: tampered_data_hash,
            meta_hash,
            combined_hash: compute_integrity_spec(data_hash, meta_hash, chain_hash).combined_hash,
            chain_hash_at_snapshot: chain_hash,
        })
{
    let original_combined = combine_hashes_spec(data_hash, meta_hash);
    let recomputed = combine_hashes_spec(tampered_data_hash, meta_hash);
    // The commitment is exactly injective in its first component, so a
    // different data_hash cannot reproduce the same commitment.
    combine_hashes_injective(tampered_data_hash, meta_hash, data_hash, meta_hash);
}

/// Changing meta_hash breaks verification (exact pair binding).
proof fn meta_tamper_detected(
    data_hash: u64,
    meta_hash: u64,
    chain_hash: u64,
    tampered_meta_hash: u64,
)
    requires tampered_meta_hash != meta_hash
    ensures
        !verify_integrity_spec(SnapshotIntegrity {
            data_hash,
            meta_hash: tampered_meta_hash,
            combined_hash: compute_integrity_spec(data_hash, meta_hash, chain_hash).combined_hash,
            chain_hash_at_snapshot: chain_hash,
        })
{
    let original_combined = combine_hashes_spec(data_hash, meta_hash);
    let recomputed = combine_hashes_spec(data_hash, tampered_meta_hash);
    // The commitment is exactly injective in its second component, so a
    // different meta_hash cannot reproduce the same commitment.
    combine_hashes_injective(data_hash, tampered_meta_hash, data_hash, meta_hash);
}

/// Wrong chain hash is detected even when integrity passes.
proof fn chain_hash_mismatch_detected(
    data_hash: u64,
    meta_hash: u64,
    chain_hash: u64,
    wrong_chain_hash: u64,
)
    requires wrong_chain_hash != chain_hash
    ensures
        !verify_with_chain_hash_spec(
            compute_integrity_spec(data_hash, meta_hash, chain_hash),
            wrong_chain_hash,
        )
{}

/// Changing either component changes the combined hash (exact pair binding).
proof fn combined_commits_to_both(
    d1: u64, m1: u64,
    d2: u64, m2: u64,
)
    requires d1 != d2 || m1 != m2
    ensures combine_hashes_spec(d1, m1) != combine_hashes_spec(d2, m2)
{
    if combine_hashes_spec(d1, m1) == combine_hashes_spec(d2, m2) {
        combine_hashes_injective(d1, m1, d2, m2);
    }
}

// --- Additional proofs ---

/// Round-trip with chain hash also works.
proof fn round_trip_with_chain(data_hash: u64, meta_hash: u64, chain_hash: u64)
    ensures
        verify_with_chain_hash_spec(
            compute_integrity_spec(data_hash, meta_hash, chain_hash),
            chain_hash,
        )
{
    combine_hashes_deterministic(data_hash, meta_hash, data_hash, meta_hash);
}

/// Verification is deterministic: same integrity → same result.
proof fn verify_deterministic(i1: SnapshotIntegrity, i2: SnapshotIntegrity)
    requires
        i1.data_hash == i2.data_hash,
        i1.meta_hash == i2.meta_hash,
        i1.combined_hash == i2.combined_hash,
    ensures verify_integrity_spec(i1) == verify_integrity_spec(i2)
{
    combine_hashes_deterministic(i1.data_hash, i1.meta_hash, i2.data_hash, i2.meta_hash);
}

} // verus!

#[cfg(test)]
mod tests {
    use proptest::prelude::*;

    use super::*;

    // r[verify snapshot-integrity.round-trip]
    // r[verify snapshot-integrity.verify-with-chain-hash]
    #[test]
    fn test_round_trip() {
        let integrity = compute_integrity(42, 99, 7);
        assert!(verify_integrity(&integrity));
        assert!(verify_with_chain_hash(&integrity, 7));
    }

    // r[verify snapshot-integrity.data-tamper-detected]
    #[test]
    fn test_data_tamper() {
        let integrity = compute_integrity(42, 99, 7);
        let tampered = SnapshotIntegrity {
            data_hash: 43,
            ..integrity
        };
        // Exact pair binding: a different data_hash cannot verify against
        // the original commitment.
        assert!(!verify_integrity(&tampered));
    }

    // r[verify snapshot-integrity.chain-hash-mismatch-detected]
    #[test]
    fn test_chain_hash_mismatch() {
        let integrity = compute_integrity(42, 99, 7);
        assert!(!verify_with_chain_hash(&integrity, 8));
    }

    // r[verify snapshot-integrity.compute]
    #[test]
    fn test_fields_stored_correctly() {
        let integrity = compute_integrity(10, 20, 30);
        assert_eq!(integrity.data_hash, 10);
        assert_eq!(integrity.meta_hash, 20);
        assert_eq!(integrity.chain_hash_at_snapshot, 30);
    }

    proptest! {
        // r[verify snapshot-integrity.round-trip]
        #[test]
        fn prop_round_trip(data_hash: u64, meta_hash: u64, chain_hash: u64) {
            let integrity = compute_integrity(data_hash, meta_hash, chain_hash);
            prop_assert!(verify_integrity(&integrity));
        }

        // r[verify snapshot-integrity.round-trip]
        #[test]
        fn prop_round_trip_with_chain(data_hash: u64, meta_hash: u64, chain_hash: u64) {
            let integrity = compute_integrity(data_hash, meta_hash, chain_hash);
            prop_assert!(verify_with_chain_hash(&integrity, chain_hash));
        }

        // r[verify snapshot-integrity.chain-hash-mismatch-detected]
        #[test]
        fn prop_chain_mismatch_detected(
            data_hash: u64,
            meta_hash: u64,
            chain_hash: u64,
            wrong in any::<u64>().prop_filter("different", |_w| true),
        ) {
            let integrity = compute_integrity(data_hash, meta_hash, chain_hash);
            if wrong != chain_hash {
                prop_assert!(!verify_with_chain_hash(&integrity, wrong));
            }
        }

        // r[verify snapshot-integrity.verify]
        #[test]
        fn prop_verify_deterministic(data_hash: u64, meta_hash: u64, chain_hash: u64) {
            let i1 = compute_integrity(data_hash, meta_hash, chain_hash);
            let i2 = compute_integrity(data_hash, meta_hash, chain_hash);
            prop_assert_eq!(verify_integrity(&i1), verify_integrity(&i2));
        }

        // r[verify snapshot-integrity.combined-commits-to-both]
        #[test]
        fn prop_combined_hash_changes(
            d1: u64, m1: u64,
            d2: u64, m2: u64,
        ) {
            if d1 != d2 || m1 != m2 {
                let c1 = compute_integrity(d1, m1, 0);
                let c2 = compute_integrity(d2, m2, 0);
                // Exact pair binding: different (data, meta) pairs always
                // produce different commitments.
                prop_assert_ne!(c1.combined_hash, c2.combined_hash);
            }
        }

        // r[verify snapshot-integrity.data-tamper-detected]
        #[test]
        fn prop_data_tamper_rejected(data_hash: u64, meta_hash: u64, chain_hash: u64) {
            let integrity = compute_integrity(data_hash, meta_hash, chain_hash);
            let tampered = SnapshotIntegrity {
                data_hash: data_hash.wrapping_add(1),
                ..integrity
            };
            prop_assert!(!verify_integrity(&tampered));
        }

        // r[verify snapshot-integrity.meta-tamper-detected]
        #[test]
        fn prop_meta_tamper_rejected(data_hash: u64, meta_hash: u64, chain_hash: u64) {
            let integrity = compute_integrity(data_hash, meta_hash, chain_hash);
            let tampered = SnapshotIntegrity {
                meta_hash: meta_hash.wrapping_add(1),
                ..integrity
            };
            prop_assert!(!verify_integrity(&tampered));
        }
    }
}
