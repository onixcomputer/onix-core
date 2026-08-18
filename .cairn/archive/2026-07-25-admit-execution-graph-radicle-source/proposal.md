# Admit execution-graph as a governed Radicle source

## Why

The production forge serves Bounded Exec and `artifact-auth`. Lattice cannot replace its vendored graph source until the exact `execution-graph` revision is available through the same bounded transports.

## Outcome

Add the reviewed public `execution-graph` RID to both selective seeds and the upload-pack-only HTTPS endpoint. Keep CI limited to Bounded Exec and keep repository governance separate from seed authority.

## Scope

- Bind RID `rad:z2oYsb9jGTyp68BKYhzpivY1eK58a` to reviewed commit `03736f1ec46c377ff86b451260ad68aa70ff3b0b`.
- Admit the source on Aspen and the desktop replica.
- Expose only exact Git upload-pack routes on `git.onix.computer`.
- Preserve the existing public sources and separately managed private source.
- Require positive and negative exact-set tests.

## Non-goals

This change does not grant seed, CI, delegate, release, canonical-reference, deployment, cache-write, or artifact authority. It does not accept consumer cutover or release readiness.
