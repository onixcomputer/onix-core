# Admit the Bounded Exec successor Radicle source

## Why

Bounded Exec moved its stdin-race fix to a successor Radicle identity, `rad:zG25DRmacxYQcXzZmLKj8tmgYbEG`, so Lattice can adopt it. The adapter URL `https://git.onix.computer/zG25DRmacxYQcXzZmLKj8tmgYbEG.git` returns 404 until Onix seeds and serves the RID. The pilot identity `rad:z2CpqLFpdP36fZXYUK5ZNWxMibpCo` is frozen at canonical `10e2ac4` and must stay served read-only for consumers pinned to `29dac88e`.

## Outcome

Append the successor to the public source catalog after canonical Artifact, keeping every existing public entry, the four private sources and their order. Move the Aspen1 CI runner from the frozen pilot to the successor at reviewed commit `9e64b2f429c8f9035a06fe60ace3adbf331c5598` under the vendored OnixOS CI policy v2, and record the canonical-guard retirement for the successor. Give the `britton-desktop` replica a static peer set (Aspen1, Aspen3) to stop its unbounded dial loop.

## Scope

- `inventory/services/services.ncl`: `bounded_exec_rid`, the eight-entry `radicle_source_rids`, CI RID, reviewed commit, policy BLAKE3, delegate (`brittonr` only), the M″ `Cargo.toml`/`Cargo.lock`/`flake.nix` BLAKE3s, and the desktop replica `staticPeers`.
- `modules/radicle-node` and `modules/radicle-seed-replica`: the governed public set gains the successor last; the replica gains a typed, reviewed `staticPeers` setting lowered to Radicle `node.connect` plus `node.peers.type = "static"`.
- `modules/radicle-ci-runner`: the successor adapter URL and M″ NAR hash; `ci-policy-v1.json` becomes a byte copy of OnixOS `fixtures/radicle/ci-policy-v2.json` (BLAKE3 `ab4e2ae72b22c4c2704aca88852e4e5f036c2ca7501d257d11bec8827af2ebb3`).
- `modules/radicle-forge-guard/contracts.ncl`: `retired_rids` records the successor with the OnixOS profile name, policy BLAKE3, reason and reinstatement condition. The generated profile is unchanged and stays bound to the pilot RID.
- Focused checks, validation fixtures and operator docs.
- Deployment of Aspen1, Aspen3 and `britton-desktop` under the deploy safety rule, followed by the source-admission receipt, probes and single-seed outage drills.

## Non-goals

- No governance change to the successor identity: it keeps one delegate at threshold 1 under the OnixOS `bounded-exec-successor-single-delegate-bootstrap` profile, pending a three-delegate identity.
- No retargeting of the canonical guard; no change to historical receipts.
- No change to the `bounded-exec*` flake inputs, `modules/kiln-aspen-radicle-ci`, or `inventory/home-profiles/brittonr/dev/tools.nix`, which stay on the pilot revision.
- No consumer cutover, release-readiness or CI-correctness claim.

## Compatibility boundaries

The pilot RID stays seeded and served. Aspen1 and Aspen3 node settings change only in their policy and HTTPS route sets; only the desktop replica switches to static peers.

## Verification expectations

`radicle-node-*`, `radicle-seed-replica`, `radicle-ci-runner-policy` and the source-admission checks, `nix flake check`, and the `aspen1`, `britton-desktop` and `aspen3` toplevels before deployment; reconciler counts, storage listings, adapter `HEAD`/`main` = M″, CI unit state, probes and outage drills after it.

## Affected domains

- `radicle-source-admission`: the public source set.
- `radicle-replica`: static peers for the desktop replica.
- `radicle-ci`: the admitted CI RID and guard retirement.
