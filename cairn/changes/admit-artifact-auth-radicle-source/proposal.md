# Admit artifact-auth as the second governed Radicle source

## Why

The production seed and desktop replica currently admit exactly the Bounded Exec pilot RID. Publishing artifact-auth for Valence requires a second explicit public RID without weakening selective seeding, HTTPS routing, CI isolation, or repository authority boundaries.

## Outcome

Evolve the production policy from exactly one pilot RID to exactly two governed public source RIDs. Reconcile both seeds, expose both upload-pack-only HTTPS routes on Aspen, retain the credentialless CI runner exclusively on Bounded Exec, and emit typed admission/deployment evidence.

## Scope

- Add the accepted artifact-auth RID to primary seed, pinned repository, HTTPS, and desktop replica allowlists.
- Keep undeclared RIDs blocked and duplicate/malformed entries rejected.
- Preserve existing seed identities, fingerprints, state roots, network bounds, backups, monitoring, and authority denials.
- Verify both reviewed objects independently from Aspen, desktop, and public HTTPS.

## Non-goals

This change does not admit private repositories, make the desktop public, expand CI to artifact-auth, grant seeds canonical-ref or delegate authority, add automatic HTTPS failover, or claim source correctness or release readiness.
