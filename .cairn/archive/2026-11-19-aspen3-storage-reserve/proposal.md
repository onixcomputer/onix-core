## Why

aspen3's 952 GiB pool kept filling: Prometheus shows `/` at 0 GiB free on Nov 11, 12, 15, 17, 18 and 19, and on 2026-11-19 Prometheus' WAL and sshd failed with ENOSPC. Every dataset draws on the same free space, so `/home` growth starves `/nix`, `/` and the AI tooling alike. Build output and caches sit inside the snapshotted `/home`: when agents deleted 68 GiB of `~/.cargo-target` and worktrees, the `00h00` snapshots kept it, and agents then destroyed snapshots by hand. Nix GC cannot help: after removing five system generations it freed 0.8 MiB.

## What Changes

- `~/.cache` and `~/.cargo-target` move to `zroot/cache` (120 GiB quota) and `zroot/cargo-target` (64 GiB quota), neither snapshotted.
- The AI tooling's state moves to `zroot/agents`, which reserves 40 GiB: `~/.omp`, `~/.claude`, and `~/.config` and `~/.local/state`, which hold herdr's, omp's and underclass's config and state.
- Activation reserves 20 GiB above `/nix`'s use and 15 GiB above `/`'s, keeps a 10 GiB emergency reserve in `zroot/reserved`, and caps `/home` at a 650 GiB refquota.
- A boot-time service moves the directories before anything opens them, checks each copy and keeps the original as `<dir>.pre-zfs`. A mount happens only after its directory has moved.
- A weekly job removes idle Cargo output with britton-desktop's safeguards. A daily job removes Codex staging copies older than a day and scratch GC roots older than 14 days.

## Impact

- Scope: `machines/aspen3/storage.nix`, its import and the `/nix` comment in `machines/aspen3/configuration.nix`, and this change.
- Authorization: Britton chose the sizes above and to move the busy directories at the next reboot, which he schedules. `~/.cargo-target` and `~/.claude`, which nothing holds open, move live after the switch.
- Space: the reservations set aside about 68 GiB of the pool's 121 GiB usable, leaving about 55 GiB that `/home`, `~/.cache` and `~/.cargo-target` share.
- Limits: `~/.claude.json` is a file in `~` and stays on `/home`. The `.pre-zfs` originals and the `/home` snapshots that reference them are removed only after the reboot is verified.
