# Radicle CI canonical guard validation — 2026-07-26

## Scope and side effects

Validation used only temporary Radicle/Git repositories and Nix evaluation/build outputs. It did not open `/var/lib/radicle`, did not execute `radicle-ci-runner guard --execute` against a production repository, did not deploy either host closure, did not change any production ref or signed ref, and did not widen live CI beyond the existing Bounded Exec RID.

The existing CI bot and runner systemd services remain least-authority services. No service command invokes `guard`; scanner/runner hardening continues to make `/var/lib/radicle` inaccessible, and the guard remains an explicit operator command requiring a separately supplied repository capability.

## Retained behavior

- Nickel policy freshness and positive/negative fixtures bind the exact Bounded Exec RID, accepted CI policy BLAKE3, Valence revision `e822bdf5395d6e1a77786c538ac0aaa13ef8c165`, non-delegate bot DID, sorted Author/Bonsai/Pine delegate set, threshold two, check `onix/ci/v1`, target `refs/heads/main`, signed-reference feature `parent`, Valence admission non-claims, and guard non-claims.
- The publisher emits a deterministic closed `onix.radicle-ci-status.v1` JSON line under the signed marker and preserves the human bounded-observation warning.
- The pure guard recomputes event, result, status, Valence receipt, and decision BLAKE3 identities and requires exact policy/patch/revision/job/object/artifact agreement.
- Admission requires both threshold exact-revision built-in accept reviews and a threshold intersection of those delegates whose cryptographically verified `refs/rad/sigrefs` is feature level `parent` and signs `refs/heads/main` at the candidate.
- The shell reloads the built-in patch evaluator, status comment author, reviews, signed refs, canonical predecessor, candidate object, and ancestry from one selected repository.
- Preview writes a create-new external receipt without ref mutation. Execute uses libgit2 `reference_matching` with the admitted expected-old OID and rereads the resulting ref.
- Negative tests reject unknown/malformed status, failed status, wrong bot/revision/object, duplicate/below-threshold approvals, missing signed-ref quorum, stale canonical state, non-descendant candidates, policy/non-claim weakening, receipt tampering, duplicate/unknown flags, output traversal, and stale compare-and-swap state.

## Commands and outcomes

The root dev shell currently contains no `cargo`; the baseline attempt failed before compilation with `cargo: not found`. The focused package rail therefore used an explicit Nix tool shell and the repository package build.

```text
nix shell nixpkgs#cargo nixpkgs#rustc nixpkgs#rustfmt nixpkgs#clippy \
  nixpkgs#gcc nixpkgs#git nixpkgs#pkg-config nixpkgs#openssl nixpkgs#sqlite \
  -c cargo test --manifest-path pkgs/radicle-ci-runner/Cargo.toml
```

Outcome: passed, 12/12 pure-library tests and 7/7 shell tests. Shell tests include built-in patch/status/review evaluator materialization, cryptographically verified `parent` signed refs naming the candidate, a successful temporary atomic compare-and-swap, and stale expected-old rejection.

```text
nix shell <same tools> -c cargo fmt --manifest-path pkgs/radicle-ci-runner/Cargo.toml --check
nix shell <same tools> -c cargo clippy --manifest-path pkgs/radicle-ci-runner/Cargo.toml --all-targets -- -D warnings
```

Outcome: passed.

```text
nix build .#radicle-ci-runner --no-link -L
nix build .#checks.x86_64-linux.radicle-ci-runner-policy --no-link -L
```

Outcome: passed. The focused policy check proves Nickel freshness/pass/fail fixtures, typed service settings, the exact runtime check name, existing deployment evidence bindings, bot/runner isolation, absence of guard invocation from services, unchanged Bounded Exec-only source scope, and package tests.

```text
nix build .#nixosConfigurations.aspen1.config.system.build.toplevel --no-link -L
nix build .#nixosConfigurations.britton-desktop.config.system.build.toplevel --no-link -L
```

Outcome: passed. The following are directional pre-final-evidence closure observations; this in-repository evidence does not self-bind the closure produced after its own bytes are committed.

- Aspen closure: `/nix/store/xaa9pm946lrdp1611bc16c29521mzynx-nixos-system-aspen1-26.11.20260629.7a1a647`
- Desktop closure: `/nix/store/yk6igbh8ad2yb0chzkgwdzh29prxx2rz-nixos-system-britton-desktop-26.11.20260629.7a1a647`

Per the existing operator direction, broad fleet `nix flake check -L` remains deferred; focused checks plus both x86_64 host closures are the accepted onix-core rail.

```text
nix run /home/brittonr/git/OnixResearch/cairn#cairn -- validate --root . --policy /home/brittonr/git/OnixResearch/cairn/cairn-policy/generated/cairn-policy.json
nix run /home/brittonr/git/OnixResearch/cairn#cairn -- gate proposal add-radicle-ci-canonical-guard --root . --policy <policy>
nix run /home/brittonr/git/OnixResearch/cairn#cairn -- gate design add-radicle-ci-canonical-guard --root . --policy <policy>
nix run /home/brittonr/git/OnixResearch/cairn#cairn -- gate tasks add-radicle-ci-canonical-guard --root . --policy <policy>
```

Outcome: passed before sync/archive.

## Claim boundary

The checks establish deterministic guarded-CAS input validation and temporary-repository behavior only. They do not establish CI/source/Nix correctness, host sandbox correctness, protocol-enforced mandatory CI, bypass-proof delegates, merge semantics, production canonical mutation, seed convergence, replication, geographic independence, release readiness, or post-update durability.
