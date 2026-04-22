Evidence-ID: V6-stats-workflow
Task-ID: V6
Artifact-Type: verification-evidence
Covers: rustcache.workspace-basedirs.checkout-path,rustcache.fail-open.server-unavailable,rustcache.stats.repeated-builds

## README Coverage

`inventory/home-profiles/brittonr/sccache/README.md` now documents:

- the `chaoscontrol` primary/worktree reuse flow with `cargo clean` in the worktree
- the dead-UDS fail-open flow and `/home/brittonr/.cache/sccache/error.log`
- the managed rustc-wrapper fallback behavior for cache startup/transport failures
- the `sccache --zero-stats; cargo build; cargo clean; cargo build; sccache --show-stats` workflow for `crunch/crunch`
- the Rust cache caveats (`incremental`, link-heavy, and some `proc-macro` cases still miss)

## Commands

```bash
cd /home/brittonr/git/crunch/crunch
sccache --zero-stats
SNIX_BUILD_SANDBOX_SHELL=/bin/sh nix develop -c cargo build
SNIX_BUILD_SANDBOX_SHELL=/bin/sh nix develop -c cargo clean
SNIX_BUILD_SANDBOX_SHELL=/bin/sh nix develop -c cargo build
sccache --show-stats
```

## Result

Final stats snapshot:

```text
Compile requests                   1113
Cache hits                            1
Cache misses                        966
Base directories                /home/brittonr/git/, /home/brittonr/git/worktrees/
REQUESTS=1113
HITS=1
V6_V9_PASS=1
```

PASS. The documented `crunch/crunch` workflow produced non-zero request and hit counts after the second build.
