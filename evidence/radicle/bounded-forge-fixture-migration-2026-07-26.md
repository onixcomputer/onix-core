# Bounded Exec controlled forge fixture migration — 2026-07-26

## Scope

The operator authorized the reviewed controlled two-record fixture instead of a source-host API export. The normalized batch retains explicit fixture actor, timestamp, issue, and pull-request attribution. Its patch range was rebound to existing Bounded Exec objects `29dac88ecded94457572db3fdfaaaab95fa91525..1baa4f552ae55923b025d99d08073286158836be` so the native built-in patch evaluator could verify the selected repository without inventing Git objects.

This is a controlled fixture migration, not evidence of GitHub export completeness.

## Preview and execution

Valence revision `e822bdf5395d6e1a77786c538ac0aaa13ef8c165` generated plan `3c18f68c5c6a1cd6307052d9e9b5a42c2c0ac1a2f8bd24018a0f43666a1380eb` under profile `1ca1407a5aa4e3fa0d503bcbb02cb8e45363cabddabee6e6cbeb1a3bdbe1d19d`. Native preview reported two executable records and changed no refs.

Execution used one ephemeral SSH agent containing only the existing Author key. It created:

- solved built-in issue `d9f9c0ad2da34c8cdd95ec0ad2f741de7361c76d`, ref OID `de02d0257d181fc61662fa8e028b2296c5b30f8f`;
- archived built-in patch `86c2607da3e4960e173f4de56f776a291574c5e1`, ref OID `97309eba9aed4ddb77934a4a49efd8c840e3be26`;
- Author `parent` signed refs `d13faa9620a139c0eedc15eb4565e35934858c1c`.

The patch preserves the imported `approved` review state only inside an attributed `revision.comment`; it creates no Radicle review or approval.

The first ordinary `rad issue show` and `rad patch show` probes correctly exposed a stale local SQLite COB cache. After the documented `rad issue cache` and `rad patch cache` refresh, ordinary Radicle CLI displayed the solved issue and archived patch with the expected labels, base/head range, and attribution. The native adapter had already reloaded and verified both built-in evaluators before reporting success.

## Bindings and idempotency

The offline migration binding verifies with no issue codes and receipt BLAKE3 `1c7a5e7feaf223a7b0dddd8e5e4d8bc50092ce0b977681633e65d2035406ecbf`.

A second batch supplied the exact existing mappings. Its plan selected `verify_existing` for both records. Native preview and execution reloaded the objects, changed zero refs, and produced a second offline-verifiable binding with receipt BLAKE3 `536c2f4af3f671669f3614e9481ba72a04339ab96ac0b3e9fec1a7038f5a24bf`.

## Convergence and canonical boundary

The Author namespace and `parent` signed refs converged on:

- the local Author repository;
- Aspen node `z6MkfpHAyrqSqhpiSGayy6AjB6L5UWkKLvsZvLh5hYD7XSu8`;
- desktop replica `z6MkkQCj5EczNiVzDzCkX9ewHNJ7NDEXSKbuRiS1x7o72yeG`;
- public read-only HTTPS.

Canonical `refs/heads/main` remained `1baa4f552ae55923b025d99d08073286158836be` before and after migration, replay, and convergence. No guard compare-and-swap was attempted. Aspen's Radicle node, HTTP service, CI node, and sync timer remained active. The archived historical patch did not create a new exact-patch CI job.

## Non-claims

This evidence does not establish source-host export completeness, actor authenticity, original source signatures or timestamps, issue/patch semantic equivalence, approval equivalence, CI correctness, merge eligibility, canonical admission, canonical mutation, release readiness, post-update durability, or whole-stack GitHub independence.
