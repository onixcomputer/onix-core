# Admit Choregraph as a governed Radicle source

## Why

Execution-graph and Lattice cannot select Choregraph until its exact published revision is available through the governed Onix source transports.

The Choregraph producer published one reviewed AGPL source through Radicle. The current forge policy rejects its RID because the exact public set does not include it.

## Outcome

Add the reviewed Choregraph RID to both selective seeds and the upload-pack-only HTTPS endpoint. Keep CI limited to Bounded Exec and preserve every existing source and authority boundary.

## Scope

- Bind RID `rad:zL2ncTUeASVYwcoGkEXv9JKgGbAF` to revision `fc47c5f4ecbb7b4341af690fa42199f25d57f54c`.
- Bind source archive BLAKE3 `dcb1faf95a7487145496ce986ae1639908600ace5bd77c4d96a37a530a7538a5`.
- Admit the source on Aspen and the desktop replica.
- Expose only exact Git upload-pack routes on `git.onix.computer`.
- Preserve current public, private, CI, governance, and service authority.
- Require positive and negative exact-set tests.

## Non-goals

This change does not grant delegate, signing, release, CI, deployment, cache-write, or canonical-reference authority. It does not accept either consumer cutover.
