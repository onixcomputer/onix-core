## Context

The live Nix config on `britton-desktop` listed duplicate `https://nix-community.cachix.org` entries and multiple substituters including `https://cache.nixos.org/`, a local `http://aspen1.local:5000`, and a project-specific cache. Remote builders are already configured in `/etc/nix/machines`. Cache routing should be explicit so workstation responsiveness improvements are not limited to local throttling.

## Goals / Non-Goals

**Goals:**
- Remove duplicate substituter entries.
- Make local-vs-public cache order a documented choice.
- Preserve trusted substituter policy.
- Provide a remote-only build probe for heavy jobs.

**Non-Goals:**
- Stand up a new binary cache.
- Change cache trust keys without a separate security review.
- Require remote builders for all local development.

## Decisions

### 1. Treat substituter order as policy

**Choice:** Define an ordered list for `britton-desktop` and verify the resolved config exactly.

**Rationale:** Duplicate or accidental ordering wastes lookups and makes cache behavior harder to reason about.

**Alternative:** Leave order implicit in merged modules. Rejected because the workstation has multiple project/local caches.

### 2. Keep remote-only builds as an operator workflow

**Choice:** Document and test `nix build --max-jobs 0 ...` for heavy jobs that should avoid local compilation.

**Rationale:** Local throttling preserves interactivity, but remote-only mode is the strongest protection for long non-interactive builds.

## Risks / Trade-offs

**Local cache latency or misses** → Place `aspen1.local` according to measured behavior and keep the order easy to change.

**Remote builder unavailable** → Remote-only probes should report builder reachability separately from local config validation.
