# Choregraph governed source deployment and probes

Observed: 2026-07-27

## Bound source

- RID: `rad:zL2ncTUeASVYwcoGkEXv9JKgGbAF`
- Candidate revision: `fc47c5f4ecbb7b4341af690fa42199f25d57f54c`
- Candidate branch: `candidate`
- Source archive BLAKE3: `dcb1faf95a7487145496ce986ae1639908600ace5bd77c4d96a37a530a7538a5`
- Source archive bytes: `1781760`
- Release bundle: `a2ac1336679542fa9573b356daddc18266fdda8147ddbe28f85aa37d135030d9`
- Candidate identity: `e4b5cd7bd77d78c20cf8b96cd0c038144028d2287000757c8ab68f5f5dfdff1a`
- License: `AGPL-3.0-or-later`

The operator explicitly authorized publication. Radicle identity revision `fce6d85cbe015b49ddab43db66884f550e66153e` has one delegate and threshold one.

The candidate branch update produced parent-feature signed refs `70148d3d6d0f5d5995fc7c4b78002189701748b5` without changing the selected source revision.

## Durable deployment

Onix Core revision `1a6446874d7bbe83f01bad13e9855f85423dd7e6` derives both public seed policies and HTTPS routes from one four-RID list.

Current systems:

- Aspen: `/nix/store/ia697wglrzfc40hx6qv1sz18sv2d4w4m-nixos-system-aspen1-26.11.20260629.7a1a647`
- Desktop: `/nix/store/2wdnwhb1pbg4pix0hyzmk0gbafcq4f3l-nixos-system-britton-desktop-26.11.20260629.7a1a647`

Both policy timers are active. The desktop reconciler reported five desired policies: four public sources and one separately managed private source.

## Replication

The following independent nodes report the publisher signed refs in sync:

- Aspen: `z6MkfpHAyrqSqhpiSGayy6AjB6L5UWkKLvsZvLh5hYD7XSu8`
- Desktop: `z6MkkQCj5EczNiVzDzCkX9ewHNJ7NDEXSKbuRiS1x7o72yeG`
- Paintedlife: `z6Mkkyj4NSrjzR7VEnzbG1Km9f66qTn3d7SApqEH9rXAVR7A`

Replication does not grant delegate, release, deployment, or source-selection authority.

Fresh isolated Radicle profiles cloned the exact candidate from Aspen alone and from the desktop alone. Both clients required parent-feature signed refs.

## HTTPS acquisition

A fresh clone from the following read-only adapter resolved the exact candidate revision:

`https://git.onix.computer/zL2ncTUeASVYwcoGkEXv9JKgGbAF.git`

`git fsck --full --strict` passed. A fresh archive matched the candidate BLAKE3 and byte count.

Negative HTTP probes returned `404` for the endpoint root, an unknown RID, receive-pack discovery, and receive-pack POST.

## Claim boundary

This evidence proves selected source identity, observed replication, durable host policy, and read-only acquisition. It does not prove Choregraph correctness, consumer correctness, indefinite availability, or release eligibility.
