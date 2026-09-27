# BranchFS on Aspen3 and britton-desktop

Both host configurations install the pinned BranchFS package `pkgs.branchfs`
from onixpkgs `pkgs/branchfs/default.nix`. The source revision is
`d7f672f370c759cf3eba914fd21cc2d764950d7a`.

BranchFS runs as `brittonr` through the existing FUSE helpers. It needs no root
daemon, automatic mount, or change to the underlying filesystem.

## Start a workspace

Use a separate storage directory for each base directory. Every command for
that workspace must use the same `--storage` path. The upstream default,
`/var/lib/branchfs`, is not writable by a normal user.

The following example uses disposable data, not an existing repository:

```sh
mkdir -p ~/branchfs-demo/base ~/branchfs-demo/mount
printf 'original\n' > ~/branchfs-demo/base/example.txt
branchfs mount --base ~/branchfs-demo/base --storage ~/branchfs-demo/state ~/branchfs-demo/mount
branchfs create experiment --storage ~/branchfs-demo/state ~/branchfs-demo/mount
printf 'changed\n' > ~/branchfs-demo/mount/example.txt
cat ~/branchfs-demo/base/example.txt
branchfs abort --storage ~/branchfs-demo/state ~/branchfs-demo/mount
branchfs unmount --storage ~/branchfs-demo/state ~/branchfs-demo/mount
```

The base file retains `original`. Abort discards the branch changes.

CAUTION: Review branch changes before you run `branchfs commit`. Commit writes
changes and deletions into the parent. This can change the base directory.
Do not use BranchFS as a backup or as a security boundary for untrusted code.

## Verification

Live checks passed as `brittonr` on both hosts:

- Mount and unmount without root.
- A branch write leaves the base unchanged.
- Abort restores the inherited file view.
- Commit copies a new file into the base.
- Abort on `main` returns an error.

The package build passed. Its 29 upstream FUSE tests are ignored by default,
so the build alone does not prove runtime behavior.

The initial installation uses the user Nix profile on each host. The host
configuration also declares the package for the next system deployment.
No full system deployment occurred for this installation.

## Pi integration

Both hosts load the global `branchfs` extension and `branchfs-workspaces` skill.
The sources live in `modules/pi-branchfs/`. The host module declares their
Home Manager paths. Live installations use a rooted Nix store copy.

For an existing Pi session, use `/reload`. New sessions load the extension
automatically. `/branchfs-status` shows whether the tool is active.
`/skill:branchfs-workspaces` loads the complete workflow.

Pi now prefers BranchFS for temporary edit workspaces. Explicit repository
requirements for real worktrees still apply. The extension does not change
Pi or Pueue working directories, migrate existing worktrees, or clean mounts
on session exit. The skill explains review, base conflicts, metadata limits,
and explicit cleanup.

Run the pure and adapter checks with:

```sh
node --test modules/pi-branchfs/tests.mjs
nix build .#checks.x86_64-linux.pi-branchfs
```

The live check uses the installed Pi runtime, the global extension, and FUSE.
It creates disposable files under the home directory without a model call:

```sh
pi --mode rpc --no-session -e modules/pi-branchfs/live-check.ts < /dev/null
```

A successful run prints `PI_BRANCHFS_LIVE_PASS`. A failed run retains its
workspace for inspection. Do not remove that workspace until its mount is closed.

Aspen3 was reachable at `100.108.13.4`, but its LAN address was unavailable.
Its `/tmp` was full. The live checks and profile installation used a temporary
directory under the home directory instead. No unrelated files were removed.
For Pi, its user-owned `/tmp/jiti` cache moved to `~/.cache/pi-jiti-aspen3`,
with a symlink at the original path. This permits extension loading without
a temporary-directory override. A reboot can clear the temporary symlink.
