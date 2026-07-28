# Design: Choregraph Radicle source admission

## Success contract

Completion requires exact source identity, one derived four-source public policy, both durable seed policies, the read-only HTTPS route, deterministic negative tests, and fresh acquisition evidence.

A local seed, temporary policy, sibling path, GitHub source, floating revision, or unverified HTTPS route is false completion.

## Policy model

One ordered public-source list contains Bounded Exec, `artifact-auth`, `execution-graph`, and Choregraph. Primary seeding, HTTPS routes, and replica seeding derive from that list. Bounded Exec keeps its separate CI policy.

The deployed hosts also carry one separately managed private RID. Public-source admission preserves that policy without exposing private source content.

## Validation

Pure validators require exact ordered membership, canonical RID syntax, unique entries, the `parent` signed-reference feature, and unchanged host identities.

Negative checks cover missing sources, unknown additions, duplicates, malformed RIDs, HTTPS mismatch, replica mismatch, CI widening, and private-source exposure.

## Deployment

Onix Core owns the durable Nix settings. Deployment must update Aspen and the desktop replica through their normal NixOS configurations.

The policy reconciler fetches signed public storage. Nginx exposes only exact info-refs and upload-pack routes. Neither path receives repository signing authority.

## Failure and rollback

If replication or HTTPS verification fails, restore the prior Onix Core revision through VCS and redeploy both hosts. Do not delete repository storage.

Consumer rollback remains separate. No runtime fallback or alternate source is allowed.

## Evidence

Evidence binds the RID, revision, archive BLAKE3, release bundle, seed identities, durable policy, HTTPS route, negative probes, producer authority, and non-claims.
