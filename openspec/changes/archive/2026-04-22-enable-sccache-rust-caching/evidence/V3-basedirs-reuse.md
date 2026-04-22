Evidence-ID: V3-basedirs-reuse
Task-ID: V3
Artifact-Type: verification-evidence
Covers: rustcache.local-only.config-inspection,rustcache.workspace-basedirs.checkout-path

## Commands

```bash
primary_repo=/home/brittonr/git/chaoscontrol
worktree_repo=/home/brittonr/git/worktrees/chaoscontrol
cache_dir=/home/brittonr/.cache/sccache

primary_rev=$(git -C "$primary_repo" rev-parse HEAD)
worktree_rev=$(git -C "$worktree_repo" rev-parse HEAD)
test "$primary_rev" = "$worktree_rev"

sccache --stop-server || true
rm -rf "$cache_dir"
mkdir -p "$cache_dir"

cd "$primary_repo"
nix develop -c cargo clean
sccache --zero-stats
nix develop -c cargo build
sccache --show-stats

cd "$worktree_repo"
nix develop -c cargo clean
nix develop -c cargo build
sccache --show-stats
```

## Key Results

```text
PRIMARY_REV=fa5123f04b017d5d3e260215eb71026e79033b3a
WORKTREE_REV=fa5123f04b017d5d3e260215eb71026e79033b3a
```

Primary build after clearing the local cache:

```text
Cache hits                            0
Cache misses                        137
Base directories                /home/brittonr/git/, /home/brittonr/git/worktrees/
PRIMARY_HITS=0
```

Worktree build at the same revision after `cargo clean`:

```text
Cache hits                          128
Cache misses                        146
Base directories                /home/brittonr/git/, /home/brittonr/git/worktrees/
WORKTREE_HITS=128
V3_PASS=1
```

## Result

PASS. With the local `sccache` store reset and both repos forced through fresh compilation, the primary checkout at `/home/brittonr/git/chaoscontrol` populated the cache and the second build from `/home/brittonr/git/worktrees/chaoscontrol` hit the cache 128 times at the same Git revision. The reported base directories match the configured normalization roots.
