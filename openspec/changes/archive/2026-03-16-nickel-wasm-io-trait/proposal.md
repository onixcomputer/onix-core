## Why

The nickel-plugin WASM module can evaluate self-contained `.ncl` files but cannot resolve `import` statements. Nickel's `SourceCache` in `cache.rs` hardcodes three `std::fs`/`std::env` calls that panic on `wasm32-unknown-unknown`: `std::env::current_dir()` in `normalize_path()`, `std::fs::read_to_string()` in `add_normalized_file()`, and `std::fs::metadata()` in `timestamp()`. These run during import resolution before any cache lookup, so even pre-populating the cache with `add_string()` doesn't help — the path normalization panics first.

Without imports, every `.ncl` file must be self-contained. This blocks the primary value proposition: shared contract libraries, composable service schemas, and machine definition templates that inherit from a base.

Vendoring `nickel-lang-core` and introducing a `SourceIO` trait to abstract these three callsites unblocks import resolution in WASM. The default implementation preserves existing behavior. The WASM implementation routes through the nix-wasm host ABI (`read_file`, `make_path`).

## What Changes

- Vendor `nickel-lang-core` 0.17.0 as a git subtree or path dependency under `wasm-plugins/vendor/nickel-lang-core/`.
- Introduce a `SourceIO` trait with three methods: `current_dir`, `read_to_string`, `metadata_timestamp`.
- Provide `StdSourceIO` (default, uses `std::fs`) and `WasmHostIO` (routes through nix-wasm-rust ABI).
- Modify `SourceCache` to hold a `Box<dyn SourceIO>` and route the three hardcoded callsites through it.
- Update `nickel-plugin` to construct a `WasmHostIO` backed by the Nix path argument's `make_path`/`read_file`.
- Update `evalNickelFile` to support Nickel `import` statements by wiring the host ABI into the IO trait.
- Add flake checks testing multi-file Nickel evaluation with imports.

## Capabilities

### New Capabilities
- `nickel-source-io`: Abstract filesystem access in `nickel-lang-core`'s `SourceCache` behind a `SourceIO` trait, enabling pluggable path resolution and file reading for non-standard environments (WASM, in-memory, virtual FS).
- `nickel-wasm-imports`: Resolve Nickel `import` statements in the WASM plugin by routing file reads through the nix-wasm host ABI, enabling multi-file `.ncl` projects.

### Modified Capabilities
<!-- No existing specs to modify -->

## Impact

- **wasm-plugins/vendor/**: New vendored copy of `nickel-lang-core` (~48K lines Rust). Pinned to 0.17.0, patched locally.
- **wasm-plugins/nickel-plugin/**: Switches from crates.io `nickel-lang-core` to the vendored path dep. Gains `WasmHostIO` implementation and updated `evalNickelFile`.
- **wasm-plugins/Cargo.lock**: Dependency graph changes from crates.io source to path source.
- **flake-outputs/_wasm-checks.nix**: New checks for import resolution.
- **lib/wasm.nix**: `evalNickelFile` doc comment updated to remove the import limitation.
- **Maintenance**: Vendored nickel-lang-core needs manual rebasing when upgrading Nickel versions. The patch is small (one new trait, three callsite changes in `cache.rs`) so conflicts should be rare.
