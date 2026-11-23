## Context

On 2026-11-19 after cleanup, `zroot` held 801 GiB of 952 GiB (84%, 85% fragmentation) with 121 GiB usable by datasets. `zroot/home` used 597 GiB, `zroot/nix` 141 GiB and `zroot/root` 91 GiB (68 GiB of it Lemonade models); only `radicle-seed` had a quota. `/home` is snapshotted 8 hourly, 7 daily, 4 weekly and 1 monthly. Prometheus has no Alertmanager, so its firing `LowDiskSpace` alerts reached nobody.

Live sizes and holders: `~/.cache` 82 GiB in 1.17 M entries (agents' worktrees in `noble-iss` and build slots among them, open in Steam, ChatGPT, Codex and two `cargo-octet` builds); `~/.omp` 7.9 GiB in 68 k entries (three omp agents, their daemons and omp's Chromium); `~/.local/state` 6.8 GiB in 381 k entries (6.7 GiB of it September VM replay state in `onix/`, plus herdr-core, omp and underclass state); `~/.config` 2.6 GiB; `~/.cargo-target` 2.1 GiB and `~/.claude` 552 KiB, which nothing held open.

## Decisions

1. One module, `machines/aspen3/storage.nix`, lists the moved directories once and derives the disko datasets, the generated mounts, the migration and the property enforcement from that list.
2. Reservations are headroom on top of current use. Activation re-applies `/nix`'s and `/`'s reservation as used + 20 GiB and used + 15 GiB on every switch and boot, so a GC releases reserved space and growth claims more. `zroot/agents` reserves 40 GiB in total, but only once omp's state has moved; reserving it over empty datasets would take 40 GiB instead of 23 GiB.
3. Activation creates missing datasets and re-applies their properties, as `kache-nix-rust` does on britton-desktop, because disko only applies options when it creates a pool. Failures warn and never fail activation.
4. Each mount carries `ConditionPathExists=` on its migration marker, ordered after the migration service, `nofail` and ordered before `local-fs.target`. A switch therefore never mounts an empty dataset over a live directory, and a missing dataset cannot stop the boot.
5. The migration service runs before `local-fs.target`, after `/home` mounts, and moves directories only while the system is `initializing` or `starting`, so nothing holds them. It refuses a directory that any process holds open, mounts the dataset at a staging path, copies with `cp -a -x --reflink=auto`, and compares entry counts and regular-file bytes. It writes the marker before renaming the original to `<dir>.pre-zfs`, so a boot interrupted after the check still mounts the verified copy. Directories move in parallel; the service times out after 45 minutes and then leaves the remaining originals in place.
6. `cp --reflink=always` fails across datasets with EXDEV (FICLONE requires one superblock). `--reflink=auto` falls back to `copy_file_range`, which OpenZFS 2.4.4 serves with block cloning across datasets: copying 29 k entries (1.7 GB) moved pool free space by 0 MiB, at 4–13 k entries/s. The 1.68 M entries should take a few minutes at boot.
7. The cleanup jobs reuse britton-desktop's rules. Cargo targets need `CACHEDIR.TAG`; those in Git repositories must also be Git-ignored, and nothing may have changed in 21 days. The job skips any run while Cargo or rustc is active, and also removes idle profile directories of the shared `~/.cargo-target`. Codex staging copies are removed by top-level age. Only indirect GC roots under `/tmp`, `/var/tmp`, `/dev/shm`, `~/.cache` and `~/scratch` that link into the store are removed.

## Risks

- The boot after deployment takes a few minutes longer, and sshd is not up until the migration finishes.
- The `.pre-zfs` originals share blocks with the new datasets, so they cost no space, but `/home` snapshots taken before the move keep the old blocks alive as the caches churn, for up to a month (monthly retention).
- The 40 GiB reservation also covers non-agent config and state under `~/.config` and `~/.local/state`, including the 6.7 GiB of VM replay state.

## Verification Plan

- Evaluate aspen3 with the module and build its toplevel; shellcheck runs on every script through `writeShellApplication`.
- After the switch: datasets and properties exist, reservations match use + headroom, the mounts were skipped by their conditions, and the timers are scheduled.
- Live-migrate `cargo-target` and `claude`; check the mounts, the markers, the entry and byte counts, and the `.pre-zfs` originals.
- After Britton's reboot: all six mounts come from their datasets, the `zroot/agents` reservation is 40 GiB, the migration journal reports each move, then delete the `.pre-zfs` originals.
