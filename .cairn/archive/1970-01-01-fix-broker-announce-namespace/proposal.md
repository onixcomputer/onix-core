# Proposal: Fix broker announce namespace

## Why

The deployed `radicle-ci-broker` 0.31.0 passes an empty namespaces list to
`node.announce`, so the Radicle node always rejects the announcement with
`no refs were announced for rad:…`. Every job COB create/update logs a
spurious `JobFailure` and the broker's announce path can never work. The
upstream fix (present at the broker repository tip) passes the broker's own
node id as the announced namespace.

## What changes

- Override the machine's `services.radicle.ci.broker.package` with a
  one-line patch that announces the broker's own node namespace instead of
  an empty list.
- Assert the patch is present in the machine evaluation checks.
- Note the fix in the module README.

## Non-goals

- No change to CI semantics, the status-sync unit, reports, or admission.
- No claim that announce success proves remote CI correctness or release
  eligibility.
