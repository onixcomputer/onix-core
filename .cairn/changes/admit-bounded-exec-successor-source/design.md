# Design: Admit the Bounded Exec successor Radicle source

## Decisions

The owner approved on 2026-11-22: a per-RID 1-of-1 OnixOS bootstrap profile for the successor, retiring the canonical guard for it while its threshold is 1, agent-run `clan machines update` where root SSH needs no password, and the desktop replica repair with static peers as the durable fix.

## Enforcement

- `inventory/services/services.ncl` is the single source of the public set. `radicle-node/validate-settings.nix` and `radicle-seed-replica/validate-settings.nix` compare `seedRepositories` (and the primary's `httpsGitRepositories`) against `governedRepositories`, which gains `boundedExecSuccessorRepository` last, matching the catalog order.
- `radicle-seed-replica/schema.ncl` adds `staticPeers`. `validate-settings.nix` admits only `NID@address:8776` entries naming the Aspen1 seed or another reviewed replica (`reviewed-hosts.nix` gains `nodeId`), never the host itself, without duplicates. `radicle-node/mk-nixos-config.nix` lowers a non-empty list to `node.connect` and `node.peers.type = "static"`; an empty list leaves the node settings unchanged, so Aspen1 and Aspen3 node configs differ only in their repository sets.
- `radicle-ci-runner/default.nix` fetches the reviewed source from the successor adapter with the M″ NAR hash `sha256-IPhzd7+GXI2xpqcNWdWW61Lqr3j6tOQ6zpklS7Au2EE=`. Until Aspen1 serves the RID the fixed-output path is pre-seeded locally from the same commit; the hash binds it.
- `radicle-forge-guard/contracts.ncl` adds `retired_rids`; `profile.ncl` still exports `expected`, so `generated/profile.json` is byte-identical and the guard tool keeps refusing any RID but the pilot's.
- `_radicle-ci-runner-checks.nix` separates the historical pilot identities (ci-deployment-v1 receipt, onixpkgs runner `Cargo.lock`) from the deployed successor identities, and checks the vendored policy hash and RID, the guard profile RID and the retirement set. `_radicle-node-checks.nix` and `_radicle-seed-replica-checks.nix` gain the successor in their governed lists; the replica check adds missing-successor, unreviewed-peer and self-peer negatives and asserts the desktop static peers and Aspen3's dynamic set.

## Data boundary

OnixOS owns the governance profile and the CI policy bytes; onix-core vendors the policy JSON byte-for-byte and pins its BLAKE3. Nickel holds inventory and the guard record; Nix validators run at evaluation; the Rust runner validates its generated config.

## Verification strategy

- Focused: `checks.x86_64-linux.radicle-seed-replica`, the `radicle-node-*` and `radicle-ci-runner-policy` checks, and the source-admission checks.
- Broad: `nix flake check` and the `aspen1`, `britton-desktop` and `aspen3` toplevels.
- Deployment: compare each host's running system with the candidate; deploy only if the delta is limited to this admission. Then verify reconcile `added=1`, then `added=0, removed=0`; storage lists the RID; adapter `HEAD`/`main` = M″; CI units active.
- Evidence: `evidence/radicle/bounded-exec-successor-source-admission-v1.{ncl,json,blake3}` with a check, following `execution-graph-source-admission-v1`, naming the bootstrap profile; single-seed outage drills.
