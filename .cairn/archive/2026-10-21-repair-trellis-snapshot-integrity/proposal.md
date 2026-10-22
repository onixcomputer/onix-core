# Repair Trellis snapshot-integrity commitment

## Why

The previous real Nemotron campaign and independent runtime consumer found that changing metadata from zero to `1 << 63` leaves the actual `u64` dual hash unchanged. Both integrity entry points accept the changed record. Verus passes because a trusted bridge and an impossible globally injective `u64 × u64 → u64` axiom hide the mismatch.

## Outcome

Run a bounded actual Nemotron repair against an isolated current Trellis snapshot. Replace the lossy combiner with an exact two-word commitment, prove the executable bridge and injectivity without new assumptions, migrate active callers and honest trust inventories, and retain independent runtime/proof acceptance evidence.

## Scope

Trellis snapshot-integrity implementation, direct consumer proofs/tests, live requirements and trust accounting. This campaign may change the impossible narrow output contract to an exact 128-bit commitment; it may not weaken field-binding postconditions, add trust escapes, or claim cryptographic authentication. Use the existing pinned Spark launcher and production Verus. Preserve unrelated current user changes.

## Operational boundary

Temporarily stop the existing three-rank DeepSeek deployment, run one loopback-only pinned Nemotron replica through an authenticated workstation tunnel, then restore the original containers and prove real DeepSeek inference. No training, new model service, or permanent Spark configuration change.
