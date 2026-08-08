# Reconciliation validation

Date: 2026-08-08

## Topology

```text
canonical first parent: bf7f37d34bb87b402bda275f09b36b097742805e
reviewed second parent: b8387cd7d59fa3b0d4ea67646352dd27c4f7d7ed
merge base: ecd2b31a6d9617fd70733fd276f96754be9ac4e5
canonical-only commits: 45
reviewed-branch-only commits: 3
```

The integration uses a normal merge. It does not rebase, squash, force-push, or replace either history.

## Policy result

The reconciled ordered public set is:

1. Bounded Exec
2. `artifact-auth`
3. `execution-graph`
4. Choregraph
5. `durable-file-publication`

Primary seed, public HTTPS, and managed replicas derive from this list. CI remains Bounded Exec-only.

## Passing checks

The following focused Nix command passed:

```text
nix build --accept-flake-config --no-pure-eval -L \
  .#checks.x86_64-linux.radicle-seed-replica \
  .#checks.x86_64-linux.radicle-choregraph-source-admission \
  .#checks.x86_64-linux.radicle-durable-file-publication-source-admission \
  .#checks.x86_64-linux.radicle-source-admission
```

The focused checks include positive exact-policy evaluation and negative missing, duplicate, unknown, malformed, private-exposure, governance, and non-claim cases.

Nickel formatting completed. This command exported the service inventory as JSON and the result contained both concurrent RIDs:

```text
nickel export --format json inventory/services/services.ncl
```

## Pre-existing package-identity blocker

`radicle-node-policy` failed before and after reconciliation with this exact diagnostic:

```text
radicle-httpd version changed without updating the reviewed package identity
```

The package currently reports version `0.27.0`. The checked reviewed identity remains `0.25.0`. This change does not accept a new package identity or hide this blocker.

## Non-claims

This evidence does not prove deployment, endpoint freshness, permanent availability, repository correctness, release readiness, retention, deletion, or new authority for any seeded repository.
