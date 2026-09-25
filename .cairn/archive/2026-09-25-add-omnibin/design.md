# Design: Add omnibin to britton-desktop

## Context

omnibin offers three ways in: `omnibin-shell`, a NixOS module, and a container
image. The CLI package wraps the binary with a pinned index artifact
(`omnibin-x86_64-linux.db`, 261 MB, fetched as a fixed-output derivation).

The module binds the real store to `/run/omnibin/real-store` and mounts the
lazy store over `/nix/store` for the whole machine. That FUSE mount is `ro`.
Its filesystem answers `lookup`, `getattr`, `readlink`, `readdir`, `open`,
`read`, and `release`, and nothing that writes. `omnibin-shell` runs the same
daemon outside a user and mount namespace, and binds its mount over
`/nix/store` only inside that namespace.

`britton-desktop` runs generation 855, built from `42bd27d4` on
`add-omp-coding-agent-desktop-final`. The working branch is 18 commits ahead
of that lineage, and its uncommitted tree moves `nixpkgs` and about twenty
other inputs.

## Decisions

### 1. Use omnibin-shell, not the NixOS module

**Choice:** Install `omnibin` and `omnibin-shell` as system packages. Do not
import `inputs.omnibin.nixosModules.default` and do not define an `omnibin`
service.

**Rationale:** On a machine that builds and receives deployments, a read-only
FUSE mount over `/nix/store` means nix-daemon can no longer add paths. Every
process on the host would also depend on one FUSE daemon: if it died,
`/nix/store` would stop answering until something outside the store remounted
it. Upstream documents the module for disposable VMs and containers, and
`omnibin-shell` for machines that must keep working.

### 2. Scope through a reusable tag, assigned to one machine

**Choice:** Add `inventory/tags/omnibin.nix`, register `omnibin` in the tag
contract, and tag only `britton-desktop`.

**Rationale:** The index costs 261 MB of closure on every machine that
installs it. A tag makes membership explicit and lets another machine opt in
with one line in `machines.ncl`, without touching the `dev` tag's eight
machines.

### 3. Follow the repository nixpkgs

**Choice:** Set `inputs.nixpkgs.follows = "nixpkgs"` on the input.

**Rationale:** omnibin builds from source either way, since no substituter
carries it. Following avoids a second nixpkgs evaluation. The index is a
fixed-output artifact, so its store path does not depend on nixpkgs.

### 4. Deploy from the lineage the machine runs

**Choice:** Commit the change on the working branch. Carry the same
functional change onto a branch from `42bd27d4`, build that system, and compare
its closure with the running one before activation.

**Rationale:** Deploying the working tree would roll the desktop onto a new
nixpkgs and unrelated uncommitted work. Deploying the working branch would
ship 18 commits that have not been activated on this machine. The deployed
lineage keeps the activation limited to omnibin.

## Risks / Trade-offs

- The first use of any package is a download at store-path granularity, and
  `~/.cache/omnibin` grows without eviction. Operators clear it by hand.
- Inside `omnibin-shell` the user is mapped to root in a user namespace.
  Programs that branch on uid 0 may behave differently there.
- The index is pinned to the locked input revision. Newer data arrives through
  `nix flake update omnibin`.
- `omnibin-shell` needs unprivileged user namespaces and `/dev/fuse`. Both are
  available on `britton-desktop`: `user.max_user_namespaces` is non-zero and
  `/dev/fuse` is mode 0666.

## Non-Claims

This change does not provide the upstream whole-machine store, prove the
correctness of any fetched package, or bound the cache's disk use.
