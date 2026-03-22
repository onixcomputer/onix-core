## 1. validateNickel exported function

- [ ] 1.1 Add `pub extern "C" fn validateNickel(arg: Value) -> Value` to `wasm-plugins/nickel-plugin/src/lib.rs` that destructures the attrset into `contract` (path) and `value` (any)
- [ ] 1.2 Read and evaluate the contract `.ncl` file using `WasmHostIO`-backed `Program` (reuse `evalNickelFile` internals for import resolution)
- [ ] 1.3 Convert the Nix `value` to a Nickel `RichTerm` using `nix_to_nickel` (from `nickel-eval-args` change, or implement inline if that hasn't landed)
- [ ] 1.4 Construct a synthetic Nickel program that merges the contract with the converted value: `(<contract>) & (<value>)`
- [ ] 1.5 Call `eval_full_for_export` on the merged program to trigger all contract checks
- [ ] 1.6 On success, return the original Nix `value` (from `arg.get_attr("value")`) — not the round-tripped conversion
- [ ] 1.7 On contract violation, format the error: prepend the contract file path, include the Nickel blame message, then call `nix_wasm_rust::panic`

## 2. lib/wasm.nix wrapper

- [ ] 2.1 Add `validateNickel` wrapper to `lib/wasm.nix` that takes a single attrset `{ contract, value }` and invokes `builtins.wasm` with the nickel_plugin and function name `validateNickel`

## 3. Flake checks

- [ ] 3.1 Add check: valid attrset passes a record contract — verify original value returned
- [ ] 3.2 Add check: type mismatch (string where Number expected) — verify Nix eval fails
- [ ] 3.3 Add check: missing required field — verify Nix eval fails
- [ ] 3.4 Add check: custom `from_predicate` contract (e.g., port range) — passing case
- [ ] 3.5 Add check: custom `from_predicate` contract — failing case (out of range)
- [ ] 3.6 Add check: nested record contract with violation at inner field
- [ ] 3.7 Add check: contract file uses `import` for shared contract library
- [ ] 3.8 Add check: open record contract (`{ port | Number, .. }`) passes with extra fields
