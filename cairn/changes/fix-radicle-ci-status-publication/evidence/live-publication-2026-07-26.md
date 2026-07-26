# Radicle CI status publication repair — 2026-07-26

## Observed production failure

After deploying onix-core `784250b933427de4f38516e97ea420bd3115fad8`, the existing exact patch result for job `ffaaabbb76f5d54c48dc5c847bbf2ee9cd1513e70af3a29867be212c3be77a90` was copied from the published spool back to the outbox and the publisher was started. The service failed with `Radicle patch status publication failed`, retained the outbox entry, and did not change the bot COB ref or any canonical ref.

A direct invocation under `radicle-ci-bot` exposed Radicle CLI's diagnostic `aborting operation due to empty comment`. The rendered body was 1,300 bytes and non-empty before submission. Upstream `strip_comments` treats a line beginning with `<!--` as an editor-comment start and only leaves that state when a later line ends with `-->`; the former one-line marker therefore caused every payload line to be discarded.

## Repair

The marker is now the visible protocol line `onix-radicle-ci-status:v1`. The signed JSON and human non-claim are unchanged. A pure regression helper models the observed sanitizer state machine and proves:

- the visible marker and body survive unchanged and parse successfully;
- the former one-line HTML marker is stripped to an empty body and rejected;
- closed-schema/tamper tests remain active.

The command's top-level usage text now also advertises the explicit operator guard surface.

## Pre-deployment validation

```text
cargo fmt --check --manifest-path pkgs/radicle-ci-runner/Cargo.toml
cargo test --manifest-path pkgs/radicle-ci-runner/Cargo.toml
cargo clippy --manifest-path pkgs/radicle-ci-runner/Cargo.toml --all-targets -- -D warnings
nix build .#radicle-ci-runner --no-link -L
nix build .#checks.x86_64-linux.radicle-ci-runner-policy --no-link -L
nix build .#nixosConfigurations.aspen1.config.system.build.toplevel --no-link -L
```

Outcome: passed. Rust coverage is 13 library tests and 7 shell tests. The pre-deployment Aspen closure is `/nix/store/vgigpmn57apggq7kb51i238szckqj2gw-nixos-system-aspen1-26.11.20260629.7a1a647`.

## Claim boundary

The failed and repaired publication probes concern comment transport and exact payload preservation only. They do not prove CI correctness, source correctness, signature trust, merge eligibility, canonical admission, ref mutation, replication, release readiness, or post-update durability. `guard --execute` was not invoked.
