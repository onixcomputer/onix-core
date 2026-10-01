## Why

nixpkgs commit `c082683d1cfe` ("radicle-node: mark insecure", 2026-09-24) follows Radicle's [2026-09-23 disclosure](https://radicle.dev/2026/09/23/disclosure-of-vulnerability-in-network-protocol): every Radicle release sends node traffic in cleartext, and a peer can claim another node's ID. After the lock moved nixpkgs to `b6c8664d` (2026-09-29), evaluation of every Radicle host stops with `Refusing to evaluate package 'radicle-node-1.10.3' … because it is marked as insecure`. `clan machines update aspen3` therefore fails in its build step, and aspen1 and britton-desktop fail the same way.

The operator accepted the risk on 2026-09-30. The fleet keeps running Radicle 1.10.3 and keeps seeding its private repositories until Radicle ships the fixed major release.

## What Changes

- The flake builds `radicle-node` from a nixpkgs instance that permits exactly `radicle-node-1.10.3`. Machines already receive that package through the `shared-nix.nix` overlay.
- `radicle-httpd` and every other package keep nixpkgs' insecure-package refusal.

## Impact

- **Files**: `flake-outputs/tools.nix`, `AGENTS.md`.
- **Risk**: private repositories keep syncing over a transport that does not encrypt or authenticate peers. The node listeners are limited to `tailscale0`, which narrows who can connect but does not stop a peer that claims an allow-listed node ID.
- **Non-goals**: no change to seeding policy, listeners, the private repository set, or the nixpkgs pin.
- **Testing**: evaluate the aspen1, britton-desktop and aspen3 toplevels; confirm a different radicle-node version still fails evaluation; build the exempted package.

## Affected Specs

- `radicle-node-hosting`: package admission under nixpkgs' insecure marking.
