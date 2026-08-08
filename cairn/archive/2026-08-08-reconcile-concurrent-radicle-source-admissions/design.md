# Design

## Context

Current Onix Core `origin/main` and `origin/pi/admit-durable-file-publication` diverged after commit `ecd2b31a6d9617fd70733fd276f96754be9ac4e5`. The current line admits Choregraph. The reviewed branch admits `durable-file-publication` through commit `b8387cd7d59fa3b0d4ea67646352dd27c4f7d7ed`.

## Decisions

### Preserve both histories

Use current `origin/main` as the first merge parent and the reviewed durable-publication tip as the second parent. Do not force-push, rebase, squash, or replace either accepted history.

### Form one exact ordered union

The production public-source order is Bounded Exec, `artifact-auth`, `execution-graph`, Choregraph, then `durable-file-publication`. Primary seed, HTTPS, and every managed replica derive from this same list. CI remains Bounded Exec-only.

### Preserve both evidence packages

Keep the existing Choregraph checks and add the reviewed durable-publication checks. Historical receipts remain immutable. Current configuration checks prove that both RIDs occur in the lowered policy.

### Test omission and widening

Positive checks require the exact five-source list. Negative checks reject each missing concurrent admission, unknown additions, duplicates, malformed RIDs, private exposure, and CI widening.

## Failure handling

A conflict resolution that drops either RID, changes ordering, weakens a negative check, mutates historical evidence, or rewrites history must fail review.
