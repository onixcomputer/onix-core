# Kiln executor publication evidence — 2026-08-18

## Published source

| Fact | Value |
|---|---|
| Kiln RID | `rad:z2wsvXm5S2sJGvuV1k5JHiwi1PbKE` |
| Bookmark | `seaglass-kiln-executor` |
| Exact revision | `8821e9adf15ad28838025bfbdd2e09c8d76fe5db` |
| Nix store package | `/nix/store/sq38b7ya66wff7c05k4xqhi87xdf16m1-kiln-0.1.0` |

The published bookmark contains only the four Radicle executor source
files. It excludes the unrelated local `align-provider-port-ownership`
Cairn draft from revision `534803a058a77459c914a612e4ef0cfc518a2f8e`.

`jj bookmark list --all-remotes seaglass-kiln-executor` reported the
same revision for the local, Git, and Radicle bookmark views.

## Validation

The isolated source passed these checks before publication:

```text
cargo fmt --all -- --check
cargo test -p kiln-adapter-radicle
cargo clippy -p kiln-adapter-radicle --all-targets --all-features -- -D warnings
```

The adapter test result was 20 passed, zero failed. The tests include
accepted push and patch requests plus empty, malformed, missing-revision,
unknown-version, oversized-input, missing-storage, and output-truncation
cases.

The exact published revision also built through its public Radicle Git
endpoint:

```text
nix build --no-link 'git+https://seed.radicle.garden/z2wsvXm5S2sJGvuV1k5JHiwi1PbKE.git?rev=8821e9adf15ad28838025bfbdd2e09c8d76fe5db#default'
```

Nix produced `/nix/store/sq38b7ya66wff7c05k4xqhi87xdf16m1-kiln-0.1.0`.
Onix-core pins the full revision in `flake.nix`. Nix generated the matching
`flake.lock` update.

The focused onix-core check also passed:

```text
nix build --option allow-import-from-derivation true --no-link -L \
  .#checks.x86_64-linux.seaglass-kiln-ci-policy
```

The check proves the desktop configuration selects the published adapter,
admits only the Seaglass RID, rejects the private pilot RID, and retains
the reviewed timeout, concurrency, output, CPU, and memory settings.

## Configured bounds

| Bound | Value |
|---|---|
| Concurrent adapters | `1` |
| Broker adapter timeout | `2h` |
| Captured output | `8 MiB` per stream |
| Broker cgroup CPU quota | `800%` |
| Broker cgroup memory limit | `24G` |

## Non-claims

The package is published and pinned but not deployed. The managed Radicle
storage does not yet contain Seaglass. The focused check does not prove a
live broker event or Radicle job status update.

The systemd cgroup covers the broker, adapter, and Nix client. This
evidence does not prove that local Nix daemon workers or remote builders
share the same memory cgroup.
