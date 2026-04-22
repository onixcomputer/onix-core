Evidence-ID: V9-post-activation-wrapper
Task-ID: V9
Artifact-Type: verification-evidence
Covers: rustcache.desktop-wrapper.cargo-build

## Commands

```bash
bash -lc 'command -v sccache && sccache --version'
fish -lc 'command -v sccache; and sccache --version'
```

Output:

```text
/home/brittonr/.local/bin/sccache
sccache 0.14.0
/home/brittonr/.local/bin/sccache
sccache 0.14.0
```

```bash
cd /home/brittonr/git/crunch/crunch
if env | grep -q '^RUSTC_WRAPPER='; then exit 1; fi
sccache --zero-stats
SNIX_BUILD_SANDBOX_SHELL=/bin/sh nix develop -c cargo build
sccache --show-stats
```

Final stats snapshot:

```text
Compile requests                    617
Compile requests executed           476
Cache hits                          473
Cache misses                          3
Cache location                  Local disk: "/home/brittonr/.cache/sccache"
Base directories                /home/brittonr/git/, /home/brittonr/git/worktrees/
Version (client)                0.14.0
REQUESTS=617
V9_PASS=1
```

## Result

PASS. The activated desktop environment has the wrapped `sccache` on `PATH` in both bash and fish, no manual `RUSTC_WRAPPER` export was present in the validation shell, and an activated `cargo build` still produced positive `sccache` request counts through the managed rustc-wrapper.
