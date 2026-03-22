## 1. Vendor nickel-lang-core

- [x] 1.1 Create `wasm-plugins/vendor/` directory and copy the `nickel-lang-core` 0.17.0 crate source into it (from `/tmp/pi-repos/nickel/core/` or a fresh checkout). Include `src/`, `stdlib/`, `Cargo.toml`, and `build.rs` if present.
- [x] 1.2 Copy the `nickel-lang-parser` crate into `wasm-plugins/vendor/nickel-lang-parser/` (required dependency of core). Include the `nickel-lang-vector` crate if also needed.
- [x] 1.3 Update vendored `nickel-lang-core/Cargo.toml`: set `default-features = false`, strip optional deps (`rustyline`, `termimad`, `comrak`, `topiary-*`, `tree-sitter-*`, `wasm-bindgen`, `cxx`), point `nickel-lang-parser` dep at `path = "../nickel-lang-parser"`.
- [x] 1.4 Update `wasm-plugins/nickel-plugin/Cargo.toml` to use `path = "../vendor/nickel-lang-core"` instead of crates.io version.
- [x] 1.5 Add vendored crates to `wasm-plugins/Cargo.toml` workspace members.
- [x] 1.6 Run `cargo check --target wasm32-unknown-unknown -p nickel-plugin` to verify the vendored source compiles identically to the crates.io version.

## 2. Introduce SourceIO trait

- [x] 2.1 Define the `SourceIO` trait in `vendor/nickel-lang-core/src/cache.rs` with three methods: `current_dir`, `read_to_string`, `metadata_timestamp`. Make it object-safe.
- [x] 2.2 Implement `StdSourceIO` that delegates to `std::env::current_dir()`, `std::fs::read_to_string()`, and `std::fs::metadata().modified()`.
- [x] 2.3 Add `io: Box<dyn SourceIO>` field to `SourceCache`. Update `SourceCache` constructors (likely `Default` impl or `new()`) to accept an optional `SourceIO` and default to `StdSourceIO`.
- [x] 2.4 Replace the `std::env::current_dir()` call in `normalize_path()` — make it a method on `SourceCache` (or accept `&dyn SourceIO`) so it can call `self.io.current_dir()`.
- [x] 2.5 Replace `std::fs::read_to_string(&path)` in `add_normalized_file()` with `self.io.read_to_string(&path)`.
- [x] 2.6 Replace `fs::metadata(path).modified()` in `timestamp()` — make it a method or accept `&dyn SourceIO` so it calls `self.io.metadata_timestamp()`.
- [x] 2.7 Fix all compilation errors from the callsite changes. `normalize_path` is a free function called from `get_or_add_file` and `add_file` — these need access to the `io` field. `timestamp` is also called from `id_or_new_timestamp_of`. Trace all callers and update signatures.
- [x] 2.8 Verify the vendored crate compiles for both native (`cargo check -p nickel-lang-core`) and WASM (`cargo check --target wasm32-unknown-unknown -p nickel-plugin`).

## 3. WasmHostIO implementation

- [x] 3.1 Define `WasmHostIO` struct in `nickel-plugin/src/lib.rs` with a `base_path: Value` field (the Nix path of the input file).
- [x] 3.2 Implement `SourceIO` for `WasmHostIO`: `current_dir()` returns the parent dir of `base_path` (via `get_path()` + `Path::parent()`), `read_to_string()` uses `Value::make_path()` + `Value::read_file()`, `metadata_timestamp()` returns `UNIX_EPOCH`.
- [x] 3.3 Update `evalNickelFile` to construct a `Program` with a `SourceCache` that uses `WasmHostIO` instead of the default `StdSourceIO`.
- [x] 3.4 Verify `evalNickelFile` still works for self-contained files (no regressions from the IO trait changes).

## 4. Import resolution integration

- [x] 4.1 Create a multi-file test directory structure (via `pkgs.runCommand` or `pkgs.symlinkJoin`): `main.ncl` that imports `lib.ncl`, both in the same Nix store path.
- [x] 4.2 Add a flake check `wasm-evalNickelFile-import` that evaluates the multi-file test and asserts the import resolves correctly.
- [x] 4.3 Add a nested import test: `main.ncl` → `sub/a.ncl` → `../b.ncl` chain.
- [x] 4.4 Add a missing import error test: confirm that importing a nonexistent file produces a Nix eval error (not a WASM panic).
- [x] 4.5 Run all wasm checks and confirm pass.

## 5. Polish

- [x] 5.1 Update `evalNickelFile` doc comment in `lib/wasm.nix` to state that relative imports are supported.
- [x] 5.2 Update `evalNickelFile` doc comment in `nickel-plugin/src/lib.rs` to describe import support.
- [x] 5.3 Record a `vendor/nickel-lang-core/PATCH.md` documenting the exact changes made, which upstream files were modified, and how to rebase onto a new Nickel release.
- [x] 5.4 Remove the DEFERRED notes from tasks 4.2/4.3 in the `nickel-wasm-plugin` change's tasks.md.
