## Why

The public Radicle source pilot proves selective native and HTTPS source serving, but it leaves private repository confidentiality and authorized acquisition untested. Broader fleet migration must not infer private behavior from public admission.

## What Changes

- Publish a non-secret repository with Radicle private visibility and an exact privacy set containing the two reviewed seed identities and one isolated authorized client.
- Separate exact public and private native seeding sets in both seed modules while keeping HTTPS and CI limited to their existing public scopes.
- Prove exact-object acquisition from each seed, denied-client inventory non-disclosure and clone rejection, HTTPS default denial, encrypted backup inclusion, and clean-root recovery.
- Add typed, BLAKE3-bound evidence and operator documentation with explicit non-claims.

## Success Criteria

- Both seed policy reconcilers report the exact two public RIDs plus one private pilot RID.
- Fresh authorized clients independently reproduce commit `ff4ff027817465b1bb04251a8a98db42cc610b0c` and source BLAKE3 `514904bdcf5f23b0813c567efbc8b6732248de94482037a58011bfff3fc26853` from each seed.
- Fresh unauthorized clients do not observe the private RID in seed inventory and cannot acquire it.
- Public HTTPS returns `404` for private upload-pack and receive-pack while existing public upload-pack remains healthy.
- Encrypted backup and clean-root recovery include the private object without exposing plaintext outside the bounded restore root.
- Positive and negative module/evidence checks, focused host builds, Cairn gates, and repository validation pass before archival.

## Non-Goals

- Storing production secrets or migrating an existing private production repository.
- Claiming global metadata secrecy, anonymity, traffic-analysis resistance, secure deletion, or confidentiality against authorized peers.
- Widening Radicle CI, HTTPS Git, delegate, deployment, signing, cache, artifact, or backup authority.
- Claiming source correctness, multi-delegate private governance, release readiness, or whole-fleet migration readiness.

## Impact

- **Native seed policy**: one exact private RID is admitted separately on Aspen and the desktop replica.
- **Public exposure**: unchanged at exactly the two accepted public RIDs.
- **CI**: unchanged at Bounded Exec only.
- **Evidence**: adds a private-pilot receipt and bounded live probe record.
