## Context

`onix-core` pins `RossComputerGuy/tenstorrent.nix` at `3c4dcbb9f8de30ae0d43177c8bc25f12170ddd94` and layers approximately two megabytes of reusable ttWKV7, RWKV harness, simulator, benchmark, owner-control, and retained-evidence sources around that input. The intended `OnixResearch/tenstorrent.nix` destination is empty. The source worktree also contains unrelated untracked lifecycle work that must not enter the destination.

## Decisions

### Decision: Port a reviewed current-state snapshot on top of the pinned upstream lineage

**Choice:** Create destination `main` from the exact pinned upstream commit, then add the reusable package state in bounded migration commits with source-revision provenance.

**Rationale:** Publishing only upstream is false completion because it omits Onix's work. Filtering all `onix-core` history risks importing host identities, operational runbooks, unrelated lifecycle artifacts, and cross-cutting commits whose package boundary is not self-contained. A snapshot preserves the upstream lineage, keeps the complete development history in `onix-core`, and produces a reviewable standalone tree.

### Decision: Separate reusable packages from fleet integration

**Choice:** Migrate `rwkv-lab`, `rwkv-layer-harness`, `ttwkv7`, the bounded/persistent ttWKV7 wrappers and evidence validators, `ttwkv7-owner-control`, `tt-vibethinker-bench`, and `ttsim`. Keep machines, inventory, secrets, service units, deployment scripts, and host-specific instantiation in `onix-core`.

**Rationale:** The migrated packages can be built and tested without an Onix host configuration. Fleet policy remains owned by the fleet repository and consumes parameterized package outputs.

### Decision: Make the dedicated flake the package authority before deleting source copies

**Choice:** Validate the destination through a local input override, push its validated commit to the empty remote, update the `onix-core` input with Nix, then remove duplicated sources and validate the consumer.

**Rationale:** This ordering prevents a broken or nonexistent remote revision from becoming the only package source and avoids manual `flake.lock` edits.

## Approach Registry

- **Publish upstream clone only**: falsified; destination would not contain Onix's package work.
- **Filter/cherry-pick full monorepo history**: rejected after boundary audit; cross-cutting commits include fleet and lifecycle data outside the reusable package contract.
- **Snapshot atop pinned upstream lineage**: selected; completion is observable through standalone outputs, checks, provenance, consumer evaluation, and remote `main` identity.

## Risks / Trade-offs

- Fine-grained Onix development commits remain discoverable in `onix-core` rather than the destination history; provenance records the source commit.
- Hardware execution is not part of migration validation. Device-free checks establish packaging, contracts, fixtures, and negative paths only.
- Host-specific Tenstorrent behavior remains in `onix-core`; migration does not claim the dedicated repository is a complete fleet configuration.
