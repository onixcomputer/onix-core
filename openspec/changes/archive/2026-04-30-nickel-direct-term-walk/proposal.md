## Why

Every Nickel evaluation goes through a JSON round-trip: Nickel's evaluated `RichTerm` is serialized to a JSON string via `serialize::to_string`, parsed back into a `serde_json::Value` tree via `serde_json::from_str`, then walked by `json_to_nix` to build Nix values. This allocates the full JSON string, escapes/unescapes all strings, and parses the entire document a second time. For small configs like sysctl tuning it doesn't matter, but it scales poorly as more `.ncl` files are evaluated per machine build — monitoring rules, service configs, backup policies.

## What Changes

- Replace the `serialize::to_string(Json)` → `serde_json::from_str` → `json_to_nix` pipeline with a direct walk over Nickel's `RichTerm` after `eval_full_for_export`
- The new `richterm_to_nix` function pattern-matches on `Term` variants (`Null`, `Bool`, `Num`, `Str`, `Record`, `Array`) and builds Nix values directly via the `nix-wasm-rust` ABI
- Remove the `serde_json` dependency from `nickel-plugin`
- All existing `evalNickel`, `evalNickelFile`, and any new `With`/`validate` variants use the direct walk

## Capabilities

### New Capabilities
- `nickel-direct-walk`: Direct conversion from Nickel's internal term representation to Nix values without JSON serialization round-trip

### Modified Capabilities
- `nickel-eval`: The internal serialization mechanism changes but the external behavior (inputs/outputs) is identical

## Impact

- `wasm-plugins/nickel-plugin/src/lib.rs` — replace `json_to_nix` and JSON serialization with `richterm_to_nix`
- `wasm-plugins/nickel-plugin/Cargo.toml` — remove `serde_json` dependency
- All existing flake checks must still pass (behavior-preserving change)
- WASM binary size may decrease slightly without serde_json
