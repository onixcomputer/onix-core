# Admit durable-file-publication as a governed Radicle source

## Why

The durable one-file publication mechanism is complete and published only through Radicle. It is not yet in the production Onix source allowlist, so the managed Aspen1 seed, desktop replica, and read-only HTTPS endpoint do not durably serve its reviewed revision.

## Outcome

Admit RID `rad:z3tAR4For7qw8ZirkJzoDw1VNDDLM` at reviewed commit `951c27f59003cea9bfdb40ed4d89653d50fada1f`. Derive both seed policies and Aspen1 HTTPS routes from the same ordered public-source list. Keep CI limited to Bounded Exec and keep repository governance separate from seed authority.

## Scope

- Bind the RID, reviewed commit, source-archive BLAKE3, identity revision, delegate threshold, signed refs, and Cairn archive receipt.
- Add the source to Aspen1 and britton-desktop through the existing selective-seed modules.
- Expose only exact read-only Git upload-pack routes on `git.onix.computer`.
- Preserve existing public sources and the separately managed private source.
- Add positive and negative exact-set and evidence validation.
- Deploy and verify both managed nodes without runtime-only overrides.

## Non-goals

This change does not grant seed nodes repository delegate, signing, CI, release, deployment, canonical-reference, retention, recovery, garbage-collection, or deletion authority. It does not prove the library correct or accept a consumer cutover.
