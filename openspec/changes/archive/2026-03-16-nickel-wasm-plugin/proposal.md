## Why

The project already has `builtins.wasm` infrastructure (nix fork + Rust plugin workspace) providing `fromYAML`, `toYAML`, and `fromINI` as pure Nix functions backed by WASM. Nickel is a typed configuration language that compiles to WASM and has a richer type/contract system than Nix, but the only existing Nix↔Nickel bridge (organist) requires import-from-derivation. Embedding Nickel's evaluator as a WASM plugin eliminates IFD, lets `.ncl` files be consumed directly during Nix evaluation, and opens the door to using Nickel contracts as a validation layer for NixOS configurations.

## What Changes

- New `nickel-plugin` Rust crate in the `wasm-plugins/` workspace that embeds `nickel-lang-core` and compiles to `wasm32-unknown-unknown`.
- New `evalNickel` WASM function: takes a Nickel source string, evaluates it, returns a Nix attrset/value.
- New `evalNickelFile` WASM function: takes a Nix path, reads the `.ncl` file via the host `read_file` ABI, evaluates it.
- New Nix wrapper functions in `lib/wasm.nix`: `evalNickel` and `evalNickelFile` that call the plugin through `builtins.wasm`.
- New flake check tests validating Nickel evaluation round-trips (string input, file input, contracts, error handling).
- Nickel added as a cargo dependency (pinned version, `default-features = false` to strip REPL/doc/format features).

## Capabilities

### New Capabilities
- `nickel-eval`: Evaluate Nickel source strings and files from within Nix evaluation via `builtins.wasm`, returning native Nix values without IFD.
- `nickel-file-import`: Read `.ncl` files from Nix store paths using the host WASM ABI (`read_file`/`make_path`), supporting Nickel's `import` resolution against the Nix source tree.

### Modified Capabilities
<!-- No existing specs to modify -->

## Impact

- **wasm-plugins/**: New `nickel-plugin` crate added to workspace. `Cargo.toml` gains `nickel-lang-core` dependency (~48K lines of Rust). WASM binary size increases (expect 2-5MB for the Nickel plugin after wasm-opt).
- **lib/wasm.nix**: Two new functions exposed (`evalNickel`, `evalNickelFile`).
- **flake-outputs/_wasm-checks.nix**: New check targets for Nickel plugin.
- **flake.nix**: No changes needed (plugin builds via existing `wasm-plugins` package).
- **Build time**: Nickel core is a substantial Rust crate; first build adds ~2-4 minutes. Subsequent builds are incremental.
- **Runtime**: Each `builtins.wasm` call spawns a fresh WASM instance. Nickel stdlib (~6K lines) is re-parsed per call. Expect ~50-200ms per evaluation depending on complexity.
