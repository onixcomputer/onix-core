## Context

Three callsites in `nickel-lang-core/src/cache.rs` use OS-specific APIs unavailable on `wasm32-unknown-unknown`:

1. **`normalize_path()`** (line 2143) — calls `std::env::current_dir()` to resolve relative paths to absolute. Runs on every `get_or_add_file()` call, which fires for every `import`.

2. **`add_normalized_file()`** (line 289) — calls `std::fs::read_to_string(&path)` to load file content on cache miss.

3. **`timestamp()`** (line 2226) — calls `std::fs::metadata().modified()` for cache invalidation. Used by `id_or_new_timestamp_of()` and `get_or_add_file()`.

The call chain for `import "foo.ncl"` is:
```
CacheHub::resolve()
  → get_or_add_file(parent_dir / "foo.ncl")
    → normalize_path()          ← panics (current_dir)
    → id_or_new_timestamp_of()  ← panics (metadata)
    → add_normalized_file()     ← panics (read_to_string)
```

Pre-populating the cache via `add_string()` (which sets `SourceKind::Memory` and bypasses disk reads) doesn't help because `normalize_path()` runs before the cache lookup.

The nix-wasm host ABI provides `Value::read_file()` to read Nix store paths and `Value::make_path(base, rel)` to resolve relative paths against a base. These are the replacements for `std::fs::read_to_string` and `std::env::current_dir`.

## Goals / Non-Goals

**Goals:**
- Abstract the three OS-dependent callsites behind a trait so `SourceCache` works on `wasm32-unknown-unknown`.
- Default implementation (`StdSourceIO`) preserves identical behavior to unpatched Nickel.
- WASM implementation (`WasmHostIO`) routes file reads through the nix-wasm host ABI.
- `evalNickelFile` supports `import "relative.ncl"` statements resolving against the input file's directory.
- Patch is minimal and localized to `cache.rs` for easy rebasing across Nickel releases.

**Non-Goals:**
- Upstreaming the patch to nickel-lang. The trait design is intentionally upstreamable, but the PR process is out of scope.
- Supporting Nickel package imports (`@pkg`). Only path-based `import "file.ncl"` is targeted.
- Supporting `import` with absolute paths. Only relative paths (resolved against the importing file's parent directory) work through the host ABI.
- Hot-reloading or filesystem watching. Nix store paths are immutable; timestamps are always `UNIX_EPOCH`.

## Decisions

### 1. Vendor as git subtree, not a fork

**Decision**: Copy `nickel-lang-core` 0.17.0 source into `wasm-plugins/vendor/nickel-lang-core/` as a Cargo path dependency. Strip everything except the `core` crate and its parser dep.

**Rationale**: A git fork requires maintaining a separate repo, tracking upstream branches, and dealing with flake input pinning. A vendored subtree lives in-repo, diffs are visible in `git log`, and rebasing patches onto a new Nickel release is a simple `cp` + `git diff` + re-apply. The vendored code is only used for WASM compilation — it never runs on the host.

**Alternative**: Cargo `[patch]` section pointing at a git fork. Rejected — adds a network dependency to builds and obscures the actual changes.

### 2. `Box<dyn SourceIO>` over generic parameter

**Decision**: Add `io: Box<dyn SourceIO>` field to `SourceCache` rather than making `SourceCache<IO: SourceIO>` generic.

**Rationale**: Making `SourceCache` generic would propagate the type parameter through `CacheHub`, `ImportResolver`, `Program`, and every function that touches the cache — a massive signature change touching dozens of files. A boxed trait object keeps the change to `SourceCache`'s constructor and the three callsites. The dynamic dispatch overhead is negligible compared to file I/O and Nickel evaluation.

**Alternative**: Generic `SourceCache<IO>`. Rejected — the patch would touch 30+ files and be impossible to rebase across Nickel releases.

### 3. `WasmHostIO` stores a base `Value` for path resolution

**Decision**: `WasmHostIO` holds the Nix `Value` of the input file path. `current_dir()` returns the parent directory of that path. `read_to_string(path)` calls `base.make_path(relative)` then `read_file()`.

**Rationale**: The nix-wasm ABI's `make_path(base, rel)` resolves relative paths within the same source tree that Nix controls. This gives us sandboxed path resolution — the WASM module can only read files that Nix considers part of the source tree. No escape from the store.

### 4. Timestamps are always UNIX_EPOCH in WASM

**Decision**: `WasmHostIO::metadata_timestamp()` returns `SystemTime::UNIX_EPOCH` unconditionally.

**Rationale**: Nix store paths are immutable and content-addressed. There's no meaningful modification time. The cache uses timestamps only for staleness detection (has the file changed since last load?). With immutable paths, nothing is ever stale.

## Risks / Trade-offs

**[Vendored code maintenance]** → The patch touches ~30 lines across 2 functions and adds ~40 lines of new code (trait + two impls). Nickel releases roughly quarterly. Rebase effort per release: check if `SourceCache`, `normalize_path`, `add_normalized_file`, or `timestamp` changed, re-apply the trait extraction if they did. Likely <30 minutes per release.

**[Nickel internal API drift]** → `SourceCache` is pub but not stability-guaranteed. The `add_string`, `get_or_add_file`, and `normalize_path` functions have been stable since at least 0.12. Risk is low for the specific callsites we patch.

**[Path resolution mismatch]** → Nickel's `normalize_path` does `.` and `..` resolution. The host ABI's `make_path` may resolve paths differently. Mitigated by using `normalize_abs_path` (pure path manipulation, no OS calls) after constructing the absolute path from the host.

**[Import depth]** → Deeply nested imports (A imports B imports C imports D) each trigger a host ABI `read_file` call. Each call crosses the WASM-host boundary. Performance should be fine for typical configs (<10 imports) but could be slow for pathological cases.
