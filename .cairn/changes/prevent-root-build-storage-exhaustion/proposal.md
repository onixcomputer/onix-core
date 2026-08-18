## Why

`britton-desktop` reached 100% root filesystem usage because repository-local Cargo targets and the interactive Kache cache were stored under `/home/brittonr` on the ext4 root disk. Several worktree targets exceeded 50 GiB, one exceeded 250 GiB, and the user Kache cache reached 30 GiB. The existing ZFS datasets did not protect root because repository checks explicitly use `CARGO_TARGET_DIR=target` for isolated builds.

## What Changes

- Mount `~/git` from a quota-limited ZFS dataset so repository-local targets cannot consume root space.
- Keep the shared Cargo target and Kache datasets quota-limited.
- Move interactive Kache state to an isolated directory on the existing machine-owned ZFS cache dataset.
- Remove inactive ignored Cargo targets after a bounded retention period, while skipping active builds.
- Limit persistent journals to 1 GiB.

## Impact

- **Scope**: `britton-desktop` build storage and the Britton Home Manager Kache profile.
- **Risk**: The one-time `~/git` migration must preserve ownership, links, worktrees, and uncommitted files. Cleanup must not remove tracked fixtures or active build output.
- **Rollback**: Stop the cleanup timer, restore the old Kache path, and copy `datapool/git` back to root before removing the dataset mount.
- **Testing**: Evaluate the machine configuration, validate Cairn artifacts, check the pruner safeguards, and verify runtime mounts, quotas, Kache environment, and root usage after deployment.
