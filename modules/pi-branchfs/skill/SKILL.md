---
name: branchfs-workspaces
description: Prefer BranchFS over temporary Git worktrees or jj workspaces for isolated edits, experiments, and parallel Pi agents on aspen3 and britton-desktop. Use the branchfs tool for explicit mount, branch, review, and cleanup operations. Preserve mandatory repository lifecycle rules.
---

# BranchFS workspaces

## Default and limits

Use BranchFS for new temporary edit workspaces instead of Git worktrees.
Keep an existing worktree intact. Do not convert active worktrees automatically.

Explicit repository worktree requirements still apply. Cairn integration can
require a real branch from `origin/main`. BranchFS does not replace that rule,
Git history, jj history, or remote integration.

BranchFS is filesystem isolation, not a security sandbox. Absolute symlinks,
external Git metadata, shared caches, services, and network writes can escape
the workspace. Do not promise conflict detection, crash-atomic publication,
or a cheap snapshot of a large tree. The pinned implementation can copy data.

## Create a workspace

1. Read the repository instructions and inspect its current state.
2. Select a small base directory with no active writers for the initial snapshot.
3. Create dedicated, empty `mount` and `state` directories outside the base tree.
4. Call `branchfs` with `action=mount`, `base`, `mount`, and `storage=state`.
5. Call `branchfs` with `action=create`, a unique `name`, and the same mount and storage.
6. Give each worker its mount path and explicit scope.

Use absolute paths in all tool arguments. The tool requires existing directories.
Do not use `/var/lib/branchfs` or storage inside the source tree. On these hosts,
a sibling under `~/git/` keeps large branch data off `/tmp`.

A linked Git worktree has a `.git` file that points outside the workspace. The
tool rejects it as a base. The tool also rejects `.jj` metadata because a generic
copy does not establish independent jj state. Use the required native workspace
workflow for these cases. Inspect nested repositories and symlinks separately.

## Work inside the branch

Use absolute paths under the returned mount for `read`, `edit`, and `write`.
Pass that mount as `cwd` to Pueue and worker processes. Pi does not change its
session directory when it creates a mount. Never assume that a shell `cd`
changes the working directory of later tools.

Create separate mount/storage pairs for independent agents unless they need an
explicit shared branch tree. Mount-level branch switches affect all users of
that mount. For a shared tree, use fixed `mount/@branch-name/` paths per worker.

Run positive and negative tests in the branch. Do not modify `.git` or `.jj`
inside a BranchFS mount. Make VCS commits in the primary repository after
reviewed integration. Do not let a child auto-commit, auto-push, or unmount.

## Review and integrate

1. Stop all writers and workers for the workspace.
2. Review the changed files and test evidence.
3. Compare the base against the version from which the workspace began.
4. If the base changed, transfer selected edits and resolve conflicts manually.
5. If the base is unchanged and integration is authorized, call `action=commit` with `reviewed=true`.
6. Run the relevant checks in the primary repository before its VCS commit.

`reviewed=true` records a caller assertion, not an approval grant. Commit can
write and delete base files. Do not commit the BranchFS tree after any metadata
changes, unrelated base changes, or incomplete review. Prefer selected patches
for repository integration when those conditions are uncertain.

## Discard and close

1. Stop all processes that use the mount.
2. Review the branch before you discard it.
3. Call `action=abort` with the same mount/storage and `reviewed=true`.
4. Call `action=unmount` with the same mount/storage and `reviewed=true`.

Commit and abort return the mount to its parent. They do not unmount it.
Unmount can discard remaining branches. Do not use it to retain unfinished work.
The extension never commits, aborts, unmounts, or removes directories on Pi exit
or `/reload`. After an error or timeout, inspect the actual mount and daemon
before a retry. Retained state is not proof of crash recovery.

Use `action=list` with the exact storage directory to inspect a live daemon.
The tool serializes commands for that storage within one Pi process. It does
not lock out other Pi processes or arbitrary file writes. Coordinate workers.
