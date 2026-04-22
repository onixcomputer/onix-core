Evidence-ID: V2-desktop-wrapper
Task-ID: V2
Artifact-Type: verification-evidence
Covers: rustcache.desktop-wrapper.cargo-build,rustcache.managed-config.file-ownership,rustcache.managed-config.profile-root-layout,rustcache.local-only.config-inspection,rustcache.shared-target-compat.managed-cargo-file

## Commands

```bash
nix eval --impure --raw --option allow-import-from-derivation true --expr \
  'let flake = builtins.getFlake (toString ./.) ; cfg = flake.nixosConfigurations.britton-desktop.config.home-manager.users.brittonr; in builtins.readFile cfg.home.file.".cargo/config.toml".source'
```

Output:

```toml
[build]
rustc-wrapper = "/nix/store/iiypmm1ak839mj4gjcza0zl4ppims8if-cargo-rustc-sccache-wrapper/bin/cargo-rustc-sccache-wrapper"
target-dir = "/home/brittonr/.cargo-target"

[net]
retry = 3

[term]
quiet = false
```

```bash
nix eval --impure --raw --option allow-import-from-derivation true --expr \
  'let flake = builtins.getFlake (toString ./.) ; cfg = flake.nixosConfigurations.britton-desktop.config.home-manager.users.brittonr; in builtins.readFile cfg.xdg.configFile."sccache/config".source'
```

Output:

```toml
basedirs = ["/home/brittonr/git", "/home/brittonr/git/worktrees"]

[cache.disk]
dir = "/home/brittonr/.cache/sccache"
size = 34359738368
```

Evaluated rustc-wrapper script referenced by the Cargo config:

```sh
#!/nix/store/v8sa6r6q037ihghxfbwzjj4p59v2x0pv-bash-5.3p9/bin/bash
set -o errexit
set -o nounset
set -o pipefail

export PATH="/nix/store/74sind1d6vf2bfwd7yklg8chsvzqxmmq-coreutils-9.10/bin:/nix/store/zdxjsar7pjr5893ac7r51g05g5zyyax5-sccache-wrapped/bin:$PATH"

if [ "$#" -lt 1 ]; then
  echo 'cargo-rustc-sccache-wrapper: expected rustc path as first argument' >&2
  exit 1
fi

real_rustc="$1"
shift

stderr_file="$(mktemp)"
trap 'rm -f "$stderr_file"' EXIT

if sccache "$real_rustc" "$@" 2>"$stderr_file"; then
  cat "$stderr_file" >&2
  exit 0
fi

status="$?"
stderr_text="$(<"$stderr_file")"
cat "$stderr_file" >&2

case "$stderr_text" in
  *'sccache: error: Connection to server timed out:'*|*'sccache: error: Server startup failed:'*|*'Timed out waiting for server startup.'*|*'sccache: error: Address already in use'*|*'failed to connect or start server'*)
    echo 'sccache-rustc-wrapper: cache transport unavailable, falling back to rustc' >&2
    exec "$real_rustc" "$@"
    ;;
esac

exit "$status"
```

Evaluated wrapped `sccache` launcher:

```sh
#! /nix/store/v8sa6r6q037ihghxfbwzjj4p59v2x0pv-bash-5.3p9/bin/bash -e
export SCCACHE_ERROR_LOG='/home/brittonr/.cache/sccache/error.log'
export SCCACHE_IGNORE_SERVER_IO_ERROR='1'
exec -a "$0" "/nix/store/zdxjsar7pjr5893ac7r51g05g5zyyax5-sccache-wrapped/bin/.sccache-wrapped"  "$@"
```

```bash
find inventory/home-profiles/brittonr/sccache -maxdepth 1 -type f | sort
find inventory/home-profiles/brittonr/sccache/lib -maxdepth 1 -type f | sort
```

Output:

```text
inventory/home-profiles/brittonr/sccache/README.md
inventory/home-profiles/brittonr/sccache/default.nix
inventory/home-profiles/brittonr/sccache/lib/config.ncl
```

## Result

PASS.

- Evaluated Cargo config points at the dedicated Nix-managed rustc-wrapper and preserves `target-dir`, `retry = 3`, and `quiet = false`.
- Evaluated wrapper scripts deliver `SCCACHE_IGNORE_SERVER_IO_ERROR=1`, `SCCACHE_ERROR_LOG=/home/brittonr/.cache/sccache/error.log`, and explicit fallback to direct `rustc` on transport/startup failures.
- Evaluated `sccache` config is local-only: only `basedirs` plus `[cache.disk]` are present, with no remote or distributed backend sections.
- Profile root has one root-level `.nix` file (`default.nix`), and helper/data config lives under `lib/config.ncl` outside the auto-imported root.
