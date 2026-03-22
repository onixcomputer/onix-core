## Why

Every `builtins.wasm` call to the Nickel plugin re-parses and re-compiles the 184KB Nickel stdlib from scratch. A full fleet eval triggers ~69 WASM calls, each independently parsing `std.ncl` (165KB) and `internals.ncl` (18KB) through the LALRPOP grammar, lowering ASTs to runtime representation, and running program transforms. The WASM module compilation itself is cached by the Nix fork's `InstancePre` mechanism (pooling allocator + COW), so WASM instantiation is fast (~10-100µs). The stdlib initialization inside the Nickel evaluator is the dominant per-call cost.

Secondary waste comes from duplicated evaluations: `machines.ncl` is evaluated 5 times (1 flake-level + 4 per-machine from `remote-builders.nix`), and `theme.nix` evaluates all 5 theme NCL files per desktop machine (15 calls for 3 machines) plus a redundant active-theme evaluation that never shares with the fold.

## What Changes

- Cache the prepared Nickel `CacheHub` (with stdlib already parsed, compiled, and transformed) across WASM calls using `thread_local!` storage in the Nickel plugin. Subsequent calls use `clone_for_eval()` with a swapped `SourceIO`.
- Skip Nickel typechecking for user source — the plugin evaluates trusted `.ncl` files from the Nix store, and `prepare_stdlib` already skips typechecking ("for performance reasons: this is done in the test suite").
- Deduplicate theme NCL evaluations by evaluating all themes once at inventory level and passing the data through module args rather than re-evaluating per machine.
- Eliminate redundant `machines.ncl` evaluations by passing the flake-level result through `specialArgs` or a shared module argument.

## Capabilities

### New Capabilities
- `stdlib-cache`: Cache the prepared Nickel CacheHub with stdlib across WASM plugin calls, eliminating per-call stdlib parse/compile/transform overhead.
- `skip-typecheck`: Skip Nickel typechecking for user source in the WASM plugin since files are trusted Nix store paths.
- `eval-dedup`: Deduplicate repeated Nickel evaluations of the same files across NixOS modules (themes, machines.ncl).

### Modified Capabilities

## Impact

- `wasm-plugins/nickel-plugin/src/lib.rs`: Add `thread_local!` CacheHub cache, modify `eval_nickel_source` and `eval_nickel_file_source` to reuse prepared stdlib, add eval-only path bypassing typecheck.
- `wasm-plugins/vendor/nickel-lang-core/`: May need minor patches if `SourceCache.io` swap after `clone_for_eval()` has issues (field is `pub`, should work directly).
- `inventory/home-profiles/shared/desktop/theme.nix`: Restructure theme evaluation to happen once at inventory level.
- `inventory/home-profiles/brittonr/base/theme-data.nix`: Consume pre-evaluated theme data instead of calling `evalNickelFile` directly.
- `inventory/core/default.nix`: Export `machines.ncl` result for consumption by tag modules.
- `inventory/tags/remote-builders.nix`: Consume pre-evaluated machines data instead of calling `evalNickelFile` directly.
- `inventory/tags/common/wasm-lib.nix`: Potentially pass shared evaluation results alongside the `wasm` module arg.
