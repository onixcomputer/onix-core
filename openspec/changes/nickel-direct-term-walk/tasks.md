## 1. richterm_to_nix conversion function

- [x] 1.1 Add `fn nickel_to_nix(value: &NickelValue) -> Value` to `wasm-plugins/nickel-plugin/src/lib.rs` with match arms for `Null`, `Bool`, `Number`, `String`, `Array`, `Record` (via `ValueContentRef`)
- [x] 1.2 Implement the int/float heuristic for `Number`: emit `make_int` when `is_integer()` and fits in i64, otherwise `make_float` via `RoundingFrom`
- [x] 1.3 For `Record(Container::Alloc(record))`, use `iter_serializable()` which skips optional/unexported fields, extract field name via `Ident::to_string()`, recurse on field values
- [x] 1.4 Add a catch-all match arm that panics with the debug representation of unexpected term variants

## 2. Replace JSON pipeline in existing functions

- [x] 2.1 In `eval_nickel_source`, replace `serialize::to_string(Json)` + `serde_json::from_str` + `json_to_nix` with `nickel_to_nix` called directly on the `NickelValue` from `eval_full_for_export`
- [x] 2.2 In `eval_nickel_file_source`, apply the same replacement
- [x] 2.3 Delete the `json_to_nix` function entirely
- [x] 2.4 Remove all `use serde_json` imports and `use nickel_lang_core::serialize` imports (no longer used anywhere)

## 3. Remove serde_json dependency

- [x] 3.1 Remove `serde_json = "1"` from `wasm-plugins/nickel-plugin/Cargo.toml`
- [x] 3.2 Run `nix build .#wasm-plugins` to confirm clean compilation

## 4. Verify existing checks still pass

- [x] 4.1 Run all 22 existing wasm flake checks — all pass with identical output
- [x] 4.2 Add a check for a large number edge case: Nickel `9999999999` → Nix int `9999999999`
- [x] 4.3 Add a check for a fractional number: Nickel `3.14` → Nix float `3.14`
