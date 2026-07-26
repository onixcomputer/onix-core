# Design: Controlled built-in COB migration evidence

## Success contract

The change is complete when the reviewed two-record batch deterministically plans one solved built-in issue and one archived built-in patch, native execution under the exact Author signer reloads both evaluators, Valence issues an offline-verifiable binding, ordinary Radicle tooling displays both objects after cache refresh, exact-mapping replay changes zero refs, Aspen/desktop/HTTPS expose the Author refs and `parent` sigrefs, and canonical `main` remains byte-for-byte unchanged.

False completion includes substituting a custom COB, claiming source-host completeness, treating imported `approved` text as a Radicle review, accepting only a receipt without native objects, omitting replay, publishing a non-`parent` signed ref, changing canonical `main`, widening CI, or claiming release readiness.

## Portfolio search

- **Source-host export:** Rejected for this operation after the operator explicitly scoped it out; the receipt says controlled fixture and makes no completeness claim.
- **Custom import object:** Rejected because ordinary Radicle issue/patch tooling would not evaluate it.
- **Built-in native import plus independent binding:** Accepted because it confines effects to one selected repository, one existing Author key, built-in issue/patch refs, and signed refs while Valence separately binds observations under its sorted canonical JSON backend.
- **Receipt-only recording:** Rejected because it would not prove live evaluator or convergence observations.

## Execution boundary

`valence-radicle` at revision `e822bdf5395d6e1a77786c538ac0aaa13ef8c165` validates and hashes the normalized input. The process-isolated native binary revalidates the plan and signs through an ephemeral SSH agent containing only the existing Author key. The patch uses existing Git objects `29dac88ecded94457572db3fdfaaaab95fa91525..1baa4f552ae55923b025d99d08073286158836be`; it is archived historical metadata, not a merge proposal.

The initial ordinary CLI read exposed a stale local COB cache. The documented cache refresh changed only SQLite cache state; subsequent ordinary CLI output agreed with the native evaluator and binding.

## Convergence and authority

Only the Author issue ref, patch ref, and `parent` signed refs are new. Direct one-seed synchronization carries them to Aspen and the desktop replica. Public HTTPS is read-only evidence. Canonical `refs/heads/main` is measured before and after every mutation/replay path. No guard execution, delegate review, canonical compare-and-swap, deployment, or CI-scope change occurs.
