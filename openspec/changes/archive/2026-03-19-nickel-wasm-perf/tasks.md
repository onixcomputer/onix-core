## 1. Stdlib Cache (nickel-plugin)

- [x] 1.1 Add `thread_local!` CacheHub storage with `RefCell<Option<CacheHub>>` in `nickel-plugin/src/lib.rs`
- [x] 1.2 Implement `get_prepared_cache(io: Arc<dyn SourceIO>) -> CacheHub` that initializes on first call (creates CacheHub, calls `prepare_stdlib`), then returns `clone_for_eval()` with swapped `sources.io` on subsequent calls
- [x] 1.3 Implement a no-op `SourceIO` struct for string-based evaluations (`evalNickel`, `evalNickelWith`) that returns `io::Error` on filesystem operations
- [x] 1.4 Modify `eval_nickel_file_source` to use `get_prepared_cache` with `WasmHostIO` instead of `CacheHub::with_io`
- [x] 1.5 Modify `eval_nickel_source` to use `get_prepared_cache` with the no-op `SourceIO` instead of creating a fresh Program from scratch
- [x] 1.6 Verify existing `wasm-evalNickel*` flake checks still pass (`nix flake check` or build the specific check derivations)

## 2. Skip Typechecking (nickel-plugin)

- [x] 2.1 Replace `Program::eval_full_for_export()` in `eval_nickel_file_source` with a manual pipeline: `VmContext::prepare_eval_impl` (skipping typecheck) → `eval_full_for_export_closure`, or use whatever Nickel API path skips the typecheck step while still running parse/compile/transform/eval
- [x] 2.2 Apply the same typecheck-skip path in `eval_nickel_source` (string-based evaluation)
- [x] 2.3 Verify contract violations still produce clear error messages by testing a `.ncl` file with a failing contract in the flake checks

## 3. Theme Evaluation Dedup (Nix modules)

- [x] 3.1 Create a shared theme evaluation site: add an `allThemeData` attrset (mapping theme name → evaluated NCL data) in a module that evaluates each theme `.ncl` file once, expose via `_module.args`
- [x] 3.2 Modify `inventory/home-profiles/shared/desktop/theme.nix` to consume `allThemeData` from module args instead of calling `wasm.evalNickelFile` — remove the `activeThemeData` local `let` binding and the fold's per-theme `wasm.evalNickelFile` calls
- [x] 3.3 Modify `inventory/home-profiles/brittonr/base/theme-data.nix` to consume `allThemeData` from module args instead of calling `wasm.evalNickelFile` for the default value
- [x] 3.4 Verify desktop machines (britton-desktop, britton-fw, bonsai) build successfully with `build <machine-name>`

## 4. Machines Data Dedup (Nix modules)

- [x] 4.1 Expose the pre-evaluated `machines.ncl` result from `inventory/core/default.nix` via `_module.args` (alongside the existing `wasm` arg pattern in `tags/common/wasm-lib.nix`)
- [x] 4.2 Modify `inventory/tags/remote-builders.nix` to consume the pre-evaluated machines data from module args instead of calling `wasm.evalNickelFile ../core/machines.ncl`
- [x] 4.3 Verify machines with the `remote-builders` tag build successfully (britton-fw, bonsai, aspen1, aspen2)

## 5. Validation

- [x] 5.1 Run full `nix flake check` to verify all WASM checks pass
- [x] 5.2 Build at least one machine from each profile set: one `hm-server` (aspen1), one `hm-laptop` (britton-fw), and `britton-desktop` (`hm-desktop`)
- [x] 5.3 Verify no regressions in generated configs by spot-checking a theme-dependent output (e.g., `nix eval --raw .#nixosConfigurations.britton-desktop.config.home-manager.users.brittonr.programs.fish.interactiveShellInit` should contain theme color values)
