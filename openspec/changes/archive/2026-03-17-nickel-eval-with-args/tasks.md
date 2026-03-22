## 1. Nix-to-Nickel value conversion

- [x] 1.1 Add `nix_to_nickel(value: Value) -> RichTerm` function to `wasm-plugins/nickel-plugin/src/lib.rs` with type dispatch via `value.get_type()` covering int, float, bool, string, null, list, attrset
- [x] 1.2 Handle the unsupported-type case (function, path) with `nix_wasm_rust::panic` and a descriptive message
- [x] 1.3 Add a unit-level sanity test: call `nix_to_nickel` on a constructed `Value` and verify the `Term` variant (if testable within the wasm build, otherwise defer to flake checks) — deferred to flake checks (wasm32 target, no host test runner)

## 2. evalNickelFileWith exported function

- [x] 2.1 Add `pub extern "C" fn evalNickelFileWith(arg: Value) -> Value` to `lib.rs` that destructures the attrset into `file` and `args` keys
- [x] 2.2 Read and evaluate the `.ncl` file using existing `WasmHostIO`-backed `Program` setup (reuse `evalNickelFile` internals)
- [x] 2.3 After evaluation, check if result is a function term; if so, convert `args` via `nix_to_nickel`, apply to the function, and re-evaluate
- [x] 2.4 If result is not a function, emit warning via `nix_wasm_rust::warn!` and return the value as-is (ignoring args)
- [x] 2.5 Convert final result to Nix value via existing `json_to_nix` pipeline (or `richterm_to_nix` if direct-walk lands first)

## 3. evalNickelWith exported function

- [x] 3.1 Add `pub extern "C" fn evalNickelWith(arg: Value) -> Value` to `lib.rs` that destructures the attrset into `source` and `args` keys
- [x] 3.2 Evaluate source string using existing `evalNickel` internals, apply args using same function-application logic as `evalNickelFileWith`

## 4. lib/wasm.nix wrappers

- [x] 4.1 Add `evalNickelFileWith = path: args: builtins.wasm { ... } { file = path; inherit args; };` to `lib/wasm.nix`
- [x] 4.2 Add `evalNickelWith = source: args: builtins.wasm { ... } { inherit source args; };` to `lib/wasm.nix`

## 5. Flake checks

- [x] 5.1 Add check: `evalNickelFileWith` with scalar args (int, string, bool) and verify output
- [x] 5.2 Add check: `evalNickelFileWith` with nested attrset args
- [x] 5.3 Add check: `evalNickelFileWith` with list args
- [x] 5.4 Add check: `evalNickelFileWith` where `.ncl` file applies contracts to args — passing case
- [x] 5.5 Add check: `evalNickelFileWith` where contract on args fails — verify Nix error
- [x] 5.6 Add check: `evalNickelWith` with source string and args
- [x] 5.7 Add check: `evalNickelFileWith` on a non-function `.ncl` file — verify value returned and warning emitted
- [x] 5.8 Add check: `evalNickelFileWith` with file that imports other `.ncl` files and uses args
