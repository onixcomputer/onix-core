# Reconcile concurrent Radicle source admissions

## Why

Onix Core accepted Choregraph and `durable-file-publication` on branches that diverged from the same older source-policy line. Canonical `main` contains Choregraph. The reviewed durable-publication branch remains separate. Replacing either source would discard accepted policy and evidence.

## What Changes

- Merge the reviewed durable-publication admission history into current canonical history without rewriting either line.
- Preserve Choregraph and add `durable-file-publication` to one ordered five-source public policy.
- Keep CI on its separate Bounded Exec-only policy.
- Run focused positive and negative checks for primary seed, managed replicas, HTTPS, source evidence, and both admission packages.
- Record the exact merge parents and canonical result.

## Impact

This change reconciles concurrent source admissions. It does not grant delegate, signing, CI, release, deployment, retention, deletion, or canonical-reference authority to a seeded repository.
