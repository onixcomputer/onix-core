# Aspen3 Storage Specification

## Purpose

Defines the `aspen3-storage` capability.

## Requirements

### Requirement: Disposable build output is bounded and unsnapshotted

r[onix.aspen3.storage.disposable] aspen3 MUST store `/home/brittonr/.cache` on `zroot/cache` with a 120 GiB quota and `/home/brittonr/.cargo-target` on `zroot/cargo-target` with a 64 GiB quota, and neither dataset may take automatic snapshots.

#### Scenario: An agent deletes build output

- GIVEN `~/.cargo-target` or `~/.cache` lives on its dataset
- WHEN an agent deletes files there
- THEN the pool regains their space without waiting for any snapshot to expire
- AND growth past the quota fails only within that dataset

### Requirement: AI tooling state has reserved space

r[onix.aspen3.storage.agents] aspen3 MUST keep `~/.omp`, `~/.claude`, `~/.config` and `~/.local/state` on children of `zroot/agents`, which MUST reserve 40 GiB once omp's state has moved, and those datasets MUST keep automatic snapshots.

#### Scenario: The rest of the pool fills

- GIVEN the agent state has moved and other datasets have consumed all unreserved space
- WHEN omp, herdr, Claude or underclass writes its state
- THEN the write succeeds until `zroot/agents` uses its 40 GiB

### Requirement: The system keeps headroom

r[onix.aspen3.storage.reservations] aspen3 MUST reserve 20 GiB above `zroot/nix`'s current use and 15 GiB above `zroot/root`'s, MUST keep 10 GiB in the empty `zroot/reserved` dataset, and MUST cap `zroot/home` with a 650 GiB refquota.

#### Scenario: /home fills the pool

- GIVEN the reservations are applied
- WHEN `/home` consumes every unreserved byte
- THEN a deployment can still add 20 GiB to `/nix`, services can still write 15 GiB under `/`, and an operator can release 10 GiB by clearing `zroot/reserved`'s refreservation

### Requirement: Properties are enforced on the live pool

r[onix.aspen3.storage.properties] Activation MUST create any missing dataset from the storage list and re-apply quotas, reservations and snapshot flags, recomputing the headroom reservations from current use, and a property ZFS refuses MUST produce a warning without failing activation.

#### Scenario: A GC shrinks /nix

- GIVEN `/nix` used less space after a garbage collection
- WHEN the configuration activates
- THEN `/nix`'s reservation becomes its new use plus 20 GiB, rounded up to a GiB

### Requirement: Directories move only while nothing uses them

r[onix.aspen3.storage.migration] A directory MUST move to its dataset only during boot before `local-fs.target`, or in an explicit run that names it while no process holds it; the copy MUST match the original's entry count and regular-file bytes before its marker is written; the original MUST be kept as `<dir>.pre-zfs`; and a dataset MUST mount only after its marker exists.

#### Scenario: Deployment switches a running system

- GIVEN a directory has no migration marker
- WHEN `switch-to-configuration` starts the new units
- THEN the migration service reports that it waits for boot, the dataset stays unmounted, and the directory stays on `/home`

#### Scenario: Copy check fails at boot

- GIVEN the copy's entry count or byte total differs from the original
- WHEN the migration service checks it
- THEN no marker is written, the original stays in place, and its mount is skipped

### Requirement: Idle Cargo output is removed safely

r[onix.aspen3.storage.cargo_cleanup] A weekly job running as `brittonr` MUST remove only Cargo output with `CACHEDIR.TAG` and no file modified within 21 days (repository targets must also be Git-ignored), including idle profile directories of the shared `~/.cargo-target`, and MUST skip the run while Cargo or rustc is active.

#### Scenario: A build is running

- GIVEN `cargo` or `rustc` runs as `brittonr`
- WHEN the weekly job starts
- THEN it exits without deleting anything

### Requirement: Known garbage expires

r[onix.aspen3.storage.garbage] A daily root job MUST remove Codex `openai-bundled.staging-*` copies older than one day and MUST remove only those indirect GC roots under `/tmp`, `/var/tmp`, `/dev/shm`, `~/.cache` or `~/scratch` that link into `/nix/store` and are older than 14 days.

#### Scenario: A recent build result

- GIVEN a `result` link under `~/git` or one created this week under `~/.cache`
- WHEN the daily job runs
- THEN the link and its closure remain
