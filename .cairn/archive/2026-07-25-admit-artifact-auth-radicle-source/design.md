# Design: second governed Radicle source admission

## Policy model

One typed ordered list is the source of truth for production public repositories. For this change it contains exactly the existing Bounded Exec RID and the accepted artifact-auth RID. Primary seed admission, pinned repositories, HTTPS routes, and desktop replica admission derive from that same list. CI retains its separate single-RID policy and must not inherit the expanded source list.

## Pure validation

Deterministic validation requires canonical public RID syntax, uniqueness, exact membership, HTTPS/pinned subsets, unchanged signed-reference feature level, and exact separation between production source admission and CI admission. Positive fixtures cover two repositories. Negative fixtures cover missing legacy RID, missing new RID, unknown third RID, duplicates, malformed IDs, HTTPS mismatch, replica mismatch, and accidental CI widening.

## Deployment shell

Onix-owned NixOS modules reconcile policy databases and service configuration. Operators import already-signed repository storage, deploy Aspen and desktop independently, and probe each endpoint. These effects do not grant repository signing or canonical-ref authority.

## Failure and rollback

A failed deployment leaves the existing Bounded Exec route intact. Removing artifact-auth is an explicit configuration rollback after consumer rollback; automatic fallback is forbidden. Policy reconciliation must never delete unrelated historical storage, but unadmitted repositories remain blocked from seeding and HTTPS.

## Evidence

A typed Nickel/JSON receipt with BLAKE3 sidecar binds both RIDs, reviewed commits, seed identities, fingerprints, policy sets, HTTP routes, CI single-RID invariance, live probes, negative observations, and non-claims.
