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

## Aspen deployment and successful publication

The repair commit `72a5b954c0d8d832b6b2cf5c26bb913405affb3f` was pushed to `onix-core/main` and deployed with strict host-key checking. Aspen activated `/nix/store/d5y40whijpihsvbxdjmlzkabgiawmfj2-nixos-system-aspen1-26.11.20260629.7a1a647`; its publisher uses `/nix/store/j9rinfw9pd34022knb787lyxb7srs6xb-radicle-ci-runner-0.1.0/bin/radicle-ci-runner`. A post-commit local evaluation produced the directional closure `/nix/store/ibigjp1nda9mm3wzyxd670xh1ag2rq9s-nixos-system-aspen1-26.11.20260629.7a1a647`.

The retained job was re-published once with the repaired binary. `radicle-ci-publisher.service` returned `Result=success` and `ExecMainStatus=0`, the outbox entry was removed, and the bot patch COB ref advanced from `53db765918597276cca4364310d3c622aa85c600` to `b0f9964700ce1be5c44d1ba030fcf2ed23442177`.

The stored built-in Radicle operation begins with the exact body:

```text
onix-radicle-ci-status:v1
{"schema":"onix.radicle-ci-status.v1","status_blake3":"02754ddc51ee58402938dcb5b1d2ebc31a4feaef0c64211b483b3a21b8f06d7c",...}
```

The operation observation BLAKE3 is `19eb9e541d37837e8727b30ecb1575ee17fed92a91cc8b977475cb273559e27f`. The status binds job `ffaaabbb76f5d54c48dc5c847bbf2ee9cd1513e70af3a29867be212c3be77a90`, result `8de4a86dfc4af84a95b6a46f4a70e536a6aae4415af518b4c89a2de567152421`, artifact `9046a67eee06c634ded25cc938acc6f076693e056a0a6fe42be9e026e06560cb`, and object `1baa4f552ae55923b025d99d08073286158836be`.

The Radicle node, HTTP service, CI node, and sync timer remained active. No systemd unit invokes `radicle-ci-runner guard`.

## Live guard preview

A Valence `e822bdf5395d6e1a77786c538ac0aaa13ef8c165` offline receipt was generated and independently verified for the historical patch base `29dac88ecded94457572db3fdfaaaab95fa91525`, candidate `1baa4f552ae55923b025d99d08073286158836be`, and supplied Author+Bonsai accept observations. The explicit operator guard was then run as the storage-owning `radicle` user without `--execute` against the live Aspen repository.

The guard failed closed and wrote execution receipt BLAKE3 `908c8d8213f56c6dc47ac6b6e2a2cbd50256c01651cb70b270dcbef18387a0b6` (`executed=false`; observation-file BLAKE3 `97db02475883c842f5c2aed30f7c76c2ae01919233c3f0eec97fd24152dee6bc`). Live materialization rejected the supplied admission on three independent facts:

- `guard-live-approvals` — the exact live revision does not carry the supplied delegate approval set;
- `guard-live-patch` — the patch base is stale relative to canonical `main`;
- `guard-live-signed-refs` — the exact candidate lacks threshold matching delegate `parent` signed refs.

Canonical `refs/heads/main` remained `1baa4f552ae55923b025d99d08073286158836be` before and after the preview.

## Claim boundary

The failed and repaired publication probes concern comment transport and exact payload preservation only. The preview proves fail-closed observation for these supplied and live facts; it does not prove CI correctness, source correctness, signature trust, merge eligibility, canonical admission, ref mutation, replication, release readiness, or post-update durability. `guard --execute` was not invoked.
